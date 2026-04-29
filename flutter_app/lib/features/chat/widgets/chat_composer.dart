import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttachPressed,
    required this.onVoicePressed,
    this.focusNode,
    this.sending = false,
    this.recording = false,
    this.recordingSeconds = 0,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttachPressed;
  final VoidCallback onVoicePressed;
  final FocusNode? focusNode;
  final bool sending;
  final bool recording;
  final int recordingSeconds;

  @override
  Widget build(BuildContext context) {
    final recordingLabel =
        'Grabando ${recordingSeconds.toString().padLeft(2, '0')}s';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              height: 48,
              child: IconButton(
                tooltip: 'Adjuntar foto',
                onPressed: sending || recording ? null : onAttachPressed,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: recording
                  ? Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.danger),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fiber_manual_record,
                            color: AppColors.danger,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            recordingLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje',
                        hintStyle: const TextStyle(color: AppColors.muted),
                        filled: true,
                        fillColor: AppColors.surface2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 48,
              child: IconButton(
                tooltip:
                    recording ? 'Enviar nota de voz' : 'Grabar nota de voz',
                onPressed: sending ? null : onVoicePressed,
                icon: Icon(recording ? Icons.stop_circle : Icons.mic_none),
                color: recording ? AppColors.danger : AppColors.primary,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: FilledButton(
                onPressed: sending || recording ? null : onSend,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.dark,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.dark,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
