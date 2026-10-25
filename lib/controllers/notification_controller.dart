import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/cache/cache_keys.dart';
import '../core/cache/swr_cache.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

/// Loads the citizen's notification inbox through the SWR cache.
///
/// Mirrors [ScheduleController]: first visit fetches + caches, later visits
/// render instantly while a background revalidation refreshes, and
/// pull-to-refresh (`load(force: true)`) always hits the network.
class NotificationController extends ChangeNotifier {
  NotificationController._() {
    _cache.addListener(_onCacheChanged);
  }
  static final NotificationController instance = NotificationController._();

  final SwrCache _cache = SwrCache.instance;
  final NotificationService _service = NotificationService.instance;

  SwrState<List<AppNotification>>? _state;
  SwrState<List<AppNotification>>? get state => _state;

  List<AppNotification> get notifications => _state?.data ?? const [];
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
    _state = await _cache.load<List<AppNotification>>(
      key: CacheKeys.notifications,
      force: force,
      fetcher: _service.getMyNotifications,
      encode: (list) => jsonEncode(list.map((n) => n.toJson()).toList()),
      decode: (json) => (jsonDecode(json) as List)
          .map((e) => AppNotification.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
    notifyListeners();
  }

  /// Mark a single notification as read (optimistic + server sync).
  Future<void> markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    final index = notifications.indexWhere((n) => n.id == notification.id);
    if (index < 0) return;

    final updated = notifications.toList();
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

  /// The number of unread items in the current inbox (drives the badge).
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  void _onCacheChanged() {
    final fresh = _cache.stateOf<List<AppNotification>>(CacheKeys.notifications);
    if (fresh != null && fresh != _state) {
      _state = fresh;
      notifyListeners();
    }
  }
}
