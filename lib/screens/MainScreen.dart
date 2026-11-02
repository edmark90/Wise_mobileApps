import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/notification_settings_controller.dart';
import '../controllers/profile_controller.dart';
import '../services/push_notification_service.dart';
import 'AiWasteInputScreen.dart';
import 'CollectionScheduleScreen.dart';
import 'DashboardScreen.dart';
import 'NotificationScreen.dart';
import 'ProfileScreen.dart';
import 'WasteGuideScreen.dart';

class MainScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const MainScreen({super.key, this.userName = '', this.userEmail = ''});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void selectTab(int index) {
    if (mounted) setState(() => _selectedIndex = index);
  }

  static const List<DrawerItem> _drawerItems = [
    DrawerItem(icon: Icons.grid_view_rounded, title: 'Dashboard'),
    DrawerItem(icon: Icons.auto_awesome_rounded, title: 'AI Waste Scanner'),
    DrawerItem(icon: Icons.menu_book_rounded, title: 'Waste Guide'),
    DrawerItem(icon: Icons.calendar_month_rounded, title: 'Collection Schedule'),
    DrawerItem(icon: Icons.notifications_rounded, title: 'Notifications'),
    DrawerItem(icon: Icons.person_rounded, title: 'Profile'),
  ];

  static const List<Widget> _screens = [
    DashboardScreen(),
    AiWasteInputScreen(),
    WasteGuideScreen(),
    CollectionScheduleScreen(),
    NotificationScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    PushNotificationService.instance.onNotificationTap = () {
      if (mounted) setState(() => _selectedIndex = 4);
    };
    if (AuthController.instance.isLoggedIn) {
      NotificationSettingsController.instance.load();
      NotificationController.instance.load();
    }
  }

  PreferredSizeWidget _buildAppBar() {
    final isDashboard = _selectedIndex == 0;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
      centerTitle: !isDashboard,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(
            Icons.menu_rounded,
            color: AppColors.textPrimary,
            size: 24,
          ),
          tooltip: 'Open navigation menu',
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: isDashboard
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'asset/logowise.png',
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                const Text(
                  'WISE',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            )
          : Text(
              _drawerItems[_selectedIndex].title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                letterSpacing: -0.2,
              ),
            ),
      actions: [
        ListenableBuilder(
          listenable: ProfileController.instance,
          builder: (context, _) {
            final profile = ProfileController.instance.profile;
            final imageUrl = profile != null
                ? ProfileController.instance.imageUrl(profile.profileImage)
                : '';
            final displayName = profile?.fullname.isNotEmpty == true
                ? profile!.fullname
                : (widget.userName.isNotEmpty ? widget.userName : 'User');
            final initial = displayName.trim().isNotEmpty
                ? displayName.trim()[0].toUpperCase()
                : 'U';

            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GestureDetector(
                onTap: () => selectTab(5),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryContainer,
                    border: Border.all(
                      color: _selectedIndex == 5
                          ? AppColors.primary
                          : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 34,
                            height: 34,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNavItem(BuildContext context, int index, int unread) {
    final item = _drawerItems[index];
    final isSelected = _selectedIndex == index;
    final showBadge = index == 4 && unread > 0;

    const selectedBlue = Color(0xFF0B57D0);
    const selectedBg = Color(0xFFE8F1FF);
    const unselectedIconColor = Color(0xFF475569);
    const unselectedTextColor = Color(0xFF1E293B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: isSelected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() => _selectedIndex = index);
            Navigator.pop(context);
          },
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left vertical blue accent bar when selected
                Container(
                  width: 4.5,
                  decoration: BoxDecoration(
                    color: isSelected ? selectedBlue : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
                      right: Radius.circular(4),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          color: isSelected ? selectedBlue : unselectedIconColor,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: isSelected
                                  ? selectedBlue
                                  : unselectedTextColor,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 15.5,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (showBadge)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0052CC),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // Decorative curved waves on top-right of blue header
          Positioned(
            top: -30,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),

          Column(
            children: [
              // ── Top Blue Profile Header (Horizontal Row) ──
              SafeArea(
                bottom: false,
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedIndex = 5);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 18, 26),
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        AuthController.instance,
                        ProfileController.instance,
                      ]),
                      builder: (context, _) {
                        final profile = ProfileController.instance.profile;
                        final displayName =
                            profile?.fullname.isNotEmpty == true
                                ? profile!.fullname
                                : (widget.userName.isNotEmpty
                                    ? widget.userName
                                    : AuthController.instance.userName ??
                                        'User');
                        final displayEmail = profile?.email.isNotEmpty == true
                            ? profile!.email
                            : (widget.userEmail.isNotEmpty
                                ? widget.userEmail
                                : AuthController.instance.userEmail ?? '');
                        final photoUrl = profile != null
                            ? ProfileController.instance
                                .imageUrl(profile.profileImage)
                            : '';
                        final hasPhoto = photoUrl.isNotEmpty;
                        final initial = displayName.trim().isNotEmpty
                            ? displayName.trim()[0].toUpperCase()
                            : 'U';

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: hasPhoto
                                    ? Image.network(
                                        photoUrl,
                                        width: 66,
                                        height: 66,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Center(
                                          child: Text(
                                            initial,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 24,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 24,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (displayEmail.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      displayEmail,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.88),
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              // ── Overlapping Rounded White Body ──
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: Listenable.merge([
                            NotificationController.instance,
                            NotificationSettingsController.instance,
                          ]),
                          builder: (context, _) {
                            final unread =
                                NotificationController.instance.unreadCount;
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: _drawerItems.length,
                              itemBuilder: (context, index) =>
                                  _buildNavItem(context, index, unread),
                            );
                          },
                        ),
                      ),

                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE2E8F0),
                      ),

                      // ── Log Out Action ──
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                await AuthController.instance.logout();
                                if (!context.mounted) return;
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/login',
                                  (route) => false,
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.logout_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 24,
                                    ),
                                    SizedBox(width: 16),
                                    Text(
                                      'Log Out',
                                      style: TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScreenScope(
      selectTab: selectTab,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        drawer: _buildDrawer(context),
        body: _screens[_selectedIndex],
      ),
    );
  }
}

class DrawerItem {
  final IconData icon;
  final String title;

  const DrawerItem({
    required this.icon,
    required this.title,
  });
}

class MainScreenScope extends InheritedWidget {
  final void Function(int) selectTab;

  const MainScreenScope({
    super.key,
    required this.selectTab,
    required super.child,
  });

  static MainScreenScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainScreenScope>();
  }

  @override
  bool updateShouldNotify(MainScreenScope oldWidget) => false;
}
