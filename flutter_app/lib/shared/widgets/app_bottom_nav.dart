import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/community/models/community_model.dart';
import '../../features/community/widgets/match_result_dialog.dart';
import '../../features/notifications/models/app_alerts_model.dart';
import '../../features/notifications/providers/app_alerts_provider.dart';
import '../../features/notifications/services/app_alerts_service.dart';
import '../../core/platform/platform_helper.dart';
import '../../core/theme/app_theme.dart';
import 'notification_dot.dart';

enum AppTab { home, venues, calendar, community, players, profile }

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Map<AppTab, bool> badgeVisibility;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.badgeVisibility = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (isCupertinoPlatform) {
      final items = [
        BottomNavigationBarItem(
          icon: _BottomNavIcon(
            icon: CupertinoIcons.home,
            showBadge: badgeVisibility[AppTab.home] ?? false,
          ),
          label: 'Inicio',
        ),
        BottomNavigationBarItem(
          icon: _BottomNavIcon(
            icon: CupertinoIcons.sportscourt,
            showBadge: badgeVisibility[AppTab.venues] ?? false,
          ),
          label: 'Clubes\nPróximamente',
        ),
        BottomNavigationBarItem(
          icon: _BottomNavIcon(
            icon: CupertinoIcons.calendar,
            showBadge: badgeVisibility[AppTab.calendar] ?? false,
          ),
          label: 'Calendario',
        ),
        BottomNavigationBarItem(
          icon: _BottomNavIcon(
            icon: CupertinoIcons.person_2,
            showBadge: badgeVisibility[AppTab.community] ?? false,
          ),
          label: 'Comunidad',
        ),
        BottomNavigationBarItem(
          icon: _BottomNavIcon(
            icon: CupertinoIcons.person_3,
            showBadge: badgeVisibility[AppTab.players] ?? false,
          ),
          label: 'Jugadores',
        ),
        BottomNavigationBarItem(
          icon: _BottomNavIcon(
            icon: CupertinoIcons.person,
            showBadge: badgeVisibility[AppTab.profile] ?? false,
          ),
          label: 'Perfil',
        ),
      ];

      return CupertinoTabBar(
        currentIndex: currentIndex,
        backgroundColor: AppColors.surface.withValues(alpha: 0.95),
        activeColor: AppColors.primary,
        inactiveColor: AppColors.muted,
        onTap: (index) {
          if (index == AppTab.venues.index) {
            return;
          }
          onTap(index);
        },
        items: items,
      );
    }

    return _ScrollableAppBottomNav(
      currentIndex: currentIndex,
      onTap: onTap,
      badgeVisibility: badgeVisibility,
    );
  }
}

class _ScrollableAppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Map<AppTab, bool> badgeVisibility;

  const _ScrollableAppBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.badgeVisibility,
  });

  static const double _destinationWidth = 108;
  static const double _destinationSpacing = 8;

  @override
  Widget build(BuildContext context) {
    final destinations = <_BottomNavDestination>[
      _BottomNavDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Inicio',
        showBadge: badgeVisibility[AppTab.home] ?? false,
      ),
      _BottomNavDestination(
        icon: Icons.sports_tennis_outlined,
        selectedIcon: Icons.sports_tennis,
        label: 'Clubes',
        subtitle: 'Próximamente',
        enabled: false,
        showBadge: badgeVisibility[AppTab.venues] ?? false,
      ),
      _BottomNavDestination(
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_today,
        label: 'Calendario',
        showBadge: badgeVisibility[AppTab.calendar] ?? false,
      ),
      _BottomNavDestination(
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        label: 'Comunidad',
        showBadge: badgeVisibility[AppTab.community] ?? false,
      ),
      _BottomNavDestination(
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
        label: 'Jugadores',
        showBadge: badgeVisibility[AppTab.players] ?? false,
      ),
      _BottomNavDestination(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Perfil',
        showBadge: badgeVisibility[AppTab.profile] ?? false,
      ),
    ];

    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 88,
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
                              onTap: destinations[i].enabled
                                  ? () => onTap(i)
                                  : null,
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
  final VoidCallback? onTap;

  const _ScrollableAppBottomNavItem({
    required this.destination,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = destination.enabled
        ? (selected ? AppColors.primary : AppColors.muted)
        : AppColors.muted.withValues(alpha: 0.75);

    return SizedBox(
      width: width,
      child: Material(
        color: selected && destination.enabled
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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      color: color,
                      size: 24,
                    ),
                    if (destination.showBadge)
                      const Positioned(
                        top: 0,
                        right: -2,
                        child: NotificationDot(visible: true),
                      ),
                  ],
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
                if (destination.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    destination.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted.withValues(alpha: 0.9),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
  final String? subtitle;
  final bool enabled;
  final bool showBadge;

  const _BottomNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.subtitle,
    this.enabled = true,
    this.showBadge = false,
  });
}

class _BottomNavIcon extends StatelessWidget {
  final IconData icon;
  final bool showBadge;

  const _BottomNavIcon({
    required this.icon,
    required this.showBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (showBadge)
          const Positioned(
            top: -2,
            right: -5,
            child: NotificationDot(visible: true),
          ),
      ],
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  // Plan IDs para los que ya se mostró el popup en esta sesión.
  final Set<int> _shownResultPlanIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appAlertsProvider.notifier).refresh();
    }
  }

  void _maybeShowResultDialogs(List<CommunityPlanModel> plans) {
    final pending = plans
        .where((p) => !_shownResultPlanIds.contains(p.id))
        .toList(growable: false);
    if (pending.isEmpty) return;

    // Marcar todos como "vistos en esta sesión" antes de mostrar.
    for (final p in pending) {
      _shownResultPlanIds.add(p.id);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final plan in pending) {
        if (!mounted) return;
        final submitted = await showMatchResultDialog(context, plan: plan);
        if (submitted == true) {
          await AppAlertsService.instance.markResultSubmitted(plan.id);
          if (mounted) {
            ref.read(appAlertsProvider.notifier).refresh(notifyOnNew: false);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppAlertsState>(appAlertsProvider, (_, next) {
      if (!next.loading) {
        _maybeShowResultDialogs(next.pendingResultPlans);
      }
    });

    final alerts = ref.watch(appAlertsProvider);

    return Scaffold(
      backgroundColor: AppColors.dark,
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: widget.navigationShell.currentIndex,
        badgeVisibility: {
          AppTab.community: alerts.hasCommunityBadge,
          AppTab.players: alerts.hasPlayersBadge,
        },
        onTap: (index) {
          if (index == AppTab.venues.index) {
            return;
          }
          appSelectionHaptic();
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
