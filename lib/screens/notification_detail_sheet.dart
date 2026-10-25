import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/app_notification.dart';

/// Full detail view for a single notification, opened as a bottom sheet.
class NotificationDetailSheet extends StatelessWidget {
  final AppNotification notification;

  const NotificationDetailSheet({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _typeBadge(notification),
                  const SizedBox(height: 12),
                  Text(
                    notification.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 15, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        notification.fullDate,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _section('Message'),
                  _valueBox(notification.message),
                  if (notification.routeName.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _section('Route'),
                    _valueBox(notification.routeName),
                  ],
                  if (notification.barangayList.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _section('Affected Barangays'),
                    _wrapChips(notification.barangayList),
                  ],
                  if (notification.reason.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _section('Reason'),
                    _valueBox(notification.reason),
                  ],
                  if (notification.additionalMessage.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _section('Additional Message'),
                    _valueBox(notification.additionalMessage),
                  ],
                  if (notification.collectionDate.isNotEmpty ||
                      notification.collectionTime.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _section('Collection Schedule'),
                    _valueBox(
                      [
                        if (notification.collectionDate.isNotEmpty) notification.collectionDate,
                        if (notification.collectionTime.isNotEmpty) notification.collectionTime,
                      ].join('  ·  '),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(AppNotification n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: n.typeBgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(n.icon, size: 15, color: n.typeColor),
          const SizedBox(width: 6),
          Text(
            n.notificationType,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: n.typeColor),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }

  Widget _valueBox(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
      ),
    );
  }

  Widget _wrapChips(List<String> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (b) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lightBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                b,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
          )
          .toList(),
    );
  }
}
