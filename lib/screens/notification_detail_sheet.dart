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
              color: AppColors.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _typeBadge(notification),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.textTertiary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 5),
                      Text(
                        notification.fullDate,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _section('MESSAGE'),
                  _valueBox(notification.message),
                  if (notification.routeName.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _section('COLLECTION ROUTE'),
                    _valueBox(notification.routeName),
                  ],
                  if (notification.barangayList.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _section('AFFECTED BARANGAYS'),
                    _wrapChips(notification.barangayList),
                  ],
                  if (notification.reason.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _section('REASON / ADVISORY DETAILS'),
                    _valueBox(notification.reason),
                  ],
                  if (notification.additionalMessage.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _section('ADDITIONAL GUIDELINES'),
                    _valueBox(notification.additionalMessage),
                  ],
                  if (notification.collectionDate.isNotEmpty ||
                      notification.collectionTime.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _section('COLLECTION SCHEDULE'),
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
        border: Border.all(color: n.typeColor.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(n.icon, size: 14, color: n.typeColor),
          const SizedBox(width: 6),
          Text(
            n.notificationType,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: n.typeColor),
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
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _valueBox(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.45),
      ),
    );
  }

  Widget _wrapChips(List<String> items) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map(
            (b) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                b,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
          )
          .toList(),
    );
  }
}
