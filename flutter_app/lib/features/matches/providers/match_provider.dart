import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/match_model.dart';

/// Parámetros de filtro para la lista de partidos.
class MatchFilters {
  final int? level;
  final String? date;
  final int? venueId;

  const MatchFilters({this.level, this.date, this.venueId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchFilters &&
          level == other.level &&
          date == other.date &&
          venueId == other.venueId;

  @override
  int get hashCode => Object.hash(level, date, venueId);
}

/// Provider que obtiene la lista de partidos con filtros opcionales.
final matchListProvider =
    FutureProvider.family<List<MatchModel>, MatchFilters>((ref, filters) async {
  final api = ref.watch(apiClientProvider);

  final queryParams = <String, String>{};
  if (filters.level != null) queryParams['level'] = filters.level.toString();
  if (filters.date != null) queryParams['date'] = filters.date!;
  if (filters.venueId != null) {
    queryParams['venue_id'] = filters.venueId.toString();
  }

  final queryString =
      queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
  final path =
      queryString.isEmpty ? '/padel/matches' : '/padel/matches?$queryString';

  final data = await api.get(path);
  final list =
      (data is List ? data : (data['matches'] ?? [])) as List;
  return list
      .map((m) => MatchModel.fromJson(m as Map<String, dynamic>))
      .toList();
});

/// Provider para el detalle de un partido.
final matchDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, matchId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/padel/matches/$matchId');
  return data as Map<String, dynamic>;
});

/// Acciones de partidos (crear, unirse, salir, cambiar estado).
final matchActionsProvider = Provider<MatchActions>((ref) {
  return MatchActions(ref.watch(apiClientProvider));
});

class MatchActions {
  final ApiClient _api;
  MatchActions(this._api);

  Future<Map<String, dynamic>> create({
    required String matchDate,
    required String startTime,
    required int venueId,
    int? bookingId,
    String matchType = 'abierto',
    int minLevel = 1,
    int maxLevel = 9,
    String? description,
  }) async {
    final data = await _api.post('/padel/matches', data: {
      'booking_id': bookingId,
      'match_type': matchType,
      'min_level': minLevel,
      'max_level': maxLevel,
      'match_date': matchDate,
      'start_time': startTime,
      'venue_id': venueId,
      'description': description,
    });
    return data as Map<String, dynamic>;
  }

  Future<void> join(int matchId) async {
    await _api.post('/padel/matches/$matchId/join', data: {});
  }

  Future<void> leave(int matchId) async {
    await _api.post('/padel/matches/$matchId/leave', data: {});
  }

  Future<void> updateStatus(int matchId, String status) async {
    await _api.put('/padel/matches/$matchId/status', data: {
      'status': status,
    });
  }
}
