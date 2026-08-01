import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../api_service.dart';

class CollectionScheduleScreen extends StatefulWidget {
  const CollectionScheduleScreen({super.key});

  @override
  State<CollectionScheduleScreen> createState() => _CollectionScheduleScreenState();
}

class _CollectionScheduleScreenState extends State<CollectionScheduleScreen> {

  List<CollectionSchedule> _schedules = [];
  bool _isLoading = false;
  String? _error;
  final Set<String> _selectedBarangays = {};

  // All barangays in Muntinlupa (from the website)
  static const List<String> allBarangays = [
    'Alabang', 'Ayala Alabang', 'Bayanan', 'Buli',
    'Cupang', 'New Alabang Village', 'Poblacion',
    'Putatan', 'Sucat', 'Tunasan',
  ];

  // Message shown when selected barangays have no schedules
  String get _filteredEmptyMessage {
    if (_selectedBarangays.isEmpty) {
      return 'No collection routes scheduled\nfrom today onwards.';
    }
    final brgyList = _selectedBarangays.take(2).join(', ');
    final extra = _selectedBarangays.length > 2 ? ' and ${_selectedBarangays.length - 2} more' : '';
    // Check which selected have no schedules at all
    final noSched = _selectedBarangays.where((b) =>
      !_schedules.any((s) => s.barangay == b));
    if (noSched.length == _selectedBarangays.length) {
      // None of the selected have schedules
      if (noSched.length == 1) {
        return 'No collection schedule for ${noSched.first}.';
      }
      return 'No collection schedule for\n$brgyList$extra.';
    }
    return 'No collection routes found\nfor selected barangay.';
  }

