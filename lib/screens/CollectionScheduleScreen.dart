import 'dart:async';

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../controllers/notification_controller.dart';
import '../controllers/schedule_controller.dart';
import '../core/constants.dart';
import '../design_system/widgets/empty_state.dart';
import '../models/collection_schedule.dart';
import '../widgets/common/swr_state_view.dart';
import '../widgets/schedule/barangay_filter.dart';
import '../widgets/schedule/day_section_header.dart';
import '../widgets/schedule/schedule_card.dart';
import '../widgets/schedule/schedule_detail_sheet.dart';

class CollectionScheduleScreen extends StatefulWidget {
  const CollectionScheduleScreen({super.key});

  @override
  State<CollectionScheduleScreen> createState() => _CollectionScheduleScreenState();
}

class _CollectionScheduleScreenState extends State<CollectionScheduleScreen> {
  final ScheduleController _controller = ScheduleController.instance;
  Timer? _liveStatusTimer;

  @override
  void initState() {
    super.initState();
    _controller.load();
    NotificationController.instance.load();
    _liveStatusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _liveStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      _controller.load(force: true),
      NotificationController.instance.load(force: true),
    ]);
  }

  void _showScheduleDetail(CollectionSchedule schedule) {
    final all = _controller.state?.data ?? const <CollectionSchedule>[];
    final sameDateSchedules = all
        .where((s) => s.collectionDate == schedule.collectionDate)
        .toList()
      ..sort((a, b) => a.collectionTime.compareTo(b.collectionTime));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleDetailSheet(
        schedule: schedule,
        allSchedules: sameDateSchedules.isNotEmpty ? sameDateSchedules : [schedule],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _controller,
        NotificationController.instance,
      ]),
      builder: (context, _) {
        final state = _controller.state;
        if (state == null) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: SwrStateView<List<CollectionSchedule>>(
            state: state,
            onRetry: _refresh,
            builder: (context, schedules) => _buildList(schedules),
          ),
        );
      },
    );
  }

  Widget _buildList(List<CollectionSchedule> schedules) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final filtered = _controller.filteredSchedules;
    final grouped = _groupByDate(filtered);
    final sortedDates = grouped.keys.toList()..sort((a, b) => a.compareTo(b));

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: BarangayFilter(
              allBarangays: AppConstants.barangays,
              selected: _controller.selectedBarangays,
              onToggle: _controller.toggleBarangay,
              onClear: _controller.clearBarangays,
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: EmptyState(
                icon: _controller.selectedBarangays.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.event_busy_rounded,
                title: _controller.selectedBarangays.isNotEmpty
                    ? 'No Schedules in Selected Barangay'
                    : 'No Upcoming Collection Schedules',
                message: _controller.filteredEmptyMessage,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  int itemIdx = 0;
                  for (int d = 0; d < sortedDates.length; d++) {
                    final date = sortedDates[d];
                    if (itemIdx == index) {
                      return DaySectionHeader(
                        label: _formatDayLabel(date, today),
                        shortDate: _formatShortDate(date),
                        routeCount: grouped[date]!.length,
                        dayDiff: _dayCount(date, today),
                      );
                    }
                    itemIdx++;
                    final routes = grouped[date]!;
                    for (int r = 0; r < routes.length; r++) {
                      if (itemIdx == index) {
                        return ScheduleCard(
                          schedule: routes[r],
                          cardIndex: r,
                          totalInGroup: routes.length,
                          onTap: () => _showScheduleDetail(routes[r]),
                        );
                      }
                      itemIdx++;
                    }
                  }
                  return const SizedBox.shrink();
                },
                childCount: () {
                  var count = 0;
                  for (final date in sortedDates) {
                    count += 1;
                    count += grouped[date]!.length;
                  }
                  return count;
                }(),
              ),
            ),
          ),
      ],
    );
  }

  Map<String, List<CollectionSchedule>> _groupByDate(List<CollectionSchedule> schedules) {
    final map = <String, List<CollectionSchedule>>{};
    for (final s in schedules) {
      map.putIfAbsent(s.collectionDate, () => []).add(s);
    }
    for (final date in map.keys) {
      map[date]!.sort((a, b) => a.collectionTime.compareTo(b.collectionTime));
    }
    return map;
  }

  String _formatDayLabel(String dateStr, DateTime today) {
    try {
      final dt = DateTime.parse(dateStr);
      final t = DateTime(today.year, today.month, today.day);
      final d = DateTime(dt.year, dt.month, dt.day);
      final diff = d.difference(t).inDays;

      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      if (diff == 2) return '2 Days From Now';
      if (diff == 3) return '3 Days From Now';

      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatShortDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return dateStr;
    }
  }

  int _dayCount(String dateStr, DateTime today) {
    try {
      final dt = DateTime.parse(dateStr);
      final t = DateTime(today.year, today.month, today.day);
      final d = DateTime(dt.year, dt.month, dt.day);
      return d.difference(t).inDays;
    } catch (_) {
      return 999;
    }
  }
}
