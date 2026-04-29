import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../services/chat_image_picker.dart';
import '../services/chat_voice_recorder.dart';
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
  final ScrollController _scrollController = ScrollController();
  final ChatVoiceRecorder _voiceRecorder = ChatVoiceRecorder();
  final Set<int> _selectedMessageIds = <int>{};
  Timer? _dateBannerTimer;
  Timer? _recordingTimer;
  bool _selectionMode = false;
  bool _showDateBanner = false;
  bool _recordingVoice = false;
  bool _voiceBusy = false;
  int _recordingSeconds = 0;
  String? _dateBannerLabel;

  @override
  void dispose() {
    _dateBannerTimer?.cancel();
    _recordingTimer?.cancel();
    if (_recordingVoice) {
      unawaited(_voiceRecorder.cancel());
    }
    unawaited(_voiceRecorder.dispose());
    _scrollController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  String? _dateLabel(DateTime? dateTime) {
    if (dateTime == null) {
      return null;
    }
    final local = dateTime.toLocal();
    return DateFormat('d MMMM yyyy', 'es_ES').format(local);
  }

  bool _shouldShowDateSeparator(
    List<ChatMessageModel> messages,
    int index,
  ) {
    final current = messages[index].createdAt;
    if (current == null) {
      return false;
    }
    if (index == 0) {
      return true;
    }

    final previous = messages[index - 1].createdAt;
    if (previous == null) {
      return true;
    }

    final currentLocal = current.toLocal();
    final previousLocal = previous.toLocal();
    return currentLocal.year != previousLocal.year ||
        currentLocal.month != previousLocal.month ||
        currentLocal.day != previousLocal.day;
  }

  String? _dateLabelForScroll(
    List<ChatMessageModel> messages,
    ScrollMetrics metrics,
  ) {
    if (messages.isEmpty) {
      return null;
    }

    final maxScroll = metrics.maxScrollExtent;
    final ratio =
        maxScroll <= 0 ? 1.0 : (metrics.pixels / maxScroll).clamp(0.0, 1.0);
    final index = (ratio * (messages.length - 1)).round();
    return _dateLabel(messages[index].createdAt);
  }

  bool _handleMessageScroll(
    ScrollNotification notification,
    List<ChatMessageModel> messages,
  ) {
    if (notification is! ScrollUpdateNotification &&
        notification is! OverscrollNotification &&
        notification is! UserScrollNotification) {
      return false;
    }

    final label = _dateLabelForScroll(messages, notification.metrics);
    if (label == null || !mounted) {
      return false;
    }

    setState(() {
      _dateBannerLabel = label;
      _showDateBanner = true;
    });

    _dateBannerTimer?.cancel();
    _dateBannerTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) {
        return;
      }
      setState(() => _showDateBanner = false);
    });

    return false;
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedMessageIds.clear();
    });
  }

  void _toggleMessageSelection(ChatMessageModel message) {
    if (!message.isMine) {
      return;
    }

    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id);
      }
    });
  }

  Future<void> _confirmDeleteSelected(ChatThreadController controller) async {
    if (_selectedMessageIds.isEmpty) {
      return;
    }

    final count = _selectedMessageIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Eliminar mensajes',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          count == 1
              ? 'Se eliminará este mensaje del chat para todos.'
              : 'Se eliminarán estos $count mensajes del chat para todos.',
          style: const TextStyle(color: AppColors.light),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final messageIds = _selectedMessageIds.toList(growable: false);
    await controller.deleteMessages(messageIds);
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedMessageIds.clear();
      _selectionMode = false;
    });
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showImageSourceSheet(ChatThreadController controller) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Galeria',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Camara',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    try {
      final dataUrl = await pickChatImageAsDataUrl(source);
      if (dataUrl == null) {
        return;
      }
      final caption = _composerController.text.trim();
      await controller.sendImage(dataUrl: dataUrl, caption: caption);
      if (!mounted) {
        return;
      }
      if (caption.isNotEmpty) {
        _composerController.clear();
      }
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _toggleVoiceRecording(ChatThreadController controller) async {
    if (_recordingVoice) {
      await _stopVoiceRecording(controller);
      return;
    }

    await _startVoiceRecording(controller);
  }

  Future<void> _startVoiceRecording(ChatThreadController controller) async {
    if (_voiceBusy) {
      return;
    }

    _voiceBusy = true;
    try {
      final allowed = await _voiceRecorder.hasPermission();
      if (!allowed) {
        _showSnack('Activa el permiso de microfono para enviar notas de voz.');
        return;
      }

      await _voiceRecorder.start();
      if (!mounted) {
        return;
      }

      setState(() {
        _recordingVoice = true;
        _recordingSeconds = 0;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_recordingVoice) {
          timer.cancel();
          return;
        }

        if (_recordingSeconds + 1 >= chatVoiceMaxSeconds) {
          setState(() => _recordingSeconds = chatVoiceMaxSeconds);
          timer.cancel();
          unawaited(_stopVoiceRecording(controller));
          return;
        }

        setState(() => _recordingSeconds += 1);
      });
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      _voiceBusy = false;
    }
  }

  Future<void> _stopVoiceRecording(ChatThreadController controller) async {
    if (_voiceBusy) {
      return;
    }

    _voiceBusy = true;
    _recordingTimer?.cancel();
    try {
      final recording = await _voiceRecorder.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _recordingVoice = false;
        _recordingSeconds = 0;
      });

      if (recording == null) {
        _showSnack('No se pudo crear la nota de voz.');
        return;
      }

      await controller.sendVoice(
        dataUrl: recording.dataUrl,
        durationSeconds: recording.durationSeconds,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _recordingVoice = false;
          _recordingSeconds = 0;
        });
      }
      _showSnack(error.toString());
    } finally {
      _voiceBusy = false;
    }
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
        title: _selectionMode
            ? Text(
                _selectedMessageIds.isEmpty
                    ? 'Selecciona mensajes'
                    : '${_selectedMessageIds.length} seleccionados',
              )
            : Column(
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
        actions: [
          if (_selectionMode)
            IconButton(
              tooltip: 'Eliminar seleccionados',
              icon: state.deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              onPressed: _selectedMessageIds.isEmpty || state.deleting
                  ? null
                  : () => _confirmDeleteSelected(controller),
            ),
          IconButton(
            tooltip: _selectionMode ? 'Cancelar selección' : 'Editar mensajes',
            icon: Icon(_selectionMode ? Icons.close : Icons.edit_outlined),
            onPressed: state.deleting ? null : _toggleSelectionMode,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectionMode) const _DeleteModeHint(),
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
          if (state.error != null && state.messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
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
                    : Stack(
                        children: [
                          RefreshIndicator(
                            color: AppColors.primary,
                            backgroundColor: AppColors.surface,
                            onRefresh: controller.refresh,
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) =>
                                  _handleMessageScroll(
                                notification,
                                state.messages,
                              ),
                              child: ListView.builder(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                itemCount: state.messages.length,
                                itemBuilder: (context, index) {
                                  final message = state.messages[index];
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (_shouldShowDateSeparator(
                                        state.messages,
                                        index,
                                      ))
                                        _ThreadDateChip(
                                          label: _dateLabel(
                                                message.createdAt,
                                              ) ??
                                              '',
                                        ),
                                      ChatMessageBubble(
                                        message: message,
                                        selectionMode: _selectionMode,
                                        selected: _selectedMessageIds
                                            .contains(message.id),
                                        onTap: message.isMine
                                            ? () => _toggleMessageSelection(
                                                  message,
                                                )
                                            : null,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          if (_dateBannerLabel != null)
                            Positioned(
                              top: 8,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: _showDateBanner ? 1 : 0,
                                  duration: const Duration(milliseconds: 180),
                                  child: Center(
                                    child: _FloatingDateBanner(
                                      label: _dateBannerLabel!,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
          if (!_selectionMode)
            ChatComposer(
              controller: _composerController,
              sending: state.sending,
              recording: _recordingVoice,
              recordingSeconds: _recordingSeconds,
              onAttachPressed: () => _showImageSourceSheet(controller),
              onVoicePressed: () => _toggleVoiceRecording(controller),
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

class _ThreadDateChip extends StatelessWidget {
  const _ThreadDateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingDateBanner extends StatelessWidget {
  const _FloatingDateBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DeleteModeHint extends StatelessWidget {
  const _DeleteModeHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface2,
      child: const Text(
        'Toca tus mensajes para seleccionarlos y eliminarlos.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
