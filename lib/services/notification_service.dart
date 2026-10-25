import '../core/network/api_client.dart';
import '../core/network/network_exception.dart';
import '../models/app_notification.dart';
import '../models/notification_settings.dart';

/// REST access to the citizen notification inbox + FCM token registration.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Fetch the current user's notifications.
  Future<List<AppNotification>> getMyNotifications() async {
    final response = await ApiClient.instance.get('/notifications/my');

    if (response.statusCode == 401) {
      throw const ApiException('Unauthorized. Please sign in again.');
    }
    final data = ApiClient.instance.decode(response, fallback: 'Failed to load notifications');
    final List<dynamic> list;
    if (data is Map && data['notifications'] is List) {
      list = data['notifications'] as List<dynamic>;
    } else if (data is List) {
      list = data;
    } else {
      list = <dynamic>[];
    }
    return list
        .map((json) => AppNotification.fromJson((json as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Fetch the unread count for the notifications badge.
  Future<int> getUnreadCount() async {
    final response = await ApiClient.instance.get('/notifications/unread-count');
    if (response.statusCode == 401) {
      throw const ApiException('Unauthorized. Please sign in again.');
    }
    final data = ApiClient.instance.decode(response, fallback: '0');
    if (data is Map && data['unread_count'] != null) {
      return int.tryParse(data['unread_count'].toString()) ?? 0;
    }
    return int.tryParse(data.toString()) ?? 0;
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(int id) async {
    final response = await ApiClient.instance.post('/notifications/my/$id/read');
    ApiClient.instance.decode(response, fallback: 'Failed to update notification');
  }

  /// Register this device's FCM token with the backend.
  Future<void> registerDeviceToken(String token, String platform) async {
    final response = await ApiClient.instance.post(
      '/notifications/device-token',
      body: {'token': token, 'platform': platform},
    );
    ApiClient.instance.decode(response, fallback: 'Failed to register device');
  }

  /// Fetch the citizen's notification preferences + location subscription.
  Future<NotificationSettings> getSettings() async {
    final response = await ApiClient.instance.get('/notifications/settings');
    final data = ApiClient.instance.decode(response, fallback: 'Failed to load settings');
    return NotificationSettings.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Save the citizen's notification preferences + location subscription.
  Future<NotificationSettings> saveSettings(NotificationSettings settings) async {
    final response = await ApiClient.instance.put(
      '/notifications/settings',
      body: settings.toJson(),
    );
    final data = ApiClient.instance.decode(response, fallback: 'Failed to save settings');
    return NotificationSettings.fromJson((data as Map).cast<String, dynamic>());
  }
}
