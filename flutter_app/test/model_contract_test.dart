import 'package:flutter_test/flutter_test.dart';
import 'package:indalo_padel/features/bookings/models/calendar_booking_model.dart';
import 'package:indalo_padel/features/bookings/screens/calendar_screen.dart';
import 'package:indalo_padel/features/chat/models/chat_models.dart';
import 'package:indalo_padel/features/community/models/community_model.dart';
import 'package:indalo_padel/features/matches/models/match_model.dart';
import 'package:indalo_padel/features/players/models/player_model.dart';
import 'package:indalo_padel/features/venues/models/venue_model.dart';
import 'package:indalo_padel/shared/utils/player_preferences.dart';

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

  group('CommunityPlanModel lifecycle contract', () {
    Map<String, dynamic> planPayloadEndingAt(DateTime endAt) {
      final start = endAt.subtract(const Duration(minutes: 90));
      return {
        'id': 21,
        'created_by': 1,
        'creator_name': 'Organizador',
        'scheduled_date':
            '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
        'scheduled_time':
            '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}:00',
        'duration_minutes': 90,
        'invite_state': 'ready',
        'reservation_state': 'confirmed',
      };
    }

    test('does not allow result capture during backend grace window', () {
      final reference = DateTime(2026, 4, 24, 12, 0);
      final plan = CommunityPlanModel.fromJson(planPayloadEndingAt(reference));

      expect(plan.hasEnded(reference: reference), isFalse);
      expect(plan.canCaptureResult(reference: reference), isFalse);
    });

    test('allows result capture after match end grace window', () {
      final endAt = DateTime(2026, 4, 24, 12, 0);
      final plan = CommunityPlanModel.fromJson(planPayloadEndingAt(endAt));

      expect(
        plan.canCaptureResult(
          reference: endAt.add(const Duration(minutes: 1)),
        ),
        isTrue,
      );
    });

    test('keeps future confirmed plans out of history and result capture', () {
      final endAt = DateTime(2026, 4, 24, 12, 0);
      final reference = DateTime(2026, 4, 24, 10, 0);
      final plan = CommunityPlanModel.fromJson({
        ...planPayloadEndingAt(endAt),
        'is_upcoming': true,
        'is_finished': false,
        'can_submit_result': true,
      });

      expect(plan.shouldAppearInHistory(), isFalse);
      expect(plan.canCaptureResult(reference: reference), isFalse);
    });

    test('does not treat future pending plans as history', () {
      final endAt = DateTime(2026, 4, 24, 12, 0);
      final reference = DateTime(2026, 4, 24, 10, 0);
      final plan = CommunityPlanModel.fromJson({
        ...planPayloadEndingAt(endAt),
        'reservation_state': 'pending',
      });

      expect(plan.shouldAppearInHistory(reference: reference), isFalse);
    });
  });

  group('CommunityPlanModel product fields contract', () {
    test('maps venue, reservation, sync, closure and participant preferences',
        () {
      final plan = CommunityPlanModel.fromJson({
        'id': 31,
        'created_by': 1,
        'creator_name': 'Organizador',
        'scheduled_date': '2026-04-24',
        'scheduled_time': '19:30:00',
        'reservation_handled_by': 4,
        'reservation_handled_by_name': 'Ana',
        'reservation_contact_phone': '+34600111222',
        'calendar_sync_status': 'error',
        'calendar_sync_error': 'quota',
        'closed_at': '2026-04-24T21:10:00.000Z',
        'closed_by': 4,
        'closed_by_name': 'Ana',
        'closed_reason': 'past_datetime',
        'venue': {
          'id': 7,
          'name': 'Club Test',
          'phone': '+34950111222',
        },
        'participants': [
          {
            'user_id': 2,
            'display_name': 'Luis',
            'main_level': 'medio',
            'sub_level': 'alto',
            'court_preferences': ['reves'],
            'availability_preferences': ['laborables', 'tardes_noches'],
            'match_preferences': ['competitivo'],
          },
        ],
      });

      expect(plan.venue?.name, 'Club Test');
      expect(plan.reservationHandledByName, 'Ana');
      expect(plan.reservationContactPhone, '+34600111222');
      expect(plan.calendarSyncStatus, 'error');
      expect(plan.calendarSyncError, 'quota');
      expect(plan.closedReason, 'past_datetime');
      expect(plan.participants.single.availabilityPreferences, [
        'laborables',
        'tardes_noches',
      ]);
    });
  });

  group('PlayerModel contract', () {
    test('maps avatar_url and personal fields from API payloads', () {
      final model = PlayerModel.fromJson({
        'user_id': 8,
        'display_name': 'María',
        'avatar_url': 'https://example.com/avatar.png',
        'gender': 'femenino',
        'birth_date': '1994-06-12',
        'phone': '+34600111222',
        'court_preferences': ['drive', 'ambos'],
        'dominant_hands': ['diestro'],
        'connection_id': 14,
        'connection_status': 'incoming_pending',
        'connection_requested_by_me': false,
        'connection_requested_at': '2026-04-13T10:00:00.000Z',
      });

      expect(model.userId, 8);
      expect(model.avatarUrl, 'https://example.com/avatar.png');
      expect(model.gender, 'femenino');
      expect(model.birthDate, '1994-06-12');
      expect(model.phone, '+34600111222');
      expect(model.courtPreferences, ['drive', 'ambos']);
      expect(model.dominantHands, ['diestro']);
      expect(model.connectionId, 14);
      expect(model.connectionStatus, 'incoming_pending');
      expect(model.connectionRequestedByMe, isFalse);
      expect(model.connectionRequestedAt, '2026-04-13T10:00:00.000Z');
    });

    test('maps rating context payload for per-match ratings', () {
      final context = RatingContextModel.fromJson({
        'context_type': 'community_plan',
        'plan_id': 44,
        'scheduled_date': '2026-04-24',
        'scheduled_time': '19:30:00',
        'venue_name': 'Club Test',
        'existing_rating': 4,
        'existing_comment': 'Buen compañero',
      });

      expect(context.planId, 44);
      expect(context.matchId, isNull);
      expect(context.hasExistingRating, isTrue);
      expect(
        context.toRatePayload(rating: 5, comment: 'Mejorado'),
        {
          'rating': 5,
          'comment': 'Mejorado',
          'plan_id': 44,
        },
      );
    });
  });

  group('PlayerPreferenceCatalog level contract', () {
    test('maps category labels to the numeric 1-9 scale', () {
      expect(PlayerPreferenceCatalog.optionForNumericLevel(1)?.label, 'Bajo');
      expect(
        PlayerPreferenceCatalog.optionForNumericLevel(2)?.label,
        'Bajo Medio',
      );
      expect(PlayerPreferenceCatalog.optionForNumericLevel(5)?.label, 'Medio');
      expect(
        PlayerPreferenceCatalog.optionForNumericLevel(8)?.label,
        'Alto Medio',
      );
      expect(PlayerPreferenceCatalog.optionForNumericLevel(9)?.label, 'Alto');
    });

    test('converts visible category back to main and sub level values', () {
      final option = PlayerPreferenceCatalog.optionForNumericLevel(6);

      expect(option?.mainLevel, 'medio');
      expect(option?.subLevel, 'alto');
      expect(
        PlayerPreferenceCatalog.numericLevelFor(
          mainLevel: option?.mainLevel,
          subLevel: option?.subLevel,
        ),
        6,
      );
      expect(
        PlayerPreferenceCatalog.levelLabel(
          mainLevel: option?.mainLevel,
          subLevel: option?.subLevel,
        ),
        'Medio Alto',
      );
    });
  });

  group('Chat social agenda contract', () {
    test('maps open social events and their chat conversation metadata', () {
      final event = ChatSocialEventModel.fromJson({
        'id': 7,
        'title': 'After padel en el club',
        'description': 'Cena informal despues de jugar',
        'venue_name': 'Club Test',
        'location': 'Almeria centro',
        'scheduled_date': '2026-04-24',
        'scheduled_time': '21:30:00',
        'duration_minutes': 120,
        'conversation_id': 33,
        'participant_count': 5,
        'is_joined': true,
      });

      expect(event.title, 'After padel en el club');
      expect(event.scheduledAt, DateTime(2026, 4, 24, 21, 30));
      expect(event.conversationId, 33);
      expect(event.isJoined, isTrue);

      final conversation = ChatConversationModel.fromJson({
        'id': 33,
        'kind': 'social_event',
        'title': 'After padel en el club',
        'event': {
          'source_type': 'social_event',
          'social_event_id': 7,
          'title': 'After padel en el club',
          'description': 'Cena informal despues de jugar',
          'scheduled_date': '2026-04-24',
          'scheduled_time': '21:30:00',
          'venue': {
            'id': 0,
            'name': 'Club Test',
            'location': 'Almeria centro',
          },
        },
      });

      expect(conversation.isSocialEvent, isTrue);
      expect(conversation.isEvent, isTrue);
      expect(conversation.event?.planId, isNull);
      expect(conversation.event?.socialEventId, 7);
      expect(conversation.event?.title, 'After padel en el club');
      expect(conversation.event?.description, 'Cena informal despues de jugar');
    });
  });
}
