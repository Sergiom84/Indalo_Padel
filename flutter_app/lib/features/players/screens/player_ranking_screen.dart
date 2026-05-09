import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../models/player_model.dart';

class PlayerRankingScreen extends ConsumerStatefulWidget {
  const PlayerRankingScreen({super.key});

  @override
  ConsumerState<PlayerRankingScreen> createState() =>
      _PlayerRankingScreenState();
}

class _PlayerRankingScreenState extends ConsumerState<PlayerRankingScreen> {
  bool _loading = true;
  String? _error;
  List<PlayerModel> _players = const [];

  @override
  void initState() {
    super.initState();
    _fetchRanking();
  }

  Future<void> _fetchRanking() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/padel/players/ranking');
      final list = data is Map ? data['players'] : const [];
      final players = list is List
          ? list
              .whereType<Map>()
              .map(
                (player) => PlayerModel.fromJson(
                  Map<String, dynamic>.from(player),
                ),
              )
              .toList(growable: false)
          : const <PlayerModel>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _players = players;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.emoji_events_outlined,
                color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Ranking'),
          ],
        ),
        backgroundColor: AppColors.surface,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _players.isEmpty) {
      return const Center(child: LoadingSpinner());
    }

    if (_error != null && _players.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _fetchRanking,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 120),
          children: [
            const Icon(Icons.error_outline, color: AppColors.muted, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    if (_players.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _fetchRanking,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 120),
          children: const [
            Icon(Icons.emoji_events_outlined, color: AppColors.muted, size: 48),
            SizedBox(height: 12),
            Text(
              'Aún no hay jugadores valorados.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _fetchRanking,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: _players.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _RankingPlayerCard(
            position: _players[index].rankingPosition ?? index + 1,
            player: _players[index],
            onTap: () => context.push('/players/${_players[index].userId}'),
          );
        },
      ),
    );
  }
}

class _RankingPlayerCard extends StatelessWidget {
  final int position;
  final PlayerModel player;
  final VoidCallback onTap;

  const _RankingPlayerCard({
    required this.position,
    required this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _RankingPosition(position: position),
              const SizedBox(width: 12),
              UserAvatar(
                displayName: player.displayName,
                avatarUrl: player.avatarUrl,
                size: 48,
                fontSize: 18,
                backgroundColor: AppColors.surface,
                borderColor: AppColors.border,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LevelBadge(
                          level: player.level,
                          mainLevel: player.mainLevel,
                          subLevel: player.subLevel,
                        ),
                        _RankingStatPill(
                          label: 'G',
                          value: player.matchesWon,
                          color: AppColors.success,
                        ),
                        _RankingStatPill(
                          label: 'P',
                          value: player.matchesLost,
                          color: AppColors.danger,
                        ),
                        _RankingStatPill(
                          label: 'PJ',
                          value: player.matchesPlayed,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${player.rankingPoints}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'pts',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingPosition extends StatelessWidget {
  final int position;

  const _RankingPosition({required this.position});

  @override
  Widget build(BuildContext context) {
    final highlighted = position <= 3;

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Text(
        '#$position',
        style: TextStyle(
          color: highlighted ? AppColors.primary : Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _RankingStatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _RankingStatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color == AppColors.muted ? Colors.white : color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
