class ChatUserSummaryModel {
  final int userId;
  final String displayName;
  final String? nombre;
  final String? avatarUrl;

  const ChatUserSummaryModel({
    required this.userId,
    required this.displayName,
    this.nombre,
    this.avatarUrl,
  });

  factory ChatUserSummaryModel.fromJson(Map<String, dynamic> json) {
    final userId = _asInt(json['user_id'] ?? json['id']);
    final displayName = _asNullableString(
          json['display_name'] ?? json['nombre'],
        ) ??
        (userId > 0 ? 'Jugador $userId' : 'Jugador');

    return ChatUserSummaryModel(
      userId: userId,
      displayName: displayName,
      nombre: _asNullableString(json['nombre']),
      avatarUrl: _asNullableString(json['avatar_url']),
    );
  }
}

class ChatParticipantModel extends ChatUserSummaryModel {
  final String role;
  final DateTime? joinedAt;
  final int? lastReadMessageId;
  final DateTime? lastReadAt;
  final bool isSelf;
  final bool isOnline;

  const ChatParticipantModel({
    required super.userId,
    required super.displayName,
    super.nombre,
    super.avatarUrl,
    this.role = 'member',
    this.joinedAt,
    this.lastReadMessageId,
    this.lastReadAt,
    this.isSelf = false,
    this.isOnline = false,
  });

  bool get isCurrentUser => isSelf;

  factory ChatParticipantModel.fromJson(Map<String, dynamic> json) {
    final summary = ChatUserSummaryModel.fromJson(json);

    return ChatParticipantModel(
      userId: summary.userId,
      displayName: summary.displayName,
      nombre: summary.nombre,
      avatarUrl: summary.avatarUrl,
      role: _asNullableString(json['role']) ?? 'member',
      joinedAt: _asDateTime(json['joined_at']),
      lastReadMessageId: _asNullableInt(json['last_read_message_id']),
      lastReadAt: _asDateTime(json['last_read_at']),
      isSelf: _asBool(json['is_self'] ?? json['is_current_user']),
      isOnline: _asBool(json['is_online']),
    );
  }
}

class ChatEventVenueModel {
  final int id;
  final String name;
  final String? location;

  const ChatEventVenueModel({
    required this.id,
    required this.name,
    this.location,
  });

  factory ChatEventVenueModel.fromJson(Map<String, dynamic> json) {
    return ChatEventVenueModel(
      id: _asInt(json['id']),
      name: _asNullableString(json['name']) ?? 'Club',
      location: _asNullableString(json['location']),
    );
  }
}

class ChatEventModel {
  final String sourceType;
  final int? planId;
  final int? socialEventId;
  final String? titleOverride;
  final String? descriptionOverride;
  final String? scheduledDate;
  final String? scheduledTime;
  final int? durationMinutes;
  final String? inviteState;
  final String? reservationState;
  final DateTime? closedAt;
  final ChatEventVenueModel? venue;
  final ChatUserSummaryModel? organizer;

  const ChatEventModel({
    this.sourceType = 'community_plan',
    this.planId,
    this.socialEventId,
    this.titleOverride,
    this.descriptionOverride,
    this.scheduledDate,
    this.scheduledTime,
    this.durationMinutes,
    this.inviteState,
    this.reservationState,
    this.closedAt,
    this.venue,
    this.organizer,
  });

  factory ChatEventModel.fromJson(Map<String, dynamic> json) {
    final venueJson = json['venue'];
    final organizerJson = json['organizer'];
    final sourceType = _asNullableString(json['source_type']) ??
        (json['social_event_id'] != null ? 'social_event' : 'community_plan');

    return ChatEventModel(
      sourceType: sourceType,
      planId: sourceType == 'social_event'
          ? null
          : _asNullableInt(json['plan_id'] ?? json['id']),
      socialEventId: _asNullableInt(json['social_event_id']),
      titleOverride: _asNullableString(json['title']),
      descriptionOverride: _asNullableString(json['description']),
      scheduledDate: _asNullableString(json['scheduled_date']),
      scheduledTime: _asNullableString(json['scheduled_time']),
      durationMinutes: _asNullableInt(json['duration_minutes']),
      inviteState: _asNullableString(json['invite_state']),
      reservationState: _asNullableString(json['reservation_state']),
      closedAt: _asDateTime(json['closed_at']),
      venue: venueJson is Map<String, dynamic>
          ? ChatEventVenueModel.fromJson(venueJson)
          : (venueJson is Map
              ? ChatEventVenueModel.fromJson(
                  Map<String, dynamic>.from(venueJson),
                )
              : null),
      organizer: organizerJson is Map<String, dynamic>
          ? ChatUserSummaryModel.fromJson(organizerJson)
          : (organizerJson is Map
              ? ChatUserSummaryModel.fromJson(
                  Map<String, dynamic>.from(organizerJson),
                )
              : null),
    );
  }

