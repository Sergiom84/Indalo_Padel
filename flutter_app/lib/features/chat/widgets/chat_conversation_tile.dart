import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../models/chat_models.dart';
import 'chat_event_card.dart';

class ChatConversationTile extends StatelessWidget {
  const ChatConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final ChatConversationModel conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timestamp = conversation.lastMessageAt == null
        ? ''
        : DateFormat('dd/MM · HH:mm', 'es_ES')
            .format(conversation.lastMessageAt!.toLocal());
    final accent = conversation.isEvent
        ? AppColors.info
        : conversation.isGroup
            ? AppColors.warning
            : AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  displayName: conversation.title,
                  avatarUrl: conversation.avatarUrl,
                  size: 46,
                  fontSize: 16,
                  backgroundColor: AppColors.surface2,
                  borderColor: AppColors.border,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (conversation.hasUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${conversation.unreadCount}',
                                style: const TextStyle(
                                  color: AppColors.dark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            conversation.isEvent
                                ? Icons.event_outlined
                                : conversation.isGroup
                                    ? Icons.group_outlined
                                    : Icons.forum_outlined,
                            color: accent,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              conversation.lastMessagePreview ??
                                  conversation.subtitle ??
                                  'Sin mensajes todavía',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (timestamp.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text(
                    timestamp,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            if (conversation.event != null) ...[
              const SizedBox(height: 12),
              ChatEventCard(event: conversation.event!),
            ],
          ],
        ),
      ),
    );
  }
}
