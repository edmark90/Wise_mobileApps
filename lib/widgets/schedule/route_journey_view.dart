import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/collection_schedule.dart';

/// Modern S-curve road preview through the day's collection stops,
/// featuring animated truck progression, status tracking, and cartographic grid visuals.
class RouteJourneyView extends StatefulWidget {
  final List<CollectionSchedule> stops;
  final int currentIndex;

  const RouteJourneyView({
    super.key,
    required this.stops,
    required this.currentIndex,
  });

  @override
  State<RouteJourneyView> createState() => _RouteJourneyViewState();
}

class _RouteJourneyViewState extends State<RouteJourneyView>
    with TickerProviderStateMixin {
  static const double _rowHeight = 72;
  static const double _pinLane = 44;

  late final AnimationController _pulse;
  late final AnimationController _truckBounce;
  late final AnimationController _flagWave;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _truckBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _flagWave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _truckBounce.dispose();
    _flagWave.dispose();
    super.dispose();
  }

  Color _zoneColor(String zone) {
    switch (zone) {
      case 'Zone 1':
        return const Color(0xFF16A34A);
      case 'Zone 2':
        return const Color(0xFF3B82F6);
      case 'Zone 3':
        return const Color(0xFFF59E0B);
      case 'Zone 4':
        return const Color(0xFF8B5CF6);
      case 'Zone 5':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _pinColor(int i, CollectionSchedule stop) {
    final st = stop.status.toLowerCase();
    if (st == 'arriving' || st == 'arrived') return const Color(0xFFF59E0B);
    if (st == 'completed') return const Color(0xFF16A34A);
    if (i == 0) return AppColors.primary;
    if (i == widget.stops.length - 1) return const Color(0xFFEF4444);
    return const Color(0xFF64748B);
  }

  int _calculateTruckIndex(List<CollectionSchedule> stops) {
    if (stops.isEmpty) return -1;

    bool allUpcoming = true;
    for (final s in stops) {
      final st = s.status.toLowerCase();
      if (st != 'upcoming' && st != 'cancelled') {
        allUpcoming = false;
        break;
      }
    }
    if (allUpcoming) return -1;

    for (int i = stops.length - 1; i >= 0; i--) {
      final st = stops[i].status.toLowerCase();
      if (st == 'arriving' || st == 'arrived' || st == 'completed' || st == 'delayed') {
        return i;
      }
    }

    if (widget.currentIndex >= 0 && widget.currentIndex < stops.length) {
      return widget.currentIndex;
    }
    return 0;
  }

  bool _checkIsFinished(List<CollectionSchedule> stops) {
    if (stops.isEmpty) return false;
    int doneCount = 0;
    for (final s in stops) {
      final st = s.status.toLowerCase();
      if (st == 'completed' || st == 'arrived') {
        doneCount++;
      }
    }
    return doneCount == stops.length;
  }

  BoxDecoration _surface() => BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    if (stops.isEmpty) return const SizedBox.shrink();
    final animate = !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

    final truckIdx = _calculateTruckIndex(stops);
    final isFinished = _checkIsFinished(stops);

    // Single stop representation
    if (stops.length == 1) {
      final stop = stops[0];
      final showTruck = truckIdx == 0;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _surface(),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RouteGridPainter(),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StopPin(
                        number: '1',
                        color: _pinColor(0, stop),
                        isCurrent: widget.currentIndex == 0,
                        pulse: animate ? _pulse : null,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: _StopCard(
                          stop: stop,
                          isCurrent: widget.currentIndex == 0,
                          isFirst: true,
                          isLast: true,
                          zoneColor: _zoneColor(stop.zone),
                        ),
                      ),
                    ],
                  ),
                  if (showTruck) ...[
                    const SizedBox(height: 12),
                    _TruckBadge(
                      status: isFinished ? 'DONE' : (stop.truckNumber.isNotEmpty ? '${stop.truckNumber} • ${stop.status}' : stop.status),
                      isFinished: isFinished,
                      bounce: animate ? _truckBounce : null,
                      flagWave: animate ? _flagWave : null,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    final totalHeight = _rowHeight * stops.length;

    return Container(
      width: double.infinity,
      decoration: _surface(),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final centerX = width / 2;

          return SizedBox(
            height: totalHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background map grid
                CustomPaint(
                  painter: _RouteGridPainter(),
                ),

                // Road layer
                CustomPaint(
                  painter: _RouteRoadPainter(
                    stopCount: stops.length,
                    rowHeight: _rowHeight,
                    wave: 18,
                  ),
                ),

                // Stop items
                Column(
                  children: List.generate(stops.length, (i) {
                    final stop = stops[i];
                    final card = _StopCard(
                      stop: stop,
                      isCurrent: i == widget.currentIndex,
                      isFirst: i == 0,
                      isLast: i == stops.length - 1,
                      zoneColor: _zoneColor(stop.zone),
                    );
                    final pin = _StopPin(
                      number: '${i + 1}',
                      color: _pinColor(i, stop),
                      isCurrent: i == widget.currentIndex,
                      pulse: animate ? _pulse : null,
                    );
                    return SizedBox(
                      height: _rowHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (i.isEven)
                            Expanded(child: Align(alignment: Alignment.centerRight, child: card))
                          else
                            const Expanded(child: SizedBox()),
                          SizedBox(width: _pinLane, child: Center(child: pin)),
                          if (i.isOdd)
                            Expanded(child: Align(alignment: Alignment.centerLeft, child: card))
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    );
                  }),
                ),

                // Animated Truck Indicator
                if (truckIdx >= 0 && truckIdx < stops.length)
                  Positioned(
                    top: truckIdx * _rowHeight + (_rowHeight / 2) - 16,
                    left: truckIdx.isEven ? centerX + 14 : null,
                    right: truckIdx.isOdd ? centerX + 14 : null,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _TruckBadge(
                        key: ValueKey('truck_${truckIdx}_$isFinished'),
                        status: isFinished ? 'DONE' : (stops[truckIdx].truckNumber.isNotEmpty ? '${stops[truckIdx].truckNumber} • ${stops[truckIdx].status}' : stops[truckIdx].status),
                        isFinished: isFinished,
                        bounce: animate ? _truckBounce : null,
                        flagWave: animate ? _flagWave : null,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Cartographic grid background painter
class _RouteGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    final dotPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Snaking asphalt road with edge glow and animated center dash line.
class _RouteRoadPainter extends CustomPainter {
  final int stopCount;
  final double rowHeight;
  final double wave;

  _RouteRoadPainter({
    required this.stopCount,
    required this.rowHeight,
    required this.wave,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stopCount < 2) return;
    final cx = size.width / 2;
    final points = <Offset>[
      for (int i = 0; i < stopCount; i++) Offset(cx, rowHeight * (i + 0.5)),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final dy = curr.dy - prev.dy;
      final dir = i.isEven ? 1.0 : -1.0;
      path.cubicTo(
        prev.dx + wave * dir, prev.dy + dy * 0.4,
        curr.dx + wave * dir, curr.dy - dy * 0.4,
        curr.dx, curr.dy,
      );
    }

    // Outer glow
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF16A34A).withValues(alpha: 0.10);

    // Road outer casing
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFCBD5E1);

    // Asphalt fill
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF475569);

    canvas.drawPath(path, glow);
    canvas.drawPath(path, bg);
    canvas.drawPath(path, fill);

    // Center dash line
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFBBF24);

    _drawDashed(canvas, path, dash);
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      const dash = 5.0;
      const gap = 6.0;
      var distance = 0.0;
      while (distance < metric.length) {
        final start = distance.clamp(0.0, metric.length);
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RouteRoadPainter oldDelegate) =>
      oldDelegate.stopCount != stopCount ||
      oldDelegate.rowHeight != rowHeight ||
      oldDelegate.wave != wave;
}

/// Numbered pin marker on the road.
class _StopPin extends StatelessWidget {
  final String number;
  final Color color;
  final bool isCurrent;
  final Animation<double>? pulse;

  const _StopPin({
    required this.number,
    required this.color,
    required this.isCurrent,
    this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pulse != null && isCurrent)
            ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 2.0).animate(pulse!),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.35, end: 0.0).animate(pulse!),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            ),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stop card displaying barangay, timing, zone, and status badges.
class _StopCard extends StatelessWidget {
  final CollectionSchedule stop;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;
  final Color zoneColor;

  const _StopCard({
    required this.stop,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
    required this.zoneColor,
  });

  String? _tag() {
    if (isCurrent) return 'YOU ARE HERE';
    if (isFirst) return 'START';
    if (isLast) return 'END';
    return null;
  }

  Color _tagColor() => isCurrent
      ? const Color(0xFFF59E0B)
      : (isFirst ? const Color(0xFF16A34A) : const Color(0xFFEF4444));

  @override
  Widget build(BuildContext context) {
    final tag = _tag();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 165),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? AppColors.primary.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    stop.barangay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (tag != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: _tagColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: _tagColor(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 10, color: Colors.grey[500]),
                const SizedBox(width: 3),
                Text(
                  stop.formattedTime,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                if (stop.zone.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.location_on_rounded, size: 10, color: zoneColor),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      stop.zone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated Truck badge shown at the active stop along the route.
class _TruckBadge extends StatelessWidget {
  final String status;
  final bool isFinished;
  final Animation<double>? bounce;
  final Animation<double>? flagWave;

  const _TruckBadge({
    super.key,
    required this.status,
    required this.isFinished,
    this.bounce,
    this.flagWave,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = isFinished ? const Color(0xFFF59E0B) : const Color(0xFF16A34A);
    final darkColor = isFinished ? const Color(0xFFD97706) : const Color(0xFF15803D);

    Widget truckIcon = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, darkColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.local_shipping_rounded,
          size: 16,
          color: Colors.white,
        ),
      ),
    );

    if (bounce != null && !isFinished) {
      truckIcon = AnimatedBuilder(
        animation: bounce!,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -2.5 * bounce!.value),
            child: child,
          );
        },
        child: truckIcon,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          truckIcon,
          if (isFinished) ...[
            const SizedBox(width: 3),
            _WavingFlag(flagWave: flagWave),
          ],
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              status.toUpperCase(),
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavingFlag extends StatelessWidget {
  final Animation<double>? flagWave;

  const _WavingFlag({this.flagWave});

  @override
  Widget build(BuildContext context) {
    Widget flag = const Icon(
      Icons.flag_rounded,
      size: 18,
      color: Color(0xFFF59E0B),
    );

    if (flagWave != null) {
      flag = AnimatedBuilder(
        animation: flagWave!,
        builder: (context, child) {
          final angle = (-0.1 + (flagWave!.value * 0.2));
          return Transform.rotate(
            angle: angle,
            child: child,
          );
        },
        child: flag,
      );
    }

    return flag;
  }
}

