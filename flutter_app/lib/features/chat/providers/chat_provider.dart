import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../players/providers/player_provider.dart';
import '../models/chat_models.dart';
import '../services/chat_socket_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});

final chatSocketSyncProvider = Provider<ChatSocketSync>((ref) {
  final sync = ChatSocketSync(ref);
  ref.onDispose(sync.dispose);
  return sync;
});

final chatConversationsProvider = FutureProvider<List<ChatConversationModel>>((
  ref,
) async {
  ref.watch(chatSocketSyncProvider);
  final repository = ref.watch(chatRepositoryProvider);
  return repository.fetchConversations();
});

final chatSocialEventsProvider = FutureProvider<List<ChatSocialEventModel>>((
  ref,
) async {
  ref.watch(chatSocketSyncProvider);
  final repository = ref.watch(chatRepositoryProvider);
  return repository.fetchSocialEvents();
});

final chatUnreadCountValueProvider = FutureProvider<int>((ref) async {
  ref.watch(chatSocketSyncProvider);
  final repository = ref.watch(chatRepositoryProvider);
  return repository.fetchUnreadCount();
});

final chatUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(chatUnreadCountValueProvider).valueOrNull ?? 0;
});

final chatActionsProvider = Provider<ChatActions>((ref) {
  return ChatActions(ref);
});

final chatThreadProvider = StateNotifierProvider.autoDispose
    .family<ChatThreadController, ChatThreadState, ChatThreadArgs>((
  ref,
  args,
) {
  final controller = ChatThreadController(ref, args);
  ref.onDispose(controller.dispose);
  return controller;
});

class ChatThreadArgs {
  final int conversationId;
  final ChatConversationModel? initialConversation;

  const ChatThreadArgs({
    required this.conversationId,
    this.initialConversation,
  });

  @override
  bool operator ==(Object other) {
    return other is ChatThreadArgs &&
        other.conversationId == conversationId &&
        other.initialConversation?.id == initialConversation?.id;
  }

  @override
  int get hashCode => Object.hash(conversationId, initialConversation?.id);
}

class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  Future<List<ChatConversationModel>> fetchConversations() async {
    final data = await _api.get('/padel/chat/conversations');
    final rawList = data is List
        ? data
        : (data is Map
            ? (data['conversations'] as List<dynamic>? ?? const [])
            : const []);

