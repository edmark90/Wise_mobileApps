import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/collection_schedule.dart';

/// S-curve road preview through the day's stops, with numbered pins.
class RouteJourneyView extends StatefulWidget {
  final List<CollectionSchedule> stops;
  final int currentIndex;

  const RouteJourneyView({super.key, required this.stops, required this.currentIndex});

  @override
  State<RouteJourneyView> createState() => _RouteJourneyViewState();
}

class _RouteJourneyViewState extends State<RouteJourneyView>
    with SingleTickerProviderStateMixin {
  static const double _rowHeight = 60;
  static const double _pinLane = 44;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color _zoneColor(String zone) {
    switch (zone) {
      case 'Zone 1': return const Color(0xFF16A34A);
      case 'Zone 2': return const Color(0xFF3B82F6);
      case 'Zone 3': return const Color(0xFFF59E0B);
      case 'Zone 4': return const Color(0xFF8B5CF6);
      case 'Zone 5': return const Color(0xFFEC4899);
      default: return const Color(0xFF6B7280);
    }
  }

  // Pin color encodes the stop's role: start, end, or "you're here".
  Color _pinColor(int i) {
    if (i == widget.currentIndex) return const Color(0xFFF59E0B);
    if (i == 0) return AppColors.primary;
    if (i == widget.stops.length - 1) return const Color(0xFFEF4444);
    return const Color(0xFF94A3B8);
  }

  BoxDecoration _surface() => BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      );

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    if (stops.isEmpty) return const SizedBox.shrink();
    final animate = !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

    // Single stop: one centered card beside the pin, no road.
    if (stops.length == 1) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _surface(),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StopPin(
                number: '1',
                color: _pinColor(0),
                isCurrent: widget.currentIndex == 0,
                pulse: animate ? _pulse : null,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: _StopCard(
                  stop: stops[0],
                  isCurrent: widget.currentIndex == 0,
                  isFirst: true,
                  isLast: true,
                  zoneColor: _zoneColor(stops[0].zone),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: _surface(),
      child: SizedBox(
        height: _rowHeight * stops.length,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _RouteRoadPainter(
                stopCount: stops.length,
                rowHeight: _rowHeight,
                wave: 14,
              ),
            ),
            Column(
              children: List.generate(stops.length, (i) {
                final card = _StopCard(
                  stop: stops[i],
                  isCurrent: i == widget.currentIndex,
                  isFirst: i == 0,
                  isLast: i == stops.length - 1,
                  zoneColor: _zoneColor(stops[i].zone),
                );
                final pin = _StopPin(
                  number: '${i + 1}',
                  color: _pinColor(i),
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
          ],
        ),
      ),
    );
  }
}

/// Draws the snaking road with a dashed center.
class _RouteRoadPainter extends CustomPainter {
  final int stopCount;
  final double rowHeight;
  final double wave;

  _RouteRoadPainter({required this.stopCount, required this.rowHeight, required this.wave});

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

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFE2E8F0);
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF94A3B8);
    canvas.drawPath(path, bg);
    canvas.drawPath(path, fill);

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF59E0B);
    _drawDashed(canvas, path, dash);
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    final metric = path.computeMetrics().first;
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

  @override
  bool shouldRepaint(covariant _RouteRoadPainter oldDelegate) =>
      oldDelegate.stopCount != stopCount ||
      oldDelegate.rowHeight != rowHeight ||
      oldDelegate.wave != wave;
}

/// Numbered marker on the road; pulses when it's the current stop.
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
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pulse != null)
            ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 2.0).animate(pulse!),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.35, end: 0.0).animate(pulse!),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6),
              ],
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barangay + time + zone card that alternates beside the road.
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
      constraints: const BoxConstraints(maxWidth: 190),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? AppColors.primary.withValues(alpha: 0.4) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stop.barangay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ),
                if (tag != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: _tagColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
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
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 10, color: Colors.grey[500]),
                const SizedBox(width: 3),
                Text(
                  stop.formattedTime,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (stop.zone.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.location_on_rounded, size: 10, color: zoneColor),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      stop.zone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey[600]),
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
