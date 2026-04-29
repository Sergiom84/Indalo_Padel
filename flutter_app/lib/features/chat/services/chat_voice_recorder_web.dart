// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'chat_voice_recording.dart';

class ChatVoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  DateTime? _startedAt;

  Future<bool> hasPermission() {
    return _recorder.hasPermission();
  }

  Future<void> start() async {
    _startedAt = DateTime.now();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.opus,
        bitRate: 32000,
        sampleRate: 22050,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: 'chat-voice.webm',
    );
  }

  Future<ChatVoiceRecording?> stop() async {
    final objectUrl = await _recorder.stop();
    if (objectUrl == null || objectUrl.isEmpty) {
      return null;
    }

    final startedAt = _startedAt;
    final durationSeconds = startedAt == null
        ? 1
        : max(1, DateTime.now().difference(startedAt).inSeconds);

    final response = await html.HttpRequest.request(
      objectUrl,
      responseType: 'arraybuffer',
    );
    html.Url.revokeObjectUrl(objectUrl);

    final bytes = Uint8List.view(response.response as ByteBuffer);
    _startedAt = null;

    return ChatVoiceRecording(
      dataUrl: 'data:audio/webm;base64,${base64Encode(bytes)}',
      durationSeconds: durationSeconds.clamp(1, chatVoiceMaxSeconds).toInt(),
    );
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    _startedAt = null;
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
