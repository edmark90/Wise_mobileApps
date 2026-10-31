import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../core/network/network_exception.dart';
import '../../models/collection_schedule.dart';
import '../../models/schedule_route.dart';
import '../../services/route_color_service.dart';
import '../../services/route_geometry_service.dart';
import '../../services/schedule_position_service.dart';
import 'schedule_route_map.dart';

typedef RouteGeometryLoader = Future<ScheduleRoute> Function(int scheduleId);

/// Route map for one selected truck assignment.
///
/// Geometry is fetched once per assignment and cached for the lifetime of the
/// sheet. Switching trucks only swaps the displayed saved route — it never
/// requests road directions again. A lightweight timer re-evaluates the
/// schedule-based position; it never animates or polls the routing API.
class TruckRouteSection extends StatefulWidget {
  final List<CollectionSchedule> assignments;
  final int selectedScheduleId;
  final ValueChanged<CollectionSchedule> onScheduleSelected;

  /// Injectable for tests; defaults to the authenticated API service.
  final RouteGeometryLoader? loadRoute;

  const TruckRouteSection({
    super.key,
    required this.assignments,
    required this.selectedScheduleId,
    required this.onScheduleSelected,
    this.loadRoute,
  });

  @override
  State<TruckRouteSection> createState() => _TruckRouteSectionState();
}

class _TruckRouteSectionState extends State<TruckRouteSection> {
  final Map<int, ScheduleRoute> _routes = {};
  final Map<int, String> _errors = {};
  final Set<int> _loading = {};

  Timer? _ticker;
  DateTime _now = SchedulePositionService.manilaWallClock();
  SchedulePosition? _position;
  int? _selectedStopId;
  bool _showDepot = false;

