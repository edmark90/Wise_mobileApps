import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app_colors.dart';
import '../../models/schedule_route.dart';
import '../../services/route_color_service.dart';
import '../../services/schedule_position_service.dart';

/// OpenStreetMap preview of the selected truck's saved planned route.
///
/// **EXACT MATCH** to website route-map.js styling:
/// - Deterministic route coloring ported from website `ROUTE_COLORS`
/// - Underneath glowing halo polyline + crisp white-bordered main polyline
/// - Accurate stop pins with route color and sequence numbers
/// - Color-matched schedule truck marker with pulse glow
/// - High-contrast Fleet Dispatch Depot pin
class ScheduleRouteMap extends StatefulWidget {
  final ScheduleRoute route;
  final SchedulePosition position;
  final List<List<LatLng>> segments;
  final Color? color;
  final List<double>? dashPattern;
  final ValueChanged<RouteStopPoint>? onStopTap;
  final VoidCallback? onDepotTap;

  const ScheduleRouteMap({
    super.key,
    required this.route,
    required this.position,
    required this.segments,
    this.color,
    this.dashPattern,
    this.onStopTap,
    this.onDepotTap,
  });

  @override
  State<ScheduleRouteMap> createState() => _ScheduleRouteMapState();
}

class _ScheduleRouteMapState extends State<ScheduleRouteMap> {
  static const LatLng _mapCenter = LatLng(14.4075, 121.0450);

  /// The pan/zoom centre always stays inside the Muntinlupa coverage area.
  static final LatLngBounds _muntinlupaBounds = LatLngBounds(
    const LatLng(14.3300, 120.9800),
    const LatLng(14.4850, 121.1600),
  );

  final MapController _mapController = MapController();
  String _fitSignature = '';

  @override
  void initState() {
    super.initState();
    _fitSignature = _signature();
  }

  @override
  void didUpdateWidget(covariant ScheduleRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _signature();
    if (next != _fitSignature) {
      _fitSignature = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitToRoute();
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String _signature() {
    final last = widget.segments.isNotEmpty ? widget.segments.last.last : null;
    return '${widget.route.scheduleId}|${widget.segments.length}|'
        '${last?.latitude},${last?.longitude}|${widget.color?.toARGB32()}';
  }

  List<LatLng> _fitPoints() {
    final points = <LatLng>[
      widget.route.depot.position,
      for (final stop in widget.route.stops)
        if (stop.position != null) stop.position!,
    ];
    for (final segment in widget.segments) {
      points.addAll(segment);
    }
    if (widget.position.coordinate != null) {
      points.add(widget.position.coordinate!);
    }
    return points;
  }

  void _fitToRoute() {
    final points = _fitPoints();
    if (points.length < 2) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(34),
        maxZoom: 16.5,
      ),
    );
  }

  Color _routeColor() {
    if (widget.color != null) return widget.color!;
    return RouteColorService.getColorForRoute(widget.route);
  }

