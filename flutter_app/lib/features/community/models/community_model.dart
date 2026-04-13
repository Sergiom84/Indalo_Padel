import '../../players/models/player_model.dart';

class CommunityDashboardModel {
  final CommunityVenueModel? venue;
  final List<PlayerModel> companions;
  final List<CommunityPlanModel> plans;
  final List<CommunityPlanModel> activePlans;
  final List<CommunityPlanModel> historyPlans;
  final CommunityPlanModel? activePlan;
  final List<CommunityNotificationModel> notifications;

  const CommunityDashboardModel({
    this.venue,
    this.companions = const [],
    this.plans = const [],
    this.activePlans = const [],
    this.historyPlans = const [],
    this.activePlan,
    this.notifications = const [],
  });

  bool get hasPlans => activePlans.isNotEmpty || historyPlans.isNotEmpty;

  factory CommunityDashboardModel.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(
      dynamic value,
      T Function(Map<String, dynamic>) mapper,
    ) {
      if (value is! List) {
        return const [];
      }

      return value
          .whereType<Map>()
          .map((item) => mapper(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    final activePlans = parseList(
      json['active_plans'] ?? json['plans'],
      CommunityPlanModel.fromJson,
    );
    final historyPlans = parseList(
      json['history_plans'],
      CommunityPlanModel.fromJson,
    );
    final activePlanRaw = json['active_plan'];

    return CommunityDashboardModel(
      venue: json['venue'] is Map<String, dynamic>
          ? CommunityVenueModel.fromJson(json['venue'] as Map<String, dynamic>)
          : (json['venue'] is Map
              ? CommunityVenueModel.fromJson(
                  Map<String, dynamic>.from(json['venue'] as Map),
                )
              : null),
      companions: parseList(json['companions'], PlayerModel.fromJson),
      plans: activePlans,
      activePlans: activePlans,
      historyPlans: historyPlans,
      activePlan: activePlanRaw is Map<String, dynamic>
          ? CommunityPlanModel.fromJson(activePlanRaw)
          : (activePlanRaw is Map
              ? CommunityPlanModel.fromJson(
                  Map<String, dynamic>.from(activePlanRaw),
                )
              : null),
      notifications: parseList(
        json['notifications'],
        CommunityNotificationModel.fromJson,
      ),
    );
  }
}

class CommunityVenueModel {
  final int? id;
  final String name;
  final String? location;
  final String? address;
  final String? phone;

  const CommunityVenueModel({
    this.id,
    required this.name,
    this.location,
    this.address,
    this.phone,
  });

  factory CommunityVenueModel.fromJson(Map<String, dynamic> json) {
    return CommunityVenueModel(
      id: _asNullableInt(json['id']),
      name: (json['name'] ?? 'Centro deportivo').toString(),
      location: _asNullableString(json['location']),
      address: _asNullableString(json['address']),
      phone: _asNullableString(json['phone']),
    );
  }
}

class CommunityPlanModel {
  final int id;
  final int createdBy;
  final String creatorName;
  final String scheduledDate;
  final String scheduledTime;
  final int durationMinutes;
  final String inviteState;
  final String reservationState;
  final int? reservationHandledBy;
  final String? reservationHandledByName;
  final String? reservationContactPhone;
  final String? googleEventId;
  final int? lastDeclinedBy;
  final String? lastDeclinedByName;
  final int? lastRescheduleBy;
  final String? lastRescheduleByName;
  final String? lastRescheduleDate;
  final String? lastRescheduleTime;
  final String? reservationConfirmedAt;
  final String calendarSyncStatus;
  final String? lastSyncedAt;
  final String? closedAt;
  final int? closedBy;
  final String? closedByName;
  final String? closedReason;
  final String? createdAt;
  final String? updatedAt;
  final CommunityVenueModel? venue;
  final List<CommunityParticipantModel> participants;
  final bool isOrganizer;
  final String? myResponseState;

  const CommunityPlanModel({
    required this.id,
    required this.createdBy,
    required this.creatorName,
    required this.scheduledDate,
    required this.scheduledTime,
    this.durationMinutes = 90,
    this.inviteState = 'pending',
    this.reservationState = 'pending',
    this.reservationHandledBy,
    this.reservationHandledByName,
    this.reservationContactPhone,
    this.googleEventId,
    this.lastDeclinedBy,
    this.lastDeclinedByName,
    this.lastRescheduleBy,
    this.lastRescheduleByName,
    this.lastRescheduleDate,
    this.lastRescheduleTime,
    this.reservationConfirmedAt,
    this.calendarSyncStatus = 'pending',
    this.lastSyncedAt,
    this.closedAt,
    this.closedBy,
    this.closedByName,
    this.closedReason,
    this.createdAt,
    this.updatedAt,
    this.venue,
    this.participants = const [],
    this.isOrganizer = false,
    this.myResponseState,
  });

  bool get isReady => inviteState == 'ready';
  bool get hasDecline => inviteState == 'replacement_required';
  bool get hasRescheduleProposal => inviteState == 'reschedule_pending';
  bool get reservationConfirmed => reservationState == 'confirmed';
  bool get isCancelled =>
      inviteState == 'cancelled' || reservationState == 'cancelled';
  bool get isExpired =>
      inviteState == 'expired' || reservationState == 'expired';
  bool get isTerminal => reservationConfirmed || isCancelled || isExpired;

  CommunityParticipantModel? get currentUserParticipant {
    for (final participant in participants) {
      if (participant.isCurrentUser) {
        return participant;
      }
    }
    return null;
  }

  factory CommunityPlanModel.fromJson(Map<String, dynamic> json) {
    List<CommunityParticipantModel> parseParticipants(dynamic value) {
      if (value is! List) {
        return const [];
      }

      return value
          .whereType<Map>()
          .map(
            (item) => CommunityParticipantModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    }

    return CommunityPlanModel(
      id: _asInt(json['id']),
      createdBy: _asInt(json['created_by']),
      creatorName: (json['creator_name'] ?? 'Organizador').toString(),
      scheduledDate: (json['scheduled_date'] ?? '').toString(),
      scheduledTime: (json['scheduled_time'] ?? '').toString(),
      durationMinutes: _asInt(json['duration_minutes'], fallback: 90),
      inviteState: (json['invite_state'] ?? 'pending').toString(),
      reservationState: (json['reservation_state'] ?? 'pending').toString(),
      reservationHandledBy: _asNullableInt(json['reservation_handled_by']),
      reservationHandledByName:
          _asNullableString(json['reservation_handled_by_name']),
      reservationContactPhone:
          _asNullableString(json['reservation_contact_phone']),
      googleEventId: _asNullableString(json['google_event_id']),
      lastDeclinedBy: _asNullableInt(json['last_declined_by']),
      lastDeclinedByName: _asNullableString(json['last_declined_by_name']),
      lastRescheduleBy: _asNullableInt(json['last_reschedule_by']),
      lastRescheduleByName: _asNullableString(json['last_reschedule_by_name']),
      lastRescheduleDate: _asNullableString(json['last_reschedule_date']),
      lastRescheduleTime: _asNullableString(json['last_reschedule_time']),
      reservationConfirmedAt:
          _asNullableString(json['reservation_confirmed_at']),
      calendarSyncStatus:
          _asNullableString(json['calendar_sync_status']) ?? 'pending',
      lastSyncedAt: _asNullableString(json['last_synced_at']),
      closedAt: _asNullableString(json['closed_at']),
      closedBy: _asNullableInt(json['closed_by']),
      closedByName: _asNullableString(json['closed_by_name']),
      closedReason: _asNullableString(json['closed_reason']),
      createdAt: _asNullableString(json['created_at']),
      updatedAt: _asNullableString(json['updated_at']),
      venue: json['venue'] is Map<String, dynamic>
          ? CommunityVenueModel.fromJson(json['venue'] as Map<String, dynamic>)
          : (json['venue'] is Map
              ? CommunityVenueModel.fromJson(
                  Map<String, dynamic>.from(json['venue'] as Map),
                )
              : null),
      participants: parseParticipants(json['participants']),
      isOrganizer: _asBool(json['is_organizer']),
      myResponseState: _asNullableString(json['my_response_state']),
    );
  }
}

class CommunityParticipantModel {
  final int userId;
  final String displayName;
  final String? nombre;
  final String? email;
  final int numericLevel;
  final bool isAvailable;
  final String? avatarUrl;
  final String role;
  final String responseState;
  final String? respondedAt;
  final bool isCurrentUser;
  final bool isOrganizer;

  const CommunityParticipantModel({
    required this.userId,
    required this.displayName,
    this.nombre,
    this.email,
    this.numericLevel = 0,
    this.isAvailable = true,
    this.avatarUrl,
    this.role = 'player',
    this.responseState = 'pending',
    this.respondedAt,
    this.isCurrentUser = false,
    this.isOrganizer = false,
  });

  factory CommunityParticipantModel.fromJson(Map<String, dynamic> json) {
    return CommunityParticipantModel(
      userId: _asInt(json['user_id'] ?? json['id']),
      displayName:
          (json['display_name'] ?? json['nombre'] ?? 'Jugador').toString(),
      nombre: _asNullableString(json['nombre']),
      email: _asNullableString(json['email']),
      numericLevel: _asInt(json['numeric_level']),
      isAvailable: _asBool(json['is_available'], fallback: true),
      avatarUrl: _asNullableString(json['avatar_url']),
      role: (json['role'] ?? 'player').toString(),
      responseState: (json['response_state'] ?? 'pending').toString(),
      respondedAt: _asNullableString(json['responded_at']),
      isCurrentUser: _asBool(json['is_current_user']),
      isOrganizer: _asBool(json['is_organizer']),
    );
  }
}

class CommunityNotificationModel {
  final int id;
  final int planId;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic> metadata;
  final String? actionType;
  final bool isRead;
  final String? createdAt;

  const CommunityNotificationModel({
    required this.id,
    required this.planId,
    required this.type,
    required this.title,
    required this.message,
    this.metadata = const {},
    this.actionType,
    this.isRead = false,
    this.createdAt,
  });

  factory CommunityNotificationModel.fromJson(Map<String, dynamic> json) {
    return CommunityNotificationModel(
      id: _asInt(json['id']),
      planId: _asInt(json['plan_id']),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : (json['metadata'] is Map
              ? Map<String, dynamic>.from(json['metadata'] as Map)
              : const {}),
      actionType: _asNullableString(
        json['action_type'] ??
            (json['metadata'] is Map ? (json['metadata'] as Map)['action_type'] : null),
      ),
      isRead: _asBool(json['is_read']),
      createdAt: _asNullableString(json['created_at']),
    );
  }
}

class CommunityConflictPreviewModel {
  final List<CommunityConflictPlayerModel> conflicts;
  final bool hasConflicts;
  final bool hasHardConflicts;

  const CommunityConflictPreviewModel({
    this.conflicts = const [],
    this.hasConflicts = false,
    this.hasHardConflicts = false,
  });

  factory CommunityConflictPreviewModel.fromJson(Map<String, dynamic> json) {
    final conflicts = ((json['conflicts'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => CommunityConflictPlayerModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);

    return CommunityConflictPreviewModel(
      conflicts: conflicts,
      hasConflicts: _asBool(json['has_conflicts'], fallback: conflicts.isNotEmpty),
      hasHardConflicts: _asBool(
        json['has_hard_conflicts'],
        fallback: conflicts.any((conflict) => conflict.level == 'hard'),
      ),
    );
  }
}

class CommunityConflictPlayerModel {
  final int userId;
  final String displayName;
  final String level;
  final List<CommunityConflictItemModel> items;

  const CommunityConflictPlayerModel({
    required this.userId,
    required this.displayName,
    required this.level,
    this.items = const [],
  });

  factory CommunityConflictPlayerModel.fromJson(Map<String, dynamic> json) {
    return CommunityConflictPlayerModel(
      userId: _asInt(json['user_id']),
      displayName: (json['display_name'] ?? 'Jugador').toString(),
      level: (json['level'] ?? 'soft').toString(),
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => CommunityConflictItemModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }
}

class CommunityConflictItemModel {
  final int id;
  final String source;
  final String severity;
  final String? scheduledDate;
  final String? scheduledTime;
  final String? message;

  const CommunityConflictItemModel({
    required this.id,
    required this.source,
    required this.severity,
    this.scheduledDate,
    this.scheduledTime,
    this.message,
  });

  factory CommunityConflictItemModel.fromJson(Map<String, dynamic> json) {
    return CommunityConflictItemModel(
      id: _asInt(json['id']),
      source: (json['source'] ?? '').toString(),
      severity: (json['severity'] ?? '').toString(),
      scheduledDate: _asNullableString(json['scheduled_date']),
      scheduledTime: _asNullableString(json['scheduled_time']),
      message: _asNullableString(json['message']),
    );
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

String? _asNullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return fallback;
}
