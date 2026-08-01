import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks the device connectivity state while the app is running.
///
/// The SWR cache listens to this so it can:
///  - skip network requests entirely when offline and serve cache only
///  - revalidate all cached resources automatically when the device
///    comes back online (online <-> offline switch behavior)
class NetworkMonitor extends ChangeNotifier {
  NetworkMonitor._();
  static final NetworkMonitor instance = NetworkMonitor._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Set of active cache keys, registered by the SWR cache, to revalidate
  /// when connectivity returns.
  final Set<String> _subscribers = {};
  bool _watching = false;

  /// Register a cache key to revalidate on reconnect.
  void subscribe(String key) {
    _subscribers.add(key);
    _startWatching();
  }

  void unsubscribe(String key) => _subscribers.remove(key);

  Set<String> get subscribers => _subscribers;

  void _startWatching() {
    if (_watching) return;
    _watching = true;
    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    });
    // Kick an initial check so the first read is accurate.
    Connectivity().checkConnectivity().then((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    });
  }
}
