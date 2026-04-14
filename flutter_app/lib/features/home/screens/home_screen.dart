import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/platform/platform_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/chronology.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../players/models/player_model.dart';
import '../../players/providers/player_provider.dart';
import '../../profile/providers/current_profile_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loadingVenues = true;
  bool _loadingBookings = true;
  bool _loadingMatches = true;
  List<dynamic> _venues = [];
  Map<String, dynamic> _bookings = {'upcoming': [], 'past': []};
  List<dynamic> _matches = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final api = ref.read(apiClientProvider);
    ref.invalidate(networkProvider);
    if (mounted) {
      setState(() {
        _loadingVenues = true;
        _loadingBookings = true;
        _loadingMatches = true;
      });
    }

    final venuesFuture = api
        .get('/padel/venues?limit=3')
        .catchError((_) => {'venues': []})
        .then((result) {
      if (!mounted) {
        return;
      }
      setState(() {
        _venues = _asList(result is Map ? result['venues'] : result);
        _loadingVenues = false;
      });
    });

    final bookingsFuture = api
        .get('/padel/bookings/my')
        .catchError((_) => {'upcoming': [], 'past': []})
        .then((result) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bookings = result is Map<String, dynamic>
            ? result
            : {'upcoming': [], 'past': []};
        _loadingBookings = false;
      });
    });

    final matchesFuture = api
        .get('/padel/matches?limit=12')
        .catchError((_) => {'matches': []})
        .then((result) {
      if (!mounted) {
        return;
      }
      setState(() {
        _matches = _asList(result is Map ? result['matches'] : result);
        _loadingMatches = false;
      });
    });

    await Future.wait([venuesFuture, bookingsFuture, matchesFuture]);
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return value;
    }
    return [];
  }

  List<dynamic> get _openMatches {
    final matches = _matches
        .whereType<Map>()
        .map((match) => Map<String, dynamic>.from(match))
        .where((match) =>
            match['status'] == 'buscando' || match['status'] == 'abierto')
        .toList();

    matches.sort((left, right) {
      final comparison = compareChronology(
        leftDate: left['match_date']?.toString(),
        leftTime: left['start_time']?.toString() ?? left['hora']?.toString(),
        rightDate: right['match_date']?.toString(),
        rightTime: right['start_time']?.toString() ?? right['hora']?.toString(),
      );
      if (comparison != 0) {
        return comparison;
      }
      final leftId = (left['id'] as num?)?.toInt() ?? 0;
      final rightId = (right['id'] as num?)?.toInt() ?? 0;
      return leftId.compareTo(rightId);
    });

    return matches.take(3).toList();
  }

  List<dynamic> get _upcomingBookings {
    final bookings = _asList(_bookings['upcoming'])
        .whereType<Map>()
        .map((booking) => Map<String, dynamic>.from(booking))
        .toList();

    bookings.sort((left, right) {
      final comparison = compareChronology(
        leftDate: left['booking_date']?.toString() ?? left['fecha']?.toString(),
        leftTime:
            left['start_time']?.toString() ?? left['hora_inicio']?.toString(),
        rightDate:
            right['booking_date']?.toString() ?? right['fecha']?.toString(),
        rightTime:
            right['start_time']?.toString() ?? right['hora_inicio']?.toString(),
      );
      if (comparison != 0) {
        return comparison;
      }
      final leftId = (left['id'] as num?)?.toInt() ?? 0;
      final rightId = (right['id'] as num?)?.toInt() ?? 0;
      return leftId.compareTo(rightId);
    });

    return bookings.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final networkAsync = ref.watch(networkProvider);
    final incomingRequests =
        networkAsync.valueOrNull?.incomingRequests ?? const <PlayerModel>[];
    final greeting = (profile?['display_name'] ??
            profile?['nombre'] ??
            user?.nombre ??
            'Jugador')
        .toString();
    final avatarUrl = profile?['avatar_url']?.toString();
    final loadingSummary =
        _loadingVenues || _loadingBookings || _loadingMatches;
    final upcomingBookings = _upcomingBookings;
    final openMatches = _openMatches;

    return Scaffold(
      backgroundColor: AppColors.dark,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _headlineDate(),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hola, $greeting',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                _NotificationBellButton(
                  pendingCount: incomingRequests.length,
                  loading: networkAsync.isLoading && incomingRequests.isEmpty,
                  onTap: () => _openNotificationsDialog(
                    incomingRequests,
                    loading: networkAsync.isLoading && incomingRequests.isEmpty,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    appLightImpact();
                    context.push('/profile');
                  },
                  child: UserAvatar(
                    displayName: greeting,
                    avatarUrl: avatarUrl,
                    size: 56,
                    fontSize: 20,
                    backgroundColor: AppColors.surface,
                    borderColor: AppColors.border,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sesión de hoy',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Todo lo importante en una vista',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Clubes',
                          value: _loadingVenues ? '—' : '${_venues.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          label: 'Reservas',
                          value: _loadingBookings
                              ? '—'
                              : '${upcomingBookings.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          label: 'Partidos',
                          value:
                              _loadingMatches ? '—' : '${openMatches.length}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _HomeSection(
              title: 'Próximas reservas',
              actionLabel: 'Ver calendario',
              onAction: () => context.go('/calendar'),
              child: _loadingBookings && upcomingBookings.isEmpty
                  ? const LoadingSpinner()
                  : upcomingBookings.isEmpty
                      ? const _EmptyState(
                          icon: Icons.calendar_today_outlined,
                          message: 'No tienes reservas próximas.',
                        )
                      : Column(
                          children: upcomingBookings
                              .map((booking) =>
                                  _BookingPreviewCard(booking: booking))
                              .toList(),
                        ),
            ),
            const SizedBox(height: 18),
            _HomeSection(
              title: 'Clubes destacados',
              actionLabel: 'Abrir clubes',
              onAction: () => context.go('/venues'),
              child: _loadingVenues && _venues.isEmpty
                  ? const LoadingSpinner()
                  : _venues.isEmpty
                      ? const _EmptyState(
                          icon: Icons.sports_tennis_outlined,
                          message: 'Aún no hay clubes listados.',
                        )
                      : Column(
                          children: _venues.take(3).map((venue) {
                            return _VenuePreviewCard(
                              venue: venue as Map<String, dynamic>,
                            );
                          }).toList(),
                        ),
            ),
            const SizedBox(height: 18),
            _HomeSection(
              title: 'Partidos abiertos',
              actionLabel: 'Ir a partidos',
              onAction: () => context.go('/matches'),
              child: _loadingMatches && openMatches.isEmpty
                  ? const LoadingSpinner()
                  : openMatches.isEmpty
                      ? const _EmptyState(
                          icon: Icons.emoji_events_outlined,
                          message: 'No hay partidos abiertos ahora mismo.',
                        )
                      : Column(
                          children: openMatches
                              .map((match) => _MatchPreviewCard(match: match))
                              .toList(),
                        ),
            ),
            if (loadingSummary)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Actualizando contenido...',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNotificationsDialog(List<PlayerModel> initialRequests,
      {required bool loading}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final requests = List<PlayerModel>.from(initialRequests);
        final busyIds = <int>{};
        final navigator = Navigator.of(dialogContext);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleAction(PlayerModel player, String action) async {
              if (busyIds.contains(player.userId)) {
                return;
              }

              setDialogState(() => busyIds.add(player.userId));

              try {
                final message = await _respondToNetworkRequest(player, action);
                notifyPlayerNetworkChanged(ref);
                if (!mounted) {
                  return;
                }

                setDialogState(() {
                  busyIds.remove(player.userId);
                  requests.removeWhere(
                    (request) => request.userId == player.userId,
                  );
                });

                _showMessage(
                  message ??
                      (action == 'accepted'
                          ? '${player.displayName} ya forma parte de tu red.'
                          : 'Has rechazado la solicitud de ${player.displayName}.'),
                );

                if (requests.isEmpty && navigator.canPop()) {
                  navigator.pop();
                }
              } catch (error) {
                if (!mounted) {
                  return;
                }
                setDialogState(() => busyIds.remove(player.userId));
                _showMessage(error.toString(), isError: true);
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: AppColors.border),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              title: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Solicitudes de red',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => navigator.pop(),
                    icon: const Icon(Icons.close, color: AppColors.muted),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LoadingSpinner(),
                            SizedBox(height: 12),
                            Text(
                              'Cargando solicitudes...',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      )
                    : requests.isEmpty
                        ? const _EmptyState(
                            icon: Icons.notifications_none_outlined,
                            message: 'No tienes solicitudes pendientes.',
                          )
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: requests
                                  .map(
                                    (player) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _NetworkRequestDialogCard(
                                        player: player,
                                        busy: busyIds.contains(player.userId),
                                        onAccept: () =>
                                            handleAction(player, 'accepted'),
                                        onReject: () =>
                                            handleAction(player, 'rejected'),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _respondToNetworkRequest(
    PlayerModel player,
    String action,
  ) async {
    final api = ref.read(apiClientProvider);
    final data = await api.post(
      '/padel/players/${player.userId}/network/respond',
      data: {'action': action},
    );
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return null;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.surface,
      ),
    );
  }

  String _headlineDate() {
    final now = DateTime.now();
    const weekDays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${weekDays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }
}

class _NotificationBellButton extends StatelessWidget {
  final int pendingCount;
  final bool loading;
  final VoidCallback onTap;

  const _NotificationBellButton({
    required this.pendingCount,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: pendingCount > 0
                      ? AppColors.primary.withValues(alpha: 0.45)
                      : AppColors.border,
                ),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(
                      pendingCount > 0
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_outlined,
                      color:
                          pendingCount > 0 ? AppColors.primary : Colors.white,
                    ),
            ),
          ),
        ),
        if (!loading && pendingCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.dark, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                pendingCount > 9 ? '9+' : '$pendingCount',
                style: const TextStyle(
                  color: AppColors.dark,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget child;

  const _HomeSection({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BookingPreviewCard extends StatelessWidget {
  final dynamic booking;

  const _BookingPreviewCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go('/calendar'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.schedule, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking['venue_name']?.toString() ?? 'Reserva',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${booking['booking_date'] ?? booking['fecha'] ?? ''} · ${booking['start_time'] ?? booking['hora_inicio'] ?? ''}',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            PadelBadge(
              label: booking['status']?.toString() ?? 'pendiente',
              variant: _badgeForBooking(booking['status']?.toString() ?? ''),
            ),
          ],
        ),
      ),
    );
  }

  PadelBadgeVariant _badgeForBooking(String status) {
    switch (status) {
      case 'confirmada':
        return PadelBadgeVariant.success;
      case 'cancelada':
        return PadelBadgeVariant.danger;
      case 'pendiente':
        return PadelBadgeVariant.warning;
      default:
        return PadelBadgeVariant.neutral;
    }
  }
}

class _VenuePreviewCard extends StatelessWidget {
  final Map<String, dynamic> venue;

  const _VenuePreviewCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/venues/${venue['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.sports_tennis, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue['name']?.toString() ??
                        venue['nombre']?.toString() ??
                        'Club',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    venue['location']?.toString() ??
                        venue['ubicacion']?.toString() ??
                        'Sin ubicación',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            PadelBadge(label: '${venue['court_count'] ?? 0} pistas'),
          ],
        ),
      ),
    );
  }
}

class _MatchPreviewCard extends StatelessWidget {
  final dynamic match;

  const _MatchPreviewCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/matches/${match['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.emoji_events, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match['venue_name']?.toString() ?? 'Partido abierto',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${match['match_date'] ?? match['fecha'] ?? ''} · ${match['start_time'] ?? match['hora'] ?? ''}',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '${match['player_count'] ?? 0}/4',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted, size: 30),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NetworkRequestDialogCard extends StatelessWidget {
  final PlayerModel player;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _NetworkRequestDialogCard({
    required this.player,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                displayName: player.displayName,
                avatarUrl: player.avatarUrl,
                size: 44,
                fontSize: 16,
                backgroundColor: AppColors.surface,
                borderColor: AppColors.border,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: player.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(
                        text: ' ha solicitado unirse a tu red.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onAccept,
                  child: busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
