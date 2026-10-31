import 'package:latlong2/latlong.dart';

import '../models/schedule_route.dart';

/// Schedule-derived phase of a truck. This system never uses GPS or live
/// tracking: the marker is always at the depot or at the latest scheduled stop.
enum SchedulePhase { atDepot, atStop, completed, cancelled, unavailable }

/// Where the truck is according to the saved schedule and Manila wall clock.
class SchedulePosition {
  final SchedulePhase phase;

  /// Index of the latest scheduled stop whose time has been reached.
  final int? stopIndex;
  final int? nextStopIndex;
  final LatLng? coordinate;
  final String detail;

  const SchedulePosition({
    required this.phase,
    this.stopIndex,
    this.nextStopIndex,
    this.coordinate,
    this.detail = '',
  });

  bool get isAtDepot => phase == SchedulePhase.atDepot;
  bool get isAtStop => phase == SchedulePhase.atStop;
  bool get isCompleted => phase == SchedulePhase.completed;
  bool get isCancelled => phase == SchedulePhase.cancelled;

  /// Whether a route line should still be visible.
  bool get hasActiveRoute =>
      phase == SchedulePhase.atDepot || phase == SchedulePhase.atStop;
}

/// Pure, testable schedule-based truck position + remaining-route logic.
///
/// Mirrors the website's `deriveRouteState` / `buildRemainingTrail`:
///  - future date or before the first stop → depot
///  - at/after a stop's time → that stop (no interpolation)
///  - at/after the final stop's time → Completed, no active route line
class SchedulePositionService {
  SchedulePositionService._();

  static const Duration _manilaOffset = Duration(hours: 8);

  /// Current Asia/Manila wall clock, independent of the device timezone.
  static DateTime manilaWallClock([DateTime? instant]) {
    final utc = (instant ?? DateTime.now()).toUtc().add(_manilaOffset);
    return DateTime(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
    );
  }

  static SchedulePosition resolve(ScheduleRoute route, {DateTime? now}) {
    final current = now ?? manilaWallClock();
    final depot = route.depot.position;

    if (route.stops.isEmpty) {
      return SchedulePosition(
        phase: SchedulePhase.unavailable,
        coordinate: depot,
        detail: 'No collection stops are scheduled for this assignment.',
      );
    }

    if (route.status == 'Cancelled') {
      return SchedulePosition(
        phase: SchedulePhase.cancelled,
        coordinate: depot,
        detail: 'This collection route was cancelled.',
      );
    }

    final date = _parseDate(route.collectionDate);
    if (date == null) {
      return SchedulePosition(
        phase: SchedulePhase.unavailable,
        coordinate: depot,
        detail: 'The scheduled collection date is unavailable.',
      );
    }

    final today = DateTime(current.year, current.month, current.day);
    final scheduledDay = DateTime(date.year, date.month, date.day);
    final lastStopIndex = route.stops.length - 1;
    final lastCoordinate = _coordinateAtOrBefore(route, lastStopIndex) ?? depot;

    // A past assignment is completed, exactly as the website treats it.
    if (scheduledDay.isBefore(today)) {
      return SchedulePosition(
        phase: SchedulePhase.completed,
        stopIndex: lastStopIndex,
        coordinate: lastCoordinate,
        detail: 'Completed on ${route.collectionDate}.',
      );
    }

    if (scheduledDay.isAfter(today)) {
      final firstTime = _parseClockMinutes(route.stops.first.collectionTime);
      return SchedulePosition(
        phase: SchedulePhase.atDepot,
        nextStopIndex: 0,
        coordinate: depot,
        detail: firstTime == null
            ? 'At the depot. Departure time is pending.'
            : 'At the depot. Departs at ${_formatMinutes(firstTime)}.',
      );
    }

    final nowMinutes = current.hour * 60 + current.minute;
    final times = route.stops
        .map((stop) => _parseClockMinutes(stop.collectionTime))
        .toList(growable: false);

    final firstTimed = times.indexWhere((t) => t != null);
    if (firstTimed < 0 || nowMinutes < times[firstTimed]!) {
      return SchedulePosition(
        phase: SchedulePhase.atDepot,
        nextStopIndex: 0,
        coordinate: depot,
        detail: firstTimed < 0
            ? 'At the depot. Departure time is pending.'
            : 'At the depot. Departs at ${_formatMinutes(times[firstTimed]!)}.',
      );
    }

    // Latest stop whose scheduled time has been reached. No interpolation.
    var reached = -1;
    for (var i = 0; i < times.length; i++) {
      final t = times[i];
      if (t != null && nowMinutes >= t) reached = i;
    }

    if (reached < 0) {
      return SchedulePosition(
        phase: SchedulePhase.atDepot,
        nextStopIndex: 0,
        coordinate: depot,
        detail: 'At the depot. Departure time is pending.',
      );
    }

    final reachedCoordinate = _coordinateAtOrBefore(route, reached) ?? depot;

    if (reached == lastStopIndex) {
      return SchedulePosition(
        phase: SchedulePhase.completed,
        stopIndex: reached,
        coordinate: reachedCoordinate,
        detail: 'Completed at ${route.stops[reached].placeName}.',
      );
    }

    return SchedulePosition(
      phase: SchedulePhase.atStop,
      stopIndex: reached,
      nextStopIndex: reached + 1,
      coordinate: reachedCoordinate,
      detail:
          'At ${route.stops[reached].placeName} — next: ${route.stops[reached + 1].placeName}.',
    );
  }

