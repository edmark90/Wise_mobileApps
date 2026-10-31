import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/collection_schedule.dart';

/// Mirrors the backend's derive_schedule_status() so the timeline stays
/// live & accurate without a refetch on every minute boundary.
///
///   - future date                     -> Upcoming
///   - today, > 30 min before time     -> Upcoming
///   - today, in the 30-min lead      -> Arriving
///   - today, at time until +60 min    -> Arrived
///   - today, after +60 min            -> Completed
///   - past date                       -> Completed
const Duration kArrivingLead = Duration(minutes: 30);
const Duration kCompletedAfter = Duration(minutes: 60);

/// Returns the live server-derived status for a schedule. Manual statuses
/// (Delayed / Cancelled) are preserved.
String deriveLiveStatus(CollectionSchedule s, DateTime now) {
  if (s.status == 'Cancelled' || s.status == 'Delayed') return s.status;
  final d = DateTime.tryParse(s.collectionDate);
  final t = _parseTime(s.collectionTime);
  if (d == null || t == null) return s.status.isEmpty ? 'Upcoming' : s.status;

  final today = DateTime(now.year, now.month, now.day);
  final schedDate = DateTime(d.year, d.month, d.day);
  final schedDt = DateTime(d.year, d.month, d.day, t.hour, t.minute);

  if (schedDate.isBefore(today)) return 'Completed';
  if (schedDate.isAfter(today)) return 'Upcoming';
  if (now.isBefore(schedDt.subtract(kArrivingLead))) return 'Upcoming';
  if (now.isBefore(schedDt)) return 'Arriving';
  if (now.isBefore(schedDt.add(kCompletedAfter))) return 'Arrived';
  return 'Completed';
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
  var h = int.tryParse(parts[0]) ?? 0;
  final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
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
  static const List<String> _steps = ['Upcoming', 'Arriving', 'Arrived', 'Completed'];
  late Timer _timer;
  DateTime _now = DateTime.now();
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = deriveLiveStatus(widget.schedule, _now);
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      final next = deriveLiveStatus(widget.schedule, DateTime.now());
      if (next != _status && mounted) {
        setState(() {
          _now = DateTime.now();
          _status = next;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant StatusTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The truck selector can swap the selected assignment in place.
    if (oldWidget.schedule.id != widget.schedule.id) {
      _now = DateTime.now();
      _status = deriveLiveStatus(widget.schedule, _now);
    }
  }

  @override
  void dispose() {
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