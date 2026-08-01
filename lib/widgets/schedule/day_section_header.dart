import 'package:flutter/material.dart';

import '../../app_colors.dart';

/// Day section header shown above a group of schedule cards.
class DaySectionHeader extends StatelessWidget {
  final String label;
  final String shortDate;
  final int routeCount;
  final int dayDiff;

  const DaySectionHeader({
    super.key,
    required this.label,
    required this.shortDate,
    required this.routeCount,
    required this.dayDiff,
  });

  Color get _color {
    if (dayDiff == 0) return AppColors.primary;
    if (dayDiff == 1) return const Color(0xFF3B82F6);
    return const Color(0xFF6B7280);
  }

  IconData get _icon {
    if (dayDiff == 0) return Icons.today_rounded;
    if (dayDiff == 1) return Icons.event_available_rounded;
    return Icons.calendar_month_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              shortDate,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$routeCount route${routeCount > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
