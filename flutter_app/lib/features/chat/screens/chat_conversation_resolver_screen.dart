import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';

enum ChatConversationResolverMode {
  direct,
  event,
}

class ChatConversationResolverScreen extends ConsumerStatefulWidget {
  const ChatConversationResolverScreen({
    super.key,
    required this.mode,
    required this.targetId,
  });

  final ChatConversationResolverMode mode;
  final int targetId;

  @override
  ConsumerState<ChatConversationResolverScreen> createState() =>
      _ChatConversationResolverScreenState();
}

class _ChatConversationResolverScreenState
    extends ConsumerState<ChatConversationResolverScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveConversation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.mode) {
      ChatConversationResolverMode.direct => 'Abriendo chat',
      ChatConversationResolverMode.event => 'Abriendo chat del evento',
    };

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.danger,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error ?? 'No se pudo abrir la conversacion.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _resolveConversation,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _resolveConversation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final actions = ref.read(chatActionsProvider);
      final ChatConversationModel conversation;

      switch (widget.mode) {
        case ChatConversationResolverMode.direct:
          conversation =
              await actions.createDirectConversation(widget.targetId);
          break;
        case ChatConversationResolverMode.event:
          conversation = await actions.openEventConversation(widget.targetId);
          break;
      }

      if (!mounted) {
        return;
      }

      context.replace('/players/chat/${conversation.id}', extra: conversation);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }
}
