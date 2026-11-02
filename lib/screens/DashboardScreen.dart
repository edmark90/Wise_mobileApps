import 'dart:async';

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/schedule_controller.dart';
import '../models/app_notification.dart';
import '../models/collection_schedule.dart';
import '../widgets/schedule/status_timeline.dart';
import 'MainScreen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _liveStatusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProfileController.instance.load();
      NotificationController.instance.load();
      ScheduleController.instance.load();
    });
    _liveStatusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _liveStatusTimer?.cancel();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _navigateToTab(int index) {
    MainScreenScope.of(context)?.selectTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreetingHeader(),
            const SizedBox(height: 16),
            _buildNextCollectionCard(),
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 22),
            _buildQuickActions(),
            const SizedBox(height: 22),
            _buildRecentUpdates(),
          ],
        ),
      ),
    );
  }

  // ─── 1. GREETING HEADER ───────────────────────────────────
  Widget _buildGreetingHeader() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AuthController.instance,
        ProfileController.instance,
      ]),
      builder: (context, _) {
        final fullName = ProfileController.instance.profile?.fullname ??
            AuthController.instance.userName ??
            'User';
        final barangay = ProfileController.instance.profile?.barangay ?? '';
        final firstName = fullName.trim().split(' ').first.isNotEmpty
            ? fullName.trim().split(' ').first
            : 'User';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    firstName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (barangay.isNotEmpty && barangay != 'Barangay')
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        barangay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ─── 2. NEXT / TODAY'S COLLECTION CARD (MATCHING PICTURE UI) ──
  Widget _buildNextCollectionCard() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ScheduleController.instance,
        NotificationController.instance,
      ]),
      builder: (context, _) {
        final schedules = ScheduleController.instance.filteredSchedules;
        final targetDate = _resolveActiveOrNextCollectionDate(schedules);

        final daySchedules = targetDate != null
            ? (schedules.where((s) => s.collectionDate == targetDate).toList()
              ..sort((a, b) => a.collectionTime.compareTo(b.collectionTime)))
            : <CollectionSchedule>[];

        final routeItems = _extractRouteItems(daySchedules);
        final totalRoutes = routeItems.length;
        final completedRoutes =
            routeItems.where((item) => item.isCompleted).length;
        final isAllCompleted =
            totalRoutes > 0 && completedRoutes == totalRoutes;
        final isToday = targetDate != null && _isTodayDate(targetDate);

        final headerBadgeLabel =
            isToday ? "Today's Collection" : 'Next Collection';

        // Overall status badge config derived from live statuses
        final String statusText;
        final Color statusBgColor;
        final Color statusTextColor;
        final Color statusIconCircleColor;
        final IconData statusIcon;

        if (isAllCompleted) {
          statusText = 'Completed';
          statusBgColor = const Color(0xFFDCFCE7);
          statusTextColor = const Color(0xFF14532D);
          statusIconCircleColor = const Color(0xFF1E9E5A);
          statusIcon = Icons.check_rounded;
        } else if (routeItems.any((r) => r.status == 'Arrived')) {
          statusText = 'Arrived';
          statusBgColor = const Color(0xFFCCFBF1);
          statusTextColor = const Color(0xFF0F766E);
          statusIconCircleColor = const Color(0xFF0D9488);
          statusIcon = Icons.local_shipping_rounded;
        } else if (routeItems.any((r) => r.status == 'Arriving')) {
          statusText = 'Arriving';
          statusBgColor = const Color(0xFFFEF3C7);
          statusTextColor = const Color(0xFF92400E);
          statusIconCircleColor = const Color(0xFFD97706);
          statusIcon = Icons.local_shipping_rounded;
        } else if (routeItems.any((r) => r.status == 'Delayed')) {
          statusText = 'Delayed';
          statusBgColor = const Color(0xFFFEF2F2);
          statusTextColor = const Color(0xFF991B1B);
          statusIconCircleColor = const Color(0xFFDC2626);
          statusIcon = Icons.schedule_rounded;
        } else if (completedRoutes > 0) {
          statusText = 'In Progress';
          statusBgColor = const Color(0xFFFEF3C7);
          statusTextColor = const Color(0xFF92400E);
          statusIconCircleColor = const Color(0xFFD97706);
          statusIcon = Icons.local_shipping_rounded;
        } else {
          statusText = routeItems.isNotEmpty
              ? routeItems.first.status
              : 'Upcoming';
          statusBgColor = const Color(0xFFDCEAFE);
          statusTextColor = const Color(0xFF1E3A8A);
          statusIconCircleColor = const Color(0xFF2563EB);
          statusIcon = Icons.schedule_rounded;
        }

        final progressValue = totalRoutes > 0
            ? (completedRoutes / totalRoutes).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x141E3A8A),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                // Subtle bottom decorative wave accent
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 36,
                  child: CustomPaint(
                    painter: _BottomWavePainter(),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top Badges Row ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left Pill: Today's Collection / Next Collection
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCEAFE),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.local_shipping_outlined,
                                    size: 19,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      headerBadgeLabel,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Right Pill: Status Badge
                          if (targetDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: statusIconCircleColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      statusIcon,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: statusTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      if (targetDate != null) ...[
                        // ── Date + Stops Count + Truck Illustration ──
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Truck illustration on the right
                            const Positioned(
                              right: -6,
                              top: -6,
                              child: _TruckSceneIllustration(),
                            ),

                            // Date and stop completion count
                            Padding(
                              padding: const EdgeInsets.only(right: 96),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.calendar_month_rounded,
                                        size: 26,
                                        color: Color(0xFF1E3A5F),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _formatCollectionDate(targetDate),
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: -0.4,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: isAllCompleted
                                              ? const Color(0xFF28A766)
                                              : const Color(0xFF2563EB),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isAllCompleted
                                              ? Icons.check_rounded
                                              : Icons.schedule_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '$completedRoutes of $totalRoutes route${totalRoutes == 1 ? '' : 's'} completed',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF475569),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ── Progress Bar ──
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: isAllCompleted
                                ? 1.0
                                : (progressValue > 0 ? progressValue : 0.06),
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isAllCompleted
                                  ? const Color(0xFF1E9E5A)
                                  : const Color(0xFF2563EB),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── All Collection Routes List (Route Name + Truck) ──
                        Column(
                          children: [
                            for (int i = 0; i < routeItems.length; i++) ...[
                              _buildStopCard(routeItems[i]),
                              if (i < routeItems.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F6FB),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.event_available_outlined,
                                size: 26,
                                color: AppColors.textTertiary,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No upcoming collection',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Check the full schedule for area updates.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // ── Bottom CTA Button ──
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _navigateToTab(3),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF1E5EFF),
                                  Color(0xFF1545B8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x381545B8),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'View Full Schedule',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 19,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStopCard(_DashboardStopItem item) {
    final Color circleColor;
    final IconData circleIcon;
    if (item.isCompleted) {
      circleColor = const Color(0xFF1E9E5A);
      circleIcon = Icons.check_rounded;
    } else if (item.status == 'Arrived') {
      circleColor = const Color(0xFF0D9488);
      circleIcon = Icons.local_shipping_rounded;
    } else if (item.status == 'Arriving') {
      circleColor = const Color(0xFFD97706);
      circleIcon = Icons.local_shipping_rounded;
    } else if (item.status == 'Delayed' || item.status == 'Cancelled') {
      circleColor = const Color(0xFFDC2626);
      circleIcon = Icons.schedule_rounded;
    } else {
      circleColor = const Color(0xFF2563EB);
      circleIcon = Icons.local_shipping_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5ECF6)),
      ),
      child: Row(
        children: [
          // Left status circle icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              circleIcon,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),

          // Vertical divider line
          Container(
            width: 1.5,
            height: 34,
            color: const Color(0xFFD5E0EE),
          ),
          const SizedBox(width: 12),

          // Route Name & Truck
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.routeName,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      size: 13.5,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        item.truckLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.status != 'Upcoming' && !item.isCompleted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: scheduleStatusBgColor(item.status),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: scheduleStatusColor(item.status),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Right Time Pill
          if (item.formattedTime.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCEAFE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.formattedTime,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Resolves the target collection date:
  /// - Finds all dates >= today sorted chronologically.
  /// - Picks the earliest date that still has at least one uncompleted schedule.
  /// - If today's schedule is completed and a next schedule exists, automatically
  ///   advances to that next schedule date!
  /// - If all schedules from today onwards are completed, falls back to the
  ///   first date >= today (so the completed card still displays cleanly).
  String? _resolveActiveOrNextCollectionDate(
    List<CollectionSchedule> schedules,
  ) {
    if (schedules.isEmpty) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final fromToday = schedules.where((s) {
      try {
        final date = DateTime.parse(s.collectionDate);
        return !date.isBefore(today);
      } catch (_) {
        return true;
      }
    }).toList();

    final pool = fromToday.isNotEmpty ? fromToday : schedules;
    final uniqueDates = pool.map((s) => s.collectionDate).toSet().toList()
      ..sort();

    // Find the first date that has at least one uncompleted schedule
    for (final dateStr in uniqueDates) {
      final onDate = pool.where((s) => s.collectionDate == dateStr).toList();
      final anyIncomplete = onDate.any((s) => !_isScheduleCompleted(s));
      if (anyIncomplete) {
        return dateStr;
      }
    }

    // All schedules are completed — show the earliest date from today (or latest overall)
    return uniqueDates.first;
  }

  bool _isScheduleCompleted(CollectionSchedule s) {
    final live = deriveLiveStatus(s).toLowerCase();
    return live == 'completed' || live == 'cancelled';
  }

  List<_DashboardStopItem> _extractRouteItems(
    List<CollectionSchedule> daySchedules,
  ) {
    final items = <_DashboardStopItem>[];
    for (final s in daySchedules) {
      final live = deriveLiveStatus(s);
      final isDone = live == 'Completed' || live == 'Cancelled';
      final timeStr = s.formattedTime.isNotEmpty
          ? s.formattedTime
          : (s.stops.isNotEmpty ? s.stops.first.formattedTime : '');
      final truckStr = s.truckNumber.trim().isNotEmpty
          ? s.truckNumber.trim()
          : 'Standard Fleet';

      items.add(
        _DashboardStopItem(
          routeName: s.displayRouteName,
          truckLabel: truckStr,
          formattedTime: timeStr,
          status: live,
          isCompleted: isDone,
        ),
      );
    }
    return items;
  }

  bool _isTodayDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    } catch (_) {
      return false;
    }
  }

  String _formatCollectionDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      const days = [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
      ];
      return '${days[dt.weekday % 7]}, ${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return dateStr;
    }
  }

  // ─── 3. COMPACT STATS ROW ─────────────────────────────────
  Widget _buildStatsRow() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        NotificationController.instance,
        ScheduleController.instance,
      ]),
      builder: (context, _) {
        final allSchedules = ScheduleController.instance.allSchedules;
        final upcomingSchedules = ScheduleController.instance.filteredSchedules;
        final unreadCount = NotificationController.instance.unreadCount;
        final now = DateTime.now();

        final thisMonthCount = allSchedules.where((s) {
          try {
            final date = DateTime.parse(s.collectionDate);
            return date.month == now.month && date.year == now.year;
          } catch (_) {
            return false;
          }
        }).length;

        final collectionsThisMonth =
            thisMonthCount > 0 ? thisMonthCount : allSchedules.length;

        final upcomingPickups = upcomingSchedules
            .where((s) => !_isScheduleCompleted(s))
            .length;

        return Row(
          children: [
            Expanded(
              child: _buildStatTile(
                value: '$collectionsThisMonth',
                label: 'This Month',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                value: '$upcomingPickups',
                label: 'Upcoming',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                value: '$unreadCount',
                label: 'Unread',
                color: const Color(0xFFD97706),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatTile({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── 4. QUICK ACTIONS ─────────────────────────────────────
  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(
        icon: Icons.auto_awesome_rounded,
        title: 'AI Scanner',
        color: AppColors.primary,
        bgColor: AppColors.primaryContainer,
        onTap: () => _navigateToTab(1),
      ),
      _QuickAction(
        icon: Icons.menu_book_rounded,
        title: 'Waste Guide',
        color: AppColors.success,
        bgColor: AppColors.successContainer,
        onTap: () => _navigateToTab(2),
      ),
      _QuickAction(
        icon: Icons.calendar_month_rounded,
        title: 'Schedule',
        color: const Color(0xFF0284C7),
        bgColor: const Color(0xFFE0F2FE),
        onTap: () => _navigateToTab(3),
      ),
      _QuickAction(
        icon: Icons.notifications_outlined,
        title: 'Alerts',
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFEF3C7),
        onTap: () => _navigateToTab(4),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) => _buildQuickActionTile(actions[index]),
        ),
      ],
    );
  }

  Widget _buildQuickActionTile(_QuickAction action) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: action.bgColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  action.icon,
                  color: action.color,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 5. RECENT UPDATES (ANNOUNCEMENTS + NOTIFICATIONS) ────
  Widget _buildRecentUpdates() {
    return ListenableBuilder(
      listenable: NotificationController.instance,
      builder: (context, _) {
        final notifications = NotificationController.instance.notifications;
        final recent = notifications.take(3).toList();
        final unreadCount = NotificationController.instance.unreadCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Recent Updates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadCount new',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (notifications.isNotEmpty)
                  TextButton(
                    onPressed: () => _navigateToTab(4),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (recent.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'No recent notifications',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < recent.length; i++) ...[
                      _buildNotificationRow(recent[i]),
                      if (i < recent.length - 1)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.border,
                          indent: 14,
                          endIndent: 14,
                        ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationRow(AppNotification n) {
    return InkWell(
      onTap: () => _navigateToTab(4),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: n.typeBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                n.icon,
                color: n.typeColor,
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                n.isRead ? FontWeight.w500 : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!n.isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.message,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              n.formattedTime,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardStopItem {
  final String routeName;
  final String truckLabel;
  final String formattedTime;
  final String status;
  final bool isCompleted;

  const _DashboardStopItem({
    required this.routeName,
    required this.truckLabel,
    required this.formattedTime,
    required this.status,
    required this.isCompleted,
  });
}

class _QuickAction {
  final IconData icon;
  final String title;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}

// ─── TRUCK SCENE ILLUSTRATION (RIGHT SIDE OF COLLECTION CARD) ──
class _TruckSceneIllustration extends StatelessWidget {
  const _TruckSceneIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 105,
      height: 68,
      child: CustomPaint(
        painter: _TruckScenePainter(),
      ),
    );
  }
}

class _TruckScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Soft background hill
    final hillPaint = Paint()
      ..color = const Color(0xFFEFF6FF)
      ..style = PaintingStyle.fill;
    final hillPath = Path()
      ..moveTo(4, size.height - 6)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.12,
        size.width,
        size.height - 8,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hillPath, hillPaint);

    // Soft pastel trees on right
    final treePaint1 = Paint()..color = const Color(0xFFBBF7D0);
    final treePaint2 = Paint()..color = const Color(0xFF86EFAC);
    canvas.drawOval(const Rect.fromLTWH(80, 12, 16, 26), treePaint1);
    canvas.drawOval(const Rect.fromLTWH(88, 18, 14, 22), treePaint2);

    // Shadow under truck
    final shadowPaint = Paint()
      ..color = const Color(0x221E3A8A)
      ..style = PaintingStyle.fill;
    canvas.drawOval(const Rect.fromLTWH(14, 52, 74, 7), shadowPaint);

    // Truck cargo body
    final cargoRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(28, 18, 38, 30),
      const Radius.circular(4),
    );
    final cargoPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF93C5FD), Color(0xFF60A5FA)],
      ).createShader(const Rect.fromLTWH(28, 18, 38, 30));
    canvas.drawRRect(cargoRect, cargoPaint);

    // Inner cargo panel highlight
    final panelRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(32, 22, 30, 22),
      const Radius.circular(3),
    );
    canvas.drawRRect(panelRect, Paint()..color = const Color(0xFFDBEAFE));

    // Rear cab / loader section (left)
    final rearPath = Path()
      ..moveTo(28, 25)
      ..lineTo(18, 25)
      ..quadraticBezierTo(14, 26, 14, 31)
      ..lineTo(14, 48)
      ..lineTo(28, 48)
      ..close();
    canvas.drawPath(rearPath, Paint()..color = const Color(0xFF60A5FA));

    // Front cabin (right)
    final cabPath = Path()
      ..moveTo(66, 24)
      ..lineTo(80, 24)
      ..quadraticBezierTo(86, 25, 88, 34)
      ..lineTo(88, 48)
      ..lineTo(66, 48)
      ..close();
    final cabPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
      ).createShader(const Rect.fromLTWH(66, 24, 24, 24));
    canvas.drawPath(cabPath, cabPaint);

    // Front windshield
    final windowPath = Path()
      ..moveTo(70, 27)
      ..lineTo(79, 27)
      ..quadraticBezierTo(83, 28, 84, 34)
      ..lineTo(70, 34)
      ..close();
    canvas.drawPath(windowPath, Paint()..color = const Color(0xFFE0F2FE));

    // Bumper
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 46, 78, 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF2563EB),
    );

    // Wheels
    final wheelOuter = Paint()..color = const Color(0xFF1E3A8A);
    final wheelInner = Paint()..color = const Color(0xFF93C5FD);
    for (final cx in [24.0, 50.0, 76.0]) {
      canvas.drawCircle(Offset(cx, 51), 5.5, wheelOuter);
      canvas.drawCircle(Offset(cx, 51), 2.3, wheelInner);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFFEFF6FF)
      ..style = PaintingStyle.fill;
    final path1 = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.28,
        0,
        size.width * 0.58,
        size.height * 0.65,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 1.1,
        size.width,
        size.height * 0.35,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path1, paint1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
