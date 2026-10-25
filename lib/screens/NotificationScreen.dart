import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import '../controllers/notification_controller.dart';
import '../models/app_notification.dart';
import '../widgets/common/swr_state_view.dart';
import '../widgets/notification/notification_card.dart';
import '../widgets/notification/notification_settings_panel.dart';
import 'notification_detail_sheet.dart';

/// Notification inbox (MVC View).
///
/// Data comes from [NotificationController] which loads through the SWR
/// cache: cached notifications render instantly, background revalidation
/// refreshes them, and pull-to-refresh forces a fetch. Includes a search box
/// and filter chips (read state, type, priority).
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

  /// How often the inbox silently re-fetches while this page is open so new
  /// notifications (from push or the admin) appear without a manual pull.
  static const Duration _pollInterval = Duration(seconds: 30);

  static const List<String> _filters = [
    'All',
    'Unread',
    'Read',
    'Collection',
    'Announcements',
    'Delayed',
    'Cancelled',
    'Upcoming',
    'Completed',
    'Mobile Update',
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
    
    // Handle Mobile Update notifications - open APK link directly
    if (notification.notificationType == 'Mobile Update' && notification.apkUrl != null && notification.apkUrl!.isNotEmpty) {
      _launchApkUrl(notification.apkUrl!);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => NotificationDetailSheet(notification: notification),
      );
    }
  }

  Future<void> _launchApkUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch APK download link.")),
        );
      }
    }
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
      case 'Read':
        return n.isRead;
      case 'Collection':
        return const {
          'Upcoming Collection',
          'Garbage Truck Arriving',
          'Garbage Truck Arrived',
          'Delayed Collection',
          'Cancelled Collection',
          'Collection Completed',
          'Collection Rescheduled',
        }.contains(n.notificationType);
      case 'Announcements':
        return n.notificationType == 'General Announcement';
      case 'Delayed':
        return n.notificationType == 'Delayed Collection';
      case 'Cancelled':
        return n.notificationType == 'Cancelled Collection';
      case 'Upcoming':
        return n.notificationType == 'Upcoming Collection';
      case 'Completed':
        return n.notificationType == 'Collection Completed';
      case 'Mobile Update':
        return n.notificationType == 'Mobile Update';
      default:
        return true;
    }
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
        return Column(
          children: [
            _buildSettingsBanner(),
            _buildSearchBar(),
            _buildFilterChips(),
            const SizedBox(height: 4),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primary,
                child: SwrStateView<List<AppNotification>>(
                  state: state,
                  onRetry: _refresh,
                  builder: (context, notifications) => _buildList(notifications),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: AppColors.lightBg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openSettings,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification Settings',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Channels and the barangays you follow',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Search notifications...',
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 22),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Color(0xFF9CA3AF), size: 20),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = _filters[index];
          final selected = _filter == label;
          return GestureDetector(
            onTap: () => setState(() => _filter = label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : const Color(0xFFE5E7EB),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF6B7280),
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
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Notifications Found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
                SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Try a different search or filter.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final notification = filtered[index];
        return NotificationCard(
          notification: notification,
          onTap: () => _openNotification(notification),
        );
      },
    );
  }
}
