import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../controllers/schedule_controller.dart';
import '../core/constants.dart';
import '../models/collection_schedule.dart';
import '../widgets/common/empty_state_view.dart';
import '../widgets/common/swr_state_view.dart';
import '../widgets/schedule/barangay_filter.dart';
import '../widgets/schedule/day_section_header.dart';
import '../widgets/schedule/schedule_card.dart';
import '../widgets/schedule/schedule_detail_sheet.dart';

/// Collection Schedule view (MVC View).
///
/// All data comes from [ScheduleController], which loads through the SWR
/// cache: cached schedules render instantly on every visit, a background
/// revalidation refreshes them, and pull-to-refresh forces a fetch.
class CollectionScheduleScreen extends StatefulWidget {
  const CollectionScheduleScreen({super.key});

  @override
  State<CollectionScheduleScreen> createState() => _CollectionScheduleScreenState();
}

class _CollectionScheduleScreenState extends State<CollectionScheduleScreen> {
  final ScheduleController _controller = ScheduleController.instance;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  Future<void> _refresh() => _controller.load(force: true);

  void _showScheduleDetail(CollectionSchedule schedule) {
    final all = _controller.state?.data ?? const <CollectionSchedule>[];
    final sameDaySchedules = all
        .where((s) => s.collectionDate == schedule.collectionDate)
        .toList()
      ..sort((a, b) => a.collectionTime.compareTo(b.collectionTime));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleDetailSheet(
        schedule: schedule,
        allSchedules: sameDaySchedules,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
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
          child: BarangayFilter(
            allBarangays: AppConstants.barangays,
            selected: _controller.selectedBarangays,
            onToggle: _controller.toggleBarangay,
            onClear: _controller.clearBarangays,
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateView(
              icon: _controller.selectedBarangays.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.event_busy_rounded,
              title: _controller.selectedBarangays.isNotEmpty ? 'No Schedules Found' : 'No Upcoming Schedules',
              message: _controller.filteredEmptyMessage,
              backgroundColor: _controller.selectedBarangays.isNotEmpty
                  ? const Color(0xFFFFF7ED)
                  : null,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
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
                    count += 1; // header
                    count += grouped[date]!.length; // cards
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
