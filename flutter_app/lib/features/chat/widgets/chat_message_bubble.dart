import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/chat_models.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    this.selectionMode = false,
    this.selected = false,
    this.onTap,
  });

  final ChatMessageModel message;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final bubbleColor = mine ? AppColors.primary : AppColors.surface2;
    final textColor = mine ? AppColors.dark : Colors.white;
    final timeLabel = message.createdAt == null
        ? ''
        : DateFormat('HH:mm', 'es_ES').format(message.createdAt!.toLocal());

    final bubble = Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine) ...[
              Text(
                message.senderName,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message.body,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (timeLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                timeLabel,
                style: TextStyle(
                  color: mine
                      ? AppColors.dark.withValues(alpha: 0.75)
                      : AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!selectionMode) {
      return bubble;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (mine) ...[
            Checkbox(
              value: selected,
              onChanged: onTap == null ? null : (_) => onTap!(),
              activeColor: AppColors.primary,
              checkColor: AppColors.dark,
              side: const BorderSide(color: AppColors.muted),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
