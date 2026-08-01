import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../api_service.dart';
import 'Login.dart';
import 'DashboardScreen.dart';
import 'AiWasteInputScreen.dart';
import 'WasteGuideScreen.dart';
import 'CollectionScheduleScreen.dart';
import 'NotificationScreen.dart';
import 'ProfileScreen.dart';

class MainScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const MainScreen({
    super.key,
    this.userName = '',
    this.userEmail = '',
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;


  final List<DrawerItem> _drawerItems = [
    DrawerItem(icon: Icons.dashboard_rounded, title: 'Dashboard'),
    DrawerItem(icon: Icons.auto_awesome_rounded, title: 'AI Waste Input'),
    DrawerItem(icon: Icons.menu_book_rounded, title: 'Waste Guide'),
    DrawerItem(icon: Icons.calendar_month_rounded, title: 'Collection Schedule'),
    DrawerItem(icon: Icons.notifications_rounded, title: 'Notification'),
    DrawerItem(icon: Icons.person_rounded, title: 'Profile'),
  ];

  final List<Widget> _screens = const [
    DashboardScreen(),
    AiWasteInputScreen(),
    WasteGuideScreen(),
    CollectionScheduleScreen(),
    NotificationScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _drawerItems[_selectedIndex].title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
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
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              // Drawer Header with gradient
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.recycling,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.userName.isNotEmpty ? widget.userName : 'WasteWise',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.userEmail,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Drawer Navigation Items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _drawerItems.length,
                  itemBuilder: (context, index) {
                    final item = _drawerItems[index];
                    final isSelected = _selectedIndex == index;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.lightBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          item.icon,
                          color: isSelected ? AppColors.primary : Colors.grey[600],
                          size: 24,
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : Colors.black87,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 15,
                          ),
                        ),
                        trailing: isSelected
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),

              // Logout Button
              const Divider(height: 1, color: Color(0xFFE0E0E0)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: ListTile(
                  leading: Icon(Icons.logout_rounded, color: Colors.red[400], size: 24),
                  title: Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red[400],
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () async {
                    await ApiService.clearSession();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }
}

class DrawerItem {
  final IconData icon;
  final String title;

  const DrawerItem({required this.icon, required this.title});
}
