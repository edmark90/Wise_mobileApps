import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A value stored in the persistent cache.
class CachedPayload<T> {
  final T data;

  /// Serialized form of [data] used for change detection (see SWR cache).
  final String encoded;

  /// When this payload was written to the cache.
  final DateTime cachedAt;

  const CachedPayload({required this.data, required this.encoded, required this.cachedAt});
}

/// Disk persistence layer for the SWR cache.
///
/// Uses [SharedPreferences] so cached data survives app restarts and is
/// available immediately on launch — the "load from local cache" path of the
/// offline strategy. Each value is stored as a single JSON string:
///
/// ```json
/// { "encoded": "...", "cachedAt": "2026-01-01T00:00:00.000" }
/// ```
class CacheStore {
  static const String _prefix = 'swr_cache_v1:';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Read a payload for [key]. Returns `null` when nothing is cached or the
  /// stored value is corrupt (which is then cleaned up).
  Future<CachedPayload<T>?> read<T>(String key, {required T Function(String) decode}) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_prefix + key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final encoded = map['encoded'] as String;
      final cachedAt = DateTime.parse(map['cachedAt'] as String);
      return CachedPayload(data: decode(encoded), encoded: encoded, cachedAt: cachedAt);
    } catch (_) {
      // Corrupt entry — drop it so the next read can refetch cleanly.
      await prefs.remove(_prefix + key);
      return null;
    }
  }

  Future<void> write<T>(String key, CachedPayload<T> payload) async {
    final prefs = await _prefs;
    await prefs.setString(
      _prefix + key,
      jsonEncode({'encoded': payload.encoded, 'cachedAt': payload.cachedAt.toIso8601String()}),
    );
  }

  Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove(_prefix + key);
  }

  /// Drop every cached resource (used on logout).
  Future<void> clearAll() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