  /// Road segments that are still ahead of the truck.
  ///
  /// Completed legs are dropped. When the backend could not split the saved
  /// geometry into legs, the remaining portion is sliced from the full
  /// polyline; when no geometry exists, labelled straight lines are used.
  static List<List<LatLng>> remainingSegments(
    ScheduleRoute route,
    SchedulePosition position,
  ) {
    if (!position.hasActiveRoute) return const [];
    if (route.stops.isEmpty) return const [];

    if (route.isSegmented && route.legs.isNotEmpty) {
      final start = _remainingLegStart(route, position);
      if (start >= route.legs.length) return const [];
      return route.legs
          .skip(start)
          .where((leg) => leg.length >= 2)
          .toList(growable: false);
    }

    if (route.geometry.length >= 2) {
      if (position.isAtStop) {
        final idx = _nearestVertexIndex(route.geometry, position.coordinate);
        // The saved polyline cannot be aligned to the reached stop: draw the
        // remaining straight segments instead of re-showing completed road.
        if (idx == null) return _straightSegments(route, position);
        if (idx >= route.geometry.length - 1) return const [];
        return [route.geometry.sublist(idx)];
      }
      return [route.geometry];
    }

    return _straightSegments(route, position);
  }

  /// Continuous polyline of the truck's remaining planned journey.
  /// Exact match to website `buildRemainingTrail(td, state)`.
  /// Legs already driven are dropped. Completed or cancelled routes return empty.
  static List<LatLng> buildRemainingTrail(
    ScheduleRoute route,
    SchedulePosition position,
  ) {
    if (!position.hasActiveRoute || route.stops.isEmpty) return const [];

    final segments = remainingSegments(route, position);
    if (segments.isEmpty) return const [];

    final trail = <LatLng>[];
    for (final seg in segments) {
      for (final pt in seg) {
        if (trail.isEmpty ||
            trail.last.latitude != pt.latitude ||
            trail.last.longitude != pt.longitude) {
          trail.add(pt);
        }
      }
    }
    return trail.length >= 2 ? trail : const [];
  }

  /// Starting leg index (0 = depot → first valid stop).
  static int _remainingLegStart(
    ScheduleRoute route,
    SchedulePosition position,
  ) {
    if (position.isAtDepot || position.stopIndex == null) return 0;
    for (var i = position.stopIndex!; i >= 0; i--) {
      final wp = route.stops[i].waypointIndex;
      if (wp != null) return wp;
    }
    return 0;
  }

  /// Stop-to-stop direct lines used only when the backend has no road geometry.
  static List<List<LatLng>> _straightSegments(
    ScheduleRoute route,
    SchedulePosition position,
  ) {
    final chain = <LatLng>[route.depot.position];
    var currentChainIndex = 0;

    for (var i = 0; i < route.stops.length; i++) {
      final point = route.stops[i].position;
      if (point == null) continue;
      chain.add(point);
      if (position.isAtStop &&
          position.stopIndex != null &&
          i <= position.stopIndex!) {
        currentChainIndex = chain.length - 1;
      }
    }

    if (chain.length < 2) return const [];

    final segments = <List<LatLng>>[];
    for (var i = currentChainIndex; i < chain.length - 1; i++) {
      segments.add([chain[i], chain[i + 1]]);
    }
    return segments;
  }

  static LatLng? _coordinateAtOrBefore(ScheduleRoute route, int index) {
    for (var i = index; i >= 0; i--) {
      final point = route.stops[i].position;
      if (point != null) return point;
    }
    return null;
  }

  static int? _nearestVertexIndex(List<LatLng> geometry, LatLng? target) {
    if (target == null) return null;
    var bestIdx = -1;
    var bestDist = double.infinity;
    for (var i = 0; i < geometry.length; i++) {
      final dLat = geometry[i].latitude - target.latitude;
      final dLng = geometry[i].longitude - target.longitude;
      final dist = dLat * dLat + dLng * dLng;
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = i;
      }
    }
    // Never slice geometry that does not actually pass near the stop.
    if (bestIdx < 0 || bestDist > 0.00018) return null;
    return bestIdx;
  }

  static DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Parses `HH:mm`, `HH:mm:ss`, or `h:mm AM/PM` into minutes since midnight.
  static int? _parseClockMinutes(String raw) {
    if (raw.isEmpty) return null;
    var text = raw.trim().toLowerCase();
    var isPm = false;
    if (text.contains('pm')) {
      isPm = true;
      text = text.replaceAll('pm', '').trim();
    } else if (text.contains('am')) {
      text = text.replaceAll('am', '').trim();
    }

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (minute < 0 || minute > 59) return null;

    if (isPm && hour < 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;
    if (hour < 0 || hour > 23) return null;
    return hour * 60 + minute;
  }

  static String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $ampm';
  }
}
