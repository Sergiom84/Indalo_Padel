import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/booking_model.dart';

/// Provider para obtener las reservas del usuario (calendario completo).
/// Devuelve el mapa raw del endpoint /my-calendar para que la pantalla
/// lo procese con CalendarFeedModel (que ya maneja legacy fallback).
final myCalendarProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/padel/bookings/my-calendar');
    return data as Map<String, dynamic>;
  } on ApiException {
    // Fallback al endpoint legacy si my-calendar no está disponible
    final data = await api.get('/padel/bookings/my');
    return data as Map<String, dynamic>;
  }
});

/// Provider para obtener las reservas simples del usuario.
final myBookingsProvider = FutureProvider<List<BookingModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/padel/bookings/my');
  final list = (data is List ? data : (data['bookings'] ?? data['upcoming'] ?? [])) as List;
  return list
      .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
      .toList();
});

/// Provider para crear una reserva.
/// No es un FutureProvider sino una función que se invoca desde la pantalla.
final bookingActionsProvider = Provider<BookingActions>((ref) {
  return BookingActions(ref.watch(apiClientProvider));
});

class BookingActions {
  final ApiClient _api;
  BookingActions(this._api);

  Future<Map<String, dynamic>> create({
    required int courtId,
    required String bookingDate,
    required String startTime,
    int durationMinutes = 90,
    String? notes,
    List<int> playerUserIds = const [],
  }) async {
    final data = await _api.post('/padel/bookings', data: {
      'court_id': courtId,
      'booking_date': bookingDate,
      'start_time': startTime,
      'duration_minutes': durationMinutes,
      'notes': notes,
      'player_user_ids': playerUserIds,
    });
    return data as Map<String, dynamic>;
  }

  Future<void> cancel(int bookingId) async {
    await _api.put('/padel/bookings/$bookingId/cancel', data: {});
  }

  Future<void> respond(int bookingId, String response) async {
    await _api.put('/padel/bookings/$bookingId/respond', data: {
      'response': response,
    });
  }
}
