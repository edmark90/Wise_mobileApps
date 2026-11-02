import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/cache/cache_keys.dart';
import '../core/cache/swr_cache.dart';
import '../core/constants.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import 'notification_settings_controller.dart';
import 'schedule_controller.dart';

/// Loads the citizen's notification inbox through the SWR cache and filters
/// notifications according to the citizen's [NotificationSettingsController]
/// preferred barangays and channel toggles.
class NotificationController extends ChangeNotifier {
  NotificationController._() {
    _cache.addListener(_onCacheChanged);
    NotificationSettingsController.instance.addListener(_onSettingsChanged);
  }
  static final NotificationController instance = NotificationController._();

  final SwrCache _cache = SwrCache.instance;
  final NotificationService _service = NotificationService.instance;

  SwrState<List<AppNotification>>? _state;
  SwrState<List<AppNotification>>? get state => _state;

  int? _lastSyncedTopNotificationId;

  /// Raw unfiltered notifications from the cache/backend.
  List<AppNotification> get allNotifications => _state?.data ?? const [];

  /// Notifications filtered by the citizen's selected preferred barangays
  /// and notification channel preferences.
  List<AppNotification> get notifications {
    final raw = _state?.data ?? const <AppNotification>[];
    final settings = NotificationSettingsController.instance.settings;
    if (settings == null) return raw;
    return raw
        .where((n) => matchesUserPreferences(n, preferredBarangays: settings.preferredBarangays))
        .toList();
  }

  /// Checks whether [n] should be shown to the user given their channel toggles
  /// and selected [preferredBarangays].
  bool matchesUserPreferences(
    AppNotification n, {
    List<String>? preferredBarangays,
  }) {
    final settings = NotificationSettingsController.instance.settings;
    final activeBarangays =
        preferredBarangays ?? settings?.preferredBarangays ?? AppConstants.barangays;

    if (settings != null) {
      final type = n.notificationType;
      if ((type == 'General Announcement' || type == 'Manual Announcement') &&
          !settings.announcements) {
        return false;
      }
      if (type == 'Collection Completed' && !settings.completedCollection) {
        return false;
      }
      if ((type == 'Upcoming Collection' ||
              type == 'Garbage Collection Scheduled' ||
              type == 'Collection Rescheduled') &&
          !settings.collectionUpdates) {
        return false;
      }
      if ((type == 'Garbage Truck Arriving' ||
              type == 'Truck Arriving' ||
              type == 'Garbage Truck Arrived' ||
              type == 'Truck Arrived' ||
              type == 'Delayed Collection' ||
              type == 'Collection Delayed' ||
              type == 'Cancelled Collection' ||
              type == 'Collection Cancelled') &&
          !settings.routeUpdates) {
        return false;
      }
    }

    // Identify which barangay(s) this notification is about
    final targetBarangays = extractNotificationBarangays(n);

    // If the notification is for specific barangay(s), only show it if at least
    // one of those barangays is enabled in the user's preferredBarangays.
    if (targetBarangays.isNotEmpty) {
      if (activeBarangays.isEmpty) return false;
      final preferredLower =
          activeBarangays.map((b) => b.trim().toLowerCase()).toSet();
      return targetBarangays.any(
        (b) => preferredLower.contains(b.trim().toLowerCase()),
      );
    }

    // City-wide notifications with no specific barangay (e.g. Mobile Update or
    // general announcement to everyone) remain visible.
    return true;
  }

  List<String> extractNotificationBarangays(AppNotification n) {
    if (n.barangayList.isNotEmpty) {
      return n.barangayList;
    }

    // Fallback: detect barangay names mentioned in routeName, title, or message
    // (checking longer names like "New Alabang Village" and "Ayala Alabang"
    // before "Alabang" so substrings don't collide).
    var combined = '${n.routeName} | ${n.title} | ${n.message}'.toLowerCase();
    final sortedBarangays = List<String>.from(AppConstants.barangays)
      ..sort((a, b) => b.length.compareTo(a.length));

    final matched = <String>[];
    for (final brgy in sortedBarangays) {
      final lower = brgy.toLowerCase();
      if (combined.contains(lower)) {
        matched.add(brgy);
        combined = combined.replaceAll(lower, ' ');
      }
    }
    return matched;
  }

  bool get hasData => _state?.hasData ?? false;
  bool get isLoading => _state?.isLoading ?? false;
  bool get isRevalidating => _state?.isRevalidating ?? false;

  /// Whether the current user is a citizen (determined by [ApiClient] token).
  bool _isCitizen = true;
  bool get isCitizen => _isCitizen;

  void setCitizen(bool value) {
    if (_isCitizen == value) return;
    _isCitizen = value;
    notifyListeners();
  }

  Future<void> load({bool force = false}) async {
    if (NotificationSettingsController.instance.settings == null &&
        !NotificationSettingsController.instance.loading) {
      await NotificationSettingsController.instance.load();
    }
    _state = await _cache.load<List<AppNotification>>(
      key: CacheKeys.notifications,
      force: force,
      fetcher: _service.getMyNotifications,
      encode: (list) => jsonEncode(list.map((n) => n.toJson()).toList()),
      decode: (json) => (jsonDecode(json) as List)
          .map(
            (e) => AppNotification.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
    );
    _syncSchedulesOnNewNotification();
    notifyListeners();
  }

  void _syncSchedulesOnNewNotification() {
    final list = _state?.data;
    if (list == null || list.isEmpty) return;
    final topId = list.first.id;
    if (_lastSyncedTopNotificationId != null &&
        topId != _lastSyncedTopNotificationId) {
      // A new notification arrived — refresh collection schedules so status
      // changes (Arriving, Arrived, Delayed, Cancelled, Completed) stay synced.
      unawaited(ScheduleController.instance.load(force: true));
    }
    _lastSyncedTopNotificationId = topId;
  }

  /// Mark a single notification as read (optimistic + server sync).
  Future<void> markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    final all = allNotifications;
    final index = all.indexWhere((n) => n.id == notification.id);
    if (index < 0) return;

    final updated = all.toList();
    updated[index] = notification.copyWith(isRead: true);
    _cache.writeThrough<List<AppNotification>>(
      key: CacheKeys.notifications,
      data: updated,
      encode: (list) => jsonEncode(list.map((n) => n.toJson()).toList()),
    );
    notifyListeners();

    try {
      await _service.markAsRead(notification.id);
    } catch (_) {
      // Keep the optimistic update; the next revalidation reconciles.
    }
  }

  /// The number of unread items in the filtered inbox (drives the badge).
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  void _onCacheChanged() {
    final fresh = _cache.stateOf<List<AppNotification>>(CacheKeys.notifications);
    if (fresh != null && fresh != _state) {
      _state = fresh;
      _syncSchedulesOnNewNotification();
      notifyListeners();
    }
  }

  void _onSettingsChanged() {
    notifyListeners();
  }
}
