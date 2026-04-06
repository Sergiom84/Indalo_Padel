import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../features/auth/providers/auth_provider.dart';

class AppBottomNav extends ConsumerWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/my-bookings');
              break;
            case 2:
              context.go('/matches');
              break;
            case 3:
              context.go('/players');
              break;
            case 4:
              context.go('/players/favorites');
              break;
            case 5:
              ref.read(authProvider.notifier).logout();
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Reservas'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), activeIcon: Icon(Icons.emoji_events), label: 'Partidos'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outlined), activeIcon: Icon(Icons.people), label: 'Jugadores'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), activeIcon: Icon(Icons.favorite), label: 'Favoritos'),
          BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Salir'),
        ],
      ),
    );
  }
}

class AppShell extends ConsumerWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  int _currentIndex(String location) {
    if (location == '/') return 0;
    if (location.startsWith('/my-bookings')) return 1;
    if (location.startsWith('/matches')) return 2;
    if (location.startsWith('/players/favorites')) return 4;
    if (location.startsWith('/players')) return 3;
    if (location.startsWith('/venues') || location.startsWith('/booking')) return 0;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNav(currentIndex: _currentIndex(location)),
    );
  }
}
