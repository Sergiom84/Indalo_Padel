import 'package:flutter_test/flutter_test.dart';
import 'package:indalo_padel/features/bookings/models/calendar_booking_model.dart';
import 'package:indalo_padel/features/bookings/screens/calendar_screen.dart';
import 'package:indalo_padel/features/matches/models/match_model.dart';
import 'package:indalo_padel/features/players/models/player_model.dart';
import 'package:indalo_padel/features/venues/models/venue_model.dart';

void main() {
  group('MatchModel contract', () {
    test('uses current_players when player_count is missing', () {
      final model = MatchModel.fromJson({
        'id': 11,
        'status': 'buscando',
        'current_players': 3,
        'max_players': 4,
      });

      expect(model.playerCount, 3);
      expect(model.maxPlayers, 4);
    });

    test('prefers player_count when both aliases exist', () {
      final model = MatchModel.fromJson({
        'id': 12,
        'status': 'buscando',
        'player_count': 2,
        'current_players': 3,
        'max_players': 4,
      });

      expect(model.playerCount, 2);
      expect(model.maxPlayers, 4);
    });
  });

  group('CalendarFeedModel contract', () {
    test('parses sync status and sync timestamp from /my-calendar', () {
      final feed = CalendarFeedModel.fromJson({
        'agenda': {
          'upcoming': [],
          'history': [],
        },
        'managed': {
          'upcoming': [],
          'history': [],
        },
        'sync': {
          'status': 'sincronizada',
          'last_synced_at': '2026-04-09T16:00:00.000Z',
        },
      });

      expect(feed.syncStatus, 'sincronizada');
      expect(feed.lastSyncedAt, isNotNull);
    });

    test('deduplicates bookings returned in agenda and managed buckets', () {
      final managedBooking = CalendarBookingModel.fromJson({
        'id': 9,
        'booking_date': '2026-04-11',
        'start_time': '09:00:00',
        'end_time': '10:30:00',
        'status': 'confirmada',
      }, isManaged: true);
      final agendaBooking = CalendarBookingModel.fromJson({
        'id': 9,
        'booking_date': '2026-04-11',
        'start_time': '09:00:00',
        'end_time': '10:30:00',
        'status': 'confirmada',
      });

      final merged = mergeUniqueCalendarBookings(
        primary: [managedBooking],
        secondary: [agendaBooking],
      );

      expect(merged, hasLength(1));
      expect(merged.first.id, 9);
      expect(merged.first.isManaged, isTrue);
    });

    test('sorts bookings chronologically by date and start time', () {
      final bookings = [
        CalendarBookingModel.fromJson({
          'id': 3,
          'booking_date': '2026-04-10',
          'start_time': '17:30:00',
          'end_time': '19:00:00',
          'status': 'confirmada',
        }),
        CalendarBookingModel.fromJson({
          'id': 4,
          'booking_date': '2026-04-10',
          'start_time': '10:30:00',
          'end_time': '12:00:00',
          'status': 'confirmada',
        }),
        CalendarBookingModel.fromJson({
          'id': 2,
          'booking_date': '2026-04-10',
          'start_time': '10:00:00',
          'end_time': '11:30:00',
          'status': 'confirmada',
        }),
        CalendarBookingModel.fromJson({
          'id': 5,
          'booking_date': '2026-04-10',
          'start_time': '22:00:00',
          'end_time': '23:30:00',
          'status': 'confirmada',
        }),
      ];

      bookings.sort(compareCalendarBookingsChronologically);

      expect(
        bookings.map((booking) => booking.id).toList(),
        [2, 4, 3, 5],
      );
    });
  });

  group('VenueModel contract', () {
    test('derives courtCount from nested courts when court_count is missing',
        () {
      final model = VenueModel.fromJson({
        'id': 1,
        'name': 'Centro Deportivo Puerto Rey',
        'location': 'Vera',
        'courts': [
          {'id': 101, 'name': 'Pista 1'},
          {'id': 102, 'name': 'Pista 2'},
        ],
      });

      expect(model.courtCount, 2);
      expect(model.courts.length, 2);
    });
  });

  group('PlayerModel contract', () {
    test('maps avatar_url from API payloads', () {
      final model = PlayerModel.fromJson({
        'user_id': 8,
        'display_name': 'María',
        'avatar_url': 'https://example.com/avatar.png',
        'court_preferences': ['drive', 'ambos'],
        'dominant_hands': ['diestro'],
      });

      expect(model.userId, 8);
      expect(model.avatarUrl, 'https://example.com/avatar.png');
      expect(model.courtPreferences, ['drive', 'ambos']);
      expect(model.dominantHands, ['diestro']);
    });
  });
}
