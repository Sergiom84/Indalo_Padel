import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/padel_card.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../auth/providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loading = true;
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
    try {
      final results = await Future.wait([
        api.get('/padel/venues').catchError((_) => []),
        api.get('/padel/bookings/my').catchError((_) => {'upcoming': [], 'past': []}),
        api.get('/padel/matches').catchError((_) => []),
      ]);
      if (mounted) {
        setState(() {
          _venues = _asList(results[0]);
          final b = results[1];
          _bookings = (b is Map)
              ? {'upcoming': _asList(b['upcoming']), 'past': _asList(b['past'])}
              : {'upcoming': [], 'past': []};
          _matches = _asList(results[2]);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> _asList(dynamic v) {
    if (v is List) return v;
    return [];
  }

  List<dynamic> get _openMatches => _matches
      .where((m) => m['status'] == 'buscando' || m['status'] == 'abierto')
      .toList();

  List<dynamic> get _upcomingBookings {
    final list = _bookings['upcoming'];
    if (list is List) return list.take(3).toList();
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userName = user?.nombre ?? 'Jugador';

    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _fetchData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero header
                const Text(
                  'Bienvenido de vuelta',
                  style: TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$userName 👋',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick actions
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.go('/venues'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.dark.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.calendar_today, color: AppColors.dark, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Reservar', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.dark, fontSize: 14)),
                                  Text('pista ahora', style: TextStyle(color: AppColors.dark, fontSize: 11, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.go('/matches'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.people_outline, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Unirse', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14)),
                                  Text('a un partido', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.business,
                      value: _loading ? '—' : '${_venues.length}',
                      label: 'Clubes',
                      onTap: () => context.go('/venues'),
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      icon: Icons.calendar_today,
                      value: _loading ? '—' : '${_upcomingBookings.length}',
                      label: 'Reservas',
                      onTap: () => context.go('/my-bookings'),
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      icon: Icons.emoji_events,
                      value: _loading ? '—' : '${_openMatches.length}',
                      label: 'Partidos',
                      onTap: () => context.go('/matches'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Venues section
                _SectionHeader(
                  title: 'Clubes',
                  onSeeAll: () => context.go('/venues'),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const LoadingSpinner()
                else if (_venues.isEmpty)
                  _EmptyCard(message: 'No hay clubes disponibles')
                else
                  ...(_venues.take(4).map((venue) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PadelCard(
                      onTap: () => context.go('/venues/${venue['id']}'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  venue['nombre'] ?? venue['name'] ?? 'Sede',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, color: AppColors.muted, size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        venue['ubicacion'] ?? venue['location'] ?? 'Sin ubicación',
                                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PadelBadge(label: '${venue['court_count'] ?? 0} pistas'),
                        ],
                      ),
                    ),
                  ))),
                const SizedBox(height: 24),

                // Upcoming bookings
                _SectionHeader(
                  title: 'Próximas reservas',
                  onSeeAll: () => context.go('/my-bookings'),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const LoadingSpinner()
                else if (_upcomingBookings.isEmpty)
                  _EmptyCard(
                    icon: Icons.calendar_today,
                    message: 'No tienes reservas próximas',
                    actionLabel: 'Reservar ahora',
                    onAction: () => context.go('/venues'),
                  )
                else
                  ...(_upcomingBookings.map((booking) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PadelCard(
                      onTap: () => context.go('/my-bookings'),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking['venue_name'] ?? booking['pista_name'] ?? 'Reserva',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, color: AppColors.muted, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${booking['fecha'] ?? booking['date'] ?? ''} ${booking['hora_inicio'] ?? booking['start_time'] ?? ''}',
                                      style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PadelBadge(
                            label: booking['status'] ?? 'Confirmada',
                            variant: PadelBadgeVariant.success,
                          ),
                        ],
                      ),
                    ),
                  ))),
                const SizedBox(height: 24),

                // Open matches
                _SectionHeader(
                  title: 'Partidos abiertos',
                  onSeeAll: () => context.go('/matches'),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const LoadingSpinner()
                else if (_openMatches.isEmpty)
                  _EmptyCard(
                    icon: Icons.emoji_events,
                    message: 'No hay partidos abiertos',
                    actionLabel: 'Crear partido',
                    onAction: () => context.go('/matches'),
                  )
                else
                  ...(_openMatches.take(3).map((match) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PadelCard(
                      onTap: () => context.go('/matches/${match['id']}'),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.bolt, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  match['venue_name'] ?? match['titulo'] ?? 'Partido',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, color: AppColors.muted, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${match['fecha'] ?? match['match_date'] ?? ''} ${match['hora'] ?? match['start_time'] ?? ''}',
                                      style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              const PadelBadge(label: 'Abierto', variant: PadelBadgeVariant.success),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.people_outline, color: AppColors.muted, size: 12),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${match['player_count'] ?? 0}/4',
                                    style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionHeader({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: const Row(
            children: [
              Text('Ver todos', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
              Icon(Icons.chevron_right, color: AppColors.primary, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyCard({
    this.icon = Icons.info_outline,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: AppColors.border, size: 32),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                child: Text(actionLabel!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
