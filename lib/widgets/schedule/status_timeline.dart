import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/notification_controller.dart';
import '../../controllers/schedule_controller.dart';
import '../../models/app_notification.dart';
import '../../models/collection_schedule.dart';

const Duration kArrivingLead = Duration(minutes: 30);
const Duration kCompletedAfter = Duration(minutes: 60);

int _statusRank(String status) {
  switch (normalizeScheduleStatus(status)) {
    case 'Upcoming':
      return 0;
    case 'Arriving':
      return 1;
    case 'Arrived':
      return 2;
    case 'Completed':
      return 3;
    default:
      return 0;
  }
}

String? _mapNotificationTypeToScheduleStatus(String notificationType) {
  switch (notificationType.trim()) {
    case 'Garbage Truck Arriving':
    case 'Truck Arriving':
      return 'Arriving';
    case 'Garbage Truck Arrived':
    case 'Truck Arrived':
      return 'Arrived';
    case 'Collection Completed':
      return 'Completed';
    case 'Delayed Collection':
    case 'Collection Delayed':
      return 'Delayed';
    case 'Cancelled Collection':
    case 'Collection Cancelled':
      return 'Cancelled';
    case 'Upcoming Collection':
    case 'Garbage Collection Scheduled':
    case 'Collection Rescheduled':
      return 'Upcoming';
    default:
      return null;
  }
}

String _datePrefix(String raw) {
  final trimmed = raw.trim();
  return trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed;
}

/// Finds the latest status reported by a notification in [NotificationController]
/// for [schedule] (and optionally a specific [stopBarangay]).
String? _latestNotificationStatus(
  CollectionSchedule schedule, {
  String? stopBarangay,
}) {
  final notifications = NotificationController.instance.allNotifications;
  if (notifications.isEmpty) return null;

  final sDate = _datePrefix(schedule.collectionDate);
  if (sDate.isEmpty) return null;

  final sRouteRaw = (schedule.routeName ?? '').trim().toLowerCase();
  final sRouteClean = schedule.displayRouteName.trim().toLowerCase();

  final scheduleBarangays = <String>{
    if (schedule.barangay.trim().isNotEmpty)
      schedule.barangay.trim().toLowerCase(),
    for (final st in schedule.stops)
      if (st.barangay.trim().isNotEmpty) st.barangay.trim().toLowerCase(),
  };

  for (final AppNotification n in notifications) {
    final mapped = _mapNotificationTypeToScheduleStatus(n.notificationType);
    if (mapped == null) continue;

    // 1. Match date
    final nDateRaw = _datePrefix(n.collectionDate);
    if (nDateRaw.isNotEmpty) {
      if (nDateRaw != sDate) continue;
    } else if (n.createdAt != null) {
      final local = n.createdAt!.toLocal();
      final createdDate =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      if (createdDate != sDate) continue;
    } else {
      continue;
    }

    // 2. Match route name and/or barangays
    final nRoute = n.routeName.trim().toLowerCase();
    final routeMatched = nRoute.isNotEmpty &&
        ((sRouteRaw.isNotEmpty &&
                (nRoute == sRouteRaw ||
                    sRouteRaw.contains(nRoute) ||
                    nRoute.contains(sRouteRaw))) ||
            (sRouteClean.isNotEmpty &&
                (nRoute == sRouteClean ||
                    sRouteClean.contains(nRoute) ||
                    nRoute.contains(sRouteClean))));

    // If notification specifies a different route name on the same day, skip
    if (nRoute.isNotEmpty && sRouteRaw.isNotEmpty && !routeMatched) {
      continue;
    }

    final nBarangays = NotificationController.instance
        .extractNotificationBarangays(n)
        .map((b) => b.trim().toLowerCase())
        .toSet();

    if (stopBarangay != null && stopBarangay.trim().isNotEmpty) {
      final targetBrgy = stopBarangay.trim().toLowerCase();
      if (nBarangays.isNotEmpty) {
        if (nBarangays.contains(targetBrgy)) {
          return mapped;
        }
        // If route-levelCompleted/Delayed/Cancelled notification matched the route name
        if (routeMatched &&
            (mapped == 'Completed' ||
                mapped == 'Delayed' ||
                mapped == 'Cancelled')) {
          return mapped;
        }
        continue;
      }
      if (routeMatched) return mapped;
    } else {
      if (routeMatched) return mapped;
      if (nBarangays.isNotEmpty &&
          nBarangays.any(scheduleBarangays.contains)) {
        return mapped;
      }
    }
  }
  return null;
}

