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

  final SwrCache _cache = SwrCache.instance;
  final ScheduleService _service = ScheduleService.instance;

  SwrState<List<CollectionSchedule>>? _state;
  SwrState<List<CollectionSchedule>>? get state => _state;

  final Set<String> _selectedBarangays = {};
  Set<String> get selectedBarangays => _selectedBarangays;

  /// Message shown when selected barangays have no schedules.
  String get filteredEmptyMessage {
    if (_selectedBarangays.isEmpty) {
      return 'No collection routes scheduled\nfrom today onwards.';
    }
    final brgyList = _selectedBarangays.take(2).join(', ');
    final extra = _selectedBarangays.length > 2 ? ' and ${_selectedBarangays.length - 2} more' : '';
    final schedules = _state?.data ?? const [];
    final noSched = _selectedBarangays.where((b) => !schedules.any((s) => s.barangay == b));
    if (noSched.length == _selectedBarangays.length) {
      if (noSched.length == 1) return 'No collection schedule for ${noSched.first}.';
      return 'No collection schedule for\n$brgyList$extra.';
    }
    return 'No collection routes found\nfor selected barangay.';
  }

  /// Schedules filtered by the selected barangays (all when none selected).
  List<CollectionSchedule> get filteredSchedules {
    final all = _state?.data ?? const <CollectionSchedule>[];
    if (_selectedBarangays.isEmpty) return all;
    return all.where((s) => _selectedBarangays.contains(s.barangay)).toList();
  }

  Future<void> load({bool force = false}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = _formatDate(today);
    final endDate = _formatDate(today.add(const Duration(days: 7)));

    _state = await _cache.load<List<CollectionSchedule>>(
      key: CacheKeys.schedules,
      force: force,
      fetcher: () => _service.getUpcomingSchedules(startDate, endDate),
      encode: (schedules) => jsonEncode(schedules.map((s) => s.toJson()).toList()),
      decode: (json) => (jsonDecode(json) as List)
          .map((e) => CollectionSchedule.fromJson((e as Map).cast<String, dynamic>()))
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
    final fresh = _cache.stateOf<List<CollectionSchedule>>(CacheKeys.schedules);
    if (fresh != null && fresh != _state) {
      _state = fresh;
      notifyListeners();
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
