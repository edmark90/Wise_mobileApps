import 'dart:async';

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../controllers/notification_controller.dart';
import '../controllers/notification_settings_controller.dart';
import '../core/constants.dart';
import '../design_system/widgets/app_card.dart';
import '../design_system/widgets/app_text_field.dart';
import '../design_system/widgets/empty_state.dart';
import '../models/app_notification.dart';
import '../widgets/common/swr_state_view.dart';
import '../widgets/notification/notification_card.dart';
import '../widgets/notification/notification_settings_panel.dart';
import 'notification_detail_sheet.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationController _controller = NotificationController.instance;

  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _filter = 'All';

  Timer? _pollTimer;

  static const Duration _pollInterval = Duration(seconds: 30);

  static const List<String> _filters = [
    'All',
    'Unread',
    'Collection',
    'Upcoming',
    'Arriving',
    'Arrived',
    'Delayed',
    'Completed',
    'Announcements',
  ];

  @override
  void initState() {
    super.initState();
    _controller.load();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (mounted) _controller.load(force: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _controller.load(force: true);

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationSettingsPanel(),
    );
  }

  void _openNotification(AppNotification notification) {
    _controller.markAsRead(notification);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationDetailSheet(notification: notification),
    );
  }

  bool _matches(AppNotification n) {
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final title = n.title.toLowerCase();
      final message = n.message.toLowerCase();
      if (!title.contains(q) && !message.contains(q)) return false;
    }
    switch (_filter) {
      case 'Unread':
        return !n.isRead;
      case 'Collection':
        return const {
          'Upcoming Collection',
          'Garbage Collection Scheduled',
          'Collection Rescheduled',
          'Garbage Truck Arriving',
          'Truck Arriving',
          'Garbage Truck Arrived',
          'Truck Arrived',
          'Delayed Collection',
          'Collection Delayed',
          'Cancelled Collection',
          'Collection Cancelled',
          'Collection Completed',
        }.contains(n.notificationType);
      case 'Announcements':
        return n.notificationType == 'General Announcement' ||
            n.notificationType == 'Manual Announcement';
      case 'Arriving':
        return n.notificationType == 'Garbage Truck Arriving' ||
            n.notificationType == 'Truck Arriving';
      case 'Arrived':
        return n.notificationType == 'Garbage Truck Arrived' ||
            n.notificationType == 'Truck Arrived';
      case 'Delayed':
        return n.notificationType == 'Delayed Collection' ||
            n.notificationType == 'Collection Delayed' ||
            n.notificationType == 'Cancelled Collection' ||
            n.notificationType == 'Collection Cancelled' ||
            n.notificationType == 'Collection Rescheduled';
      case 'Upcoming':
        return n.notificationType == 'Upcoming Collection' ||
            n.notificationType == 'Garbage Collection Scheduled' ||
            n.notificationType == 'Collection Rescheduled';
      case 'Completed':
        return n.notificationType == 'Collection Completed';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          _controller,
          NotificationSettingsController.instance,
        ]),
        builder: (context, _) {
          final state = _controller.state;
          if (state == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          return Column(
            children: [
              _buildSettingsBanner(),
              _buildSearchBar(),
              _buildFilterChips(),
              const SizedBox(height: 6),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primary,
                  child: SwrStateView<List<AppNotification>>(
                    state: state,
                    onRetry: _refresh,
                    builder: (context, _) =>
                        _buildList(_controller.notifications),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsBanner() {
    final settings = NotificationSettingsController.instance.settings;
    final preferred = settings?.preferredBarangays ?? AppConstants.barangays;
    final String subtitleText;
    if (preferred.isEmpty) {
      subtitleText = 'No barangay selected · General announcements only';
    } else if (preferred.length == AppConstants.barangays.length) {
      subtitleText = 'Receiving alerts for all barangays';
    } else if (preferred.length <= 2) {
      subtitleText = 'Receiving alerts for ${preferred.join(', ')}';
    } else {
      subtitleText =
          'Receiving alerts for ${preferred.take(2).join(', ')} +${preferred.length - 2} more';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        color: AppColors.primaryContainer,
        borderColor: AppColors.primary.withValues(alpha: 0.2),
        borderWidth: 1,
        elevation: 0,
        borderRadius: BorderRadius.circular(14),
        onTap: _openSettings,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Settings',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: WiseSearchField(
        controller: _search,
        hint: 'Search notification messages or titles…',
        onChanged: (v) => setState(() => _query = v),
        onClear: () {
          _search.clear();
          setState(() => _query = '');
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = _filters[index];
          final selected = _filter == label;
          return GestureDetector(
            onTap: () => setState(() => _filter = label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(List<AppNotification> notifications) {
    final filtered = notifications.where(_matches).toList();
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No Notifications Found',
            message: _query.isNotEmpty
                ? 'No notifications match "$_query".'
                : 'No notifications in the "$_filter" category.',
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final notification = filtered[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: NotificationCard(
            notification: notification,
            onTap: () => _openNotification(notification),
          ),
        );
      },
    );
  }
}