  @override
  Widget build(BuildContext context) {
    final color = _routeColor();
    final isApproximate = !widget.route.isSegmented;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _fitPoints().isNotEmpty
            ? _fitPoints().first
            : _mapCenter,
        initialZoom: 13,
        minZoom: 11,
        maxZoom: 18,
        cameraConstraint: CameraConstraint.containCenter(
          bounds: _muntinlupaBounds,
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: _fitToRoute,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.wise',
          maxNativeZoom: 19,
        ),
        if (widget.segments.isNotEmpty)
          PolylineLayer(
            polylines: [
              // Underneath: halo polyline (soft glow matching website haloStyle)
              for (final segment in widget.segments)
                Polyline(
                  points: segment,
                  strokeWidth: 9,
                  color: color.withValues(alpha: 0.18),
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                  pattern: isApproximate
                      ? StrokePattern.dashed(segments: const [8, 6])
                      : const StrokePattern.solid(),
                ),
              // On top: main road route polyline
              for (final segment in widget.segments)
                Polyline(
                  points: segment,
                  strokeWidth: isApproximate ? 3.5 : 4.5,
                  color: color,
                  borderStrokeWidth: 1.2,
                  borderColor: Colors.white,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                  pattern: isApproximate
                      ? StrokePattern.dashed(segments: const [8, 6])
                      : (widget.dashPattern != null
                          ? StrokePattern.dashed(segments: widget.dashPattern!)
                          : const StrokePattern.solid()),
                ),
            ],
          ),
        MarkerLayer(markers: _buildMarkers(color)),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          showFlutterMapAttribution: false,
          attributions: const [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  List<Marker> _buildMarkers(Color color) {
    final markers = <Marker>[
      // Fleet Dispatch Depot Pin (Matching website DEFAULT_DEPOT marker)
      Marker(
        point: widget.route.depot.position,
        width: 36,
        height: 36,
        child: Tooltip(
          message: 'Fleet Dispatch Depot\n${widget.route.depot.name}\n${widget.route.depot.address}',
          child: GestureDetector(
            onTap: widget.onDepotTap,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF59E0B), width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'D',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFBBF24),
                ),
              ),
            ),
          ),
        ),
      ),
    ];

    // Scheduled Stop Pins. Pins keep their real coordinate so the road line
    // stays accurate; coincident stops are only separated in screen space.
    final pinOffsets = _stopPinOffsets();

    for (var i = 0; i < widget.route.stops.length; i++) {
      final stop = widget.route.stops[i];
      if (stop.position == null) continue;

      final isCurrent =
          widget.position.stopIndex == i &&
          (widget.position.isAtStop || widget.position.isCompleted);
      final isDone =
          widget.position.isCompleted ||
          (widget.position.stopIndex != null && i < widget.position.stopIndex!);

      markers.add(
        Marker(
          point: stop.position!,
          width: 34,
          height: 34,
          child: Transform.translate(
            offset: pinOffsets[i] ?? Offset.zero,
            child: Tooltip(
              message: 'Stop ${i + 1} · ${stop.placeName}\n${stop.formattedTime}',
              child: GestureDetector(
                onTap: widget.onStopTap == null
                    ? null
                    : () => widget.onStopTap!(stop),
                child: _mapBadge(
                  background: isDone ? const Color(0xFF94A3B8) : color,
                  ring: isCurrent ? color : null,
                  child: isDone
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        )
                      : Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Schedule-based Truck Marker (Color-matched to route)
    if (widget.position.coordinate != null) {
      final overlapsPin =
          widget.position.isAtDepot ||
          widget.position.isAtStop ||
          widget.position.isCompleted;
      markers.add(
        Marker(
          point: widget.position.coordinate!,
          width: 48,
          height: 48,
          alignment: overlapsPin ? Alignment.topRight : Alignment.center,
          child: Tooltip(
            message: widget.position.isCompleted
                ? '${widget.route.truckNumber.isNotEmpty ? widget.route.truckNumber : 'Truck'} — Completed'
                : '${widget.route.truckNumber.isNotEmpty ? widget.route.truckNumber : 'Truck'} — Schedule-based position',
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.40),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.local_shipping_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  /// Pixel spread for stops that share one coordinate.
  ///
  /// Only the marker is moved; the latitude/longitude the route polyline and
  /// the backend geometry use are never altered.
  Map<int, Offset> _stopPinOffsets() {
    final groups = <String, List<int>>{};
    for (var i = 0; i < widget.route.stops.length; i++) {
      final position = widget.route.stops[i].position;
      if (position == null) continue;
      final key = '${position.latitude.toStringAsFixed(5)},'
          '${position.longitude.toStringAsFixed(5)}';
      groups.putIfAbsent(key, () => <int>[]).add(i);
    }

    final offsets = <int, Offset>{};
    for (final group in groups.values) {
      if (group.length < 2) continue;
      for (var slot = 0; slot < group.length; slot++) {
        final dx = (slot - (group.length - 1) / 2) * 26;
        final dy = slot.isOdd ? -20.0 : 0.0;
        offsets[group[slot]] = Offset(dx, dy);
      }
    }
    return offsets;
  }

  Widget _mapBadge({
    required Color background,
    required Widget child,
    Color? ring,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          if (ring != null)
            BoxShadow(
              color: ring.withValues(alpha: 0.45),
              blurRadius: 0,
              spreadRadius: 4,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Empty/fallback map card used when geometry cannot be loaded.
class ScheduleRouteMapPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool loading;

  const ScheduleRouteMapPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.primary,
              ),
            )
          else
            Icon(icon, size: 34, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
