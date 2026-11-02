import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../design_system/widgets/app_card.dart';
import '../../models/app_notification.dart';

/// A single row in the notification inbox.
class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const NotificationCard({super.key, required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;

    return AppCard(
      padding: const EdgeInsets.all(14),
      color: unread ? const Color(0xFFF8FAFC) : Colors.white,
      borderColor: unread ? AppColors.primary.withValues(alpha: 0.25) : AppColors.border,
      borderWidth: 1,
      elevation: unread ? 1.5 : 0.5,
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: notification.typeBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(notification.icon, color: notification.typeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  notification.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      notification.formattedTime,
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    if (notification.priority == 'Emergency')
                      _priorityTag('EMERGENCY', const Color(0xFFB91C1C), const Color(0xFFFEE2E2))
                    else if (notification.priority == 'Important')
                      _priorityTag('IMPORTANT', const Color(0xFF92400E), const Color(0xFFFEF3C7))
                    else
                      _priorityTag('NORMAL', const Color(0xFF15803D), const Color(0xFFF0FDF4)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priorityTag(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}
