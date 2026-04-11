import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/match_model.dart';

class MatchDetailScreen extends ConsumerStatefulWidget {
  final String matchId;
  const MatchDetailScreen({super.key, required this.matchId});

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen> {
  bool _loading = true;
  MatchModel? _match;
  List<MatchPlayerModel> _players = [];
  bool _actionLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMatch();
  }

  Future<void> _fetchMatch() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/padel/matches/${widget.matchId}');
      if (mounted) {
        final matchData = data['match'] as Map<String, dynamic>? ?? {};
        final playersData = data['players'] as List<dynamic>? ?? [];
        setState(() {
          _match = MatchModel.fromJson(matchData);
          _players = playersData
              .map((p) => MatchPlayerModel.fromJson(p as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar el partido.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _joinMatch(int team) async {
    setState(() {
      _actionLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api
          .post('/padel/matches/${widget.matchId}/join', data: {'team': team});
      await _fetchMatch();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _leaveMatch() async {
    setState(() {
      _actionLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/padel/matches/${widget.matchId}/leave', data: {});
      await _fetchMatch();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    setState(() {
      _actionLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/padel/matches/${widget.matchId}/status',
          data: {'status': newStatus});
      await _fetchMatch();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat("EEEE d 'de' MMMM yyyy", 'es_ES').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.dark,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: const Center(child: LoadingSpinner()),
      );
    }

    if (_match == null) {
      return Scaffold(
        backgroundColor: AppColors.dark,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Partido no encontrado',
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: () => context.go('/matches'),
                  child: const Text('Volver')),
            ],
          ),
        ),
      );
    }

    final match = _match!;
    final user = ref.watch(authProvider).user;
    final isCreator = user?.id != null && match.creatorId == user?.id;
    final isInMatch = _players.any((p) => p.userId == user?.id);
    final canJoin = !isInMatch && match.status == 'buscando';

    final team1 = _players.where((p) => p.team == 1).toList();
    final team2 = _players.where((p) => p.team == 2).toList();

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Detalle del partido'),
          ],
        ),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Text(_error!,
                    style:
                        const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
              const SizedBox(height: 12),
            ],

            // Match info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Información del partido',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16),
                      ),
                      PadelBadge(
                        label: _statusLabel(match.status),
                        variant: _statusVariant(match.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                      icon: Icons.calendar_today,
                      text: _formatDate(match.matchDate)),
                  const SizedBox(height: 8),
                  if (match.startTime != null)
                    _InfoRow(
                      icon: Icons.access_time,
                      text: match.startTime!.length >= 5
                          ? match.startTime!.substring(0, 5)
                          : match.startTime!,
                    ),
                  const SizedBox(height: 8),
                  _InfoRow(
                      icon: Icons.location_on_outlined,
                      text: match.venueName ?? 'Sin sede'),
                  const SizedBox(height: 8),
                  _InfoRow(
                      icon: Icons.security, text: match.matchType ?? 'Abierto'),
                  if (match.minLevel != null && match.maxLevel != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Nivel: ',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 14)),
                        LevelBadge(level: match.minLevel),
                        const SizedBox(width: 4),
                        const Text('—',
                            style: TextStyle(color: AppColors.muted)),
                        const SizedBox(width: 4),
                        LevelBadge(level: match.maxLevel),
                      ],
                    ),
                  ],
                  if (match.description != null &&
                      match.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.muted, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(match.description!,
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Players card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_outline,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Jugadores (${_players.length} / ${match.maxPlayers})',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child:
                              _TeamSection(title: 'Equipo 1', players: team1)),
                      const SizedBox(width: 12),
                      Expanded(
                          child:
                              _TeamSection(title: 'Equipo 2', players: team2)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Join buttons
                  if (canJoin) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_actionLoading || team1.length >= 2)
                                ? null
                                : () => _joinMatch(1),
                            icon: const Icon(Icons.login, size: 16),
                            label: const Text('Equipo 1',
                                style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_actionLoading || team2.length >= 2)
                                ? null
                                : () => _joinMatch(2),
                            icon: const Icon(Icons.login, size: 16),
                            label: const Text('Equipo 2',
                                style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Leave button
                  if (isInMatch && !isCreator) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _actionLoading ? null : _leaveMatch,
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Salir del partido'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.muted,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Creator actions
            if (isCreator) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security,
                            color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Acciones del organizador',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (match.status != 'completo')
                          _ActionButton(
                            label: 'Marcar completo',
                            icon: Icons.check_circle_outline,
                            onTap: _actionLoading
                                ? null
                                : () => _changeStatus('completo'),
                          ),
                        if (match.status != 'en_juego')
                          _ActionButton(
                            label: 'Iniciar partido',
                            icon: Icons.play_arrow,
                            onTap: _actionLoading
                                ? null
                                : () => _changeStatus('en_juego'),
                          ),
                        if (match.status != 'finalizado')
                          _ActionButton(
                            label: 'Finalizar',
                            icon: Icons.emoji_events,
                            onTap: _actionLoading
                                ? null
                                : () => _changeStatus('finalizado'),
                          ),
                        if (match.status != 'cancelado')
                          _ActionButton(
                            label: 'Cancelar',
                            icon: Icons.cancel_outlined,
                            onTap: _actionLoading
                                ? null
                                : () => _changeStatus('cancelado'),
                            danger: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'buscando':
        return 'Buscando jugadores';
      case 'completo':
        return 'Completo';
      case 'en_juego':
        return 'En juego';
      case 'finalizado':
        return 'Finalizado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return status;
    }
  }

  PadelBadgeVariant _statusVariant(String status) {
    switch (status) {
      case 'buscando':
        return PadelBadgeVariant.warning;
      case 'completo':
        return PadelBadgeVariant.success;
      case 'en_juego':
        return PadelBadgeVariant.info;
      case 'cancelado':
        return PadelBadgeVariant.danger;
      default:
        return PadelBadgeVariant.neutral;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.muted, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 14))),
      ],
    );
  }
}

class _TeamSection extends StatelessWidget {
  final String title;
  final List<MatchPlayerModel> players;
  static const maxPerTeam = 2;

  const _TeamSection({required this.title, required this.players});

  @override
  Widget build(BuildContext context) {
    final slots = List<MatchPlayerModel?>.generate(
      maxPerTeam,
      (i) => i < players.length ? players[i] : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        ...slots.asMap().entries.map((e) {
          final player = e.value;
          if (player == null) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.border, style: BorderStyle.solid),
              ),
              child: const Row(
                children: [
                  Icon(Icons.people_outline, color: AppColors.muted, size: 20),
                  SizedBox(width: 8),
                  Text('Puesto libre',
                      style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            );
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.dark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      player.name.isNotEmpty
                          ? player.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                LevelBadge(level: player.level),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;

  const _ActionButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? AppColors.danger : Colors.white,
        side: BorderSide(
            color: danger
                ? AppColors.danger.withValues(alpha: 0.5)
                : AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