  DateTime? get scheduledAt {
    final date = scheduledDate?.trim();
    if (date == null || date.isEmpty) {
      return null;
    }

    final time = scheduledTime?.trim();
    final normalizedTime = time == null || time.isEmpty ? '00:00:00' : time;
    return DateTime.tryParse('${date}T$normalizedTime');
  }

  bool get isSocialEvent => sourceType == 'social_event';
  String get title => titleOverride ?? venue?.name ?? 'Convocatoria';
  String? get venueName => venue?.name;
  String? get description => descriptionOverride ?? venue?.location;
}

class ChatSocialEventModel {
  final int id;
  final String title;
  final String? description;
  final String? venueName;
  final String? location;
  final String? scheduledDate;
  final String? scheduledTime;
  final int durationMinutes;
  final String status;
  final int? createdBy;
  final ChatUserSummaryModel? creator;
  final int? conversationId;
  final int participantCount;
  final bool isJoined;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChatSocialEventModel({
    required this.id,
    required this.title,
    this.description,
    this.venueName,
    this.location,
    this.scheduledDate,
    this.scheduledTime,
    this.durationMinutes = 90,
    this.status = 'active',
    this.createdBy,
    this.creator,
    this.conversationId,
    this.participantCount = 0,
    this.isJoined = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ChatSocialEventModel.fromJson(Map<String, dynamic> json) {
    final creatorJson = json['creator'];

    return ChatSocialEventModel(
      id: _asInt(json['id']),
      title: _asNullableString(json['title']) ?? 'Evento social',
      description: _asNullableString(json['description']),
      venueName: _asNullableString(json['venue_name']),
      location: _asNullableString(json['location']),
      scheduledDate: _asNullableString(json['scheduled_date']),
      scheduledTime: _asNullableString(json['scheduled_time']),
      durationMinutes: _asInt(json['duration_minutes'], fallback: 90),
      status: _asNullableString(json['status']) ?? 'active',
      createdBy: _asNullableInt(json['created_by']),
      creator: creatorJson is Map<String, dynamic>
          ? ChatUserSummaryModel.fromJson(creatorJson)
          : (creatorJson is Map
              ? ChatUserSummaryModel.fromJson(
                  Map<String, dynamic>.from(creatorJson),
                )
              : null),
      conversationId: _asNullableInt(json['conversation_id']),
      participantCount: _asInt(json['participant_count']),
      isJoined: _asBool(json['is_joined']),
      createdAt: _asDateTime(json['created_at']),
      updatedAt: _asDateTime(json['updated_at']),
    );
  }

  DateTime? get scheduledAt {
    final date = scheduledDate?.trim();
    if (date == null || date.isEmpty) {
      return null;
    }

    final time = scheduledTime?.trim();
    final normalizedTime = time == null || time.isEmpty ? '00:00:00' : time;
    return DateTime.tryParse('${date}T$normalizedTime');
  }
}

class ChatMessageModel {
  final int id;
  final int conversationId;
  final ChatUserSummaryModel sender;
  final String body;
  final DateTime? createdAt;
  final bool isOwn;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.body,
    this.createdAt,
    this.isOwn = false,
  });

  int get senderId => sender.userId;
  String get senderName => sender.displayName;
  bool get isMine => isOwn;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final senderJson = json['sender'];
    final sender = senderJson is Map<String, dynamic>
        ? ChatUserSummaryModel.fromJson(senderJson)
        : (senderJson is Map
            ? ChatUserSummaryModel.fromJson(
                Map<String, dynamic>.from(senderJson))
            : ChatUserSummaryModel.fromJson(json));

