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
          if (conversation?.kind == 'event' &&
              conversation!.participants.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _MatchParticipantsCard(
                participants: conversation.participants,
              ),
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
                    ? _EmptyThreadState(
                        onSuggestionSelected: (text) {
                          _composerController.text = text;
                          _composerController.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: text.length),
                          );
                        },
                      )
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

class _MatchParticipantsCard extends StatelessWidget {
  const _MatchParticipantsCard({required this.participants});

  final List<ChatParticipantModel> participants;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final participant in participants)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                participant.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyThreadState extends StatelessWidget {
  const _EmptyThreadState({
    required this.onSuggestionSelected,
  });

  final ValueChanged<String> onSuggestionSelected;

  static const _suggestions = [
    '¿Cuándo te viene bien jugar?',
    '¿Te apuntas a un partido esta semana?',
    '¿Post pádel después del partido?',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              color: AppColors.muted,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Todavía no hay mensajes.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Empieza la conversación y rompe el hielo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final suggestion in _suggestions)
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: () => onSuggestionSelected(suggestion),
                    backgroundColor: AppColors.surface2,
                    side: const BorderSide(color: AppColors.border),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
