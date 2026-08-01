import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/network_exception.dart';
import '../network/network_monitor.dart';
import 'cache_store.dart';

/// Snapshot of a resource managed by the SWR cache.
///
/// A single immutable object a view can render against — no need to
/// juggle separate `isLoading` / `error` / `data` fields.
class SwrState<T> {
  /// Latest known data. `null` while the first fetch is still in flight.
  final T? data;

  /// True while there is no usable cache and the network is being hit
  /// (i.e. a real "first load" — the UI should show a loader).
  final bool isLoading;

  /// True while cached data is shown and a background refresh is running
  /// (stale-while-revalidate). The UI can show a subtle sync indicator.
  final bool isRevalidating;

  /// True when the last sync failed because the device is offline.
  final bool isOffline;

  /// Last error encountered during sync. `null` on success.
  final Object? error;

  /// When the current [data] was fetched from the server.
  final DateTime? lastUpdated;

  /// Whether we currently have any data (cached or fresh) to display.
  bool get hasData => data != null;

  const SwrState({
    this.data,
    this.isLoading = false,
    this.isRevalidating = false,
    this.isOffline = false,
    this.error,
    this.lastUpdated,
  });

  const SwrState.loading()
      : data = null,
        isLoading = true,
        isRevalidating = false,
        isOffline = false,
        error = null,
        lastUpdated = null;

  @override
  String toString() =>
      'SwrState(hasData: $hasData, isLoading: $isLoading, isRevalidating: $isRevalidating, isOffline: $isOffline, error: $error)';
}

/// Options controlling how a resource is cached.
class SwrOptions {
  /// While a cached value is younger than this, it is served directly
  /// without touching the network (avoids repeated API requests).
  final Duration freshFor;

  /// Number of retry attempts for transient network failures.
  final int retries;

  const SwrOptions({
    this.freshFor = const Duration(minutes: 5),
    this.retries = 2,
  });
}

class _Entry<T> {
  T? data;
  String? encoded;
  DateTime? cachedAt;
  SwrState<T>? state;

  // Retained so the cache can revalidate on reconnect without the caller.
  Future<T> Function()? fetcher;
  String Function(T)? encode;
  T Function(String)? decode;
  SwrOptions options = const SwrOptions();

  // Captures [T] at load time so background revalidation from the reconnect
  // listener is type-safe (reading this entry back from the type-erased map
  // would otherwise re-infer T as `dynamic` and break the runtime state type).
  Future<void> Function()? revalidate;
}

/// Stale-While-Revalidate cache.
///
/// Strategy (applied app-wide to every screen that consumes REST API data):
///
/// 1. **First visit** → fetch from the API, save to memory + disk cache.
/// 2. **Subsequent visits** → return the cached value instantly (no loading
///    screen) and re-fetch in the background (stale-while-revalidate).
/// 3. **Change detection** → compare the serialized payload with what is
///    cached. If different, update the cache + notify listeners (UI refreshes
///    automatically). If identical, keep using the cached version.
/// 4. **Offline** → serve cache only. If nothing is cached, surface an
///    offline state; when connectivity returns, revalidate automatically.
/// 5. **TTL / freshness** → within [SwrOptions.freshFor] no request is made;
///    a manual refresh (pull-to-refresh) always forces a fetch.
///
/// The cache is a [ChangeNotifier]; any view that renders SWR state should
/// listen to it (directly or through a controller) so background sync updates
/// all affected screens.
class SwrCache extends ChangeNotifier {
  SwrCache._() {
    // When the device comes back online, revalidate everything that was
    // previously cached so screens update automatically (online <-> offline
    // switch behavior).
    NetworkMonitor.instance.addListener(_onNetworkChanged);
  }
  static final SwrCache instance = SwrCache._();

  final CacheStore _store = CacheStore();
  final Map<String, _Entry<dynamic>> _entries = {};
  final Map<String, Future<SwrState<dynamic>>> _inflight = {};

  /// Read the current state for [key] without triggering a fetch.
  SwrState<T>? stateOf<T>(String key) => (_entries[key] as _Entry<T>?)?.state;

