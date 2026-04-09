import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../models/player_model.dart';

class PlayerSearchScreen extends ConsumerStatefulWidget {
  const PlayerSearchScreen({super.key});

  @override
  ConsumerState<PlayerSearchScreen> createState() => _PlayerSearchScreenState();
}

class _PlayerSearchScreenState extends ConsumerState<PlayerSearchScreen> {
  final _searchCtrl = TextEditingController();
  bool _loading = false;
  List<PlayerModel> _players = [];
  int? _filterLevel;
  bool _filterAvailable = false;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _search();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _search();
    });
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final params = <String, dynamic>{};
      if (_searchCtrl.text.trim().isNotEmpty) params['name'] = _searchCtrl.text.trim();
      if (_filterLevel != null) params['level'] = _filterLevel!;
      if (_filterAvailable) params['available'] = 'true';

      final queryString = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}').join('&');
      final data = await api.get('/padel/players/search${queryString.isNotEmpty ? '?$queryString' : ''}');
      final list = data is List ? data : (data['players'] ?? []);
      if (mounted) {
        setState(() {
          _players = (list as List)
              .map((p) => PlayerModel.fromJson(p as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.people_outline, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Buscar jugadores'),
          ],
        ),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_outline, color: AppColors.primary),
            tooltip: 'Favoritos',
            onPressed: () => context.push('/players/favorites'),
          ),
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _showFilters ? AppColors.primary : AppColors.muted,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: Icon(Icons.search, color: AppColors.muted, size: 20),
              ),
            ),
          ),

          // Filters
          if (_showFilters)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: _filterLevel,
                    dropdownColor: AppColors.surface2,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nivel',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('Todos los niveles', style: TextStyle(color: AppColors.muted)),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todos los niveles', style: TextStyle(color: AppColors.muted)),
                      ),
                      ...List.generate(9, (i) => i + 1)
                          .map((n) => DropdownMenuItem<int?>(
                                value: n,
                                child: Text('Nivel $n', style: const TextStyle(color: Colors.white)),
                              )),
                    ],
                    onChanged: (v) {
                      setState(() => _filterLevel = v);
                      _search();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Switch(
                        value: _filterAvailable,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) {
                          setState(() => _filterAvailable = v);
                          _search();
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text('Solo disponibles', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),

          // Results
          Expanded(
            child: _loading
                ? const Center(child: LoadingSpinner())
                : _players.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, color: AppColors.border, size: 48),
                            SizedBox(height: 12),
                            Text('No se encontraron jugadores', style: TextStyle(color: AppColors.muted)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _players.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final player = _players[index];
                          return _PlayerCard(
                            player: player,
                            onTap: () => context.push('/players/${player.userId}'),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final PlayerModel player;
  final VoidCallback onTap;

  const _PlayerCard({required this.player, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surface2,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.displayName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      LevelBadge(level: player.level),
                      if (player.preferredSide != null) ...[
                        const SizedBox(width: 6),
                        PadelBadge(label: player.preferredSide!, variant: PadelBadgeVariant.outline),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Rating & availability
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (player.avgRating > 0)
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        player.avgRating.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: player.isAvailable ? AppColors.success : AppColors.muted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      player.isAvailable ? 'Disponible' : 'No disponible',
                      style: TextStyle(
                        color: player.isAvailable ? AppColors.success : AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
