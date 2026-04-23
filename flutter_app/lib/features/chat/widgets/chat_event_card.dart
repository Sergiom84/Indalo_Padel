import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/chat_models.dart';

class ChatEventCard extends StatelessWidget {
  const ChatEventCard({
    super.key,
    required this.event,
  });

  final ChatEventModel event;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('EEE d MMM · HH:mm', 'es_ES');
    final scheduleLabel = event.scheduledAt == null
        ? 'Fecha pendiente'
        : formatter.format(event.scheduledAt!.toLocal());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            scheduleLabel,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
          if (event.venueName != null) ...[
            const SizedBox(height: 4),
            Text(
              event.venueName!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              event.description!,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
