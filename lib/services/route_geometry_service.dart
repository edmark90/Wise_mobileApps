import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../controllers/schedule_controller.dart';
import '../core/network/api_client.dart';
import '../core/network/network_exception.dart';
import '../models/collection_schedule.dart';
import '../models/schedule_route.dart';
import 'muntinlupa_geocoding.dart';

/// Reads or generates road-route geometry for a collection assignment.
///
/// Matches the website's `route-map.js`:
/// - ONE routing request for the whole waypoint chain (never per leg)
/// - `splitRouteIntoLegs` cuts that single road polyline at the scheduled stops
/// - real road geometry is never thrown away, only labelled when unavailable
/// - geometry is cached by waypoint chain, so ticks and re-opens never refetch
class RouteGeometryService {
  RouteGeometryService._();
  static final RouteGeometryService instance = RouteGeometryService._();

  static const DepotInfo defaultDepot = DepotInfo(
    name: 'Tunasan Dispatch Depot',
    address: 'Arandia Street, Barangay Tunasan, Muntinlupa City',
    position: MuntinlupaGeocoding.depotPosition,
  );

  /// Keyless fallback router, used only when the backend proxy cannot return
  /// road geometry, so the preview still follows real roads.
  static const String _osrmRouteUrl =
      'https://router.project-osrm.org/route/v1/driving/';

  /// Render cold starts can exceed the default request timeout.
  static const Duration _geometryTimeout = Duration(seconds: 45);

  /// In-memory geometry cache keyed by waypoint chain (website `_routeGeometries`).
  final Map<String, _CachedGeometry> _geometryCache = {};

  /// Deployed backends that predate `/routing/schedule-geometry` answer 404/405.
  /// Once seen, the probe is skipped for the session instead of costing a round
  /// trip every time a truck is opened.
  bool _savedGeometryEndpointMissing = false;

  Future<ScheduleRoute> getScheduleRoute(
    int scheduleId, {
    CollectionSchedule? schedule,
  }) async {
    final resolvedSchedule = schedule ??
        ScheduleController.instance.state?.data
            ?.cast<CollectionSchedule?>()
            .firstWhere((s) => s?.id == scheduleId, orElse: () => null);

    if (!_savedGeometryEndpointMissing) {
      try {
        final response = await ApiClient.instance.get(
          '/routing/schedule-geometry/$scheduleId',
        );

        if (response.statusCode == 200) {
          final data = ApiClient.instance.decode(
            response,
            fallback: 'Saved route geometry is unavailable right now.',
          );
          if (data is Map) {
            final savedRoute =
                ScheduleRoute.fromJson(data.cast<String, dynamic>());
            return _resegmentIfNeeded(savedRoute) ?? savedRoute;
          }
        } else if (response.statusCode == 404 || response.statusCode == 405) {
          _savedGeometryEndpointMissing = true;
        }
      } catch (_) {
        // Endpoint missing or unreachable: build from the schedule data.
      }
    }

    if (resolvedSchedule != null) {
      return buildRouteFromSchedule(resolvedSchedule);
    }

    throw const ApiException('This collection schedule could not be found.');
  }

  /// Re-cuts saved geometry whose stored legs do not line up 1:1 with the
  /// waypoint chain, so the map hides the correct part of the road.
  ScheduleRoute? _resegmentIfNeeded(ScheduleRoute savedRoute) {
    if (savedRoute.geometry.length < 2) return null;

    final waypoints = _waypoints(savedRoute.depot.position, savedRoute.stops);
    if (waypoints.length < 2) return null;

    final aligned = savedRoute.isSegmented &&
        savedRoute.legs.isNotEmpty &&
        savedRoute.legs.length == waypoints.length - 1;
    if (aligned) return null;

    final legs = splitRouteIntoLegs(savedRoute.geometry, waypoints);
    if (legs == null || legs.isEmpty) return null;

    return ScheduleRoute(
      scheduleId: savedRoute.scheduleId,
      truckNumber: savedRoute.truckNumber,
      routeName: savedRoute.routeName,
      startingPoint: savedRoute.startingPoint,
      collectionDate: savedRoute.collectionDate,
      collectionTime: savedRoute.collectionTime,
      status: savedRoute.status,
      depot: savedRoute.depot,
      stops: savedRoute.stops,
      geometry: savedRoute.geometry,
      legs: legs,
      isSegmented: true,
      distanceMeters: savedRoute.distanceMeters,
      durationSeconds: savedRoute.durationSeconds,
      message: savedRoute.message,
      warnings: savedRoute.warnings,
    );
  }

