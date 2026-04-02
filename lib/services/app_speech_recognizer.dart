import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef SpeechTextCallback = void Function(String text, bool isFinal);
typedef SpeechStatusCallback = void Function(String status);
typedef SpeechErrorCallback = void Function(Object error);

class AppSpeechRecognizer {
  AppSpeechRecognizer();

  final SpeechToText _recognizer = SpeechToText();

  bool _speechEnabled = false;
  bool _isListening = false;
  SpeechStatusCallback? _statusCallback;
  SpeechErrorCallback? _errorCallback;

  bool get isListening => _isListening;

  Future<bool> initialize({
    SpeechStatusCallback? onStatus,
    SpeechErrorCallback? onError,
  }) async {
    _statusCallback = onStatus;
    _errorCallback = onError;

    try {
      _speechEnabled = await _recognizer.initialize(
        onError: (error) => _errorCallback?.call(error),
        onStatus: (status) => _statusCallback?.call(status),
      );
    } catch (error) {
      _speechEnabled = false;
      _errorCallback?.call(error);
    }

    return _speechEnabled;
  }

  Future<void> listen({
    required SpeechTextCallback onResult,
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 3),
    String localeId = 'en_IN',
    bool partialResults = true,
    bool cancelOnError = false,
    ListenMode listenMode = ListenMode.confirmation,
  }) async {
    if (!_speechEnabled) return;

    await stop();

    await _recognizer.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenFor: listenFor,
      pauseFor: pauseFor,
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        partialResults: partialResults,
        cancelOnError: cancelOnError,
        listenMode: listenMode,
      ),
    );
    _isListening = true;
  }

  Future<void> stop() async {
    _isListening = false;
    await _recognizer.stop();
    _statusCallback?.call('notListening');
  }

  Future<void> dispose() async {
    await stop();
  }
}
