import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/assignment_store.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.store, required this.child});

  final AssignmentStore store;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexFor(location),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/assignments');
              break;
            case 1:
              context.go('/sync');
              break;
            case 2:
              context.go('/reminders');
              break;
            case 3:
              context.go('/profile');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: '作业'),
          NavigationDestination(
              icon: Icon(Icons.sync_outlined),
              selectedIcon: Icon(Icons.sync),
              label: '同步'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: '提醒'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的'),
        ],
      ),
    );
  }

  int _indexFor(String location) {
    if (location.startsWith('/sync')) {
      return 1;
    }
    if (location.startsWith('/reminders')) {
      return 2;
    }
    if (location.startsWith('/profile')) {
      return 3;
    }
    return 0;
  }
}

class StudyAssistantTheme {
  static ThemeData get light {
    const ink = Color(0xFF17211D);
    const paper = Color(0xFFF7F8F8);
    const mint = Color(0xFF20B8A4);
    const amber = Color(0xFFE8A336);

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: mint,
        brightness: Brightness.light,
        surface: paper,
        primary: mint,
        secondary: amber,
      ),
      scaffoldBackgroundColor: paper,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: paper,
          foregroundColor: ink),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE7E9E8))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
      ),
      navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white, indicatorColor: Color(0xFFD8F3EE)),
    );
  }
}
