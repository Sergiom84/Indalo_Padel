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

/// Provider para obtener la red del jugador actual.
final networkProvider = FutureProvider<PlayerNetworkSnapshot>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/padel/players/network');
  return PlayerNetworkSnapshot.fromJson(
    data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map),
  );
});

/// Compatibilidad temporal: compañeros confirmados.
final favoritesProvider = FutureProvider<List<PlayerModel>>((ref) async {
  final network = await ref.watch(networkProvider.future);
  return network.companions;
});

/// Provider para buscar jugadores.
final playerSearchProvider =
    FutureProvider.family<List<PlayerModel>, String>((ref, query) async {
  final api = ref.watch(apiClientProvider);
  final path = query.isEmpty
      ? '/padel/players/search'
      : '/padel/players/search?name=${Uri.encodeComponent(query)}';
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

/// Acciones de jugadores (actualizar perfil, valorar y red de jugadores).
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

  Future<void> sendPlayRequest(int playerId) async {
    await _api.post('/padel/players/$playerId/network/request', data: {});
  }

  Future<void> respondToPlayRequest(int playerId, String action) async {
    await _api.post(
      '/padel/players/$playerId/network/respond',
      data: {'action': action},
    );
  }
}