  @override
  void initState() {
    super.initState();
    _load(widget.selectedScheduleId);
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant TruckRouteSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedScheduleId != widget.selectedScheduleId) {
      _selectedStopId = null;
      _showDepot = false;
      _now = SchedulePositionService.manilaWallClock();
      final cached = _routes[widget.selectedScheduleId];
      _position = cached == null
          ? null
          : SchedulePositionService.resolve(cached, now: _now);
      if (cached == null) _load(widget.selectedScheduleId);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load(int scheduleId, {bool force = false}) async {
    if (_loading.contains(scheduleId)) return;
    if (!force && _routes.containsKey(scheduleId)) return;

    setState(() {
      _loading.add(scheduleId);
      _errors.remove(scheduleId);
    });

    try {
      final assignment = widget.assignments.cast<CollectionSchedule?>().firstWhere(
            (s) => s?.id == scheduleId,
            orElse: () => null,
          );

      // Paint the map, depot and stop pins straight away; the road line is
      // filled in as soon as the saved geometry arrives.
      if (assignment != null && !_routes.containsKey(scheduleId)) {
        final local = RouteGeometryService.instance.buildLocalRoute(assignment);
        setState(() {
          _routes[scheduleId] = local;
          if (widget.selectedScheduleId == scheduleId) {
            _now = SchedulePositionService.manilaWallClock();
            _position = SchedulePositionService.resolve(local, now: _now);
          }
        });
      }

      final loader = widget.loadRoute;
      final route = loader != null
          ? await loader(scheduleId)
          : await RouteGeometryService.instance.getScheduleRoute(
              scheduleId,
              schedule: assignment,
            );
      if (!mounted) return;
      setState(() {
        _routes[scheduleId] = route;
        _loading.remove(scheduleId);
        if (widget.selectedScheduleId == scheduleId) {
          _now = SchedulePositionService.manilaWallClock();
          _position = SchedulePositionService.resolve(route, now: _now);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading.remove(scheduleId);
        _errors[scheduleId] = _messageFor(error);
        if (widget.selectedScheduleId == scheduleId) _position = null;
      });
    }
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is NetworkException) return error.message;
    return 'Saved route geometry could not be loaded.';
  }

  void _tick() {
    final route = _routes[widget.selectedScheduleId];
    if (route == null || !mounted) return;
    final next = SchedulePositionService.resolve(
      route,
      now: SchedulePositionService.manilaWallClock(),
    );
    final previous = _position;
    if (previous == null ||
        previous.phase != next.phase ||
        previous.stopIndex != next.stopIndex ||
        previous.nextStopIndex != next.nextStopIndex) {
      setState(() {
        _now = SchedulePositionService.manilaWallClock();
        _position = next;
      });
    }
  }

  void _refreshSelected() {
    _selectedStopId = null;
    _showDepot = false;
    final id = widget.selectedScheduleId;
    final cached = _routes[id];
    if (cached != null) {
      setState(() {
        _now = SchedulePositionService.manilaWallClock();
        _position = SchedulePositionService.resolve(cached, now: _now);
      });
    }
    _load(id, force: true);
  }

  @override
  Widget build(BuildContext context) {
    final route = _routes[widget.selectedScheduleId];
    final error = _errors[widget.selectedScheduleId];
    final isLoading = _loading.contains(widget.selectedScheduleId);
    final assignedColors = RouteColorService.assignRouteColors(widget.assignments);

    final selectedIdx = widget.assignments.indexWhere((s) => s.id == widget.selectedScheduleId);
    final selectedColor = (selectedIdx >= 0 ? assignedColors[selectedIdx]?.color : null) ??
        (route != null ? RouteColorService.getColorForRoute(route) : const Color(0xFF1D4ED8));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_rounded, size: 16, color: selectedColor),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Truck Route',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selectedColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: selectedColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'SCHEDULE-BASED',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: selectedColor,
                  ),
                ),
              ),
              IconButton(
                onPressed: isLoading ? null : _refreshSelected,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Refresh schedule position',
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          if (widget.assignments.length > 1) ...[
            const SizedBox(height: 6),
            const Text(
              'Select truck',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var i = 0; i < widget.assignments.length; i++)
                  _truckChip(
                    widget.assignments[i],
                    i,
                    assignedColors[i]?.color ??
                        RouteColorService.getColorForSchedule(widget.assignments[i]).color,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (route != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRoute(context, route, assignedColors),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  _noteCard(
                    icon: Icons.cloud_off_rounded,
                    color: AppColors.warning,
                    text: 'Showing the last saved route. $error',
                  ),
                ],
              ],
            )
          else if (isLoading)
            const ScheduleRouteMapPlaceholder(
              icon: Icons.route_rounded,
              title: 'Loading saved truck route…',
              loading: true,
            )
          else if (error != null)
            Column(
              children: [
                ScheduleRouteMapPlaceholder(
                  icon: Icons.cloud_off_rounded,
                  title: 'Route map unavailable',
                  message: error,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _load(widget.selectedScheduleId, force: true),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Try again'),
                  ),
                ),
              ],
            )
          else
            const ScheduleRouteMapPlaceholder(
              icon: Icons.route_rounded,
              title: 'No truck route available',
              message: 'This assignment has no saved route to display.',
            ),
        ],
      ),
    );
  }

  Widget _truckChip(CollectionSchedule schedule, int index, Color truckColor) {
    final selected = schedule.id == widget.selectedScheduleId;
    final label = schedule.truckNumber.isNotEmpty
        ? schedule.truckNumber
        : 'Truck ${index + 1}';

    return ChoiceChip(
      selected: selected,
      onSelected: (_) => widget.onScheduleSelected(schedule),
      avatar: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          color: truckColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selectedColor: truckColor,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? truckColor : AppColors.border,
        width: selected ? 1.5 : 1.0,
      ),
      visualDensity: VisualDensity.compact,
      showCheckmark: false,
    );
  }

  Widget _buildRoute(
    BuildContext context,
    ScheduleRoute route,
    Map<int, RouteColorInfo> assignedColors,
  ) {
    final position =
        _position ?? SchedulePositionService.resolve(route, now: _now);
    final segments = SchedulePositionService.remainingSegments(route, position);
    final hasCoordinates = route.stops.any((s) => s.position != null);

    final selectedIndex = widget.assignments.indexWhere((s) => s.id == route.scheduleId);
    final colorInfo = (selectedIndex >= 0 ? assignedColors[selectedIndex] : null) ??
        RouteColorService.getColorForSchedule(
          widget.assignments.firstWhere(
            (s) => s.id == route.scheduleId,
            orElse: () => CollectionSchedule(
              id: route.scheduleId,
              truckNumber: route.truckNumber,
              barangay: '',
              zone: '',
              collectionDate: route.collectionDate,
              collectionTime: route.collectionTime,
              assignedPersonnel: '',
              status: route.status,
            ),
          ),
          allAssignments: widget.assignments,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (route.stops.isEmpty)
          const ScheduleRouteMapPlaceholder(
            icon: Icons.event_busy_rounded,
            title: 'No stops scheduled',
            message: 'This truck assignment has no collection stops.',
          )
        else if (!hasCoordinates)
          const ScheduleRouteMapPlaceholder(
            icon: Icons.location_off_rounded,
            title: 'Stop coordinates unavailable',
            message:
                'The assigned stops do not have usable map coordinates yet.',
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 290,
              child: ScheduleRouteMap(
                route: route,
                position: position,
                segments: segments,
                color: colorInfo.color,
                dashPattern: colorInfo.dashPattern,
                onStopTap: (stop) => setState(() {
                  _selectedStopId = stop.id;
                  _showDepot = false;
                }),
                onDepotTap: () => setState(() {
                  _selectedStopId = null;
                  _showDepot = true;
                }),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 12,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule-based position — not live GPS',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(
                      fontSize: 8,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (route.distanceLabel.isNotEmpty)
              Text(
                route.distanceLabel,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _positionPanel(route, position),
        if (!route.isSegmented &&
            route.hasGeometry &&
            (route.message == null || route.message!.isEmpty)) ...[
          const SizedBox(height: 8),
          _noteCard(
            icon: Icons.alt_route_rounded,
            color: AppColors.warning,
            text:
                'Road geometry could not be matched to every stop. The dashed line is an approximate route.',
          ),
        ],
        if (route.message != null && route.message!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _noteCard(
            icon: Icons.cloud_off_rounded,
            color: AppColors.warning,
            text: route.message!,
          ),
        ] else if (route.warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          _noteCard(
            icon: Icons.info_outline_rounded,
            color: AppColors.warning,
            text: route.warnings.first,
          ),
        ],
        if (_selectedStopId != null) _stopDetail(route),
        if (_showDepot) _depotDetail(route),
      ],
    );
  }

  Widget _positionPanel(ScheduleRoute route, SchedulePosition position) {
    final nextStop =
        (position.nextStopIndex != null &&
            position.nextStopIndex! >= 0 &&
            position.nextStopIndex! < route.stops.length)
        ? route.stops[position.nextStopIndex!]
        : null;

    final (label, color, icon) = switch (position.phase) {
      SchedulePhase.atDepot => (
        'At Depot',
        const Color(0xFF1D4ED8),
        Icons.warehouse_rounded,
      ),
      SchedulePhase.atStop => (
        'At Scheduled Stop',
        const Color(0xFFB45309),
        Icons.local_shipping_rounded,
      ),
      SchedulePhase.completed => (
        'Completed',
        AppColors.statusCompleted,
        Icons.check_circle_rounded,
      ),
      SchedulePhase.cancelled => (
        'Cancelled',
        AppColors.statusCancelled,
        Icons.cancel_rounded,
      ),
      SchedulePhase.unavailable => (
        'Unavailable',
        AppColors.textTertiary,
        Icons.help_outline_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const Spacer(),
              if (position.stopIndex != null && !position.isAtDepot)
                Text(
                  'Stop ${position.stopIndex! + 1} of ${route.stops.length}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            position.isCompleted
                ? 'All scheduled stops have been reached. No further route line is shown.'
                : position.detail,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          if (nextStop != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 13,
                    color: Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Next: ${nextStop.placeName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  if (nextStop.formattedTime.isNotEmpty)
                    Text(
                      nextStop.formattedTime,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stopDetail(ScheduleRoute route) {
    RouteStopPoint? stop;
    for (final candidate in route.stops) {
      if (candidate.id == _selectedStopId) {
        stop = candidate;
        break;
      }
    }
    if (stop == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _noteCard(
        icon: Icons.pin_drop_rounded,
        color: AppColors.primary,
        text:
            'Stop ${stop.sequence}: ${stop.placeName}'
            '${stop.formattedTime.isNotEmpty ? ' · ${stop.formattedTime}' : ''}'
            '${stop.isExact ? '' : ' · approximate position'}',
        onClose: () => setState(() => _selectedStopId = null),
      ),
    );
  }

  Widget _depotDetail(ScheduleRoute route) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _noteCard(
        icon: Icons.warehouse_rounded,
        color: const Color(0xFF0F172A),
        text: '${route.depot.name} · ${route.depot.address}',
        onClose: () => setState(() => _showDepot = false),
      ),
    );
  }

  Widget _noteCard({
    required IconData icon,
    required Color color,
    required String text,
    VoidCallback? onClose,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.35,
                color: color == AppColors.warning
                    ? const Color(0xFF78350F)
                    : AppColors.textSecondary,
              ),
            ),
          ),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close_rounded, size: 14, color: color),
            ),
        ],
      ),
    );
  }
}
