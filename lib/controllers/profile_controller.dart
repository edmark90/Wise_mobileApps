import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/cache/cache_keys.dart';
import '../core/cache/swr_cache.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';

/// Loads and mutates the current user's profile through the SWR cache.
///
/// Mutations (update / photo upload / photo removal) write the server's
/// response straight into the cache (`writeThrough`) so the screen and any
/// other listener refresh immediately, without a spurious network round-trip.
class ProfileController extends ChangeNotifier {
  ProfileController._() {
    _cache.addListener(_onCacheChanged);
  }
  static final ProfileController instance = ProfileController._();

  final SwrCache _cache = SwrCache.instance;
  final ProfileService _service = ProfileService.instance;

  SwrState<Profile>? _state;
  SwrState<Profile>? get state => _state;

  Profile? get profile => _state?.data;

  Future<void> load({bool force = false}) async {
    _state = await _cache.load<Profile>(
      key: CacheKeys.profile,
      force: force,
      fetcher: _service.getProfile,
      encode: (p) => jsonEncode(p.toJson()),
      decode: (json) => Profile.fromJson((jsonDecode(json) as Map).cast<String, dynamic>()),
    );
    notifyListeners();
  }

  Future<void> update({
    String? fullname,
    String? phone,
    String? barangay,
    String? zone,
  }) async {
    final updated = await _service.updateProfile(
      fullname: fullname,
      phone: phone,
      barangay: barangay,
      zone: zone,
    );
    await _cache.writeThrough<Profile>(
      key: CacheKeys.profile,
      data: updated,
      encode: (p) => jsonEncode(p.toJson()),
    );
  }

  Future<void> uploadPhoto(List<int> bytes, {required String filename}) async {
    final imagePath = await _service.uploadProfilePhoto(bytes, filename: filename);
    final current = _state?.data;
    if (current != null) {
      await _cache.writeThrough<Profile>(
        key: CacheKeys.profile,
        data: current.copyWith(profileImage: imagePath),
        encode: (p) => jsonEncode(p.toJson()),
      );
    } else {
      await load(force: true);
    }
  }

  Future<void> removePhoto() async {
    await _service.removeProfilePhoto();
    final current = _state?.data;
    if (current != null) {
      await _cache.writeThrough<Profile>(
        key: CacheKeys.profile,
        data: current.copyWith(profileImage: ''),
        encode: (p) => jsonEncode(p.toJson()),
      );
    } else {
      await load(force: true);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _service.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }

  String imageUrl(String? path) => _service.profileImageUrl(path);

  void _onCacheChanged() {
    final fresh = _cache.stateOf<Profile>(CacheKeys.profile);
    if (fresh != null && fresh != _state) {
      _state = fresh;
      notifyListeners();
    }
  }
}
