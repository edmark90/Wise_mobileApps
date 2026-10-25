import 'dart:convert';

import 'package:flutter/material.dart' show Color, Icons, IconData;

/// A notification delivered to the citizen's inbox (from `/notifications/my`).
class AppNotification {
  final int id;
  final String title;
  final String message;
  final String notificationType;
  final String category;
  final String priority;
  final String routeName;
  final String affectedBarangays;
  final String reason;
  final String additionalMessage;
  final String collectionDate;
  final String collectionTime;
  final DateTime? createdAt;
  final bool isRead;
  final String? appVersion;
  final String? apkUrl;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.category,
    required this.priority,
    required this.routeName,
    required this.affectedBarangays,
    required this.reason,
    this.additionalMessage = '',
    required this.collectionDate,
    required this.collectionTime,
    this.createdAt,
    required this.isRead,
    this.appVersion,
    this.apkUrl,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      notificationType: json['notification_type'] ?? 'General Announcement',
      category: json['category'] ?? '',
      priority: json['priority'] ?? 'Normal',
      routeName: json['route_name'] ?? '',
      affectedBarangays: json['affected_barangays'] ?? '',
      reason: json['reason'] ?? '',
      additionalMessage: json['additional_message'] ?? '',
      collectionDate: json['collection_date'] ?? '',
      collectionTime: json['collection_time'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      isRead: json['is_read'] ?? false,
      appVersion: json['app_version'],
      apkUrl: json['apk_url'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'notification_type': notificationType,
        'category': category,
        'priority': priority,
        'route_name': routeName,
        'affected_barangays': affectedBarangays,
        'reason': reason,
        'additional_message': additionalMessage,
        'collection_date': collectionDate,
        'collection_time': collectionTime,
        'created_at': createdAt?.toIso8601String(),
        'is_read': isRead,
      };

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        message: message,
        notificationType: notificationType,
        category: category,
        priority: priority,
        routeName: routeName,
        affectedBarangays: affectedBarangays,
        reason: reason,
        additionalMessage: additionalMessage,
        collectionDate: collectionDate,
        collectionTime: collectionTime,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  List<String> get barangayList {
    if (affectedBarangays.isEmpty) return const [];
    try {
      final list = jsonDecode(affectedBarangays);
      return list is List ? list.map((e) => e.toString()).toList() : const [];
    } catch (_) {
      return const [];
    }
  }

  String get formattedTime {
    if (createdAt == null) return '';
    final dt = createdAt!.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$h:$mm $ampm';
    if (day == today) return timeStr;
    final diff = today.difference(day).inDays;
    if (diff == 1) return 'Yesterday $timeStr';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, $timeStr';
  }

  String get fullDate {
    if (createdAt == null) return '';
    final dt = createdAt!.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[(dt.weekday - 1) % 7]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Color get typeColor {
    switch (notificationType) {
      case 'Upcoming Collection':
      case 'Garbage Collection Scheduled':
      case 'Collection Rescheduled':
        return const Color(0xFF1D4ED8);
      case 'Garbage Truck Arriving':
      case 'Truck Arriving':
        return const Color(0xFF92400E);
      case 'Garbage Truck Arrived':
      case 'Truck Arrived':
        return const Color(0xFF0F766E);
      case 'Collection Completed':
        return const Color(0xFF15803D);
      case 'Delayed Collection':
      case 'Collection Delayed':
        return const Color(0xFFB91C1C);
      case 'Cancelled Collection':
      case 'Collection Cancelled':
        return const Color(0xFF4B5563);
      case 'General Announcement':
      case 'Manual Announcement':
        return const Color(0xFF6D28D9);
      default:
        return const Color(0xFF0E7490);
    }
  }

  Color get typeBgColor {
    switch (notificationType) {
      case 'Upcoming Collection':
      case 'Garbage Collection Scheduled':
      case 'Collection Rescheduled':
        return const Color(0xFFEFF6FF);
      case 'Garbage Truck Arriving':
      case 'Truck Arriving':
        return const Color(0xFFFEF3C7);
      case 'Garbage Truck Arrived':
      case 'Truck Arrived':
        return const Color(0xFFCCFBF1);
      case 'Collection Completed':
        return const Color(0xFFF0FDF4);
      case 'Delayed Collection':
      case 'Collection Delayed':
        return const Color(0xFFFEE2E2);
      case 'Cancelled Collection':
      case 'Collection Cancelled':
        return const Color(0xFFF3F4F6);
      case 'General Announcement':
      case 'Manual Announcement':
        return const Color(0xFFF5F3FF);
      default:
        return const Color(0xFFECFEFF);
    }
  }

  IconData get icon {
    switch (notificationType) {
      case 'Upcoming Collection':
      case 'Garbage Collection Scheduled':
      case 'Collection Rescheduled':
        return Icons.event_available_rounded;
      case 'Garbage Truck Arriving':
      case 'Truck Arriving':
      case 'Garbage Truck Arrived':
      case 'Truck Arrived':
        return Icons.local_shipping_rounded;
      case 'Collection Completed':
        return Icons.check_circle_rounded;
      case 'Delayed Collection':
      case 'Collection Delayed':
        return Icons.schedule_rounded;
      case 'Cancelled Collection':
      case 'Collection Cancelled':
        return Icons.cancel_rounded;
      case 'General Announcement':
      case 'Manual Announcement':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}
