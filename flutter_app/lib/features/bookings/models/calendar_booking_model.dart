class CalendarParticipantModel {
  final int userId;
  final String displayName;
  final String? email;
  final String role;
  final String inviteStatus;
  final String googleResponseStatus;
  final DateTime? respondedAt;

  const CalendarParticipantModel({
    required this.userId,
    required this.displayName,
    this.email,
    required this.role,
    required this.inviteStatus,
    required this.googleResponseStatus,
    this.respondedAt,
  });

  factory CalendarParticipantModel.fromJson(Map<String, dynamic> json) {
    final respondedRaw = json['responded_at'] ?? json['respondedAt'];
    DateTime? respondedAt;
    if (respondedRaw is String && respondedRaw.isNotEmpty) {
      respondedAt = DateTime.tryParse(respondedRaw);
    }

    return CalendarParticipantModel(
      userId: _asInt(json['user_id'] ?? json['id']),
      displayName: (json['display_name'] ??
          json['nombre'] ??
          json['name'] ??
          '') as String,
      email: json['email'] as String?,
      role: (json['role'] ?? 'player') as String,
      inviteStatus: (json['invite_status'] ?? 'pendiente') as String,
      googleResponseStatus: (json['google_response_status'] ??
          json['response_status'] ??
          'needsAction') as String,
      respondedAt: respondedAt,
    );
  }
}

class CalendarBookingModel {
  final int id;
  final int? courtId;
  final int? venueId;
  final String? venueName;
  final String? courtName;
  final String? bookingDate;
  final String? startTime;
  final String? endTime;
  final int durationMinutes;
  final String status;
  final String inviteStatus;
  final String calendarSyncStatus;
  final String? notes;
  final double? price;
  final String? googleEventId;
  final bool isManaged;
  final List<CalendarParticipantModel> participants;

  const CalendarBookingModel({
    required this.id,
    this.courtId,
    this.venueId,
    this.venueName,
    this.courtName,
    this.bookingDate,
    this.startTime,
    this.endTime,
    required this.durationMinutes,
    required this.status,
    required this.inviteStatus,
    required this.calendarSyncStatus,
    this.notes,
    this.price,
    this.googleEventId,
    this.isManaged = false,
    this.participants = const [],
  });

  factory CalendarBookingModel.fromJson(
    Map<String, dynamic> json, {
    bool isManaged = false,
  }) {
    final participantsRaw = (json['participants'] ??
            json['players'] ??
            json['booking_players'] ??
            json['invitees']) as List<dynamic>? ??
        const [];
    final participants = participantsRaw
        .whereType<Map>()
        .map((participant) => CalendarParticipantModel.fromJson(
              Map<String, dynamic>.from(participant),
            ))
        .toList();

    final bookingDate =
        (json['booking_date'] ?? json['date'] ?? json['fecha']) as String?;
    final startTime = (json['start_time'] ?? json['hora_inicio']) as String?;
    final endTime = (json['end_time'] ?? json['hora_fin']) as String?;
    final duration = CalendarFeedModel._durationMinutes(
      durationMinutes: json['duration_minutes'] ?? json['duration'],
      startTime: startTime,
      endTime: endTime,
    );

    return CalendarBookingModel(
      id: _asInt(json['id']),
      courtId: _asNullableInt(json['court_id'] ?? json['courtId']),
      venueId: _asNullableInt(json['venue_id'] ?? json['venueId']),
      venueName: (json['venue_name'] ?? json['venueName']) as String?,
      courtName: (json['court_name'] ?? json['courtName']) as String?,
      bookingDate: bookingDate,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: duration,
      status: (json['status'] ?? 'pendiente') as String,
      inviteStatus: (json['invite_status'] ??
          json['my_invite_status'] ??
          json['response_status'] ??
          'pendiente') as String,
      calendarSyncStatus: (json['calendar_sync_status'] ??
          json['sync_status'] ??
          'sincronizada') as String,
      notes: json['notes'] as String?,
      price: _asNullableDouble(json['price'] ?? json['total_price']),
      googleEventId: json['google_event_id'] as String?,
      isManaged:
          (json['is_managed'] ?? json['created_by_me'] ?? isManaged) == true,
      participants: participants,
    );
  }

