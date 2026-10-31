import 'package:latlong2/latlong.dart';

/// Configured dispatch depot returned by the backend.
class DepotInfo {
  final String name;
  final String address;
  final LatLng position;

  const DepotInfo({
    required this.name,
    required this.address,
    required this.position,
  });

  factory DepotInfo.fromJson(Map<String, dynamic> json) {
    return DepotInfo(
      name: json['name'] as String? ?? 'Dispatch Depot',
      address: json['address'] as String? ?? '',
      position: LatLng(
        _asDouble(json['latitude']) ?? 14.384538,
        _asDouble(json['longitude']) ?? 121.051391,
      ),
    );
  }
}

/// One scheduled collection stop with its resolved map position.
class RouteStopPoint {
  final int id;
  final String barangay;
  final String street;
  final int sequence;
  final String collectionTime;
  final String status;
  final LatLng? position;
  final bool isExact;

  /// Index into the route's waypoint chain (0 = depot), or null when the stop
  /// has no usable coordinate.
  final int? waypointIndex;

  const RouteStopPoint({
    required this.id,
    required this.barangay,
    this.street = '',
    this.sequence = 1,
    this.collectionTime = '',
    this.status = 'Upcoming',
    this.position,
    this.isExact = false,
    this.waypointIndex,
  });

  factory RouteStopPoint.fromJson(Map<String, dynamic> json) {
    final lat = _asDouble(json['latitude']);
    final lng = _asDouble(json['longitude']);
    return RouteStopPoint(
      id: _asInt(json['id']),
      barangay: json['barangay'] as String? ?? '',
      street: json['street'] as String? ?? '',
      sequence: _asInt(json['sequence'], fallback: 1),
      collectionTime: json['collection_time'] as String? ?? '',
      status: json['status'] as String? ?? 'Upcoming',
      position: (lat != null && lng != null) ? LatLng(lat, lng) : null,
      isExact: json['is_exact'] as bool? ?? false,
      waypointIndex: json['waypoint_index'] == null
          ? null
          : _asInt(json['waypoint_index']),
    );
  }

  String get placeName => street.isNotEmpty ? street : barangay;

  String get formattedTime {
    if (collectionTime.isEmpty) return '';
    final parts = collectionTime.split(':');
    if (parts.length < 2) return collectionTime;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $ampm';
  }
}

/// The saved road geometry for one schedule assignment.
class ScheduleRoute {
  final int scheduleId;
  final String truckNumber;
  final String routeName;
  final String startingPoint;
  final String collectionDate;
  final String collectionTime;
  final String status;
  final DepotInfo depot;
  final List<RouteStopPoint> stops;

  /// Full GeoJSON LineString converted to LatLng, or empty when unavailable.
  final List<LatLng> geometry;

  /// Ordered stop-to-stop legs (depot is the first waypoint). Each leg is a
  /// separate road polyline so completed segments can be hidden without
  /// another Directions request.
  final List<List<LatLng>> legs;
  final bool isSegmented;
  final int? distanceMeters;
  final int? durationSeconds;
  final String? message;
  final List<String> warnings;

  const ScheduleRoute({
    required this.scheduleId,
    required this.truckNumber,
    required this.routeName,
    required this.startingPoint,
    required this.collectionDate,
    required this.collectionTime,
    required this.status,
    required this.depot,
    required this.stops,
    this.geometry = const [],
    this.legs = const [],
    this.isSegmented = false,
    this.distanceMeters,
    this.durationSeconds,
    this.message,
    this.warnings = const [],
  });

  factory ScheduleRoute.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'] as List<dynamic>? ?? const [];
    final rawLegs = json['legs'] as List<dynamic>? ?? const [];

    return ScheduleRoute(
      scheduleId: _asInt(json['schedule_id']),
      truckNumber: json['truck_number'] as String? ?? '',
      routeName: json['route_name'] as String? ?? '',
      startingPoint: json['starting_point'] as String? ?? '',
      collectionDate: json['collection_date'] as String? ?? '',
      collectionTime: json['collection_time'] as String? ?? '',
      status: json['status'] as String? ?? 'Upcoming',
      depot: DepotInfo.fromJson(
        (json['depot'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      stops: rawStops
          .map(
            (s) => RouteStopPoint.fromJson((s as Map).cast<String, dynamic>()),
          )
          .toList(),
      geometry: _lineStringPoints(json['geometry']),
      legs: rawLegs
          .map(_coordinateList)
          .where((leg) => leg.length >= 2)
          .toList(),
      isSegmented: json['is_segmented'] as bool? ?? false,
      distanceMeters: json['distance_meters'] == null
          ? null
          : _asInt(json['distance_meters']),
      durationSeconds: json['duration_seconds'] == null
          ? null
          : _asInt(json['duration_seconds']),
      message: json['message'] as String?,
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((w) => w.toString())
          .toList(),
    );
  }

  bool get hasGeometry => geometry.length >= 2 || legs.isNotEmpty;

  String get distanceLabel {
    final m = distanceMeters;
    if (m == null || m <= 0) return '';
    return m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '$m m';
  }

  String get durationLabel {
    final s = durationSeconds;
    if (s == null || s <= 0) return '';
    return '${(s / 60).round()} min';
  }
}

/// Converts a GeoJSON geometry object to [LatLng] points.
List<LatLng> _lineStringPoints(dynamic geometry) {
  if (geometry is! Map) return const [];
  return _coordinateList(geometry['coordinates']);
}

/// Converts GeoJSON `[longitude, latitude]` coordinates to [LatLng].
List<LatLng> _coordinateList(dynamic coords) {
  if (coords is! List) return const [];
  final points = <LatLng>[];
  for (final raw in coords) {
    if (raw is! List || raw.length < 2) continue;
    final lng = _asDouble(raw[0]);
    final lat = _asDouble(raw[1]);
    if (lat == null || lng == null) continue;
    points.add(LatLng(lat, lng));
  }
  return points;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}
