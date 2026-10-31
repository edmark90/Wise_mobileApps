import 'package:flutter/material.dart';

import '../models/collection_schedule.dart';
import '../models/schedule_route.dart';

/// Information about a route's deterministic display color and dash pattern.
class RouteColorInfo {
  final Color color;
  final int colorIndex;
  final List<double>? dashPattern;

  const RouteColorInfo({
    required this.color,
    required this.colorIndex,
    this.dashPattern,
  });
}

/// Exact deterministic route colors from the WISE website (`ROUTE_COLORS`).
///
/// Ported from `assets/js/components/route-map.js`:
/// - Palette of 12 distinct saturated colors readable over OSM tiles
/// - FNV-1a hash for deterministic assignment (never random)
/// - Collision resolution across simultaneous schedules on the same day
/// - Dash pattern cycling when assignments exceed palette size
class RouteColorService {
  RouteColorService._();

  /// High-contrast palette for simultaneously displayed truck routes.
  /// Exact match to website `ROUTE_COLORS` in `route-map.js`.
  static const List<Color> routeColors = [
    Color(0xFF1D4ED8), // 0: Blue
    Color(0xFFDC2626), // 1: Red
    Color(0xFF047857), // 2: Emerald
    Color(0xFF7E22CE), // 3: Purple
    Color(0xFFC2410C), // 4: Burnt orange
    Color(0xFF0F766E), // 5: Teal
    Color(0xFFBE185D), // 6: Pink
    Color(0xFF4338CA), // 7: Indigo
    Color(0xFFA16207), // 8: Ochre
    Color(0xFF0E7490), // 9: Cyan
    Color(0xFF7C2D12), // 10: Brown
    Color(0xFF4D7C0F), // 11: Olive
  ];

  /// Dash patterns used only when more routes are shown than palette entries.
  /// Exact match to website `ROUTE_DASH_PATTERNS`.
  static const List<List<double>?> routeDashPatterns = [
    null,
    [14.0, 8.0],
    [3.0, 7.0],
    [18.0, 6.0, 4.0, 6.0],
  ];

  /// Stable identity key for a route assignment.
  /// Matches website `routeIdentityKey(a)`.
  static String routeIdentityKey({
    int? id,
    String? routeName,
    String? truckNumber,
  }) {
    if (id != null && id > 0) return 'id:$id';
    return 'route:${routeName ?? ''}|${truckNumber ?? ''}';
  }

  /// 32-bit FNV-1a hash matching website `hashStringToUint(str)`.
  static int hashStringToUint(String str) {
    var h = 2166136261;
    for (final code in str.codeUnits) {
      h ^= code;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h;
  }

  /// Assigns each assignment a unique, deterministic route color.
  ///
  /// Exact port of website `assignRouteColors(assignments)`:
  /// - Base color = hash of stable route id.
  /// - Collisions between simultaneously displayed routes are resolved in sorted-key order.
  /// - With more routes than palette entries, colors repeat with distinct dash patterns.
  static Map<int, RouteColorInfo> assignRouteColors(List<CollectionSchedule> assignments) {
    final result = <int, RouteColorInfo>{};
    if (assignments.isEmpty) return result;

    final entries = [
      for (var i = 0; i < assignments.length; i++)
        (
          idx: i,
          key: routeIdentityKey(
            id: assignments[i].id,
            routeName: assignments[i].routeName,
            truckNumber: assignments[i].truckNumber,
          ),
        ),
    ];

    entries.sort((a, b) {
      final cmp = a.key.compareTo(b.key);
      return cmp != 0 ? cmp : a.idx.compareTo(b.idx);
    });

    final paletteUses = <int, int>{};

    for (final entry in entries) {
      final start = hashStringToUint(entry.key) % routeColors.length;
      var chosen = -1;
      for (var step = 0; step < routeColors.length; step++) {
        final cand = (start + step) % routeColors.length;
        if (!paletteUses.containsKey(cand)) {
          chosen = cand;
          break;
        }
      }
      var repeat = 0;
      if (chosen == -1) {
        chosen = start;
        repeat = paletteUses[chosen] ?? 0;
      }
      paletteUses[chosen] = (paletteUses[chosen] ?? 0) + 1;

      result[entry.idx] = RouteColorInfo(
        color: routeColors[chosen],
        colorIndex: chosen,
        dashPattern: repeat > 0
            ? routeDashPatterns[repeat % routeDashPatterns.length]
            : null,
      );
    }

    return result;
  }

  /// Gets the deterministic route color for a single schedule.
  static RouteColorInfo getColorForSchedule(
    CollectionSchedule schedule, {
    List<CollectionSchedule>? allAssignments,
  }) {
    if (allAssignments != null && allAssignments.isNotEmpty) {
      final map = assignRouteColors(allAssignments);
      final idx = allAssignments.indexWhere((s) => s.id == schedule.id);
      if (idx >= 0 && map.containsKey(idx)) {
        return map[idx]!;
      }
    }

    final key = routeIdentityKey(
      id: schedule.id,
      routeName: schedule.routeName,
      truckNumber: schedule.truckNumber,
    );
    final idx = hashStringToUint(key) % routeColors.length;
    return RouteColorInfo(color: routeColors[idx], colorIndex: idx);
  }

  /// Gets the deterministic route color for a ScheduleRoute.
  static Color getColorForRoute(
    ScheduleRoute route, {
    List<CollectionSchedule>? allAssignments,
  }) {
    if (allAssignments != null && allAssignments.isNotEmpty) {
      final map = assignRouteColors(allAssignments);
      final idx = allAssignments.indexWhere((s) => s.id == route.scheduleId);
      if (idx >= 0 && map.containsKey(idx)) {
        return map[idx]!.color;
      }
    }

    final key = 'id:${route.scheduleId}';
    final idx = hashStringToUint(key) % routeColors.length;
    return routeColors[idx];
  }
}
