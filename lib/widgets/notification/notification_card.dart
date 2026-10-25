import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/app_notification.dart';

/// A single row in the notification inbox.
class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const NotificationCard({super.key, required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread ? const Color(0xFFF8FAFF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unread ? const Color(0xFFD6E4FF) : const Color(0xFFEEEEEE),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: notification.typeBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(notification.icon, color: notification.typeColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        notification.formattedTime,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
      ),
    );
  }

  Widget _priorityTag(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}
