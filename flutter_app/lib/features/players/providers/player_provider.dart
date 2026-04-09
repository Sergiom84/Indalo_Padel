import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/player_model.dart';

/// Provider para obtener el perfil del jugador actual.
final myProfileProvider = FutureProvider<PlayerModel>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/padel/players/profile');
  final profile = data['profile'] ?? data;
  return PlayerModel.fromJson(profile as Map<String, dynamic>);
});

/// Provider para obtener la lista de jugadores favoritos.
final favoritesProvider = FutureProvider<List<PlayerModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/padel/players/favorites');
  final list = (data is List ? data : (data['favorites'] ?? [])) as List;
  return list
      .map((p) => PlayerModel.fromJson(p as Map<String, dynamic>))
      .toList();
});

/// Provider para buscar jugadores.
final playerSearchProvider =
    FutureProvider.family<List<PlayerModel>, String>((ref, query) async {
  final api = ref.watch(apiClientProvider);
  final path = query.isEmpty
      ? '/padel/players/search'
      : '/padel/players/search?q=$query';
  final data = await api.get(path);
  final list = (data is List ? data : (data['players'] ?? [])) as List;
  return list
      .map((p) => PlayerModel.fromJson(p as Map<String, dynamic>))
      .toList();
});

/// Provider para obtener el perfil público de un jugador.
final playerDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, playerId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/padel/players/$playerId');
  return data as Map<String, dynamic>;
});

/// Acciones de jugadores (actualizar perfil, valorar, toggle favorito).
final playerActionsProvider = Provider<PlayerActions>((ref) {
  return PlayerActions(ref.watch(apiClientProvider));
});

class PlayerActions {
  final ApiClient _api;
  PlayerActions(this._api);

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    await _api.put('/padel/players/profile', data: updates);
  }

  Future<void> rate(int playerId, int rating, {String? comment}) async {
    await _api.post('/padel/players/$playerId/rate', data: {
      'rating': rating,
      if (comment != null) 'comment': comment,
    });
  }

  Future<void> toggleFavorite(int playerId) async {
    await _api.post('/padel/players/$playerId/favorite', data: {});
  }
}