  // Filter schedules by selected barangays (show all if none selected)
  List<CollectionSchedule> get _filteredSchedules {
    if (_selectedBarangays.isEmpty) return _schedules;
    return _schedules.where((s) => _selectedBarangays.contains(s.barangay)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  String _pad(int n) => n < 10 ? '0$n' : '$n';

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

      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatShortDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final startDate = '${today.year}-${_pad(today.month)}-${_pad(today.day)}';
      final futureDate = DateTime(today.year, today.month, today.day + 7);
      final endDate = '${futureDate.year}-${_pad(futureDate.month)}-${_pad(futureDate.day)}';

      final schedules = await ApiService.getUpcomingSchedules(startDate, endDate);

      if (mounted) {
        setState(() {
          _schedules = schedules;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  // Group schedules by date (using filtered schedules)
  Map<String, List<CollectionSchedule>> _groupByDate() {
    final map = <String, List<CollectionSchedule>>{};
    final source = _filteredSchedules;
    for (final s in source) {
      final date = s.collectionDate;
      map.putIfAbsent(date, () => []);
      map[date]!.add(s);
    }
    // Sort schedules within each date group by time
    for (final date in map.keys) {
      map[date]!.sort((a, b) => a.collectionTime.compareTo(b.collectionTime));
    }
    return map;
  }

  void _showScheduleDetail(CollectionSchedule schedule) {
    // Get only schedules from the same date as this schedule
    final sameDaySchedules = _schedules
        .where((s) => s.collectionDate == schedule.collectionDate)
        .toList()
      ..sort((a, b) => a.collectionTime.compareTo(b.collectionTime));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ScheduleDetailSheet(
        schedule: schedule,
        allSchedules: sameDaySchedules,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Compute grouped data
    final grouped = _groupByDate();
    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return RefreshIndicator(
      onRefresh: _loadSchedules,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          // === LOADING STATE ===
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )

          // === ERROR STATE ===
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_off_rounded, color: Color(0xFF991B1B), size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Connection Error',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadSchedules,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )

          // === BARANGAY FILTER BAR ===
          else
            SliverToBoxAdapter(
              child: _BarangayFilter(
                allBarangays: allBarangays,
                selected: _selectedBarangays,
                onToggle: (brgy) {
                  setState(() {
                    if (_selectedBarangays.contains(brgy)) {
                      _selectedBarangays.remove(brgy);
                    } else {
                      _selectedBarangays.add(brgy);
                    }
                  });
                },
                onClear: () {
                  setState(() => _selectedBarangays.clear());
                },
              ),
            ),

          // === EMPTY STATE ===
          if (_filteredSchedules.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: _selectedBarangays.isNotEmpty ? const Color(0xFFFFF7ED) : AppColors.lightBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedBarangays.isNotEmpty ? Icons.search_off_rounded : Icons.event_busy_rounded,
                        color: AppColors.primary,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedBarangays.isNotEmpty ? 'No Schedules Found' : 'No Upcoming Schedules',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _filteredEmptyMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
                    ),
                  ],
                ),
              ),
            )

          // === GROUPED SCHEDULE LIST ===
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Build flat items dynamically
                    int itemIdx = 0;
                    for (int d = 0; d < sortedDates.length; d++) {
                      final date = sortedDates[d];
                      // Day header
                      if (itemIdx == index) {
                        return _DaySectionHeader(
                          label: _formatDayLabel(date, today),
                          shortDate: _formatShortDate(date),
                          routeCount: grouped[date]!.length,
                          dayDiff: _dayCount(date, today),
                        );
                      }
                      itemIdx++;

                      // Route cards for this date
                      final routes = grouped[date]!;
                      for (int r = 0; r < routes.length; r++) {
                        if (itemIdx == index) {
                          return _ScheduleCard(
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
                    int count = 0;
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
      ),
    );
  }
}

// =================================================================
// Day Section Header Widget
// =================================================================
class _DaySectionHeader extends StatelessWidget {
  final String label;
  final String shortDate;
  final int routeCount;
  final int dayDiff;

  const _DaySectionHeader({
    required this.label,
    required this.shortDate,
    required this.routeCount,
    required this.dayDiff,
  });


  Color _labelColor() {
    if (dayDiff == 0) return AppColors.primary;
    if (dayDiff == 1) return const Color(0xFF3B82F6);
    return const Color(0xFF6B7280);
  }

  IconData _labelIcon() {
    if (dayDiff == 0) return Icons.today_rounded;      if (dayDiff == 1) return Icons.event_available_rounded;
    return Icons.calendar_month_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _labelColor();
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_labelIcon(), color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              shortDate,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$routeCount route${routeCount > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// Schedule Card Widget
// =================================================================
class _ScheduleCard extends StatelessWidget {
  final CollectionSchedule schedule;
  final int cardIndex;
  final int totalInGroup;
  final VoidCallback onTap;

  const _ScheduleCard({
    required this.schedule,
    required this.cardIndex,
    required this.totalInGroup,
    required this.onTap,
  });


  Color _zoneColor(String zone) {
    switch (zone) {
      case 'Zone 1': return const Color(0xFF16A34A);
      case 'Zone 2': return const Color(0xFF3B82F6);
      case 'Zone 3': return const Color(0xFFF59E0B);
      case 'Zone 4': return const Color(0xFF8B5CF6);
      case 'Zone 5': return const Color(0xFFEC4899);
      default: return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zoneColor = _zoneColor(schedule.zone);
    final isFirst = cardIndex == 0;
    final isLast = cardIndex == totalInGroup - 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isFirst ? AppColors.primary.withValues(alpha: 0.15) : const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: isFirst ? AppColors.primary.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left timeline bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        if (isFirst) AppColors.primary else const Color(0xFFCBD5E1),
                        if (isLast) AppColors.primary else const Color(0xFFCBD5E1),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Time column
                SizedBox(
                  width: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        schedule.formattedTime.split(' ')[0],
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        schedule.formattedTime.split(' ')[1],
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Vertical divider
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.grey[200],
                  margin: const EdgeInsets.symmetric(vertical: 12),
                ),
                const SizedBox(width: 10),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                schedule.barangay,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: schedule.statusBgColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                schedule.status,
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: schedule.statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 12, color: zoneColor),
                            const SizedBox(width: 3),
                            Text(
                              schedule.zone.isEmpty ? 'No zone' : schedule.zone,
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                            if (schedule.assignedPersonnel.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Icon(Icons.person_outline, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 3),
                              Text(
                                schedule.assignedPersonnel,
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =================================================================
// Schedule Detail Bottom Sheet
// =================================================================
class _ScheduleDetailSheet extends StatelessWidget {
  final CollectionSchedule schedule;
  final List<CollectionSchedule> allSchedules;

  const _ScheduleDetailSheet({
    required this.schedule,
    required this.allSchedules,
  });


  Color _zoneColor(String zone) {
    switch (zone) {
      case 'Zone 1': return const Color(0xFF16A34A);
      case 'Zone 2': return const Color(0xFF3B82F6);
      case 'Zone 3': return const Color(0xFFF59E0B);
      case 'Zone 4': return const Color(0xFF8B5CF6);
      case 'Zone 5': return const Color(0xFFEC4899);
      default: return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zoneColor = _zoneColor(schedule.zone);
    final index = allSchedules.indexOf(schedule);
    final routeStops = allSchedules.map((s) => s.barangay).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: schedule.statusBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: schedule.statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COLLECTION ROUTE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        schedule.barangay,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schedule.formattedDate,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: schedule.statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    schedule.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: schedule.statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 24, indent: 20, endIndent: 20),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Cards Row
                  Row(
                    children: [
                      _InfoCard(
                        icon: Icons.access_time_rounded,
                        label: 'Time',
                        value: schedule.formattedTime,
                        color: const Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 10),
                      _InfoCard(
                        icon: Icons.location_on_rounded,
                        label: 'Zone',
                        value: schedule.zone.isEmpty ? 'N/A' : schedule.zone,
                        color: zoneColor,
                      ),
                      const SizedBox(width: 10),
                      _InfoCard(
                        icon: Icons.person_outline,
                        label: 'Personnel',
                        value: schedule.assignedPersonnel.isEmpty ? 'N/A' : schedule.assignedPersonnel,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Route Preview Title
                  Row(
                    children: [
                      const Icon(Icons.route_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Route Preview',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      Text(
                        '${routeStops.length} stop${routeStops.length > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Route Journey Preview (S-curve road through the day's stops)
                  _RouteJourneyView(
                    stops: allSchedules,
                    currentIndex: index,
                  ),

                  const SizedBox(height: 24),

                  // All Routes for the Day
                  const Text(
                    'All Routes Today',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(allSchedules.length, (i) {
                    final s = allSchedules[i];
                    final isCurrent = i == index;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isCurrent ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isCurrent ? AppColors.primary : Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? Colors.white : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.barangay,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                Text(
                                  '${s.formattedTime} • ${s.zone.isEmpty ? 'No zone' : s.zone}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: s.statusBgColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              s.status,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: s.statusColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// Route Journey Preview — S-curve road through the day's stops
// =================================================================
class _RouteJourneyView extends StatefulWidget {
  final List<CollectionSchedule> stops;
  final int currentIndex;

  const _RouteJourneyView({required this.stops, required this.currentIndex});

  @override
  State<_RouteJourneyView> createState() => _RouteJourneyViewState();
}

class _RouteJourneyViewState extends State<_RouteJourneyView>
    with SingleTickerProviderStateMixin {
  static const double _rowHeight = 60;
  static const double _pinLane = 44;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color _zoneColor(String zone) {
    switch (zone) {
      case 'Zone 1': return const Color(0xFF16A34A);
      case 'Zone 2': return const Color(0xFF3B82F6);
      case 'Zone 3': return const Color(0xFFF59E0B);
      case 'Zone 4': return const Color(0xFF8B5CF6);
      case 'Zone 5': return const Color(0xFFEC4899);
      default: return const Color(0xFF6B7280);
    }
  }

  // Pin color encodes the stop's role in the run: start, end, or "you're here".
  Color _pinColor(int i) {
    if (i == widget.currentIndex) return const Color(0xFFF59E0B);
    if (i == 0) return AppColors.primary;
    if (i == widget.stops.length - 1) return const Color(0xFFEF4444);
    return const Color(0xFF94A3B8);
  }

  BoxDecoration _surface() => BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      );

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    if (stops.isEmpty) return const SizedBox.shrink();
    final animate = !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

    // Single stop: one centered card beside the pin, no road.
    if (stops.length == 1) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _surface(),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StopPin(
                number: '1',
                color: _pinColor(0),
                isCurrent: widget.currentIndex == 0,
                pulse: animate ? _pulse : null,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: _StopCard(
                  stop: stops[0],
                  isCurrent: widget.currentIndex == 0,
                  isFirst: true,
                  isLast: true,
                  zoneColor: _zoneColor(stops[0].zone),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: _surface(),
      child: SizedBox(
        height: _rowHeight * stops.length,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _RouteRoadPainter(
                stopCount: stops.length,
                rowHeight: _rowHeight,
                wave: 14,
              ),
            ),
            Column(
              children: List.generate(stops.length, (i) {
                final card = _StopCard(
                  stop: stops[i],
                  isCurrent: i == widget.currentIndex,
                  isFirst: i == 0,
                  isLast: i == stops.length - 1,
                  zoneColor: _zoneColor(stops[i].zone),
                );
                final pin = _StopPin(
                  number: '${i + 1}',
                  color: _pinColor(i),
                  isCurrent: i == widget.currentIndex,
                  pulse: animate ? _pulse : null,
                );
                return SizedBox(
                  height: _rowHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (i.isEven)
                        Expanded(child: Align(alignment: Alignment.centerRight, child: card))
                      else
                        const Expanded(child: SizedBox()),
                      SizedBox(width: _pinLane, child: Center(child: pin)),
                      if (i.isOdd)
                        Expanded(child: Align(alignment: Alignment.centerLeft, child: card))
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// Route Road Painter — draws the snaking road with a dashed center
// =================================================================
class _RouteRoadPainter extends CustomPainter {
  final int stopCount;
  final double rowHeight;
  final double wave;

  _RouteRoadPainter({required this.stopCount, required this.rowHeight, required this.wave});

  @override
  void paint(Canvas canvas, Size size) {
    if (stopCount < 2) return;
    final cx = size.width / 2;
    final points = <Offset>[
      for (int i = 0; i < stopCount; i++) Offset(cx, rowHeight * (i + 0.5)),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final dy = curr.dy - prev.dy;
      final dir = i.isEven ? 1.0 : -1.0;
      path.cubicTo(
        prev.dx + wave * dir, prev.dy + dy * 0.4,
        curr.dx + wave * dir, curr.dy - dy * 0.4,
        curr.dx, curr.dy,
      );
    }

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFE2E8F0);
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF94A3B8);
    canvas.drawPath(path, bg);
    canvas.drawPath(path, fill);

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF59E0B);
    _drawDashed(canvas, path, dash);
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    final metric = path.computeMetrics().first;
    const dash = 5.0;
    const gap = 6.0;
    var distance = 0.0;
    while (distance < metric.length) {
      final start = distance.clamp(0.0, metric.length);
      final end = (distance + dash).clamp(0.0, metric.length);
      canvas.drawPath(metric.extractPath(start, end), paint);
      distance += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _RouteRoadPainter oldDelegate) =>
      oldDelegate.stopCount != stopCount ||
      oldDelegate.rowHeight != rowHeight ||
      oldDelegate.wave != wave;
}

// =================================================================
// Stop Pin — numbered marker on the road, pulses when "you're here"
// =================================================================
class _StopPin extends StatelessWidget {
  final String number;
  final Color color;
  final bool isCurrent;
  final Animation<double>? pulse;

  const _StopPin({
    required this.number,
    required this.color,
    required this.isCurrent,
    this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pulse != null)
            ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 2.0).animate(pulse!),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.35, end: 0.0).animate(pulse!),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6),
              ],
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// Stop Card — barangay + time + zone, alternates beside the road
// =================================================================
class _StopCard extends StatelessWidget {
  final CollectionSchedule stop;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;
  final Color zoneColor;

  const _StopCard({
    required this.stop,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
    required this.zoneColor,
  });

  String? _tag() {
    if (isCurrent) return 'YOU ARE HERE';
    if (isFirst) return 'START';
    if (isLast) return 'END';
    return null;
  }

  Color _tagColor() => isCurrent
      ? const Color(0xFFF59E0B)
      : (isFirst ? const Color(0xFF16A34A) : const Color(0xFFEF4444));

  @override
  Widget build(BuildContext context) {
    final tag = _tag();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? AppColors.primary.withValues(alpha: 0.4) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stop.barangay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ),
                if (tag != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: _tagColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: _tagColor(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 10, color: Colors.grey[500]),
                const SizedBox(width: 3),
                Text(
                  stop.formattedTime,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (stop.zone.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.location_on_rounded, size: 10, color: zoneColor),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      stop.zone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// Supporting Widgets
// =================================================================

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800]),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// Barangay Filter Widget
// =================================================================
class _BarangayFilter extends StatelessWidget {
  final List<String> allBarangays;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;

  const _BarangayFilter({
    required this.allBarangays,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });


  @override
  Widget build(BuildContext context) {
    if (allBarangays.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_rounded, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
        selected.isEmpty ? 'Select barangay' : '${selected.length} selected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              if (selected.isNotEmpty) ...[                const Spacer(),
                GestureDetector(
                  onTap: onClear,
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allBarangays.map((brgy) {
              final isSelected = selected.contains(brgy);
              return GestureDetector(
                onTap: () => onToggle(brgy),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : const Color(0xFFD1D5DB),
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(right: 5),
                          child: Icon(Icons.check, size: 12, color: Colors.white),
                        ),
                      Text(
                        brgy,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}