  /// Map-ready route from local data only - no network, no routing.
  ///
  /// Paints the map, depot and stop pins immediately so the user never waits on
  /// a spinner; the road line replaces it as soon as geometry arrives.
  ScheduleRoute buildLocalRoute(CollectionSchedule schedule) {
    final stops = _resolveStops(schedule);
    return ScheduleRoute(
      scheduleId: schedule.id,
      truckNumber: schedule.truckNumber,
      routeName: schedule.routeName ?? '${schedule.barangay} Route',
      startingPoint: schedule.startingPoint ?? defaultDepot.name,
      collectionDate: schedule.collectionDate,
      collectionTime: schedule.collectionTime,
      status: schedule.status,
      depot: defaultDepot,
      stops: stops,
      message: null,
      warnings: _stopWarnings(stops),
    );
  }

  Future<ScheduleRoute> buildRouteFromSchedule(
    CollectionSchedule schedule,
  ) async {
    final stops = _resolveStops(schedule);
    final waypoints = _waypoints(defaultDepot.position, stops);
    final warnings = _stopWarnings(stops);

    var geometry = const <LatLng>[];
    var legs = const <List<LatLng>>[];
    int? distanceMeters;
    int? durationSeconds;
    var isSegmented = false;
    String? message;

    if (waypoints.length >= 2) {
      final cacheKey =
          waypoints.map((p) => '${p.latitude},${p.longitude}').join('|');
      final cached = _geometryCache[cacheKey];

      if (cached != null) {
        geometry = cached.geometry;
        legs = cached.legs;
        isSegmented = cached.isSegmented;
        distanceMeters = cached.distanceMeters;
        durationSeconds = cached.durationSeconds;
      } else {
        final road = await _fetchRoadGeometry(waypoints);
        if (road != null) {
          geometry = road.geometry;
          legs = road.legs;
          isSegmented = true;
          distanceMeters = road.distanceMeters;
          durationSeconds = road.durationSeconds;
          _geometryCache[cacheKey] = _CachedGeometry(
            geometry: geometry,
            legs: legs,
            isSegmented: true,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
          );
        }
      }

      if (legs.isEmpty) {
        // No road geometry at all: direct stop-to-stop lines, clearly labelled
        // (the website's `isStraightFallback`). Never invent curves.
        legs = buildStraightLegs(waypoints);
        geometry = legs.expand((leg) => leg).toList();
        isSegmented = false;
        message = 'Road routing is unavailable right now, so direct '
            'stop-to-stop lines are shown instead of the road path.';
      }

      if (distanceMeters == null) {
        const distanceCalc = Distance();
        var total = 0.0;
        for (var i = 0; i < waypoints.length - 1; i++) {
          total += distanceCalc.as(
            LengthUnit.Meter,
            waypoints[i],
            waypoints[i + 1],
          );
        }
        distanceMeters = total.round();
        // ~25 km/h average driving speed plus 8 minutes per collection stop.
        durationSeconds = (total / (25000 / 3600) + stops.length * 480).round();
      }
    } else if (stops.isNotEmpty) {
      message = 'No collection stop has a usable coordinate, so a road route '
          'cannot be drawn.';
    }

    return ScheduleRoute(
      scheduleId: schedule.id,
      truckNumber: schedule.truckNumber,
      routeName: schedule.routeName ?? '${schedule.barangay} Route',
      startingPoint: schedule.startingPoint ?? defaultDepot.name,
      collectionDate: schedule.collectionDate,
      collectionTime: schedule.collectionTime,
      status: schedule.status,
      depot: defaultDepot,
      stops: stops,
      geometry: geometry,
      legs: legs,
      isSegmented: isSegmented,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      message: message,
      warnings: warnings,
    );
  }

  /// Backend proxy first (shared and cached server-side), then a keyless router
  /// for the same chain. Never per-leg stitching.
  static Future<_RoadGeometry?> _fetchRoadGeometry(
    List<LatLng> waypoints,
  ) async {
    final coordinates = [
      for (final point in waypoints) [point.longitude, point.latitude],
    ];

    try {
      final response = await ApiClient.instance.post(
        '/routing/directions',
        body: {'coordinates': coordinates},
        timeout: _geometryTimeout,
      );
      if (response.statusCode == 200) {
        final road =
            _withLegs(_parseGeoJson(jsonDecode(response.body)), waypoints);
        if (road != null) return road;
      }
    } catch (_) {
      // Proxy unreachable; try the keyless router below.
    }

    return _fetchOsrmRoute(waypoints);
  }

