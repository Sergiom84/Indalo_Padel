import 'package:flutter_test/flutter_test.dart';
import 'package:indalo_padel/features/bookings/models/calendar_booking_model.dart';
import 'package:indalo_padel/features/matches/models/match_model.dart';
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
  });

  group('VenueModel contract', () {
    test('derives courtCount from nested courts when court_count is missing', () {
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
}
