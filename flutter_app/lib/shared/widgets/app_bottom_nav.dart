import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/providers/chat_provider.dart';
import '../../features/community/models/community_model.dart';
import '../../features/community/models/match_result_model.dart';
import '../../features/community/providers/community_provider.dart';
import '../../features/community/widgets/match_result_dialog.dart';
import '../../features/notifications/models/app_alerts_model.dart';
import '../../features/notifications/providers/app_alerts_provider.dart';
import '../../core/platform/platform_helper.dart';
import '../../core/theme/app_theme.dart';
import 'notification_dot.dart';

enum AppTab { home, venues, calendar, community, players, profile }

class _BottomNavPalette {
  static const homeBackground = Color(0xFFF4F6FA);
  static const background = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const active = Color(0xFFE8732C);
  static const activeBg = Color(0xFFFFF1E8);
  static const text = Color(0xFF1A3A5C);
  static const muted = Color(0xFF94A0B4);
}

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
        backgroundColor: _BottomNavPalette.background.withValues(alpha: 0.96),
        activeColor: _BottomNavPalette.active,
        inactiveColor: _BottomNavPalette.muted,
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

class _ScrollableAppBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Map<AppTab, bool> badgeVisibility;

  const _ScrollableAppBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.badgeVisibility,
  });

  @override
  State<_ScrollableAppBottomNav> createState() =>
      _ScrollableAppBottomNavState();
}

