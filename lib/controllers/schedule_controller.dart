import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/cache/cache_keys.dart';
import '../core/cache/swr_cache.dart';
import '../models/collection_schedule.dart';
import '../services/schedule_service.dart';

/// Loads and filters collection schedules through the SWR cache.
///
/// - First visit → fetches from the API and caches the result.
/// - Later visits → cached data renders instantly while a background
///   revalidation refreshes it (stale-while-revalidate).
/// - Pull-to-refresh (`load(force: true)`) always hits the network.
class ScheduleController extends ChangeNotifier {
  ScheduleController._() {
    _cache.addListener(_onCacheChanged);
  }
  static final ScheduleController instance = ScheduleController._();

  static const String _monthlyCacheKey = '${CacheKeys.schedules}_monthly';

  final SwrCache _cache = SwrCache.instance;
  final ScheduleService _service = ScheduleService.instance;

  SwrState<List<CollectionSchedule>>? _state;
  SwrState<List<CollectionSchedule>>? get state => _state;

  final Set<String> _selectedBarangays = {};
  Set<String> get selectedBarangays => _selectedBarangays;

  /// Message shown when selected barangays have no schedules.
  String get filteredEmptyMessage {
    if (_selectedBarangays.isEmpty) {
      return 'No collection routes scheduled\nfor this month.';
    }
    final brgyList = _selectedBarangays.take(2).join(', ');
    final extra = _selectedBarangays.length > 2
        ? ' and ${_selectedBarangays.length - 2} more'
        : '';
    final schedules = _state?.data ?? const [];
    final noSched = _selectedBarangays.where(
      (b) => !schedules.any((s) => _scheduleMatchesBarangay(s, b)),
    );
    if (noSched.length == _selectedBarangays.length) {
      if (noSched.length == 1) {
        return 'No collection schedule for ${noSched.first}.';
      }
      return 'No collection schedule for\n$brgyList$extra.';
    }
    return 'No collection routes found\nfor selected barangay.';
  }

  bool _scheduleMatchesBarangay(CollectionSchedule s, String barangay) {
    final target = barangay.trim().toLowerCase();
    if (s.barangay.toLowerCase().contains(target)) return true;
    return s.stops.any((stop) => stop.barangay.toLowerCase().contains(target));
  }

  bool _isTodayOrFuture(CollectionSchedule s, DateTime today) {
    try {
      final d = DateTime.parse(s.collectionDate);
      final dateOnly = DateTime(d.year, d.month, d.day);
      return !dateOnly.isBefore(today);
    } catch (_) {
      return true;
    }
  }

  /// All schedules loaded from the start of the month (used for monthly stats).
  List<CollectionSchedule> get allSchedules =>
      _state?.data ?? const <CollectionSchedule>[];

  /// Upcoming schedules from today onwards (hides past days), filtered by
  /// selected barangays on the Schedule page.
  List<CollectionSchedule> get filteredSchedules {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = allSchedules
        .where((s) => _isTodayOrFuture(s, today))
        .toList();
    if (_selectedBarangays.isEmpty) return upcoming;
    return upcoming
        .where(
          (s) => _selectedBarangays.any((b) => _scheduleMatchesBarangay(s, b)),
        )
        .toList();
  }

  Future<void> load({bool force = false}) async {
    final now = DateTime.now();
    // Load all schedules from the start of the current month through the end
    // of next month (60+ days window) so schedules like Nov 12 and all monthly
    // routes/trucks are always included.
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfNextMonth = DateTime(now.year, now.month + 2, 0);
    final startDate = _formatDate(startOfMonth);
    final endDate = _formatDate(endOfNextMonth);

    _state = await _cache.load<List<CollectionSchedule>>(
      key: _monthlyCacheKey,
      force: force,
      fetcher: () => _service.getUpcomingSchedules(startDate, endDate),
      encode: (schedules) =>
          jsonEncode(schedules.map((s) => s.toJson()).toList()),
      decode: (json) => (jsonDecode(json) as List)
          .map(
            (e) =>
                CollectionSchedule.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
    );
    notifyListeners();
  }

  void toggleBarangay(String barangay) {
    if (!_selectedBarangays.add(barangay)) {
      _selectedBarangays.remove(barangay);
    }
    notifyListeners();
  }

  void clearBarangays() {
    _selectedBarangays.clear();
    notifyListeners();
  }

  /// Keep the local state in sync when the SWR cache refreshes in the
  /// background (so the UI updates automatically on change detection).
  void _onCacheChanged() {
    final fresh =
        _cache.stateOf<List<CollectionSchedule>>(_monthlyCacheKey);
    if (fresh != null && fresh != _state) {
      _state = fresh;
      notifyListeners();
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