  /// Load [key] following the SWR strategy. See the class docs.
  ///
  /// [fetcher] performs the network request and returns a parsed value;
  /// [encode] serializes it for caching + change detection; [decode] parses
  /// a cached serialized value back.
  ///
  /// When [force] is true (pull-to-refresh) the cache is bypassed and the
  /// result reflects the outcome of the fresh fetch.
  Future<SwrState<T>> load<T>({
    required String key,
    required Future<T> Function() fetcher,
    required String Function(T) encode,
    required T Function(String) decode,
    SwrOptions options = const SwrOptions(),
    bool force = false,
  }) async {
    final entry = _entryFor<T>(key);
    entry
      ..fetcher = fetcher
      ..encode = encode
      ..decode = decode
      ..options = options;
    entry.revalidate = () => _revalidate(key, entry, fetcher, encode, options);
    NetworkMonitor.instance.subscribe(key);

    // 1) Deduplicate concurrent loads for the same key.
    final inflight = _inflight[key];
    if (inflight != null && !force) {
      return await inflight as SwrState<T>;
    }

    // 2) Serve from cache if we have one and it is still fresh.
    if (!force) {
      final cached = await _readFromCache(key, entry, decode);
      if (cached != null) {
        final age = DateTime.now().difference(cached.cachedAt);

        if (age <= options.freshFor && !NetworkMonitor.instance.isOnline) {
          // Fresh + offline → serve cache, flag offline.
          _publish(key, entry, cached.data, cached.encoded, cached.cachedAt, isOffline: true);
          return entry.state!;
        }
        if (age <= options.freshFor) {
          // Fresh + online → serve cache without touching the network.
          _publish(key, entry, cached.data, cached.encoded, cached.cachedAt);
          return entry.state!;
        }

        // Stale → serve cached data instantly, then revalidate in the
        // background. Capture the flag BEFORE publishing so we don't skip
        // the revalidation we just started.
        final alreadyRevalidating = entry.state?.isRevalidating ?? false;
        _publish(key, entry, cached.data, cached.encoded, cached.cachedAt, isRevalidating: true);
        if (!alreadyRevalidating) {
          unawaited(_revalidate(key, entry, fetcher, encode, options));
        }
        return entry.state!;
      }
    }

    // 3) No usable cache (or forced refresh) → fetch now.
    if (!NetworkMonitor.instance.isOnline && entry.data == null) {
      // Offline with nothing cached → offline state with retry.
      final state = SwrState<T>(
        isLoading: false,
        isOffline: true,
        error: const NetworkException('You are offline. Connect to the internet to load fresh data.'),
      );
      _publishState(key, entry, state);
      return state;
    }

    final Future<SwrState<T>> future = _fetch(key, entry, fetcher, encode, options,
        showLoading: entry.state?.hasData != true);
    _inflight[key] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(key);
    }
  }

  /// Invalidate a single key (used after mutations so the next visit
  /// refetches from the server).
  Future<void> invalidate(String key) async {
    _entries.remove(key);
    await _store.remove(key);
    notifyListeners();
  }

  /// Authoritatively replace the cached value for [key] after a successful
  /// mutation (e.g. profile updated) so every screen listening to this key
  /// refreshes immediately without waiting for the next revalidation.
  Future<void> writeThrough<T>({
    required String key,
    required T data,
    required String Function(T) encode,
  }) async {
    final encoded = encode(data);
    final cachedAt = DateTime.now();
    await _store.write(key, CachedPayload(data: data, encoded: encoded, cachedAt: cachedAt));
    final entry = _entryFor<T>(key);
    entry
      ..data = data
      ..encoded = encoded
      ..cachedAt = cachedAt;
    _publishState(key, entry, SwrState(data: data, lastUpdated: cachedAt));
  }

  /// Drop every cached resource (used on logout).
  Future<void> clearAll() async {
    _entries.clear();
    await _store.clearAll();
    notifyListeners();
  }

  /// Revalidate every currently registered key (used when the device comes
  /// back online). Background revalidation — cached data stays on screen and
  /// updates automatically if the server payload changed.
  Future<void> revalidateAll() async {
    for (final key in NetworkMonitor.instance.subscribers.toList()) {
      final entry = _entries[key];
      if (entry == null || entry.revalidate == null) continue;
      if (entry.state?.isRevalidating == true) continue; // already syncing
      unawaited(entry.revalidate!());
    }
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  _Entry<T> _entryFor<T>(String key) {
    final existing = _entries[key];
    if (existing != null) return existing as _Entry<T>;
    final created = _Entry<T>();
    _entries[key] = created;
    return created;
  }

  void _onNetworkChanged() {
    if (NetworkMonitor.instance.isOnline) {
      unawaited(revalidateAll());
    }
  }

  Future<CachedPayload<T>?> _readFromCache<T>(
    String key,
    _Entry<T> entry,
    T Function(String) decode,
  ) async {
    if (entry.data != null) {
      return CachedPayload(
        data: entry.data as T,
        encoded: entry.encoded!,
        cachedAt: entry.cachedAt!,
      );
    }
    final disk = await _store.read<T>(key, decode: decode);
    if (disk != null) {
      entry.data = disk.data;
      entry.encoded = disk.encoded;
      entry.cachedAt = disk.cachedAt;
    }
    return disk;
  }

  Future<SwrState<T>> _fetch<T>(
    String key,
    _Entry<T> entry,
    Future<T> Function() fetcher,
    String Function(T) encode,
    SwrOptions options, {
    required bool showLoading,
  }) async {
    if (showLoading) {
      _publishState(key, entry, SwrState<T>.loading());
    }

    try {
      final data = await _withRetry(fetcher, options);
      final encoded = encode(data);
      await _store.write(key, CachedPayload(data: data, encoded: encoded, cachedAt: DateTime.now()));
      entry.data = data;
      entry.encoded = encoded;
      entry.cachedAt = DateTime.now();
      _publishState(key, entry, SwrState(data: data, lastUpdated: entry.cachedAt));
      return entry.state!;
    } on NetworkException catch (e) {
      if (entry.data != null) {
        // Failed request must never remove valid cached data.
        _publishState(
          key,
          entry,
          SwrState(data: entry.data, lastUpdated: entry.cachedAt, isOffline: true, error: e),
        );
      } else {
        _publishState(key, entry, SwrState(isLoading: false, isOffline: true, error: e));
      }
      return entry.state!;
    } catch (e) {
      if (entry.data != null) {
        _publishState(
          key,
          entry,
          SwrState(
            data: entry.data,
            lastUpdated: entry.cachedAt,
            isOffline: !NetworkMonitor.instance.isOnline,
            error: e,
          ),
        );
      } else {
        _publishState(key, entry, SwrState(isLoading: false, error: e));
      }
      return entry.state!;
    }
  }

  Future<void> _revalidate<T>(
    String key,
    _Entry<T> entry,
    Future<T> Function() fetcher,
    String Function(T) encode,
    SwrOptions options,
  ) async {
    if (!NetworkMonitor.instance.isOnline) {
      // Offline → keep stale cache, mark offline; the reconnect listener
      // will trigger a new revalidation once connectivity returns.
      _publishState(
        key,
        entry,
        SwrState(data: entry.data, lastUpdated: entry.cachedAt, isOffline: true),
      );
      return;
    }

    try {
      final data = await _withRetry(fetcher, options);
      final encoded = encode(data);

      // Persist the refreshed payload (bumps the timestamp, so the next
      // visit within `freshFor` is served straight from cache).
      await _store.write(key, CachedPayload(data: data, encoded: encoded, cachedAt: DateTime.now()));
      entry.data = data;
      entry.encoded = encoded;
      entry.cachedAt = DateTime.now();

      // Publish the refreshed state. Change detection happens by comparing
      // the serialized payloads — when unchanged the UI renders identical
      // data (keep using the cached version); when changed, `entry.encoded`
      // differs and listeners rebuild with the fresh data automatically.
      _publishState(key, entry, SwrState(data: data, lastUpdated: entry.cachedAt));
    } catch (e) {
      // Background revalidation failed. Keep whatever we have — a failed
      // request must never remove valid cached data.
      final isOffline = !NetworkMonitor.instance.isOnline || e is NetworkException;
      _publishState(
        key,
        entry,
        SwrState(data: entry.data, lastUpdated: entry.cachedAt, isOffline: isOffline, error: e),
      );
    }
  }

  Future<T> _withRetry<T>(Future<T> Function() fetcher, SwrOptions options) async {
    var attempt = 0;
    while (true) {
      try {
        return await fetcher();
      } on NetworkException {
        attempt++;
        if (attempt > options.retries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
      }
    }
  }

  void _publish<T>(
    String key,
    _Entry<T> entry,
    T data,
    String encoded,
    DateTime cachedAt, {
    bool isOffline = false,
    bool isRevalidating = false,
  }) {
    _publishState(
      key,
      entry,
      SwrState(
        data: data,
        lastUpdated: cachedAt,
        isOffline: isOffline,
        isRevalidating: isRevalidating,
      ),
    );
  }

  void _publishState<T>(String key, _Entry<T> entry, SwrState<T> state) {
    entry.state = state;
    notifyListeners();
  }
}