  Map<String, dynamic> toBookingFormState() {
    return {
      'booking_id': id,
      'court_id': courtId,
      'date': bookingDate,
      'start_time': startTime,
      'duration_minutes': durationMinutes,
      'venue_name': venueName,
      'court_name': courtName,
      'price': price,
      'notes': notes,
      'players': participants
          .where((participant) =>
              participant.role != 'organizer' &&
              participant.inviteStatus != 'cancelada')
          .map(
            (participant) => {
              'user_id': participant.userId,
              'display_name': participant.displayName,
              'email': participant.email,
            },
          )
          .toList(),
    };
  }
}

class CalendarFeedModel {
  final List<CalendarBookingModel> agendaUpcoming;
  final List<CalendarBookingModel> agendaHistory;
  final List<CalendarBookingModel> managedUpcoming;
  final List<CalendarBookingModel> managedHistory;
  final String? syncStatus;
  final DateTime? lastSyncedAt;
  final bool fromLegacyEndpoint;

  const CalendarFeedModel({
    required this.agendaUpcoming,
    required this.agendaHistory,
    required this.managedUpcoming,
    required this.managedHistory,
    this.syncStatus,
    this.lastSyncedAt,
    this.fromLegacyEndpoint = false,
  });

  factory CalendarFeedModel.fromJson(Map<String, dynamic> json) {
    final agenda = json['agenda'];
    final managed = json['managed'];
    final sync = json['sync'];
    final syncMap = sync is Map ? Map<String, dynamic>.from(sync) : null;

    if (agenda is Map || managed is Map || syncMap != null) {
      return CalendarFeedModel(
        agendaUpcoming: _mapBookings(_extractList(agenda, 'upcoming')),
        agendaHistory: _mapBookings(_extractList(agenda, 'history')),
        managedUpcoming:
            _mapBookings(_extractList(managed, 'upcoming'), isManaged: true),
        managedHistory:
            _mapBookings(_extractList(managed, 'history'), isManaged: true),
        syncStatus:
            syncMap?['status'] as String? ?? json['sync_status'] as String?,
        lastSyncedAt: _parseDateTime(
            syncMap?['last_synced_at'] ?? json['last_synced_at']),
      );
    }

    final upcoming = _mapBookings(_extractList(json, 'upcoming'));
    final past = _mapBookings(_extractList(json, 'past'));

    return CalendarFeedModel(
      agendaUpcoming: upcoming,
      agendaHistory: past,
      managedUpcoming: upcoming,
      managedHistory: past,
      syncStatus: 'sincronizada',
      lastSyncedAt: DateTime.now(),
      fromLegacyEndpoint: true,
    );
  }

  static List<dynamic> _extractList(dynamic source, String key) {
    if (source is Map && source[key] is List) {
      return source[key] as List<dynamic>;
    }
    return const [];
  }

  static List<CalendarBookingModel> _mapBookings(
    List<dynamic> raw, {
    bool isManaged = false,
  }) {
    return raw
        .whereType<Map>()
        .map((booking) => CalendarBookingModel.fromJson(
              Map<String, dynamic>.from(booking),
              isManaged: isManaged,
            ))
        .toList();
  }

  static int _durationMinutes({
    dynamic durationMinutes,
    String? startTime,
    String? endTime,
  }) {
    if (durationMinutes is int) {
      return durationMinutes;
    }
    if (durationMinutes is num) {
      return durationMinutes.round();
    }
    if (durationMinutes is String) {
      final parsed = int.tryParse(durationMinutes);
      if (parsed != null) {
        return parsed;
      }
    }
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);
    if (start != null && end != null) {
      final minutes = end.difference(start).inMinutes;
      if (minutes > 0) {
        return minutes;
      }
    }
    return 90;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static DateTime? _parseTime(String? time) {
    if (time == null || time.isEmpty) {
      return null;
    }
    final parts = time.split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return DateTime(2000, 1, 1, hour, minute);
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}
