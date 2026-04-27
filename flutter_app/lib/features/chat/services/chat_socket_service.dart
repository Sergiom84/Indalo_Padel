import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/chat_models.dart';

class ChatSocketService {
  ChatSocketService._();

  static final ChatSocketService instance = ChatSocketService._();

  io.Socket? _socket;
  String? _activeToken;
  final Set<int> _joinedConversationIds = <int>{};

  StreamController<ChatConversationCreatedEventModel>?
      _conversationCreatedController;
  StreamController<ChatMessageCreatedEventModel>? _messageCreatedController;
  StreamController<ChatMessagesDeletedEventModel>? _messagesDeletedController;
  StreamController<ChatConversationReadEventModel>? _conversationReadController;

  Stream<ChatConversationCreatedEventModel> get conversationCreatedEvents {
    _conversationCreatedController ??=
        StreamController<ChatConversationCreatedEventModel>.broadcast();
    return _conversationCreatedController!.stream;
  }

  Stream<ChatMessageCreatedEventModel> get messageCreatedEvents {
    _messageCreatedController ??=
        StreamController<ChatMessageCreatedEventModel>.broadcast();
    return _messageCreatedController!.stream;
  }

  Stream<ChatMessagesDeletedEventModel> get messagesDeletedEvents {
    _messagesDeletedController ??=
        StreamController<ChatMessagesDeletedEventModel>.broadcast();
    return _messagesDeletedController!.stream;
  }

  Stream<ChatConversationReadEventModel> get conversationReadEvents {
    _conversationReadController ??=
        StreamController<ChatConversationReadEventModel>.broadcast();
    return _conversationReadController!.stream;
  }

  Future<void> connect() async {
    final token = await SecureStorage.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final socketBaseUrl = _resolveSocketBaseUrl();
    if (socketBaseUrl == null) {
      return;
    }

    _conversationCreatedController ??=
        StreamController<ChatConversationCreatedEventModel>.broadcast();
    _messageCreatedController ??=
        StreamController<ChatMessageCreatedEventModel>.broadcast();
    _messagesDeletedController ??=
        StreamController<ChatMessagesDeletedEventModel>.broadcast();
    _conversationReadController ??=
        StreamController<ChatConversationReadEventModel>.broadcast();

    if (_socket != null && _activeToken == token) {
      if (_socket!.disconnected) {
        _socket!.connect();
      }
      return;
    }

    _disposeSocket();
    _activeToken = token;

    final socket = io.io(
      socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    socket
      ..onConnect((_) => _rejoinActiveConversations())
      ..on('chat:ready', (_) => _rejoinActiveConversations())
      ..on('chat:conversation.created', _handleConversationCreated)
      ..on('chat:message.created', _handleMessageCreated)
      ..on('chat:messages.deleted', _handleMessagesDeleted)
      ..on('chat:conversation.read', _handleConversationRead)
      ..on('connect_error', (_) {})
      ..connect();

    _socket = socket;
  }

  void joinConversation(int conversationId) {
    if (conversationId <= 0) {
      return;
    }

    _joinedConversationIds.add(conversationId);
    if (_socket?.connected == true) {
      _socket!.emit('chat:join', {'conversation_id': conversationId});
    }
  }

  void leaveConversation(int conversationId) {
    if (conversationId <= 0) {
      return;
    }

    _joinedConversationIds.remove(conversationId);
    if (_socket?.connected == true) {
      _socket!.emit('chat:leave', {'conversation_id': conversationId});
    }
  }

  void _rejoinActiveConversations() {
    for (final conversationId in _joinedConversationIds) {
      _socket?.emit('chat:join', {'conversation_id': conversationId});
    }
  }

  void _handleConversationCreated(dynamic payload) {
    final json = _asJsonMap(payload);
    if (json == null) {
      return;
    }

    _conversationCreatedController?.add(
      ChatConversationCreatedEventModel.fromJson(json),
    );
  }

  void _handleMessageCreated(dynamic payload) {
    final json = _asJsonMap(payload);
    if (json == null) {
      return;
    }

    _messageCreatedController?.add(ChatMessageCreatedEventModel.fromJson(json));
  }

  void _handleMessagesDeleted(dynamic payload) {
    final json = _asJsonMap(payload);
    if (json == null) {
      return;
    }

    _messagesDeletedController?.add(
      ChatMessagesDeletedEventModel.fromJson(json),
    );
  }

  void _handleConversationRead(dynamic payload) {
    final json = _asJsonMap(payload);
    if (json == null) {
      return;
    }

    _conversationReadController?.add(
      ChatConversationReadEventModel.fromJson(json),
    );
  }

  Map<String, dynamic>? _asJsonMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }

    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }

    return null;
  }

  void _disposeSocket() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    _disposeSocket();
    _joinedConversationIds.clear();
    _activeToken = null;
  }

  String? _resolveSocketBaseUrl() {
    final apiBase = resolveBaseUrl();
    if (apiBase == null || apiBase.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(apiBase);
    if (uri == null) {
      return null;
    }

    return uri.replace(path: '', query: null, fragment: null).toString();
  }
}
