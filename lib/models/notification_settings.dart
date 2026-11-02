import 'dart:convert';

import '../core/constants.dart';

/// The citizen's notification preferences + preferred location subscription.
///
/// Mirrors `GET/PUT /notifications/settings` on the backend. The toggles gate
/// which channels the user receives; [preferredBarangays] (multi-select)
/// narrows deliveries to the subscribed locations. The backend matches each
/// notification's affected barangays against this list — the admin never
/// chooses recipients directly.
class NotificationSettings {
  final bool collectionUpdates;
  final bool routeUpdates;
  final bool announcements;
  final bool emergencyAlerts;
  final bool reminders;
  final bool completedCollection;
  final List<String> preferredBarangays;

  const NotificationSettings({
    this.collectionUpdates = true,
    this.routeUpdates = true,
    this.announcements = true,
    this.emergencyAlerts = true,
    this.reminders = true,
    this.completedCollection = true,
    this.preferredBarangays = AppConstants.barangays,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    bool flag(String key, bool fallback) {
      final v = json[key];
      return v == null
          ? fallback
          : (v == true || v == 1 || v == '1' || v == 'true');
    }

    List<String> parseBarangays(dynamic raw) {
      if (raw == null) return AppConstants.barangays;
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) return const [];
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        } catch (_) {
          // Fallback to comma-separated string
        }
        return trimmed
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return AppConstants.barangays;
    }

    final hasKey = json.containsKey('preferred_barangays');
    final parsedBarangays = hasKey
        ? parseBarangays(json['preferred_barangays'])
        : AppConstants.barangays;

    return NotificationSettings(
      collectionUpdates: flag('notif_collection_updates', true),
      routeUpdates: flag('notif_route_updates', true),
      announcements: flag('notif_announcements', true),
      emergencyAlerts: flag('notif_emergency_alerts', true),
      reminders: flag('notif_reminders', true),
      completedCollection: flag('notif_completed_collection', true),
      preferredBarangays: parsedBarangays,
    );
  }

  Map<String, dynamic> toJson() => {
        'notif_collection_updates': collectionUpdates,
        'notif_route_updates': routeUpdates,
        'notif_announcements': announcements,
        'notif_emergency_alerts': emergencyAlerts,
        'notif_reminders': reminders,
        'notif_completed_collection': completedCollection,
        'preferred_barangays': preferredBarangays,
      };

  NotificationSettings copyWith({
    bool? collectionUpdates,
    bool? routeUpdates,
    bool? announcements,
    bool? emergencyAlerts,
    bool? reminders,
    bool? completedCollection,
    List<String>? preferredBarangays,
  }) {
    return NotificationSettings(
      collectionUpdates: collectionUpdates ?? this.collectionUpdates,
      routeUpdates: routeUpdates ?? this.routeUpdates,
      announcements: announcements ?? this.announcements,
      emergencyAlerts: emergencyAlerts ?? this.emergencyAlerts,
      reminders: reminders ?? this.reminders,
      completedCollection: completedCollection ?? this.completedCollection,
      preferredBarangays: preferredBarangays ?? this.preferredBarangays,
    );
  }
}
