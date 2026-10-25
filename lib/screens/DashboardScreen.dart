import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/schedule_controller.dart';
import '../models/app_notification.dart';
import '../models/collection_schedule.dart';
import 'MainScreen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProfileController.instance.load();
      NotificationController.instance.load();
      ScheduleController.instance.load();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: AppColors.background,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(),
              const SizedBox(height: 24),
              _buildHeroCard(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildAnnouncements(),
              const SizedBox(height: 24),
              _buildRecentNotifications(),
              const SizedBox(height: 24),
              _buildStatistics(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── GREETING ─────────────────────────────────────────────
  Widget _buildGreeting() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AuthController.instance,
        ProfileController.instance,
      ]),
      builder: (context, _) {
        final name = ProfileController.instance.profile?.fullname ??
            AuthController.instance.userName ??
            'User';
        final barangay =
            ProfileController.instance.profile?.barangay ?? 'Barangay';
        final displayName =
            name.split(' ').first.isNotEmpty ? name.split(' ').first : name;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_greeting()} 👋',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Welcome back,',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (barangay.isNotEmpty && barangay != 'Barangay') ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    Text(
                      barangay,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ─── HERO CARD ────────────────────────────────────────────
  Widget _buildHeroCard() {
    return ListenableBuilder(
      listenable: ScheduleController.instance,
      builder: (context, _) {
        final schedules = ScheduleController.instance.filteredSchedules;
        final nextSchedule = _getNextCollection(schedules);

        final daySchedules = nextSchedule != null
            ? schedules.where((s) => s.collectionDate == nextSchedule.collectionDate).toList()
            : <CollectionSchedule>[];

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF023CD1),
                Color(0xFF07207A),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              // ── Decorative dots (top-right) ──
              Positioned(
                top: 16,
                right: 16,
                child: CustomPaint(
                  size: const Size(80, 80),
                  painter: _DotsPainter(),
                ),
              ),
              // ── Decorative dots (bottom-left) ──
              Positioned(
                bottom: 16,
                left: 16,
                child: CustomPaint(
                  size: const Size(80, 80),
                  painter: _DotsPainter(),
                ),
              ),
              // ── Decorative soft circle (bottom-right) ──
              Positioned(
                bottom: -20,
                right: -10,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              // ── Decorative soft circle (top-left, behind badge) ──
              Positioned(
                top: -30,
                left: -20,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                ),
              ),
              // ── Content ──
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Badge ──
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1.2,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'NEXT COLLECTION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ── Date and Truck ──
                    if (nextSchedule != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _formatCollectionDate(nextSchedule.collectionDate),
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const GlassmorphicGarbageTruck(),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // ── Schedule list container ──
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          children: daySchedules.asMap().entries.map((entry) {
                            final i = entry.key;
                            final s = entry.value;
                            final isLast = i == daySchedules.length - 1;
                            final zone = s.zone;
                            final address = zone.isNotEmpty ? zone : s.assignedPersonnel;

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      // ── Location icon circle ──
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // ── Barangay + address (Single Line) ──
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: s.barangay,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              if (address.isNotEmpty) ...[
                                                TextSpan(
                                                  text: '  ·  $address',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.normal,
                                                    color: Colors.white.withValues(alpha: 0.75),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // ── Time capsule ──
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.15),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.schedule_outlined,
                                              size: 13,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              s.formattedTime,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // ── Divider ──
                                if (!isLast)
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Colors.white.withValues(alpha: 0.08),
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'No upcoming collection',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check the schedule for your area',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // ── Button ──
                    GestureDetector(
                      onTap: () => MainScreenScope.of(context)?.selectTab(3),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Schedule',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F4CD9),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: Color(0xFF0F4CD9),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  CollectionSchedule? _getNextCollection(List<CollectionSchedule> schedules) {
    if (schedules.isEmpty) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcoming = schedules.where((s) {
      try {
        final date = DateTime.parse(s.collectionDate);
        return !date.isBefore(today);
      } catch (_) {
        return true;
      }
    }).toList();

    if (upcoming.isEmpty) return schedules.first;
    upcoming.sort((a, b) => a.collectionDate.compareTo(b.collectionDate));
    return upcoming.first;
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
        'December'
      ];
      const days = [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday'
      ];
      return '${days[dt.weekday % 7]}, ${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return dateStr;
    }
  }

  // ─── QUICK ACTIONS ────────────────────────────────────────
  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(
        icon: Icons.calendar_month_rounded,
        title: 'Collection\nSchedule',
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        onTap: () => _navigateToTab(context, 3),
      ),
      _QuickAction(
        icon: Icons.notifications_rounded,
        title: 'Notifications',
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFEF3C7),
        onTap: () => _navigateToTab(context, 4),
      ),
      _QuickAction(
        icon: Icons.person_rounded,
        title: 'Profile',
        color: const Color(0xFF8B5CF6),
        bgColor: const Color(0xFFF5F3FF),
        onTap: () => _navigateToTab(context, 5),
      ),
      _QuickAction(
        icon: Icons.recycling_rounded,
        title: 'Waste\nGuide',
        color: const Color(0xFF22C55E),
        bgColor: const Color(0xFFF0FDF4),
        onTap: () => _navigateToTab(context, 2),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return _buildQuickActionCard(action);
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(_QuickAction action) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: action.bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  action.icon,
                  color: action.color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                action.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTab(BuildContext context, int index) {
    MainScreenScope.of(context)?.selectTab(index);
  }

  // ─── ANNOUNCEMENTS ────────────────────────────────────────
  Widget _buildAnnouncements() {
    return ListenableBuilder(
      listenable: NotificationController.instance,
      builder: (context, _) {
        final notifications = NotificationController.instance.notifications;
        final announcements = notifications
            .where((n) =>
                n.notificationType == 'General Announcement' ||
                n.notificationType == 'Manual Announcement')
            .take(5)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Announcements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (announcements.isNotEmpty)
                  TextButton(
                    onPressed: () => _navigateToTab(context, 4),
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (announcements.isEmpty)
              _buildEmptyAnnouncements()
            else
              SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: announcements.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _buildAnnouncementCard(announcements[index]);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAnnouncementCard(AppNotification notification) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: notification.typeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notification.notificationType,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: notification.typeColor,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              notification.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            notification.message,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            notification.formattedTime,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAnnouncements() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_rounded,
              size: 32,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              'No announcements yet',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RECENT NOTIFICATIONS ─────────────────────────────────
  Widget _buildRecentNotifications() {
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
                      'Recent Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (notifications.isNotEmpty)
                  TextButton(
                    onPressed: () => _navigateToTab(context, 4),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              _buildEmptyNotifications()
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < recent.length; i++) ...[
                      _buildNotificationItem(recent[i]),
                      if (i < recent.length - 1)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.border,
                          indent: 64,
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

  Widget _buildNotificationItem(AppNotification notification) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          NotificationController.instance.markAsRead(notification);
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: notification.typeBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  notification.icon,
                  color: notification.typeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Time
              Text(
                notification.formattedTime,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 28,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No notifications',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'You\'re all caught up!',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATISTICS ───────────────────────────────────────────
  Widget _buildStatistics() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        NotificationController.instance,
        ScheduleController.instance,
      ]),
      builder: (context, _) {
        final schedules = ScheduleController.instance.filteredSchedules;
        final unreadCount = NotificationController.instance.unreadCount;
        final now = DateTime.now();

        // Count collections this month
        final collectionsThisMonth = schedules.where((s) {
          try {
            final date = DateTime.parse(s.collectionDate);
            return date.month == now.month && date.year == now.year;
          } catch (_) {
            return false;
          }
        }).length;

        // Count upcoming pickups
        final upcomingPickups = schedules.where((s) {
          try {
            final date = DateTime.parse(s.collectionDate);
            final today = DateTime(now.year, now.month, now.day);
            return !date.isBefore(today);
          } catch (_) {
            return false;
          }
        }).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    value: '$collectionsThisMonth',
                    subtitle: 'Collections\nThis Month',
                    icon: Icons.delete_rounded,
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    value: '$upcomingPickups',
                    subtitle: 'Upcoming\nPickups',
                    icon: Icons.local_shipping_rounded,
                    color: const Color(0xFF22C55E),
                    bgColor: const Color(0xFFF0FDF4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    value: '$unreadCount',
                    subtitle: 'Unread\nNotifications',
                    icon: Icons.mark_email_unread_rounded,
                    color: const Color(0xFFF59E0B),
                    bgColor: const Color(0xFFFEF3C7),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QUICK ACTION MODEL ────────────────────────────────────
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

// ─── GLASSMORPHIC GARBAGE TRUCK ──────────────────────────────
class GlassmorphicGarbageTruck extends StatelessWidget {
  const GlassmorphicGarbageTruck({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 65,
      child: CustomPaint(
        painter: _GarbageTruckPainter(),
      ),
    );
  }
}

class _GarbageTruckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle shadow under the truck
    final paintShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromLTRB(6, 51, 88, 55),
      paintShadow,
    );

    final paintBody = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.24),
          Colors.white.withValues(alpha: 0.06),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final paintBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.35);

    // 1. Cargo Box (Right part)
    final cargoPath = Path()
      ..moveTo(34, 6)
      ..lineTo(74, 6)
      ..quadraticBezierTo(84, 8, 86, 18)
      ..lineTo(86, 44)
      ..lineTo(34, 44)
      ..close();

    canvas.drawPath(cargoPath, paintBody);
    canvas.drawPath(cargoPath, paintBorder);

    // 2. Cabin (Left part)
    final cabinPath = Path()
      ..moveTo(34, 18)
      ..lineTo(18, 18)
      ..quadraticBezierTo(10, 20, 8, 28)
      ..lineTo(8, 44)
      ..lineTo(34, 44)
      ..close();

    canvas.drawPath(cabinPath, paintBody);
    canvas.drawPath(cabinPath, paintBorder);

    // 3. Cabin Windshield / Window
    final windowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.25);

    final windowPath = Path()
      ..moveTo(28, 22)
      ..lineTo(18, 22)
      ..quadraticBezierTo(14, 23, 13, 28)
      ..lineTo(13, 34)
      ..lineTo(28, 34)
      ..close();

    canvas.drawPath(windowPath, windowPaint);
    canvas.drawPath(windowPath, paintBorder);

    // 4. Recycling icon inside cargo box
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.recycling.codePoint),
        style: TextStyle(
          fontSize: 20,
          fontFamily: Icons.recycling.fontFamily,
          package: Icons.recycling.fontPackage,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(60 - textPainter.width / 2, 25 - textPainter.height / 2),
    );

    // 5. Wheels
    final wheelCenters = [
      const Offset(20, 46),
      const Offset(50, 46),
      const Offset(72, 46),
    ];

    final paintWheelOuter = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.08),
        ],
      ).createShader(Rect.fromCircle(center: const Offset(0, 0), radius: 6.5));

    final paintWheelHub = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.45);

    for (final center in wheelCenters) {
      canvas.drawCircle(center, 6.5, paintWheelOuter);
      canvas.drawCircle(center, 6.5, paintBorder);
      canvas.drawCircle(center, 2.2, paintWheelHub);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── DOTS PAINTER (decorative) ─────────────────────────────
class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const spacing = 12.0;
    final rows = (size.height / spacing).ceil();
    final cols = (size.width / spacing).ceil();

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final dx = c * spacing;
        final dy = r * spacing;
        if (dx <= size.width && dy <= size.height) {
          canvas.drawCircle(Offset(dx, dy), 1.0, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