  /// Keyless road routing used only when the backend proxy fails.
  /// Same single request for the whole chain, split at the same waypoints.
  static Future<_RoadGeometry?> _fetchOsrmRoute(
    List<LatLng> waypoints,
  ) async {
    if (waypoints.length < 2) return null;

    final path =
        waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');

    try {
      final response = await http
          .get(
            Uri.parse(
              '$_osrmRouteUrl$path'
              '?overview=full&geometries=geojson&continue_straight=false',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map) return null;

      final routes = body['routes'];
      if (routes is! List || routes.isEmpty || routes.first is! Map) return null;

      final route = routes.first as Map;
      final geometry = route['geometry'];
      if (geometry is! Map || geometry['coordinates'] is! List) return null;

      final points = <LatLng>[];
      for (final raw in geometry['coordinates'] as List) {
        if (raw is List && raw.length >= 2) {
          points.add(
            LatLng((raw[1] as num).toDouble(), (raw[0] as num).toDouble()),
          );
        }
      }
      if (points.length < 2) return null;

      final legs = splitRouteIntoLegs(points, waypoints);
      if (legs == null || legs.isEmpty) return null;

      return _RoadGeometry(
        geometry: points,
        legs: legs,
        distanceMeters: (route['distance'] as num?)?.round(),
        durationSeconds: (route['duration'] as num?)?.round(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Cuts one continuous road polyline at the scheduled waypoints.
  static _RoadGeometry? _withLegs(
    _ParsedGeometry? parsed,
    List<LatLng> waypoints,
  ) {
    if (parsed == null) return null;
    final legs = splitRouteIntoLegs(parsed.points, waypoints);
    if (legs == null || legs.isEmpty) return null;
    return _RoadGeometry(
      geometry: parsed.points,
      legs: legs,
      distanceMeters: parsed.distanceMeters,
      durationSeconds: parsed.durationSeconds,
    );
  }

  /// Reads a GeoJSON LineString (`[lng, lat]`) plus its routing summary.
  static _ParsedGeometry? _parseGeoJson(dynamic body) {
    if (body is! Map) return null;

    final features = body['features'];
    final feature =
        (features is List && features.isNotEmpty && features.first is Map)
            ? features.first as Map
            : body;

    final geometry = feature['geometry'];
    if (geometry is! Map || geometry['coordinates'] is! List) return null;

    final points = <LatLng>[];
    for (final raw in geometry['coordinates'] as List) {
      if (raw is List && raw.length >= 2) {
        points.add(
          LatLng((raw[1] as num).toDouble(), (raw[0] as num).toDouble()),
        );
      }
    }
    if (points.length < 2) return null;

    final summary = (feature['properties'] as Map?)?['summary'] as Map?;
    return _ParsedGeometry(
      points: points,
      distanceMeters: (summary?['distance'] as num?)?.round(),
      durationSeconds: (summary?['duration'] as num?)?.round(),
    );
  }

  /// Stops of one assignment, resolved with the website's registry.
  List<RouteStopPoint> _resolveStops(CollectionSchedule schedule) {
    final rawStops = schedule.stops.isNotEmpty
        ? schedule.stops
        : [
            CollectionStop(
              id: schedule.id,
              scheduleId: schedule.id,
              barangay: schedule.barangay,
              street: schedule.zone.isNotEmpty
                  ? schedule.zone
                  : (schedule.startingPoint ?? ''),
              sequence: 1,
              collectionTime: schedule.collectionTime,
              status: schedule.status,
            ),
          ];

    final stops = <RouteStopPoint>[];
    // Waypoint 0 is the depot, so only stops with a real coordinate consume an
    // index - the same numbering the backend produces.
    var waypointCount = 0;

    for (var i = 0; i < rawStops.length; i++) {
      final stop = rawStops[i];
      final resolved = MuntinlupaGeocoding.resolve(
        barangay: stop.barangay,
        street: stop.street,
      );
      final position = resolved?.position;

      stops.add(
        RouteStopPoint(
          id: stop.id,
          barangay: stop.barangay,
          street: stop.street,
          sequence: stop.sequence > 0 ? stop.sequence : (i + 1),
          collectionTime: stop.collectionTime.isNotEmpty
              ? stop.collectionTime
              : schedule.collectionTime,
          status: stop.status.isNotEmpty ? stop.status : schedule.status,
          position: position,
          isExact: resolved?.isExact ?? false,
          waypointIndex: position == null ? null : ++waypointCount,
        ),
      );
    }
    return stops;
  }

  static List<LatLng> _waypoints(LatLng depot, List<RouteStopPoint> stops) {
    return <LatLng>[
      depot,
      for (final stop in stops)
        if (stop.position != null) stop.position!,
    ];
  }

  static List<String> _stopWarnings(List<RouteStopPoint> stops) {
    return [
      for (var i = 0; i < stops.length; i++)
        if (stops[i].position == null)
          'Stop ${i + 1} (${stops[i].barangay}): coordinates could not be resolved.',
    ];
  }

  /// Straight direct stop-to-stop legs used as fallback when no router answers.
  /// Exact match to website `buildStraightLegs(waypoints)`.
  static List<List<LatLng>> buildStraightLegs(List<LatLng> waypoints) {
    final legs = <List<LatLng>>[];
    for (var i = 0; i < waypoints.length - 1; i++) {
      legs.add([waypoints[i], waypoints[i + 1]]);
    }
    return legs;
  }

  /// Index of the polyline vertex closest to a waypoint, searched forward only.
  /// Exact match to website `findNearestVertexIndex(latlngs, target, fromIndex)`.
  static int? findNearestVertexIndex(
    List<LatLng> latlngs,
    LatLng target,
    int fromIndex,
  ) {
    final idx = _nearestVertexIndex(latlngs, target, fromIndex);
    if (idx == null) return null;

    final dLat = latlngs[idx].latitude - target.latitude;
    final dLng = latlngs[idx].longitude - target.longitude;
    // Reject matches further than roughly 1.5 km (~0.00018 sq-deg in Manila)
    if (dLat * dLat + dLng * dLng > 0.00018) return null;
    return idx;
  }

  /// Splits one continuous road polyline into ordered legs between consecutive
  /// stops. Geometry is never altered - only cut indices are computed - so every
  /// leg still follows real roads and `legs.length == waypoints.length - 1`.
  static List<List<LatLng>>? splitRouteIntoLegs(
    List<LatLng> latlngs,
    List<LatLng> waypoints,
  ) {
    if (latlngs.length < 2 || waypoints.length < 2) return null;

    // Website-compatible strict cut first.
    final strict = _cutAtWaypoints(latlngs, waypoints, 0.00018);
    if (strict != null) return strict;

    // A stop that the router snapped away from the polyline must never throw
    // away real road geometry: cut at the nearest vertex in scheduled order
    // instead, so the drawn line still follows the road.
    return _cutAtWaypoints(latlngs, waypoints, double.infinity);
  }

  static List<List<LatLng>>? _cutAtWaypoints(
    List<LatLng> latlngs,
    List<LatLng> waypoints,
    double maxDistanceSq,
  ) {
    final cuts = <int>[0];
    var cursor = 0;

    for (var w = 1; w < waypoints.length - 1; w++) {
      // Search forward only: stops must stay in their scheduled order.
      final idx = _nearestVertexIndex(latlngs, waypoints[w], cursor);
      if (idx == null || idx < cursor) return null;

      final dLat = latlngs[idx].latitude - waypoints[w].latitude;
      final dLng = latlngs[idx].longitude - waypoints[w].longitude;
      if (dLat * dLat + dLng * dLng > maxDistanceSq) return null;

      cuts.add(idx);
      cursor = idx;
    }
    cuts.add(latlngs.length - 1);

    final legs = <List<LatLng>>[];
    for (var i = 0; i < cuts.length - 1; i++) {
      final start = cuts[i];
      final end = cuts[i + 1];
      if (start == end) {
        // Two stops share one vertex: keep a two-point leg so the leg count
        // still matches the waypoint chain.
        legs.add([latlngs[start], latlngs[end]]);
      } else {
        legs.add(latlngs.sublist(start, end + 1));
      }
    }
    return legs;
  }

  static int? _nearestVertexIndex(
    List<LatLng> latlngs,
    LatLng target,
    int fromIndex,
  ) {
    var bestIdx = -1;
    var bestDist = double.infinity;
    for (var i = fromIndex < 0 ? 0 : fromIndex; i < latlngs.length; i++) {
      final dLat = latlngs[i].latitude - target.latitude;
      final dLng = latlngs[i].longitude - target.longitude;
      final dist = dLat * dLat + dLng * dLng;
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = i;
      }
    }
    return bestIdx == -1 ? null : bestIdx;
  }
}

class _CachedGeometry {
  final List<LatLng> geometry;
  final List<List<LatLng>> legs;
  final bool isSegmented;
  final int? distanceMeters;
  final int? durationSeconds;

  const _CachedGeometry({
    required this.geometry,
    required this.legs,
    required this.isSegmented,
    this.distanceMeters,
    this.durationSeconds,
  });
}

/// A road polyline plus its stop-to-stop legs.
class _RoadGeometry {
  final List<LatLng> geometry;
  final List<List<LatLng>> legs;
  final int? distanceMeters;
  final int? durationSeconds;

  const _RoadGeometry({
    required this.geometry,
    required this.legs,
    this.distanceMeters,
    this.durationSeconds,
  });
}

/// Parsed GeoJSON LineString with its routing summary.
class _ParsedGeometry {
  final List<LatLng> points;
  final int? distanceMeters;
  final int? durationSeconds;

  const _ParsedGeometry({
    required this.points,
    this.distanceMeters,
    this.durationSeconds,
  });
}
