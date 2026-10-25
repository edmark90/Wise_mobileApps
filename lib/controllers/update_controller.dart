import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_update.dart';
import '../services/app_update_service.dart';

class UpdateController extends ChangeNotifier {
  static final UpdateController instance = UpdateController._internal();
  UpdateController._internal();

  AppUpdate? _latest;
  DateTime? _dismissedUntil;
  int _installedVersionCode = 0;
  bool _pendingNextAppOpen = false;

  AppUpdate? get latest => _latest;
  bool get pendingNextAppOpen => _pendingNextAppOpen;
  int get installedVersionCode => _installedVersionCode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _pendingNextAppOpen = prefs.getBool('pending_next_app_open') ?? false;
    final dismissedMs = prefs.getInt('dismissed_until_ms');
    if (dismissedMs != null) {
      _dismissedUntil = DateTime.fromMillisecondsSinceEpoch(dismissedMs);
    }

    // Always read actual installed version from PackageInfo
    try {
      final info = await PackageInfo.fromPlatform();
      _installedVersionCode = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {
      _installedVersionCode = 0;
    }
    debugPrint("[UpdateController] init installedVersionCode=$_installedVersionCode");

    // Restore persisted latest update
    final latestJson = prefs.getString('persisted_latest_update');
    if (latestJson != null) {
      try {
        _latest = AppUpdate.fromJson(jsonDecode(latestJson));
        debugPrint("[UpdateController] restored latest: ${_latest?.version} code=${_latest?.versionCode}");

        // If already installed, discard
        if (_latest != null && _latest!.versionCode <= _installedVersionCode) {
          debugPrint("[UpdateController] persisted latest already installed — discarding");
          _latest = null;
          await prefs.remove('persisted_latest_update');
        }
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_next_app_open', _pendingNextAppOpen);
    if (_dismissedUntil != null) {
      await prefs.setInt('dismissed_until_ms', _dismissedUntil!.millisecondsSinceEpoch);
    }
    if (_latest != null) {
      await prefs.setString('persisted_latest_update', jsonEncode({
        'id': _latest!.id,
        'version': _latest!.version,
        'version_code': _latest!.versionCode,
        'title': _latest!.title,
        'release_notes': _latest!.releaseNotes,
        'apk_url': _latest!.apkUrl,
        'is_force': _latest!.isForce,
      }));
    } else {
      await prefs.remove('persisted_latest_update');
    }
  }

  Future<void> checkNow() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _installedVersionCode = int.tryParse(info.buildNumber) ?? 0;
      debugPrint("[UpdateController] checkNow installedVersionCode=$_installedVersionCode");

      final res = await AppUpdateService.getLatestUpdate();
      debugPrint("[UpdateController] API: update_available=${res.updateAvailable}, version=${res.latest?.version}, code=${res.latest?.versionCode}");

      if (res.updateAvailable && res.latest != null) {
        if (res.latest!.versionCode > _installedVersionCode) {
          // Preserve force flag from push if API returns non-force
          final wasForce = _latest?.isForce == true && _latest?.versionCode == res.latest!.versionCode;
          _latest = res.latest;
          if (wasForce) {
            _latest = AppUpdate(
              id: _latest!.id,
              version: _latest!.version,
              versionCode: _latest!.versionCode,
              title: _latest!.title,
              releaseNotes: _latest!.releaseNotes,
              apkUrl: _latest!.apkUrl,
              isForce: true,
            );
          }
          debugPrint("[UpdateController] _latest set to ${_latest!.version} code=${_latest!.versionCode} isForce=${_latest!.isForce}");
        } else {
          debugPrint("[UpdateController] API version already installed — ignoring");
          _latest = null;
        }
      } else {
        // No update from server — only clear if no pending push override
        if (!_pendingNextAppOpen) {
          debugPrint("[UpdateController] no update from server — clearing _latest");
          _latest = null;
        } else {
          debugPrint("[UpdateController] no update from server but pendingNextAppOpen — keeping _latest");
        }
      }
      notifyListeners();
      await _persist();
    } catch (e) {
      debugPrint("[UpdateController] checkNow failed: $e");
      // On network error, keep existing _latest if it's a force update
      if (_latest != null && _latest!.isForce) {
        debugPrint("[UpdateController] keeping force update _latest despite network error");
        await _persist();
      }
    }
  }

  void setFromPush(Map<String, dynamic> data) {
    final versionCode = int.tryParse(data['version_code']?.toString() ?? '0') ?? 0;
    debugPrint("[UpdateController] setFromPush version_code=$versionCode, force=${data['force']}, reminder=${data['reminder']}");

    // Don't accept push for already installed version
    if (versionCode > 0 && versionCode <= _installedVersionCode) {
      debugPrint("[UpdateController] push version_code=$versionCode already installed — ignoring");
      return;
    }

    _latest = AppUpdate(
      id: int.tryParse(data['id']?.toString() ?? '0') ?? 0,
      version: data['version'] ?? '',
      versionCode: versionCode,
      title: data['title'] ?? 'Mobile Update Available',
      releaseNotes: data['message'],
      apkUrl: data['apk_url'] ?? '',
      isForce: data['force'] == 'true',
    );

    final reminder = data['reminder'] as String?;
    if (reminder == 'Next App Open') {
      _pendingNextAppOpen = true;
      _persist();
      notifyListeners();
      return;
    }

    _persist();
    notifyListeners();
  }

  bool get shouldPrompt {
    if (_latest == null) return false;

    debugPrint("[UpdateController] shouldPrompt: latest_code=${_latest!.versionCode}, installed=$_installedVersionCode, isForce=${_latest!.isForce}, dismissedUntil=$_dismissedUntil");

    // Already installed — don't prompt
    if (_latest!.versionCode <= _installedVersionCode) return false;

    // Force — always prompt
    if (_latest!.isForce) return true;

    // Non-force — check if dismissed within 24 hours
    if (_dismissedUntil != null && DateTime.now().isBefore(_dismissedUntil!)) {
      return false;
    }

    return true;
  }

  Future<void> checkPendingNextAppOpen() async {
    if (_pendingNextAppOpen && _latest != null) {
      debugPrint("[UpdateController] clearing pendingNextAppOpen, showing dialog for ${_latest?.version}");
      _pendingNextAppOpen = false;
      await _persist();
      notifyListeners();
    }
  }

  void markDismissed() {
    _dismissedUntil = DateTime.now().add(const Duration(days: 1));
    // Only clear _latest if NOT a force update.
    // Force updates must persist until the user actually updates.
    if (_latest == null || !_latest!.isForce) {
      _latest = null;
    }
    _persist();
    notifyListeners();
  }
}
