import 'package:flutter/material.dart';

import 'features/discover/screens/discover_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/library/screens/library_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/statistics/screens/statistics_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static const homeTab = 0;
  static const libraryTab = 1;
  static const discoverTab = 2;
  static const statisticsTab = 3;
  static const profileTab = 4;

  /// Cambia de pestaña desde cualquier pantalla interna.
  static void goToTab(BuildContext context, int index) {
    context.findAncestorStateOfType<MainNavigationScreenState>()?.selectTab(index);
  }

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  void selectTab(int index) => setState(() => _selectedIndex = index);

  static const _screens = [
    HomeScreen(),
    LibraryScreen(),
    DiscoverScreen(),
    StatisticsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Biblioteca',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Descubrir',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Estadísticas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
