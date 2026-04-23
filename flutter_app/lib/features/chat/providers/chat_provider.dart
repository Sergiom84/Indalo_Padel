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

final chatUnreadCountProvider = Provider<int>((ref) {
  ref.watch(chatSocketSyncProvider);
  final conversations = ref.watch(chatConversationsProvider).valueOrNull;
  if (conversations == null) {
    return 0;
  }

  return conversations.fold<int>(
    0,
    (sum, conversation) => sum + conversation.unreadCount,
  );
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

  Future<ChatConversationModel> fetchConversation(int conversationId) async {
    final data = await _api.get('/padel/chat/conversations/$conversationId');
    return _parseConversationPayload(data);
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
  }) async {
    final data = await _api.post(
      '/padel/chat/conversations/$conversationId/messages',
      data: {'body': body},
    );
    return ChatSendMessageResult.fromJson(
        Map<String, dynamic>.from(data as Map));
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

  ChatConversationModel _parseConversationPayload(dynamic data) {
    final json = data is Map && data['conversation'] is Map
        ? Map<String, dynamic>.from(data['conversation'] as Map)
        : Map<String, dynamic>.from(data as Map);
    return ChatConversationModel.fromJson(json);
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
  StreamSubscription<ChatConversationReadEventModel>?
      _conversationReadSubscription;

  Future<void> _initialize() async {
    try {
      await ChatSocketService.instance.connect();
      _conversationCreatedSubscription = ChatSocketService
          .instance.conversationCreatedEvents
          .listen((_) => _ref.invalidate(chatConversationsProvider));
      _messageCreatedSubscription = ChatSocketService
          .instance.messageCreatedEvents
          .listen((_) => _ref.invalidate(chatConversationsProvider));
      _conversationReadSubscription = ChatSocketService
          .instance.conversationReadEvents
          .listen((_) => _ref.invalidate(chatConversationsProvider));
    } catch (_) {}
  }

  void dispose() {
    _conversationCreatedSubscription?.cancel();
    _messageCreatedSubscription?.cancel();
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

  Future<void> markRead([int? messageId]) async {
    try {
      await _ref.read(chatRepositoryProvider).markConversationRead(
            _args.conversationId,
            messageId: messageId,
          );
      _ref.invalidate(chatConversationsProvider);
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

  void _handleReadUpdate(ChatConversationReadEventModel event) {
    if (event.conversationId != _args.conversationId) {
      return;
    }

    final conversation = state.conversation;
    if (conversation == null) {
      return;
    }

    state = state.copyWith(
      conversation: conversation.copyWith(
        lastReadMessageId: event.messageId,
        lastReadAt: event.readAt,
      ),
    );
    _ref.invalidate(chatConversationsProvider);
  }

  @override
  void dispose() {
    ChatSocketService.instance.leaveConversation(_args.conversationId);
    _messageSubscription?.cancel();
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