    return ChatMessageModel(
      id: _asInt(json['id']),
      conversationId: _asInt(json['conversation_id']),
      sender: sender,
      body: (json['body'] ?? '').toString(),
      createdAt: _asDateTime(json['created_at']),
      isOwn: _asBool(json['is_own'] ?? json['is_mine']),
    );
  }
}

class ChatConversationModel {
  final int id;
  final String kind;
  final String title;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int unreadCount;
  final int? lastReadMessageId;
  final DateTime? lastReadAt;
  final int memberCount;
  final List<ChatParticipantModel> participants;
  final ChatUserSummaryModel? directPeer;
  final ChatEventModel? event;
  final ChatMessageModel? lastMessage;

  const ChatConversationModel({
    required this.id,
    required this.kind,
    required this.title,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.unreadCount = 0,
    this.lastReadMessageId,
    this.lastReadAt,
    this.memberCount = 0,
    this.participants = const [],
    this.directPeer,
    this.event,
    this.lastMessage,
  });

  bool get isDirect => kind == 'direct';
  bool get isGroup => kind == 'group';
  bool get isSocialEvent => kind == 'social_event';
  bool get isEvent => kind == 'event' || isSocialEvent;
  bool get hasUnread => unreadCount > 0;
  String? get avatarUrl => directPeer?.avatarUrl;
  String? get subtitle =>
      directPeer?.nombre ??
      event?.venue?.location ??
      (isSocialEvent ? event?.description : null) ??
      (participants.length > 2 ? '${participants.length} participantes' : null);
  DateTime? get lastMessageAt =>
      lastMessage?.createdAt ?? updatedAt ?? createdAt;
  String? get lastMessagePreview => lastMessage?.body;

  ChatConversationModel copyWith({
    int? unreadCount,
    int? lastReadMessageId,
    DateTime? lastReadAt,
    ChatMessageModel? lastMessage,
    bool clearLastMessage = false,
  }) {
    return ChatConversationModel(
      id: id,
      kind: kind,
      title: title,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      memberCount: memberCount,
      participants: participants,
      directPeer: directPeer,
      event: event,
      lastMessage: clearLastMessage ? null : (lastMessage ?? this.lastMessage),
    );
  }

  factory ChatConversationModel.fromJson(Map<String, dynamic> json) {
    final participants = _parseList(
      json['participants'],
      ChatParticipantModel.fromJson,
    );
    final directPeerJson = json['direct_peer'];
    final eventJson = json['event'];
    final lastMessageJson = json['last_message'];

    return ChatConversationModel(
      id: _asInt(json['id']),
      kind: (json['kind'] ?? 'direct').toString(),
      title: _asNullableString(json['title']) ?? 'Conversacion',
      createdBy: _asNullableInt(json['created_by']),
      createdAt: _asDateTime(json['created_at']),
      updatedAt: _asDateTime(json['updated_at']),
      unreadCount: _asInt(json['unread_count']),
      lastReadMessageId: _asNullableInt(json['last_read_message_id']),
      lastReadAt: _asDateTime(json['last_read_at']),
      memberCount: _asInt(
        json['member_count'],
        fallback: participants.length,
      ),
      participants: participants,
      directPeer: directPeerJson is Map<String, dynamic>
          ? ChatUserSummaryModel.fromJson(directPeerJson)
          : (directPeerJson is Map
              ? ChatUserSummaryModel.fromJson(
                  Map<String, dynamic>.from(directPeerJson),
                )
              : null),
      event: eventJson is Map<String, dynamic>
          ? ChatEventModel.fromJson(eventJson)
          : (eventJson is Map
              ? ChatEventModel.fromJson(Map<String, dynamic>.from(eventJson))
              : null),
      lastMessage: lastMessageJson is Map<String, dynamic>
          ? ChatMessageModel.fromJson(lastMessageJson)
          : (lastMessageJson is Map
              ? ChatMessageModel.fromJson(
                  Map<String, dynamic>.from(lastMessageJson),
                )
              : null),
    );
  }
}

