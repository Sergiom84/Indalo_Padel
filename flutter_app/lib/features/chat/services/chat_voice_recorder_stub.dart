import 'chat_voice_recording.dart';

class ChatVoiceRecorder {
  Future<bool> hasPermission() async => false;

  Future<void> start() {
    throw UnsupportedError(
      'Las notas de voz no estan disponibles en esta plataforma.',
    );
  }

  Future<ChatVoiceRecording?> stop() async => null;

  Future<void> cancel() async {}

  Future<void> dispose() async {}
}
