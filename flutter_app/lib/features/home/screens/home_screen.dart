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