    return rawList
        .whereType<Map>()
        .map(
          (item) => ChatConversationModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<int> fetchUnreadCount() async {
    final data = await _api.get('/padel/chat/unread-count');
    if (data is Map) {
      return _asInt(data['unread_count']);
    }
    return 0;
  }

  Future<ChatConversationModel> fetchConversation(int conversationId) async {
    final data = await _api.get('/padel/chat/conversations/$conversationId');
    return _parseConversationPayload(data);
  }

  Future<List<ChatSocialEventModel>> fetchSocialEvents() async {
    final data = await _api.get('/padel/chat/social-events');
    final rawList = data is List
        ? data
        : (data is Map
            ? (data['events'] as List<dynamic>? ?? const [])
            : const []);

    return rawList
        .whereType<Map>()
        .map(
          (item) => ChatSocialEventModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<ChatMessagePageModel> fetchMessages(
    int conversationId, {
    int? beforeMessageId,
    int limit = 50,
  }) async {
    final queryParameters = <String, dynamic>{
      'limit': limit,
      if (beforeMessageId != null) 'before_message_id': beforeMessageId,
    };
    final data = await _api.get(
      '/padel/chat/conversations/$conversationId/messages',
      queryParameters: queryParameters,
    );
    return ChatMessagePageModel.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<ChatSendMessageResult> sendMessage({
    required int conversationId,
    required String body,
    String messageType = 'text',
    String? attachmentDataUrl,
    int? attachmentDurationSeconds,
  }) async {
    final payload = <String, dynamic>{
      'message_type': messageType,
      'body': body,
    };
    if (attachmentDataUrl != null) {
      payload['attachment_data_url'] = attachmentDataUrl;
    }
    if (attachmentDurationSeconds != null) {
      payload['attachment_duration_seconds'] = attachmentDurationSeconds;
    }

    final data = await _api.post(
      '/padel/chat/conversations/$conversationId/messages',
      data: payload,
    );
    return ChatSendMessageResult.fromJson(
        Map<String, dynamic>.from(data as Map));
  }

  Future<ChatDeleteMessagesResult> deleteMessages({
    required int conversationId,
    required List<int> messageIds,
  }) async {
    final data = await _api.delete(
      '/padel/chat/conversations/$conversationId/messages',
      data: {'message_ids': messageIds},
    );
    return ChatDeleteMessagesResult.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<ChatConversationModel?> clearHistory({
    required int conversationId,
  }) async {
    final data = await _api.delete(
      '/padel/chat/conversations/$conversationId/history',
      data: const {},
    );
    if (data is Map && data['conversation'] is Map) {
      return ChatConversationModel.fromJson(
        Map<String, dynamic>.from(data['conversation'] as Map),
      );
    }
    return null;
  }

  Future<void> markConversationRead(
    int conversationId, {
    int? messageId,
  }) async {
    await _api.post(
      '/padel/chat/conversations/$conversationId/read',
      data: {
        if (messageId != null) 'message_id': messageId,
      },
    );
  }

  Future<ChatConversationModel> createDirectConversation({
    required int otherUserId,
  }) async {
    final data =
        await _api.post('/padel/chat/direct/$otherUserId', data: const {});
    return _parseConversationPayload(data);
  }

  Future<ChatConversationModel> createGroupConversation({
    required String title,
    required List<int> participantUserIds,
  }) async {
    final data = await _api.post(
      '/padel/chat/groups',
      data: {
        'title': title,
        'participant_user_ids': participantUserIds,
      },
    );
    return _parseConversationPayload(data);
  }

  Future<ChatConversationModel> createEventConversation({
    required int planId,
  }) async {
    final data = await _api.post('/padel/chat/events/$planId', data: const {});
    return _parseConversationPayload(data);
  }

  Future<ChatConversationModel> createSocialEvent({
    required String title,
    String? description,
    String? venueName,
    String? location,
    required String scheduledDate,
    required String scheduledTime,
    int durationMinutes = 90,
  }) async {
    final data = await _api.post(
      '/padel/chat/social-events',
      data: {
        'title': title,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (venueName != null && venueName.trim().isNotEmpty)
          'venue_name': venueName.trim(),
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'duration_minutes': durationMinutes,
      },
    );
    return _parseConversationPayload(data);
  }

  Future<ChatConversationModel> openSocialEventConversation({
    required int eventId,
  }) async {
    final data = await _api.post(
      '/padel/chat/social-events/$eventId/join',
      data: const {},
    );
    return _parseConversationPayload(data);
  }

  ChatConversationModel _parseConversationPayload(dynamic data) {
    final json = data is Map && data['conversation'] is Map
        ? Map<String, dynamic>.from(data['conversation'] as Map)
        : Map<String, dynamic>.from(data as Map);
    return ChatConversationModel.fromJson(json);
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}

class ChatActions {
  ChatActions(this._ref);

  final Ref _ref;

  Future<ChatConversationModel> createDirectConversation(
      int otherUserId) async {
    final repository = _ref.read(chatRepositoryProvider);
    final conversation = await repository.createDirectConversation(
      otherUserId: otherUserId,
    );
    _ref.invalidate(chatConversationsProvider);
    return conversation;
  }

  Future<ChatConversationModel> createGroupConversation({
    required String title,
    required List<int> participantUserIds,
  }) async {
    final repository = _ref.read(chatRepositoryProvider);
    final conversation = await repository.createGroupConversation(
      title: title,
      participantUserIds: participantUserIds,
    );
    _ref.invalidate(chatConversationsProvider);
    return conversation;
  }

  Future<ChatConversationModel> createSocialEvent({
    required String title,
    String? description,
    String? venueName,
    String? location,
    required String scheduledDate,
    required String scheduledTime,
    int durationMinutes = 90,
  }) async {
    final repository = _ref.read(chatRepositoryProvider);
    final conversation = await repository.createSocialEvent(
      title: title,
      description: description,
      venueName: venueName,
      location: location,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      durationMinutes: durationMinutes,
    );
    _ref.invalidate(chatSocialEventsProvider);
    _ref.invalidate(chatConversationsProvider);
    return conversation;
  }

  Future<ChatConversationModel> openSocialEventConversation(int eventId) async {
    final repository = _ref.read(chatRepositoryProvider);
    final conversation =
        await repository.openSocialEventConversation(eventId: eventId);
    _ref.invalidate(chatSocialEventsProvider);
    _ref.invalidate(chatConversationsProvider);
    return conversation;
  }

  Future<ChatConversationModel> openEventConversation(int planId) async {
    final repository = _ref.read(chatRepositoryProvider);
    final conversation =
        await repository.createEventConversation(planId: planId);
    _ref.invalidate(chatConversationsProvider);
    return conversation;
  }
}

class ChatSocketSync {
  ChatSocketSync(this._ref) {
    _initialize();
  }

  final Ref _ref;
  StreamSubscription<ChatConversationCreatedEventModel>?
      _conversationCreatedSubscription;
  StreamSubscription<ChatMessageCreatedEventModel>? _messageCreatedSubscription;
  StreamSubscription<ChatMessagesDeletedEventModel>?
      _messagesDeletedSubscription;
  StreamSubscription<ChatConversationReadEventModel>?
      _conversationReadSubscription;

  Future<void> _initialize() async {
    try {
      await ChatSocketService.instance.connect();
      _conversationCreatedSubscription =
          ChatSocketService.instance.conversationCreatedEvents.listen((_) {
        _ref.invalidate(chatConversationsProvider);
        _ref.invalidate(chatSocialEventsProvider);
        _ref.invalidate(chatUnreadCountValueProvider);
      });
      _messageCreatedSubscription =
          ChatSocketService.instance.messageCreatedEvents.listen((_) {
        _ref.invalidate(chatConversationsProvider);
        _ref.invalidate(chatUnreadCountValueProvider);
      });
      _messagesDeletedSubscription =
          ChatSocketService.instance.messagesDeletedEvents.listen((_) {
        _ref.invalidate(chatConversationsProvider);
        _ref.invalidate(chatUnreadCountValueProvider);
      });
      _conversationReadSubscription =
          ChatSocketService.instance.conversationReadEvents.listen((_) {
        _ref.invalidate(chatConversationsProvider);
        _ref.invalidate(chatUnreadCountValueProvider);
      });
    } catch (_) {}
  }

  void dispose() {
    _conversationCreatedSubscription?.cancel();
    _messageCreatedSubscription?.cancel();
    _messagesDeletedSubscription?.cancel();
    _conversationReadSubscription?.cancel();
  }
}

class ChatThreadController extends StateNotifier<ChatThreadState> {
  ChatThreadController(this._ref, this._args)
      : super(ChatThreadState(conversation: _args.initialConversation)) {
    _initialize();
  }

  final Ref _ref;
  final ChatThreadArgs _args;

  StreamSubscription<ChatMessageCreatedEventModel>? _messageSubscription;
  StreamSubscription<ChatMessagesDeletedEventModel>? _deleteSubscription;
  StreamSubscription<ChatConversationReadEventModel>? _readSubscription;

  Future<void> _initialize() async {
    try {
      _ref.read(chatSocketSyncProvider);
      await ChatSocketService.instance.connect();
      ChatSocketService.instance.joinConversation(_args.conversationId);
      _messageSubscription =
          ChatSocketService.instance.messageCreatedEvents.listen(
        _handleIncomingMessage,
      );
      _deleteSubscription =
          ChatSocketService.instance.messagesDeletedEvents.listen(
        _handleDeletedMessages,
      );
      _readSubscription =
          ChatSocketService.instance.conversationReadEvents.listen(
        _handleReadUpdate,
      );
      await refresh();
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: error.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      final repository = _ref.read(chatRepositoryProvider);
      final page = await repository.fetchMessages(_args.conversationId);
      state = state.copyWith(
        conversation: page.conversation ?? state.conversation,
        messages: page.messages,
        loading: false,
      );

      if (page.messages.isNotEmpty) {
        unawaited(markRead(page.messages.last.id));
      } else {
        unawaited(markRead());
      }
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: error.toString(),
      );
    }
  }

  Future<void> sendMessage(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || state.sending) {
      return;
    }

    state = state.copyWith(sending: true, clearError: true);
    try {
      final repository = _ref.read(chatRepositoryProvider);
      final result = await repository.sendMessage(
        conversationId: _args.conversationId,
        body: trimmed,
      );

      final existing =
          state.messages.any((item) => item.id == result.message.id);
      final nextMessages = existing
          ? state.messages
          : (List<ChatMessageModel>.from(state.messages)..add(result.message));

      state = state.copyWith(
        conversation: result.conversation ?? state.conversation,
        messages: nextMessages,
        sending: false,
      );
      _ref.invalidate(chatConversationsProvider);
    } catch (error) {
      state = state.copyWith(
        sending: false,
        error: error.toString(),
      );
    }
  }

  Future<void> sendImage({
    required String dataUrl,
    String caption = '',
  }) {
    return _sendMedia(
      messageType: 'image',
      dataUrl: dataUrl,
      body: caption,
    );
  }

  Future<void> sendVoice({
    required String dataUrl,
    required int durationSeconds,
  }) {
    return _sendMedia(
      messageType: 'voice',
      dataUrl: dataUrl,
      body: '',
      durationSeconds: durationSeconds,
    );
  }

  Future<void> _sendMedia({
    required String messageType,
    required String dataUrl,
    required String body,
    int? durationSeconds,
  }) async {
    if (state.sending) {
      return;
    }

    state = state.copyWith(sending: true, clearError: true);
    try {
      final repository = _ref.read(chatRepositoryProvider);
      final result = await repository.sendMessage(
        conversationId: _args.conversationId,
        messageType: messageType,
        body: body.trim(),
        attachmentDataUrl: dataUrl,
        attachmentDurationSeconds: durationSeconds,
      );

      final existing =
          state.messages.any((item) => item.id == result.message.id);
      final nextMessages = existing
          ? state.messages
          : (List<ChatMessageModel>.from(state.messages)..add(result.message));

      state = state.copyWith(
        conversation: result.conversation ?? state.conversation,
        messages: nextMessages,
        sending: false,
      );
      _ref.invalidate(chatConversationsProvider);
      unawaited(markRead(result.message.id));
    } catch (error) {
      state = state.copyWith(
        sending: false,
        error: error.toString(),
      );
    }
  }

  Future<void> deleteMessages(List<int> messageIds) async {
    final ids = messageIds.toSet().toList(growable: false);
    if (ids.isEmpty || state.deleting) {
      return;
    }

    state = state.copyWith(deleting: true, clearError: true);
    try {
      final repository = _ref.read(chatRepositoryProvider);
      final result = await repository.deleteMessages(
        conversationId: _args.conversationId,
        messageIds: ids,
      );
      final deletedIds = result.deletedMessageIds.toSet();
      final nextMessages = state.messages
          .where((message) => !deletedIds.contains(message.id))
          .toList(growable: false);

      state = state.copyWith(
        conversation: result.conversation ?? state.conversation,
        messages: nextMessages,
        deleting: false,
      );
      _ref.invalidate(chatConversationsProvider);
      _ref.invalidate(chatUnreadCountValueProvider);
    } catch (error) {
      state = state.copyWith(
        deleting: false,
        error: error.toString(),
      );
    }
  }

  Future<bool> clearHistory() async {
    if (state.deleting) {
      return false;
    }

    state = state.copyWith(deleting: true, clearError: true);
    try {
      final repository = _ref.read(chatRepositoryProvider);
      final conversation = await repository.clearHistory(
        conversationId: _args.conversationId,
      );
      state = state.copyWith(
        conversation: conversation ?? state.conversation,
        messages: const [],
        deleting: false,
      );
      _ref.invalidate(chatConversationsProvider);
      _ref.invalidate(chatUnreadCountValueProvider);
      return true;
    } catch (error) {
      state = state.copyWith(
        deleting: false,
        error: error.toString(),
      );
      return false;
    }
  }

  Future<void> markRead([int? messageId]) async {
    try {
      await _ref.read(chatRepositoryProvider).markConversationRead(
            _args.conversationId,
            messageId: messageId,
          );
      _ref.invalidate(chatConversationsProvider);
      _ref.invalidate(chatUnreadCountValueProvider);
    } catch (_) {}
  }

  void _handleIncomingMessage(ChatMessageCreatedEventModel event) {
    if (event.conversationId != _args.conversationId) {
      _ref.invalidate(chatConversationsProvider);
      return;
    }

    final existing = state.messages.any((item) => item.id == event.message.id);
    if (existing) {
      return;
    }

    final nextMessages = List<ChatMessageModel>.from(state.messages)
      ..add(event.message);
    state = state.copyWith(messages: nextMessages);
    _ref.invalidate(chatConversationsProvider);
    unawaited(markRead(event.message.id));
  }

  void _handleDeletedMessages(ChatMessagesDeletedEventModel event) {
    if (event.conversationId != _args.conversationId) {
      _ref.invalidate(chatConversationsProvider);
      return;
    }

    final deletedIds = event.messageIds.toSet();
    if (deletedIds.isEmpty) {
      return;
    }

    final nextMessages = state.messages
        .where((message) => !deletedIds.contains(message.id))
        .toList(growable: false);
    state = state.copyWith(
      conversation: event.conversation ?? state.conversation,
      messages: nextMessages,
    );
    _ref.invalidate(chatConversationsProvider);
    _ref.invalidate(chatUnreadCountValueProvider);
  }

  void _handleReadUpdate(ChatConversationReadEventModel event) {
    if (event.conversationId != _args.conversationId) {
      return;
    }

    final conversation = state.conversation;
    if (conversation == null) {
      return;
    }

    final readUserIsSelf = conversation.participants.any(
      (participant) => participant.userId == event.userId && participant.isSelf,
    );
    final participants = conversation.participants
        .map(
          (participant) => participant.userId == event.userId
              ? participant.copyWith(
                  lastReadMessageId: event.messageId,
                  lastReadAt: event.readAt,
                )
              : participant,
        )
        .toList(growable: false);

    state = state.copyWith(
      conversation: conversation.copyWith(
        lastReadMessageId:
            readUserIsSelf ? event.messageId : conversation.lastReadMessageId,
        lastReadAt: readUserIsSelf ? event.readAt : conversation.lastReadAt,
        participants: participants,
      ),
    );
    _ref.invalidate(chatConversationsProvider);
  }

  @override
  void dispose() {
    ChatSocketService.instance.leaveConversation(_args.conversationId);
    _messageSubscription?.cancel();
    _deleteSubscription?.cancel();
    _readSubscription?.cancel();
    super.dispose();
  }
}

final chatNetworkOptionsProvider = FutureProvider<List<ChatParticipantModel>>((
  ref,
) async {
  final network = await ref.watch(networkProvider.future);
  return network.companions
      .map(
        (player) => ChatParticipantModel(
          userId: player.userId,
          displayName: player.displayName,
          avatarUrl: player.avatarUrl,
        ),
      )
      .toList(growable: false);
});
