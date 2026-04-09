import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/platform/platform_helper.dart';
import '../../core/theme/app_theme.dart';

enum AppTab { home, venues, calendar, community, players, profile }

class AppBottomNav extends StatelessWidget {
  final AppTab currentTab;

  const AppBottomNav({super.key, required this.currentTab});

  int get currentIndex => AppTab.values.indexOf(currentTab);

  @override
  Widget build(BuildContext context) {
    if (isCupertinoPlatform) {
      return CupertinoTabBar(
        currentIndex: currentIndex,
        backgroundColor: AppColors.surface.withValues(alpha: 0.95),
        activeColor: AppColors.primary,
        inactiveColor: AppColors.muted,
        onTap: (index) => _onTap(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.sportscourt),
            label: 'Clubes',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            label: 'Calendario',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2),
            label: 'Comunidad',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_3),
            label: 'Jugadores',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            label: 'Perfil',
          ),
        ],
      );
    }

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) => _onTap(context, index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.sports_tennis_outlined),
          selectedIcon: Icon(Icons.sports_tennis),
          label: 'Clubes',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_today_outlined),
          selectedIcon: Icon(Icons.calendar_today),
          label: 'Calendario',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Comunidad',
        ),
        NavigationDestination(
          icon: Icon(Icons.group_outlined),
          selectedIcon: Icon(Icons.group),
          label: 'Jugadores',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }

  void _onTap(BuildContext context, int index) {
    appSelectionHaptic();
    switch (AppTab.values[index]) {
      case AppTab.home:
        context.go('/');
        break;
      case AppTab.venues:
        context.go('/venues');
        break;
      case AppTab.calendar:
        context.go('/calendar');
        break;
      case AppTab.community:
        context.go('/community');
        break;
      case AppTab.players:
        context.go('/players');
        break;
      case AppTab.profile:
        context.go('/profile');
        break;
    }
  }
}

class AppShell extends StatelessWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  AppTab _currentTab(String path) {
    if (path.startsWith('/venues') || path.startsWith('/booking')) {
      return AppTab.venues;
    }
    if (path.startsWith('/calendar') || path.startsWith('/my-bookings')) {
      return AppTab.calendar;
    }
    if (path.startsWith('/community') || path.startsWith('/matches')) {
      return AppTab.community;
    }
    if (path.startsWith('/players')) {
      return AppTab.players;
    }
    if (path.startsWith('/profile')) {
      return AppTab.profile;
    }
    return AppTab.home;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      extendBody: true,
      body: child,
      bottomNavigationBar: AppBottomNav(currentTab: _currentTab(location)),
    );
  }
}
