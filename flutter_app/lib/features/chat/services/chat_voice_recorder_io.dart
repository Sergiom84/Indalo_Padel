import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'chat_voice_recording.dart';

class ChatVoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  DateTime? _startedAt;
  String? _path;

  Future<bool> hasPermission() {
    return _recorder.hasPermission();
  }

  Future<void> start() async {
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}${Platform.pathSeparator}chat-voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    _path = path;
    _startedAt = DateTime.now();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 22050,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: path,
    );
  }

  Future<ChatVoiceRecording?> stop() async {
    final stoppedPath = await _recorder.stop();
    final path = stoppedPath ?? _path;
    if (path == null) {
      return null;
    }

    final startedAt = _startedAt;
    final durationSeconds = startedAt == null
        ? 1
        : max(1, DateTime.now().difference(startedAt).inSeconds);
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    await file.delete().catchError((_) => file);
    _path = null;
    _startedAt = null;

    return ChatVoiceRecording(
      dataUrl: 'data:audio/mp4;base64,${base64Encode(bytes)}',
      durationSeconds: durationSeconds.clamp(1, chatVoiceMaxSeconds).toInt(),
    );
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    final path = _path;
    if (path != null) {
      await File(path).delete().catchError((_) => File(path));
    }
    _path = null;
    _startedAt = null;
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