class _ScrollableAppBottomNavState extends State<_ScrollableAppBottomNav> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  static const double _destinationWidth = 62;
  static const double _destinationSpacing = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollCues);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateScrollCues)
      ..dispose();
    super.dispose();
  }

  void _updateScrollCues() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final nextCanScrollLeft = position.pixels > 4;
    final nextCanScrollRight = position.pixels < position.maxScrollExtent - 4;

    if (nextCanScrollLeft == _canScrollLeft &&
        nextCanScrollRight == _canScrollRight) {
      return;
    }

    setState(() {
      _canScrollLeft = nextCanScrollLeft;
      _canScrollRight = nextCanScrollRight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final destinations = <_BottomNavDestination>[
      _BottomNavDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Inicio',
        showBadge: widget.badgeVisibility[AppTab.home] ?? false,
      ),
      _BottomNavDestination(
        icon: Icons.sports_tennis_outlined,
        selectedIcon: Icons.sports_tennis,
        label: 'Clubes',
        subtitle: 'Próximamente',
        enabled: false,
        showBadge: widget.badgeVisibility[AppTab.venues] ?? false,
      ),
      _BottomNavDestination(
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_today,
        label: 'Calendario',
        showBadge: widget.badgeVisibility[AppTab.calendar] ?? false,
      ),
      _BottomNavDestination(
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        label: 'Comunidad',
        showBadge: widget.badgeVisibility[AppTab.community] ?? false,
      ),
      _BottomNavDestination(
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
        label: 'Jugadores',
        showBadge: widget.badgeVisibility[AppTab.players] ?? false,
      ),
      _BottomNavDestination(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Perfil',
        showBadge: widget.badgeVisibility[AppTab.profile] ?? false,
      ),
    ];

    return Material(
      color: _BottomNavPalette.background,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _BottomNavPalette.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 88,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = destinations.length * _destinationWidth +
                    (destinations.length - 1) * _destinationSpacing;
                final shouldCenter = contentWidth < constraints.maxWidth;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _updateScrollCues();
                  }
                });

                return Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minWidth: constraints.maxWidth),
                        child: Align(
                          alignment: shouldCenter
                              ? Alignment.center
                              : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0;
                                    i < destinations.length;
                                    i++) ...[
                                  _ScrollableAppBottomNavItem(
                                    destination: destinations[i],
                                    selected: i == widget.currentIndex,
                                    width: _destinationWidth,
                                    onTap: destinations[i].enabled
                                        ? () => widget.onTap(i)
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
                    ),
                    _ScrollCue(
                      alignment: Alignment.centerLeft,
                      visible: _canScrollLeft,
                      icon: Icons.keyboard_arrow_left,
                    ),
                    _ScrollCue(
                      alignment: Alignment.centerRight,
                      visible: _canScrollRight,
                      icon: Icons.keyboard_arrow_right,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollCue extends StatelessWidget {
  final Alignment alignment;
  final bool visible;
  final IconData icon;

  const _ScrollCue({
    required this.alignment,
    required this.visible,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: visible ? 1 : 0,
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _BottomNavPalette.background.withValues(alpha: 0.96),
              shape: BoxShape.circle,
              border: Border.all(color: _BottomNavPalette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: _BottomNavPalette.active, size: 22),
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
        ? (selected ? _BottomNavPalette.active : _BottomNavPalette.text)
        : _BottomNavPalette.muted.withValues(alpha: 0.72);

    return SizedBox(
      width: width,
      child: Material(
        color: selected && destination.enabled
            ? _BottomNavPalette.activeBg
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      color: color,
                      size: 23,
                    ),
                    if (destination.showBadge)
                      const Positioned(
                        top: 0,
                        right: -2,
                        child: NotificationDot(
                          visible: true,
                          color: _BottomNavPalette.active,
                        ),
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
                    fontSize: 10,
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
                      color: _BottomNavPalette.muted.withValues(alpha: 0.9),
                      fontSize: 8,
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
            child: NotificationDot(
              visible: true,
              color: _BottomNavPalette.active,
            ),
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
  final Set<String> _shownRatingAlertKeys = {};

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
        final prepared = await _prepareResultPrompt(plan);
        if (!mounted) {
          return;
        }

        if (!prepared.shouldShow) {
          continue;
        }

        final submitted = await showMatchResultDialog(
          context,
          plan: plan,
          existingSubmission: prepared.existingSubmission,
        );
        if (submitted == true) {
          if (mounted) {
            ref.invalidate(communityDashboardProvider);
            ref.read(appAlertsProvider.notifier).refresh(notifyOnNew: false);
          }
        }
      }
    });
  }

  void _maybeShowRatingDialog(List<AppAlertItem> alerts) {
    final pending = alerts
        .where((alert) => !_shownRatingAlertKeys.contains(alert.uniqueKey))
        .toList(growable: false);
    if (pending.isEmpty) return;

    for (final alert in pending) {
      _shownRatingAlertKeys.add(alert.uniqueKey);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final first = pending.first;
      final multiple = pending.length > 1;
      final openProfile = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            multiple ? 'Nuevas valoraciones' : first.title,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            multiple
                ? 'Tienes ${pending.length} valoraciones nuevas. Puedes revisarlas en Perfil, dentro de la tarjeta Valoración.'
                : first.body,
            style: const TextStyle(color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Más tarde'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ver perfil'),
            ),
          ],
        ),
      );

      if (openProfile == true && mounted) {
        widget.navigationShell.goBranch(AppTab.profile.index);
      }
    });
  }

  Future<_PreparedResultPrompt> _prepareResultPrompt(
    CommunityPlanModel plan,
  ) async {
    final currentUserId = plan.currentUserParticipant?.userId;
    if (currentUserId == null) {
      return const _PreparedResultPrompt(shouldShow: true);
    }

    try {
      final result = await ref.read(communityActionsProvider).fetchMatchResult(
            plan.id,
          );
      final existingSubmission = result.submissionFor(currentUserId);

      if (result.isConsensuado) {
        return _PreparedResultPrompt(
          existingSubmission: existingSubmission,
          shouldShow: false,
        );
      }

      return _PreparedResultPrompt(
        existingSubmission: existingSubmission,
        shouldShow: true,
      );
    } catch (_) {
      return const _PreparedResultPrompt(shouldShow: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppAlertsState>(appAlertsProvider, (_, next) {
      if (!next.loading) {
        _maybeShowResultDialogs(next.pendingResultPlans);
        _maybeShowRatingDialog(next.profileRatingAlerts);
      }
    });

    final alerts = ref.watch(appAlertsProvider);
    final chatUnreadCount = ref.watch(chatUnreadCountProvider);
    final isHomeTab = widget.navigationShell.currentIndex == AppTab.home.index;

    return Scaffold(
      backgroundColor:
          isHomeTab ? _BottomNavPalette.homeBackground : AppColors.dark,
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: widget.navigationShell.currentIndex,
        badgeVisibility: {
          AppTab.calendar: alerts.hasCalendarBadge,
          AppTab.community: alerts.hasCommunityBadge,
          AppTab.players: alerts.hasPlayersBadge || chatUnreadCount > 0,
          AppTab.profile: alerts.hasProfileBadge,
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

class _PreparedResultPrompt {
  final MatchResultSubmissionModel? existingSubmission;
  final bool shouldShow;

  const _PreparedResultPrompt({
    this.existingSubmission,
    required this.shouldShow,
  });
}
