import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../models/chat_models.dart';
import '../services/chat_voice_recorder.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    this.selectionMode = false,
    this.selected = false,
    this.readByOthers = false,
    this.onTap,
  });

  final ChatMessageModel message;
  final bool selectionMode;
  final bool selected;
  final bool readByOthers;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final bubbleColor = mine ? AppColors.primary : AppColors.surface2;
    final textColor = mine ? AppColors.dark : Colors.white;
    const maxBubbleWidth = 320.0;
    final timeLabel = message.createdAt == null
        ? ''
        : DateFormat('HH:mm', 'es_ES').format(message.createdAt!.toLocal());
    final metaColor =
        mine ? AppColors.dark.withValues(alpha: 0.75) : AppColors.muted;
    final hasMeta = timeLabel.isNotEmpty || (mine && readByOthers);

    final bubbleContent = message.isImage
        ? _ImageMessageBubbleContent(
            message: message,
            mine: mine,
            selected: selected,
            textColor: textColor,
            bubbleColor: bubbleColor,
            timeLabel: timeLabel,
            readByOthers: readByOthers,
            maxWidth: maxBubbleWidth,
          )
        : AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(maxWidth: maxBubbleWidth),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(8),
              border:
                  selected ? Border.all(color: Colors.white, width: 2) : null,
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
                if (message.isVoice)
                  _ChatVoiceAttachment(message: message, mine: mine)
                else
                  Text(
                    message.body,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (message.isVoice && message.attachment?.url == null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Archivo no disponible',
                    style: TextStyle(
                      color: mine
                          ? AppColors.dark.withValues(alpha: 0.75)
                          : AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (hasMeta) ...[
                  const SizedBox(height: 6),
                  _MessageMeta(
                    timeLabel: timeLabel,
                    mine: mine,
                    readByOthers: readByOthers,
                    color: metaColor,
                  ),
                ],
              ],
            ),
          );

    final bubble = Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: mine
          ? bubbleContent
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: UserAvatar(
                    displayName: message.senderName,
                    avatarUrl: message.sender.avatarUrl,
                    size: 30,
                    fontSize: 12,
                    backgroundColor: AppColors.surface,
                    borderColor: AppColors.border,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(child: bubbleContent),
              ],
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

class _ImageMessageBubbleContent extends StatelessWidget {
  const _ImageMessageBubbleContent({
    required this.message,
    required this.mine,
    required this.selected,
    required this.textColor,
    required this.bubbleColor,
    required this.timeLabel,
    required this.readByOthers,
    required this.maxWidth,
  });

  final ChatMessageModel message;
  final bool mine;
  final bool selected;
  final Color textColor;
  final Color bubbleColor;
  final String timeLabel;
  final bool readByOthers;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final caption = message.body.trim();
    final url = message.attachment?.url;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      constraints: BoxConstraints(maxWidth: maxWidth),
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      decoration: selected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: Text(
                message.senderName,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          _ChatImageAttachment(
            message: message,
            meta: _ImageMetaPill(
              timeLabel: timeLabel,
              mine: mine,
              readByOthers: readByOthers,
            ),
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                caption,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (url == null || url.isEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Archivo no disponible',
                style: TextStyle(
                  color: mine
                      ? AppColors.dark.withValues(alpha: 0.75)
                      : AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatImageAttachment extends StatelessWidget {
  const _ChatImageAttachment({
    required this.message,
    required this.meta,
  });

  final ChatMessageModel message;
  final Widget meta;

  @override
  Widget build(BuildContext context) {
    final attachment = message.attachment;
    final url = attachment?.url;
    if (url == null || url.isEmpty) {
      return const SizedBox.shrink();
    }

    final width = (attachment?.width ?? 1).toDouble();
    final height = (attachment?.height ?? 1).toDouble();
    final aspectRatio = width > 0 && height > 0 ? width / height : 1.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: aspectRatio.clamp(0.6, 1.8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return const ColoredBox(
                  color: AppColors.surface,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(
                  color: AppColors.surface,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.muted,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: meta,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageMetaPill extends StatelessWidget {
  const _ImageMetaPill({
    required this.timeLabel,
    required this.mine,
    required this.readByOthers,
  });

  final String timeLabel;
  final bool mine;
  final bool readByOthers;

  @override
  Widget build(BuildContext context) {
    if (timeLabel.isEmpty && !(mine && readByOthers)) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: _MessageMeta(
          timeLabel: timeLabel,
          mine: mine,
          readByOthers: readByOthers,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({
    required this.timeLabel,
    required this.mine,
    required this.readByOthers,
    required this.color,
  });

  final String timeLabel;
  final bool mine;
  final bool readByOthers;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (timeLabel.isNotEmpty)
          Text(
            timeLabel,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (mine && readByOthers) ...[
          if (timeLabel.isNotEmpty) const SizedBox(width: 4),
          const Icon(
            Icons.done_all_rounded,
            size: 14,
            color: AppColors.info,
          ),
        ],
      ],
    );
  }
}

class _ChatVoiceAttachment extends StatefulWidget {
  const _ChatVoiceAttachment({
    required this.message,
    required this.mine,
  });

  final ChatMessageModel message;
  final bool mine;

  @override
  State<_ChatVoiceAttachment> createState() => _ChatVoiceAttachmentState();
}

class _ChatVoiceAttachmentState extends State<_ChatVoiceAttachment> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  PlayerState _state = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    final fallbackDuration =
        widget.message.attachment?.durationSeconds ?? chatVoiceMaxSeconds;
    _duration = Duration(seconds: fallbackDuration);

    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() => _state = state);
    });
    _durationSubscription = _player.onDurationChanged.listen((duration) {
      if (!mounted) {
        return;
      }
      setState(() => _duration = duration);
    });
    _positionSubscription = _player.onPositionChanged.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() => _position = position);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = PlayerState.completed;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(_positionSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    final url = widget.message.attachment?.url;
    if (url == null || url.isEmpty) {
      return;
    }

    if (_state == PlayerState.playing) {
      await _player.pause();
      return;
    }

    await _player.play(
      UrlSource(
        url,
        mimeType: widget.message.attachment?.mimeType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.mine;
    final fgColor = mine ? AppColors.dark : Colors.white;
    final mutedColor =
        mine ? AppColors.dark.withValues(alpha: 0.72) : AppColors.muted;
    final duration = _duration.inMilliseconds <= 0
        ? Duration(seconds: widget.message.attachment?.durationSeconds ?? 0)
        : _duration;
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : (_position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return SizedBox(
      width: 230,
      child: Row(
        children: [
          IconButton.filled(
            tooltip: _state == PlayerState.playing ? 'Pausar' : 'Reproducir',
            onPressed: widget.message.attachment?.url == null ? null : _toggle,
            style: IconButton.styleFrom(
              backgroundColor: mine
                  ? AppColors.dark.withValues(alpha: 0.12)
                  : AppColors.surface,
              foregroundColor: fgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(
              _state == PlayerState.playing
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: mutedColor.withValues(alpha: 0.22),
                    color: fgColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 99);
  return '0:${seconds.toString().padLeft(2, '0')}';
}
