import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../models/player_model.dart';

class FavoritesListScreen extends ConsumerStatefulWidget {
  const FavoritesListScreen({super.key});

  @override
  ConsumerState<FavoritesListScreen> createState() => _FavoritesListScreenState();
}

class _FavoritesListScreenState extends ConsumerState<FavoritesListScreen> {
  bool _loading = true;
  List<PlayerModel> _favorites = [];

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/padel/players/favorites');
      final list = (data['favorites'] as List<dynamic>?) ?? [];
      if (mounted) {
        setState(() {
          _favorites = list
              .map((f) => PlayerModel.fromJson(f as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeFavorite(int userId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/padel/players/$userId/favorite', data: {});
      setState(() => _favorites.removeWhere((f) => f.userId == userId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text('Jugadores favoritos'),
          ],
        ),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(child: LoadingSpinner())
          : _favorites.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_outline, color: AppColors.border, size: 56),
                      SizedBox(height: 12),
                      Text(
                        'No tienes jugadores favoritos aún',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: _fetchFavorites,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final fav = _favorites[index];
                      return GestureDetector(
                        onTap: () => context.push('/players/${fav.userId}'),
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
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.favorite, color: Colors.red, size: 22),
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fav.displayName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        LevelBadge(level: fav.level),
                                        if (fav.avgRating > 0) ...[
                                          const SizedBox(width: 8),
                                          const Icon(Icons.star, color: Colors.amber, size: 13),
                                          const SizedBox(width: 2),
                                          Text(
                                            fav.avgRating.toStringAsFixed(1),
                                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Remove button
                              IconButton(
                                icon: const Icon(Icons.close, color: AppColors.muted, size: 20),
                                onPressed: () => _removeFavorite(fav.userId),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
