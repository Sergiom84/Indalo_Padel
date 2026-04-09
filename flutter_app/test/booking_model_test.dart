import 'package:flutter_test/flutter_test.dart';
import 'package:indalo_padel/features/bookings/models/booking_model.dart';

void main() {
  test('BookingModel parses price strings from backend responses', () {
    final booking = BookingModel.fromJson({
      'id': 7,
      'court_id': 2,
      'booking_date': '2026-04-09',
      'start_time': '11:30:00',
      'duration_minutes': 90,
      'total_price': '18.00',
      'status': 'confirmada',
    });

    expect(booking.id, 7);
    expect(booking.courtId, 2);
    expect(booking.durationMinutes, 90);
    expect(booking.price, 18.0);
    expect(booking.status, 'confirmada');
  });
}
