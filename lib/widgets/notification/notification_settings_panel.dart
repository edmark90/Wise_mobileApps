import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../controllers/notification_settings_controller.dart';
import '../../core/constants.dart';
import '../../models/notification_settings.dart';
import '../../services/push_notification_service.dart';

/// Citizen notification preferences, presented as a bottom sheet from the
/// notification inbox.
///
/// The citizen manages which channels they receive and which barangays they
/// follow. Mirrors `GET/PUT /notifications/settings` — the backend resolves
/// delivery automatically from these choices, so saving here is exactly what
/// drives push targeting.
class NotificationSettingsPanel extends StatefulWidget {
  const NotificationSettingsPanel({super.key});

  @override
  State<NotificationSettingsPanel> createState() => _NotificationSettingsPanelState();
}

class _ChannelMeta {
  const _ChannelMeta(this.title, this.subtitle, this.icon, this.color, this.bg);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bg;
}

class _NotificationSettingsPanelState extends State<NotificationSettingsPanel> {
  final NotificationSettingsController _controller =
      NotificationSettingsController.instance;

  static const List<_ChannelMeta> _channels = [
    _ChannelMeta(
      'Collection Updates',
      'New schedules for your area',
      Icons.calendar_month_rounded,
      Color(0xFF1D4ED8),
      Color(0xFFDBEAFE),
    ),
    _ChannelMeta(
      'Route Updates',
      'Truck arriving, delayed, cancelled',
      Icons.local_shipping_rounded,
      Color(0xFF0F766E),
      Color(0xFFCCFBF1),
    ),
    _ChannelMeta(
      'Collection Completed',
      'When pickup finishes',
      Icons.check_circle_rounded,
      Color(0xFF15803D),
      Color(0xFFDCFCE7),
    ),
    _ChannelMeta(
      'Announcements',
      'News from the LGU',
      Icons.campaign_rounded,
      Color(0xFF6D28D9),
      Color(0xFFEDE9FE),
    ),
    _ChannelMeta(
      'Reminders',
      'Heads-up before collection day',
      Icons.alarm_rounded,
      Color(0xFFB45309),
      Color(0xFFFEF3C7),
    ),
    _ChannelMeta(
      'Emergency Alerts',
      'Floods, typhoons, road closures',
      Icons.warning_amber_rounded,
      Color(0xFFB91C1C),
      Color(0xFFFEE2E2),
    ),
  ];

  NotificationSettings? _draft;
  bool _loaded = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _controller.load();
    if (!mounted) return;
    setState(() {
      _draft = _controller.settings ?? const NotificationSettings();
      _loaded = true;
    });
    final enabled = await PushNotificationService.instance.areNotificationsEnabled();
    if (!mounted) return;
    setState(() => _notificationsEnabled = enabled);
  }

  bool _valueAt(int index) {
    final s = _draft!;
    switch (index) {
      case 0:
        return s.collectionUpdates;
      case 1:
        return s.routeUpdates;
      case 2:
        return s.completedCollection;
      case 3:
        return s.announcements;
      case 4:
        return s.reminders;
      case 5:
        return s.emergencyAlerts;
      default:
        return true;
    }
  }

  void _setAt(int index, bool value) {
    final s = _draft!;
    setState(() {
      switch (index) {
        case 0:
          _draft = s.copyWith(collectionUpdates: value);
        case 1:
          _draft = s.copyWith(routeUpdates: value);
        case 2:
          _draft = s.copyWith(completedCollection: value);
        case 3:
          _draft = s.copyWith(announcements: value);
        case 4:
          _draft = s.copyWith(reminders: value);
        case 5:
          _draft = s.copyWith(emergencyAlerts: value);
      }
    });
  }

  void _toggleBarangay(String barangay, bool selected) {
    final s = _draft!;
    final current = List<String>.from(s.preferredBarangays);
    if (selected && !current.contains(barangay)) {
      current.add(barangay);
    } else if (!selected) {
      current.remove(barangay);
    }
    setState(() => _draft = s.copyWith(preferredBarangays: current));
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFC62828) : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    final s = _draft;
    if (s == null) return;
    final ok = await _controller.save(s);
    if (!mounted) return;
    _snack(ok ? 'Saved' : _controller.error ?? 'Could not save settings', isError: !ok);
  }

  void _reset() {
    setState(() => _draft = const NotificationSettings());
    _snack('Reset to defaults. Save to apply.');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _header(),
          Flexible(
            child: _loaded
                ? _buildBody()
                : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),
          _saveBar(),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'You control what lands in your inbox',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final settings = _draft!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_notificationsEnabled) ...[
            _disabledBanner(),
            const SizedBox(height: 16),
          ],
          _sectionLabel('Notification Channels'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _channels.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 62, color: Color(0xFFF1F5F9)),
                  _channelTile(_channels[i], _valueAt(i), (v) => _setAt(i, v)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _sectionLabel('Preferred Barangays'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${settings.preferredBarangays.length} selected',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Only receive alerts for these areas.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: settings.preferredBarangays.isEmpty
                ? Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB45309)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'No area selected — you will only get announcements sent to everyone.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF57534E), height: 1.35),
                        ),
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppConstants.barangays.map((barangay) {
                      final selected = settings.preferredBarangays.contains(barangay);
                      return _barangayChip(barangay, selected);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        color: Color(0xFF6B7280),
      ),
    );
  }

  Widget _disabledBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_off_rounded, size: 20, color: Color(0xFFC2410C)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Notifications are turned off',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C2D12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'You will not receive alerts on this device. Open your phone settings to allow notifications for WasteWise.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF9A3412), height: 1.4),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () => PushNotificationService.instance.openAppSettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC2410C),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text(
                'Enable Notifications',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelTile(_ChannelMeta meta, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: meta.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(meta.icon, color: meta.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 1),
                Text(
                  meta.subtitle,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _barangayChip(String barangay, bool selected) {
    return GestureDetector(
      onTap: () => _toggleBarangay(barangay, !selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightBg : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFD6DBE3),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.add_rounded,
              size: 15,
              color: selected ? AppColors.primary : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 5),
            Text(
              barangay,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              TextButton(
                onPressed: _controller.saving ? null : _reset,
                child: const Text(
                  'Reset',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _controller.saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _controller.saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
