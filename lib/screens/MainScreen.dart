import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/update_controller.dart';
import '../screens/update_dialog.dart';
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
    DrawerItem(icon: Icons.dashboard_rounded, title: 'Dashboard'),
    DrawerItem(icon: Icons.auto_awesome_rounded, title: 'AI Waste Input'),
    DrawerItem(icon: Icons.menu_book_rounded, title: 'Waste Guide'),
    DrawerItem(icon: Icons.calendar_month_rounded, title: 'Collection Schedule'),
    DrawerItem(icon: Icons.notifications_rounded, title: 'Notification'),
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
      NotificationController.instance.load();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await UpdateController.instance.init();
      await UpdateController.instance.checkNow();

      bool shouldShow = false;
      if (UpdateController.instance.shouldPrompt) {
        shouldShow = true;
      }
      if (UpdateController.instance.pendingNextAppOpen && UpdateController.instance.latest != null) {
        if (UpdateController.instance.latest!.versionCode > 0) {
          shouldShow = true;
        }
        await UpdateController.instance.checkPendingNextAppOpen();
      }

      debugPrint(
        "[MainScreen] shouldPrompt=${UpdateController.instance.shouldPrompt}, pending=${UpdateController.instance.pendingNextAppOpen}, latest=${UpdateController.instance.latest?.version}, latestCode=${UpdateController.instance.latest?.versionCode}",
      );

      if (mounted && shouldShow && UpdateController.instance.latest != null) {
        showUpdateDialog(context, UpdateController.instance.latest!);
      }
    });
  }

  PreferredSizeWidget _buildAppBar() {
    final isDashboard = _selectedIndex == 0;

    if (isDashboard) {
      return AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A), size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
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
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: ProfileController.instance,
            builder: (context, _) {
              final profile = ProfileController.instance.profile;
              final imageUrl = profile != null
                  ? ProfileController.instance.imageUrl(profile.profileImage)
                  : '';
              final hasImage = imageUrl.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => selectTab(5),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEFF6FF),
                    ),
                    child: hasImage
                        ? ClipOval(
                            child: Image.network(
                              imageUrl,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.person_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    return AppBar(
      title: Text(
        _drawerItems[_selectedIndex].title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
      ),
      backgroundColor: AppColors.primary,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, int unread) {
    final item = _drawerItems[index];
    final isSelected = _selectedIndex == index;
    final showBadge = index == 4 && unread > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _selectedIndex = index);
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                if (showBadge)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Clean, Spacious Profile Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    AuthController.instance,
                    ProfileController.instance,
                  ]),
                  builder: (context, _) {
                    final profile = ProfileController.instance.profile;
                    final displayName = profile?.fullname.isNotEmpty == true
                        ? profile!.fullname
                        : (widget.userName.isNotEmpty
                            ? widget.userName
                            : AuthController.instance.userName ?? 'User');
                    final displayEmail = profile?.email.isNotEmpty == true
                        ? profile!.email
                        : (widget.userEmail.isNotEmpty
                            ? widget.userEmail
                            : AuthController.instance.userEmail ?? '');
                    final photoUrl = profile != null
                        ? ProfileController.instance.imageUrl(profile.profileImage)
                        : '';
                    final hasPhoto = photoUrl.isNotEmpty;
                    final initial = displayName.trim().isNotEmpty
                        ? displayName.trim()[0].toUpperCase()
                        : 'U';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Avatar
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: hasPhoto
                                ? Image.network(
                                    photoUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
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
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // User Full Name
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // User Email
                        if (displayEmail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            displayEmail,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Drawer Navigation Items
          Expanded(
            child: ListenableBuilder(
              listenable: NotificationController.instance,
              builder: (context, _) {
                final unread = NotificationController.instance.unreadCount;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _drawerItems.length,
                  itemBuilder: (context, index) => _buildNavItem(context, index, unread),
                );
              },
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  await AuthController.instance.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
                      SizedBox(width: 14),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Version
          const Padding(
            padding: EdgeInsets.only(bottom: 16, top: 4),
            child: Text(
              'v1.2.4',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
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
        backgroundColor: _selectedIndex == 0 ? AppColors.background : Colors.white,
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

  const DrawerItem({required this.icon, required this.title});
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
