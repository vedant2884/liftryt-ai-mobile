import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper around `speech_to_text` for the Coach page's mic button —
/// speak-to-type only, mirroring the web app's Web Speech API integration
/// in `CoachInput.tsx` (no text-to-speech; the coach's replies are still
/// read on screen, not spoken aloud).
class SpeechInputService {
  SpeechInputService._();

  static final SpeechToText _speech = SpeechToText();
  static bool? _available;

  /// Requests the mic/speech permission and checks device support, caching
  /// the result after the first call. Callers should hide the mic button if
  /// this resolves false (permission denied, or no recognizer on-device).
  static Future<bool> ensureAvailable() async {
    _available ??= await _speech.initialize();
    return _available!;
  }

  static bool get isListening => _speech.isListening;

  /// Starts listening, invoking [onResult] with the live transcript on every
  /// update (interim and final results both come through — partial results
  /// are on by default) and [onDone] once recognition stops for any reason
  /// (silence timeout, [stop], or an error).
  static Future<void> listen({
    required void Function(String transcript) onResult,
    required void Function() onDone,
  }) {
    _speech.statusListener = (status) {
      if (status == 'notListening' || status == 'done') onDone();
    };
    _speech.errorListener = (_) => onDone();
    return _speech.listen(onResult: (result) => onResult(result.recognizedWords));
  }

  static Future<void> stop() => _speech.stop();
}
