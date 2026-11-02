import 'package:flutter/material.dart';

import '../../app_colors.dart';

/// Consistent status badge used across all screens.
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color backgroundColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    required this.backgroundColor,
    this.icon,
  });

  const StatusBadge.upcoming({super.key, required this.text})
      : color = AppColors.statusUpcoming,
        backgroundColor = AppColors.statusUpcomingBg,
        icon = Icons.event_available_rounded;

  const StatusBadge.arriving({super.key, required this.text})
      : color = AppColors.statusArriving,
        backgroundColor = AppColors.statusArrivingBg,
        icon = Icons.local_shipping_rounded;

  const StatusBadge.arrived({super.key, required this.text})
      : color = AppColors.statusArrived,
        backgroundColor = AppColors.statusArrivedBg,
        icon = Icons.check_circle_rounded;

  const StatusBadge.delayed({super.key, required this.text})
      : color = AppColors.statusDelayed,
        backgroundColor = AppColors.statusDelayedBg,
        icon = Icons.warning_amber_rounded;

  const StatusBadge.completed({super.key, required this.text})
      : color = AppColors.statusCompleted,
        backgroundColor = AppColors.statusCompletedBg,
        icon = Icons.task_alt_rounded;

  const StatusBadge.cancelled({super.key, required this.text})
      : color = AppColors.statusCancelled,
        backgroundColor = AppColors.statusCancelledBg,
        icon = Icons.cancel_outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Category badge for waste classification results.
class CategoryBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color backgroundColor;

  const CategoryBadge({
    super.key,
    required this.text,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Read/unread indicator dot.
class ReadIndicator extends StatelessWidget {
  final bool isRead;

  const ReadIndicator({
    super.key,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isRead ? Colors.transparent : const Color(0xFF2563EB),
        shape: BoxShape.circle,
        border: isRead ? null : Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}