class ChatMessagePageModel {
  final ChatConversationModel? conversation;
  final List<ChatMessageModel> messages;
  final bool hasMore;
  final int? nextBeforeMessageId;

  const ChatMessagePageModel({
    this.conversation,
    this.messages = const [],
    this.hasMore = false,
    this.nextBeforeMessageId,
  });

  factory ChatMessagePageModel.fromJson(Map<String, dynamic> json) {
    final conversationJson = json['conversation'];
    return ChatMessagePageModel(
      conversation: conversationJson is Map<String, dynamic>
          ? ChatConversationModel.fromJson(conversationJson)
          : (conversationJson is Map
              ? ChatConversationModel.fromJson(
                  Map<String, dynamic>.from(conversationJson),
                )
              : null),
      messages: _parseList(json['messages'], ChatMessageModel.fromJson),
      hasMore: _asBool(json['has_more']),
      nextBeforeMessageId: _asNullableInt(json['next_before_message_id']),
    );
  }
}

class ChatSendMessageResult {
  final ChatConversationModel? conversation;
  final ChatMessageModel message;

  const ChatSendMessageResult({
    required this.message,
    this.conversation,
  });

  factory ChatSendMessageResult.fromJson(Map<String, dynamic> json) {
    final conversationJson = json['conversation'];
    final messageJson = json['message'];

    return ChatSendMessageResult(
      conversation: conversationJson is Map<String, dynamic>
          ? ChatConversationModel.fromJson(conversationJson)
          : (conversationJson is Map
              ? ChatConversationModel.fromJson(
                  Map<String, dynamic>.from(conversationJson),
                )
              : null),
      message: messageJson is Map<String, dynamic>
          ? ChatMessageModel.fromJson(messageJson)
          : ChatMessageModel.fromJson(
              Map<String, dynamic>.from(messageJson as Map)),
    );
  }
}

class ChatConversationCreatedEventModel {
  final int conversationId;
  final String kind;

  const ChatConversationCreatedEventModel({
    required this.conversationId,
    required this.kind,
  });

  factory ChatConversationCreatedEventModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ChatConversationCreatedEventModel(
      conversationId: _asInt(json['conversation_id']),
      kind: (json['kind'] ?? '').toString(),
    );
  }
}

class ChatMessageCreatedEventModel {
  final int conversationId;
  final String kind;
  final ChatMessageModel message;

  const ChatMessageCreatedEventModel({
    required this.conversationId,
    required this.kind,
    required this.message,
  });

  factory ChatMessageCreatedEventModel.fromJson(Map<String, dynamic> json) {
    final messageJson = json['message'];
    final payload = messageJson is Map<String, dynamic>
        ? messageJson
        : Map<String, dynamic>.from(messageJson as Map);

    return ChatMessageCreatedEventModel(
      conversationId: _asInt(json['conversation_id']),
      kind: (json['kind'] ?? '').toString(),
      message: ChatMessageModel.fromJson(payload),
    );
  }
}

class ChatConversationReadEventModel {
  final int conversationId;
  final int userId;
  final int? messageId;
  final DateTime? readAt;

  const ChatConversationReadEventModel({
    required this.conversationId,
    required this.userId,
    this.messageId,
    this.readAt,
  });

  factory ChatConversationReadEventModel.fromJson(Map<String, dynamic> json) {
    return ChatConversationReadEventModel(
      conversationId: _asInt(json['conversation_id']),
      userId: _asInt(json['user_id']),
      messageId: _asNullableInt(json['message_id']),
      readAt: _asDateTime(json['read_at']),
    );
  }
}

class ChatThreadState {
  final ChatConversationModel? conversation;
  final List<ChatMessageModel> messages;
  final bool loading;
  final bool sending;
  final String? error;

  const ChatThreadState({
    this.conversation,
    this.messages = const [],
    this.loading = true,
    this.sending = false,
    this.error,
  });

  ChatThreadState copyWith({
    ChatConversationModel? conversation,
    List<ChatMessageModel>? messages,
    bool? loading,
    bool? sending,
    String? error,
    bool clearError = false,
  }) {
    return ChatThreadState(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

List<T> _parseList<T>(
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

DateTime? _asDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value.toString());
}

String? _asNullableString(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

bool _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  return false;
}