/// Derives the live status for a single [stop] inside [schedule].
String deriveStopLiveStatus(
  CollectionSchedule schedule,
  CollectionStop stop, {
  int stopIndex = 0,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final parentNorm = normalizeScheduleStatus(schedule.status);
  final stopNorm = normalizeScheduleStatus(stop.status);
  final notifStopStatus = _latestNotificationStatus(
    schedule,
    stopBarangay: stop.barangay.isNotEmpty ? stop.barangay : schedule.barangay,
  );

  // Manual overrides (Cancelled / Delayed)
  if (parentNorm == 'Cancelled' ||
      stopNorm == 'Cancelled' ||
      notifStopStatus == 'Cancelled') {
    return 'Cancelled';
  }
  if (parentNorm == 'Completed' ||
      stopNorm == 'Completed' ||
      notifStopStatus == 'Completed') {
    return 'Completed';
  }
  if (parentNorm == 'Delayed' ||
      stopNorm == 'Delayed' ||
      notifStopStatus == 'Delayed') {
    return 'Delayed';
  }

  final d = DateTime.tryParse(schedule.collectionDate);
  final rawTime = stop.collectionTime.isNotEmpty
      ? stop.collectionTime
      : schedule.collectionTime;
  final t = _parseTime(rawTime);

  String clockStatus = 'Upcoming';
  if (d != null) {
    final today = DateTime(current.year, current.month, current.day);
    final schedDate = DateTime(d.year, d.month, d.day);

    if (schedDate.isBefore(today)) {
      return 'Completed';
    } else if (!schedDate.isAfter(today) && t != null) {
      final stopDt = DateTime(d.year, d.month, d.day, t.hour, t.minute);

      // Check if a subsequent stop has a later time that has already been reached
      DateTime? nextStopDt;
      if (stopIndex + 1 < schedule.stops.length) {
        final nextRaw = schedule.stops[stopIndex + 1].collectionTime;
        final nextParsed = _parseTime(nextRaw);
        if (nextParsed != null) {
          final candidate = DateTime(
            d.year,
            d.month,
            d.day,
            nextParsed.hour,
            nextParsed.minute,
          );
          if (candidate.isAfter(stopDt)) {
            nextStopDt = candidate;
          }
        }
      }

      final completedCutoff = nextStopDt ?? stopDt.add(kCompletedAfter);

      if (current.isBefore(stopDt.subtract(kArrivingLead))) {
        clockStatus = 'Upcoming';
      } else if (current.isBefore(stopDt)) {
        clockStatus = 'Arriving';
      } else if (current.isBefore(completedCutoff)) {
        clockStatus = 'Arrived';
      } else {
        clockStatus = 'Completed';
      }
    }
  }

  // Combine stop backend status, notification status, and clock status
  var best = stopNorm;
  if (notifStopStatus != null &&
      _statusRank(notifStopStatus) > _statusRank(best)) {
    best = notifStopStatus;
  }
  if (_statusRank(clockStatus) > _statusRank(best)) {
    best = clockStatus;
  }
  return best;
}

/// Returns the live status for [s], combining:
/// 1. Backend schedule status & stop statuses
/// 2. Real-time notifications (`Arriving`, `Arrived`, `Delayed`, `Cancelled`, `Completed`)
/// 3. Schedule time window (`T-30m` -> Arriving, `on-time` -> Arrived, `lastStop + 60m` -> Completed)
String deriveLiveStatus(CollectionSchedule s, [DateTime? now]) {
  final current = now ?? DateTime.now();
  final backendNorm = normalizeScheduleStatus(s.status);
  final notifStatus = _latestNotificationStatus(s);

  if (backendNorm == 'Cancelled' || notifStatus == 'Cancelled') {
    return 'Cancelled';
  }
  if (backendNorm == 'Completed' || notifStatus == 'Completed') {
    return 'Completed';
  }
  if (backendNorm == 'Delayed' || notifStatus == 'Delayed') {
    return 'Delayed';
  }

  final d = DateTime.tryParse(s.collectionDate);
  if (d != null) {
    final today = DateTime(current.year, current.month, current.day);
    final schedDate = DateTime(d.year, d.month, d.day);
    if (schedDate.isBefore(today)) return 'Completed';
  }

  // Evaluate multi-stop progression when stops exist
  String stopsAggregate = 'Upcoming';
  if (s.stops.isNotEmpty) {
    final stopStatuses = <String>[
      for (var i = 0; i < s.stops.length; i++)
        deriveStopLiveStatus(s, s.stops[i], stopIndex: i, now: current),
    ];

    if (stopStatuses.every((st) => st == 'Completed')) {
      return 'Completed';
    }
    if (stopStatuses.any((st) => st == 'Delayed')) {
      return 'Delayed';
    }
    if (stopStatuses.any((st) => st == 'Arrived' || st == 'Completed')) {
      stopsAggregate = 'Arrived';
    } else if (stopStatuses.any((st) => st == 'Arriving')) {
      stopsAggregate = 'Arriving';
    }
  }

  // Evaluate schedule-level clock status using earliest & latest stop times
  String clockStatus = 'Upcoming';
  if (d != null) {
    final today = DateTime(current.year, current.month, current.day);
    final schedDate = DateTime(d.year, d.month, d.day);

    if (!schedDate.isAfter(today)) {
      final parsedTimes = <DateTime>[];
      final mainTime = _parseTime(s.collectionTime);
      if (mainTime != null) {
        parsedTimes.add(
          DateTime(d.year, d.month, d.day, mainTime.hour, mainTime.minute),
        );
      }
      for (final stop in s.stops) {
        final st = _parseTime(stop.collectionTime);
        if (st != null) {
          parsedTimes.add(DateTime(d.year, d.month, d.day, st.hour, st.minute));
        }
      }

      if (parsedTimes.isNotEmpty) {
        parsedTimes.sort();
        final firstDt = parsedTimes.first;
        final lastDt = parsedTimes.last;

        if (current.isBefore(firstDt.subtract(kArrivingLead))) {
          clockStatus = 'Upcoming';
        } else if (current.isBefore(firstDt)) {
          clockStatus = 'Arriving';
        } else if (current.isBefore(lastDt.add(kCompletedAfter))) {
          clockStatus = 'Arrived';
        } else {
          clockStatus = 'Completed';
        }
      }
    }
  }

  // Pick the highest progression among backend status, notification status,
  // stop aggregate status, and clock status.
  var best = backendNorm;
  if (notifStatus != null && _statusRank(notifStatus) > _statusRank(best)) {
    best = notifStatus;
  }
  if (_statusRank(stopsAggregate) > _statusRank(best)) {
    best = stopsAggregate;
  }
  if (_statusRank(clockStatus) > _statusRank(best)) {
    best = clockStatus;
  }
  return best;
}

/// Parses "HH:mm", "HH:mm:ss", or "H:mm AM/PM"-style strings.
DateTime? _parseTime(String raw) {
  if (raw.isEmpty) return null;
  var text = raw.trim().toLowerCase();
  var isPm = false;
  if (text.contains('pm')) {
    isPm = true;
    text = text.replaceAll('pm', '');
  } else if (text.contains('am')) {
    text = text.replaceAll('am', '');
  }
  final parts = text.split(':');
  if (parts.isEmpty) return null;
  var h = int.tryParse(parts[0].trim()) ?? 0;
  final m = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
  if (isPm && h < 12) h += 12;
  if (!isPm && h == 12) h = 0;
  return DateTime(2000, 1, 1, h, m);
}

enum _State { past, active, upcoming }

/// Horizontal status stepper: Upcoming -> Arriving -> Arrived -> Completed,
/// with the active step pulsing and, when delayed/cancelled, an aware banner.
class StatusTimeline extends StatefulWidget {
  final CollectionSchedule schedule;

  const StatusTimeline({super.key, required this.schedule});

  @override
  State<StatusTimeline> createState() => _StatusTimelineState();
}

class _StatusTimelineState extends State<StatusTimeline> {
  static const List<String> _steps = [
    'Upcoming',
    'Arriving',
    'Arrived',
    'Completed',
  ];
  late Timer _timer;
  DateTime _now = DateTime.now();
  late String _status;

  late final Listenable _externalListeners = Listenable.merge([
    ScheduleController.instance,
    NotificationController.instance,
  ]);

  @override
  void initState() {
    super.initState();
    _status = deriveLiveStatus(widget.schedule, _now);
    _externalListeners.addListener(_onDataChanged);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _onDataChanged());
  }

  void _onDataChanged() {
    if (!mounted) return;
    final now = DateTime.now();
    final next = deriveLiveStatus(widget.schedule, now);
    if (next != _status) {
      setState(() {
        _now = now;
        _status = next;
      });
    }
  }

  @override
  void didUpdateWidget(covariant StatusTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    _now = DateTime.now();
    _status = deriveLiveStatus(widget.schedule, _now);
  }

  @override
  void dispose() {
    _externalListeners.removeListener(_onDataChanged);
    _timer.cancel();
    super.dispose();
  }

  static const _defaultColors = <String, Color>{
    'Upcoming': Color(0xFF64748B),
    'Arriving': Color(0xFFF59E0B),
    'Arrived': Color(0xFF2563EB),
    'Completed': Color(0xFF16A34A),
    'Delayed': Color(0xFFB45309),
    'Cancelled': Color(0xFFDC2626),
  };

  Color _stepColor(String step) {
    if (step == _status) return _defaultColors[step]!;
    return const Color(0xFFCBD5E1);
  }

  _State _stepState(String step) {
    final idx = _steps.indexOf(step);
    final cur = _steps.indexOf(_status);
    if (_status == 'Delayed' || _status == 'Cancelled') {
      return idx <= cur ? _State.past : _State.upcoming;
    }
    if (idx < cur) return _State.past;
    if (idx == cur) return _State.active;
    return _State.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    final isManual = _status == 'Delayed' || _status == 'Cancelled';
    final bannerColor = _defaultColors[_status] ?? const Color(0xFF6B7280);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: isManual ? 0.05 : 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isManual
                    ? (_status == 'Cancelled' ? Icons.cancel_rounded : Icons.schedule_rounded)
                    : Icons.track_changes_rounded,
                color: bannerColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Data Status',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bannerColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: bannerColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isManual)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: bannerColor, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _status == 'Cancelled'
                        ? 'This collection route has been cancelled.'
                        : 'This collection route is running behind schedule.',
                    style: TextStyle(fontSize: 12, color: bannerColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          else
            _buildStepper(),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Column(
      children: [
        Row(
          children: [
            for (int i = 0; i < _steps.length; i++) ...[
              _buildStep(_steps[i]),
              if (i < _steps.length - 1) _buildConnector(i),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_relativeLabel(_steps[0]), style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w500)),
            Text(_relativeLabel(_steps[1]), style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w500)),
            Text(_relativeLabel(_steps[2]), style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w500)),
            Text(_relativeLabel(_steps[3]), style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildStep(String step) {
    final color = _stepColor(step);
    final state = _stepState(step);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (state == _State.active)
                _Pulse(
                  color: color,
                  child: Container(width: 26, height: 26, decoration: BoxDecoration(color: color.withValues(alpha: 0.25), shape: BoxShape.circle)),
                ),
              Container(
                width: state == _State.active ? 18 : 14,
                height: state == _State.active ? 18 : 14,
                decoration: BoxDecoration(
                  color: state == _State.past ? color : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: state == _State.active ? 3 : 2),
                ),
                child: state == _State.past
                    ? Icon(Icons.check_rounded, size: 10, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          step,
          style: TextStyle(
            fontSize: 9,
            fontWeight: state == _State.active ? FontWeight.w800 : FontWeight.w600,
            color: state == _State.active
                ? color
                : (state == _State.past ? const Color(0xFF334155) : Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(int i) {
    final cur = _steps.indexOf(_status);
    final done = i < cur;
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: done ? _defaultColors[_steps[i]] : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  String _relativeLabel(String step) {
    switch (step) {
      case 'Upcoming':
        return _status == 'Upcoming' ? 'now' : '--:--';
      case 'Arriving':
        return 'T-30m';
      case 'Arrived':
        return 'on-time';
      case 'Completed':
        return '+60m';
      default:
        return '';
    }
  }
}

class _Pulse extends StatefulWidget {
  final Color color;
  final Widget child;

  const _Pulse({required this.color, required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.6).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 0.0).animate(_c),
        child: widget.child,
      ),
    );
  }
}