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
    if (dayDiff == 1) return const Color(0xFF0284C7);
    return AppColors.textPrimary;
  }

  Color get _bgTint {
    if (dayDiff == 0) return AppColors.primaryContainer;
    if (dayDiff == 1) return const Color(0xFFE0F2FE);
    return AppColors.surfaceContainer;
  }

  IconData get _icon {
    if (dayDiff == 0) return Icons.today_rounded;
    if (dayDiff == 1) return Icons.event_available_rounded;
    return Icons.calendar_month_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final isSpecialDay = dayDiff == 0 || dayDiff == 1;

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _bgTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: isSpecialDay ? color : AppColors.textSecondary, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '·  $shortDate',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '$routeCount route${routeCount > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
