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
      return v == null ? fallback : (v == true || v == 1 || v == '1' || v == 'true');
    }

    List<String> barangays(List<dynamic>? raw) {
      if (raw == null) return const [];
      return raw.map((e) => e.toString()).toList();
    }

    final rawBarangays = json['preferred_barangays'];
    final barangayList = rawBarangays is List ? barangays(rawBarangays) : const <String>[];
    final effectiveBarangays = barangayList.isEmpty ? AppConstants.barangays : barangayList;

    return NotificationSettings(
      collectionUpdates: flag('notif_collection_updates', true),
      routeUpdates: flag('notif_route_updates', true),
      announcements: flag('notif_announcements', true),
      emergencyAlerts: flag('notif_emergency_alerts', true),
      reminders: flag('notif_reminders', true),
      completedCollection: flag('notif_completed_collection', true),
      preferredBarangays: effectiveBarangays,
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
