import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/platform/platform_helper.dart';
import '../../core/theme/app_theme.dart';

enum AppTab { home, venues, calendar, community, players, profile }

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isCupertinoPlatform) {
      return CupertinoTabBar(
        currentIndex: currentIndex,
        backgroundColor: AppColors.surface.withValues(alpha: 0.95),
        activeColor: AppColors.primary,
        inactiveColor: AppColors.muted,
        onTap: onTap,
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

    return _ScrollableAppBottomNav(
      currentIndex: currentIndex,
      onTap: onTap,
    );
  }
}

class _ScrollableAppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ScrollableAppBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  static const double _destinationWidth = 96;
  static const double _destinationSpacing = 8;

  @override
  Widget build(BuildContext context) {
    const destinations = <_BottomNavDestination>[
      _BottomNavDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Inicio',
      ),
      _BottomNavDestination(
        icon: Icons.sports_tennis_outlined,
        selectedIcon: Icons.sports_tennis,
        label: 'Clubes',
      ),
      _BottomNavDestination(
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_today,
        label: 'Calendario',
      ),
      _BottomNavDestination(
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        label: 'Comunidad',
      ),
      _BottomNavDestination(
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
        label: 'Jugadores',
      ),
      _BottomNavDestination(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Perfil',
      ),
    ];

    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = destinations.length * _destinationWidth +
                  (destinations.length - 1) * _destinationSpacing;
              final shouldCenter = contentWidth < constraints.maxWidth;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Align(
                    alignment:
                        shouldCenter ? Alignment.center : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < destinations.length; i++) ...[
                            _ScrollableAppBottomNavItem(
                              destination: destinations[i],
                              selected: i == currentIndex,
                              width: _destinationWidth,
                              onTap: () => onTap(i),
                            ),
                            if (i != destinations.length - 1)
                              const SizedBox(width: _destinationSpacing),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScrollableAppBottomNavItem extends StatelessWidget {
  final _BottomNavDestination destination;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  const _ScrollableAppBottomNavItem({
    required this.destination,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.muted;

    return SizedBox(
      width: width,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _BottomNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          appSelectionHaptic();
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
