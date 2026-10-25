import 'package:flutter/foundation.dart';

import '../models/notification_settings.dart';
import '../services/notification_service.dart';

/// Loads and saves the citizen's notification preferences + location
/// subscription (MVC Controller for the Notification Settings screen).
class NotificationSettingsController extends ChangeNotifier {
  NotificationSettingsController._();
  static final NotificationSettingsController instance =
      NotificationSettingsController._();

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
    try {
      _settings = await _service.getSettings();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> save(NotificationSettings settings) async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      _settings = await _service.saveSettings(settings);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
