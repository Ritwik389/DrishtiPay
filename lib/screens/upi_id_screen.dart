import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../providers/accessibility_provider.dart';
import '../widgets/accessible_layout.dart';

class UpiIdScreen extends ConsumerStatefulWidget {
  const UpiIdScreen({super.key});

  @override
  ConsumerState<UpiIdScreen> createState() => _UpiIdScreenState();
}

class _UpiIdScreenState extends ConsumerState<UpiIdScreen> {
  final SpeechToText _stt = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _stt.initialize(
      onError: (error) => debugPrint('STT Error: $error'),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          _restartListening();
        }
      },
    );

    if (_speechEnabled) {
      _speak('Please say the U P I I D or phone number of the receiver. Say confirm to continue.');
      _startListening();
    } else {
      _speak('Microphone not available. Please allow microphone access.');
    }
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    await _stt.stop(); // reset session for continuous listening
    await _stt.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
      localeId: 'en_IN',
      partialResults: true,
    );
    setState(() => _isListening = true);
  }

  void _restartListening() {
    if (!_isListening) {
      Future.delayed(const Duration(milliseconds: 400), _startListening);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() => _lastWords = result.recognizedWords);

    if (result.finalResult) {
      ref.read(upiIdProvider.notifier).state = result.recognizedWords.trim();

      if (_saidConfirm(result.recognizedWords)) {
        _confirmUpi();
      } else {
        _speak('You said ${result.recognizedWords}. Say confirm to continue or repeat to change.');
      }
    }
  }

  bool _saidConfirm(String text) {
    final lower = text.toLowerCase();
    return lower.contains('confirm') || lower.contains('ok');
  }

  void _confirmUpi() {
    final upi = ref.read(upiIdProvider);
    if (upi.isEmpty) {
      _speak('I need a U P I I D or phone number before confirming.');
      return;
    }
    _speak('Confirming recipient $upi. Now say the amount.');
    _stt.stop();
    setState(() => _isListening = false);
    Navigator.pushNamed(context, '/amount');
  }

  @override
  Widget build(BuildContext context) {
    final upi = ref.watch(upiIdProvider);

    return AccessibleLayout(
      onActivateSpeak: 'Say the U P I I D or phone number, then say confirm.',
      onSwipeRight: _confirmUpi,
      onSwipeLeft: () => Navigator.pop(context),
      onDoubleTap: _startListening,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              upi.isEmpty ? 'LISTENING' : upi,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.yellow,
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              size: 80,
              color: _isListening ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _confirmUpi,
              icon: const Icon(Icons.check),
              label: const Text('Confirm'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                ref.read(upiIdProvider.notifier).state = '9999999999';
                _speak('Sample number 9999999999 set. Say confirm to proceed.');
              },
              child: const Text('Use sample number'),
            ),
          ],
        ),
      ),
    );
  }

  void _speak(String text) {
    ref.read(accessibilityProvider.notifier).speak(text);
  }

  @override
  void dispose() {
    _stt.stop();
    super.dispose();
  }
}
