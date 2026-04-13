import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/venue_model.dart';

/// Provider que obtiene y cachea la lista de venues.
/// Se puede invalidar con ref.invalidate(venueListProvider) para refrescar.
final venueListProvider = FutureProvider<List<VenueModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/padel/venues');
  final list = (data is List ? data : (data['venues'] ?? [])) as List;
  return list
      .map((v) => VenueModel.fromJson(v as Map<String, dynamic>))
      .toList();
});

/// Provider que obtiene el detalle de una sede con sus pistas.
final venueDetailProvider =
    FutureProvider.family<VenueModel, int>((ref, venueId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/padel/venues/$venueId');
  final venueJson = data['venue'] as Map<String, dynamic>;
  final courtsJson = (data['courts'] as List?) ?? [];
  venueJson['courts'] = courtsJson;
  return VenueModel.fromJson(venueJson);
});

/// Provider que obtiene la disponibilidad de una sede para una fecha dada.
final venueAvailabilityProvider =
    FutureProvider.family<AvailabilityModel, ({int venueId, String date, int? durationMinutes, int? slotStepMinutes})>(
        (ref, params) async {
  final api = ref.watch(apiClientProvider);
  final queryParams = <String, String>{'date': params.date};
  if (params.durationMinutes != null) {
    queryParams['duration_minutes'] = params.durationMinutes.toString();
  }
  if (params.slotStepMinutes != null) {
    queryParams['slot_step_minutes'] = params.slotStepMinutes.toString();
  }
  final queryString =
      queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
  final data = await api.get('/padel/venues/${params.venueId}/availability?$queryString');
  return AvailabilityModel.fromJson(data as Map<String, dynamic>);
});
