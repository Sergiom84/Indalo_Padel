import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_event_card.dart';
import '../widgets/chat_message_bubble.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    this.initialConversation,
  });

  final int conversationId;
  final ChatConversationModel? initialConversation;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final TextEditingController _composerController = TextEditingController();

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ChatThreadArgs(
      conversationId: widget.conversationId,
      initialConversation: widget.initialConversation,
    );
    final state = ref.watch(chatThreadProvider(args));
    final controller = ref.read(chatThreadProvider(args).notifier);
    final conversation = state.conversation ?? widget.initialConversation;

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conversation?.title ?? 'Chat',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (conversation != null)
              Text(
                conversation.isEvent
                    ? 'Evento local'
                    : conversation.isGroup
                        ? '${conversation.memberCount} participantes'
                        : 'Chat privado',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (conversation?.event != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: ChatEventCard(event: conversation!.event!),
            ),
          if (state.error != null && state.messages.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                state.error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: state.loading && state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? const _EmptyThreadState()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        onRefresh: controller.refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          itemCount: state.messages.length,
                          itemBuilder: (context, index) {
                            return ChatMessageBubble(
                              message: state.messages[index],
                            );
                          },
                        ),
                      ),
          ),
          ChatComposer(
            controller: _composerController,
            sending: state.sending,
            onSend: () async {
              final body = _composerController.text;
              await controller.sendMessage(body);
              if (!mounted) {
                return;
              }
              _composerController.clear();
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyThreadState extends StatelessWidget {
  const _EmptyThreadState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              color: AppColors.muted,
              size: 42,
            ),
            SizedBox(height: 12),
            Text(
              'Todavía no hay mensajes.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Empieza la conversación y rompe el hielo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
