import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/notification_settings.dart';
import '../services/notification_service.dart';
import 'notification_controller.dart';

/// Loads and saves the citizen's notification preferences + location
/// subscription (MVC Controller for the Notification Settings screen).
class NotificationSettingsController extends ChangeNotifier {
  NotificationSettingsController._();
  static final NotificationSettingsController instance =
      NotificationSettingsController._();

  static const String _prefsKey = 'wise_notification_settings_v1';

  final NotificationService _service = NotificationService.instance;

  NotificationSettings? _settings;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  NotificationSettings? get settings => _settings;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    // 1. Load local cached preferences first so barangay filter is instant
    final local = await _readLocal();
    if (local != null) {
      _settings = local;
      notifyListeners();
    }

    // 2. Sync with backend
    try {
      final remote = await _service.getSettings();
      // If user already saved custom barangays locally and remote returned empty,
      // preserve their selection; otherwise use remote.
      if (remote.preferredBarangays.isEmpty && local != null) {
        _settings = remote.copyWith(
          preferredBarangays: local.preferredBarangays,
        );
      } else if (remote.preferredBarangays.isEmpty && local == null) {
        _settings = remote.copyWith(
          preferredBarangays: AppConstants.barangays,
        );
      } else {
        _settings = remote;
      }
      await _writeLocal(_settings!);
    } catch (e) {
      _settings ??= const NotificationSettings();
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> save(NotificationSettings settings) async {
    _saving = true;
    _error = null;
    _settings = settings;
    notifyListeners();

    // Persist locally immediately so notification filtering updates right away
    await _writeLocal(settings);

    try {
      final saved = await _service.saveSettings(settings);
      // Keep the user's exact preferredBarangays selection
      _settings = saved.copyWith(
        preferredBarangays: settings.preferredBarangays,
      );
      await _writeLocal(_settings!);
      // Refresh notifications from backend so inbox matches new preferences
      await NotificationController.instance.load(force: true);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<NotificationSettings?> _readLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return NotificationSettings.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLocal(NotificationSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(settings.toJson()));
    } catch (_) {
      // Ignore storage errors
    }
  }
}
