import 'package:flutter/material.dart';
import '../chat/chat_screen.dart';
import '../plans/daily_plan_screen.dart';
import '../chat/memory_vault_screen.dart';
import 'home_tab.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}


class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeTab(),
    const DailyPlanScreen(),
    const MemoryVaultScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 67,
          indicatorColor: const Color(0xFF006B6B).withAlpha(30),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006B6B),
              );
            }
            return TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                size: 26,
                color: Color(0xFF006B6B),
              );
            }
            return IconThemeData(
              size: 26,
              color: Colors.grey[700],
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: "Home",
            ),
            const NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: "Plan",
            ),
            const NavigationDestination(
              icon: Icon(Icons.add_box_outlined, size: 30),
              selectedIcon: Icon(Icons.add_box_rounded, size: 30),
              label: "Memory",
            ),
            const NavigationDestination(
              icon: Icon(Icons.chat_outlined),
              selectedIcon: Icon(Icons.chat),
              label: "Coach",
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline, size: 28),
              selectedIcon: Icon(Icons.person, size: 28),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}
