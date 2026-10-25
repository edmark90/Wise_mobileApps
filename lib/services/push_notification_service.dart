import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../controllers/notification_controller.dart';
import '../controllers/update_controller.dart';
import '../core/network/api_client.dart';
import '../main.dart';
import '../screens/update_dialog.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushNotificationService.instance.handleRemoteMessage(message, background: true);
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  void Function()? onNotificationTap;

  final NotificationService _service = NotificationService.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'wise_notifications',
    'WasteWise Notifications',
    channelDescription: 'Garbage collection alerts from WasteWise',
    importance: Importance.high,
    priority: Priority.high,
  );

  bool _initialized = false;
  bool _firebaseAvailable = false;
  String? _token;
  Future<void>? _initFuture;

  bool get isInitialized => _initialized;
  bool get isFirebaseAvailable => _firebaseAvailable;

  Future<void> initialize() => _initFuture ??= _doInitialize();

  Future<void> _doInitialize() async {
    if (_initialized) return;
    _initialized = true;

    await _initLocalNotifications();

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseAvailable = true;
    } catch (e) {
      debugPrint('PushNotificationService: Firebase unavailable — $e');
      _firebaseAvailable = false;
    }

    if (_firebaseAvailable) {
      final messaging = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((message) {
        unawaited(handleRemoteMessage(message));
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        unawaited(handleRemoteMessage(message, openApp: true));
      });

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        unawaited(handleRemoteMessage(initial, openApp: true));
      }

      messaging.onTokenRefresh.listen((token) => _registerToken(token));
      await _requestPermission();
      await _fetchAndRegisterToken();
    }
  }

  Future<void> handleRemoteMessage(
    RemoteMessage message, {
    bool background = false,
    bool openApp = false,
  }) async {
    if (ApiClient.instance.token == null) return;

    debugPrint('[Push] received type=${message.data['type']}, background=$background, openApp=$openApp');

    // Handle app_update type messages
    if (message.data['type'] == 'app_update') {
      final reminder = message.data['reminder'] as String?;
      final pushVersionCode = int.tryParse(message.data['version_code']?.toString() ?? '0') ?? 0;

      // Skip entirely if version already installed — no dialog, no notification
      if (pushVersionCode > 0 && pushVersionCode <= UpdateController.instance.installedVersionCode) {
        debugPrint('[Push] app_update v$pushVersionCode already installed — skipping');
        unawaited(NotificationController.instance.load(force: true));
        return;
      }

      // "Next App Open" — only save data, don't show dialog now
      if (reminder == 'Next App Open') {
        UpdateController.instance.setFromPush(message.data);
        if (!background) {
          final title = message.notification?.title ?? message.data['title'] ?? 'App Update Available';
          final body = message.notification?.body ?? message.data['message'] ?? 'A new version is available. Open the app to update.';
          await _showLocalNotification(title, body, message.messageId);
        }
        unawaited(NotificationController.instance.load(force: true));
        if (openApp) _openNotificationScreen();
        return;
      }

      // All other reminders (None, 10min, 30min, 1hr, Daily) — show dialog now
      UpdateController.instance.setFromPush(message.data);

      // If _latest is null after setFromPush, the push was invalid
      if (UpdateController.instance.latest == null) {
        debugPrint('[Push] app_update ignored — version already installed or invalid');
        unawaited(NotificationController.instance.load(force: true));
        if (openApp) _openNotificationScreen();
        return;
      }

      if (!background) {
        final title = message.notification?.title ?? message.data['title'] ?? 'App Update Available';
        final body = message.notification?.body ?? message.data['message'] ?? 'A new version is available';
        await _showLocalNotification(title, body, message.messageId);
      }

      unawaited(NotificationController.instance.load(force: true));

      final context = navigatorKey.currentContext;
      if (context != null && UpdateController.instance.shouldPrompt && UpdateController.instance.latest != null) {
        showUpdateDialog(context, UpdateController.instance.latest!);
      }

      if (openApp) _openNotificationScreen();
      return;
    }

    // Non-app_update: refresh inbox
    if (!background) {
      unawaited(NotificationController.instance.load(force: true));
    }

    if (openApp) {
      _openNotificationScreen();
      return;
    }
    if (background) {
      return;
    }

    // Show heads-up local notification for regular notifications
    final title = message.notification?.title ?? 'WasteWise';
    final body = message.notification?.body ?? message.data['message'] ?? 'New notification';
    await _showLocalNotification(title, body, message.messageId);
  }

  Future<void> _initLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.id.toString().isNotEmpty) _openNotificationScreen();
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _requestPermission() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('PushNotificationService: permission ${settings.authorizationStatus}');
  }

  Future<void> _fetchAndRegisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _registerToken(token);
      }
    } catch (e) {
      debugPrint('PushNotificationService: token fetch failed — $e');
    }
  }

  Future<void> _registerToken(String token) async {
    if (ApiClient.instance.token == null) return;
    if (token == _token) return;
    try {
      await _service.registerDeviceToken(token, 'android');
      _token = token;
    } catch (e) {
      debugPrint('PushNotificationService: token registration failed — $e');
    }
  }

  Future<void> _showLocalNotification(String title, String body, String? id) async {
    await _localNotifications.show(
      id: id.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: _androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  void _openNotificationScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onNotificationTap?.call();
    });
  }

  Future<void> registerAfterLogin() async {
    await initialize();
    if (!_firebaseAvailable || ApiClient.instance.token == null) return;
    await _fetchAndRegisterToken();
  }

  void reset() {
    _token = null;
  }

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final impl = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await impl?.areNotificationsEnabled();
      return enabled ?? true;
    } catch (e) {
      debugPrint('PushNotificationService: check enabled failed — $e');
      return true;
    }
  }

  Future<void> openAppSettings() async {
    if (kIsWeb) return;
    try {
      const channel = MethodChannel('wise/notifications');
      await channel.invokeMethod('openAppSettings');
    } catch (e) {
      debugPrint('PushNotificationService: open settings failed — $e');
    }
  }
}
