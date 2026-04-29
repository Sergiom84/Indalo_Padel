const int chatVoiceMaxSeconds = 60;

class ChatVoiceRecording {
  final String dataUrl;
  final int durationSeconds;

  const ChatVoiceRecording({
    required this.dataUrl,
    required this.durationSeconds,
  });
}
