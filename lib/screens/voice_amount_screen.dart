import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/accessibility_provider.dart';
import '../widgets/accessible_layout.dart';

class VoiceAmountScreen extends ConsumerStatefulWidget {
  const VoiceAmountScreen({super.key});

  @override
  ConsumerState<VoiceAmountScreen> createState() => _VoiceAmountScreenState();
}

class _VoiceAmountScreenState extends ConsumerState<VoiceAmountScreen> {
  final SpeechToText _stt = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _stt.initialize(
      onError: (error) {
        debugPrint("STT Error: $error");
      },
      onStatus: (status) {
        debugPrint("STT Status: $status");

        // Restart listening automatically if stopped
        if (status == "done" || status == "notListening") {
          _restartListening();
        }
      },
    );

    if (_speechEnabled) {
      _speak("Listening for amount. Please say the amount in rupees.");
      _startListening();
    } else {
      _speak("Microphone not available. Please allow microphone access.");
    }
  }

  void _startListening() async {
    if (!_speechEnabled) return;

    await _stt.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      localeId: "en_IN",
    );

    setState(() {
      _isListening = true;
    });
  }

  void _restartListening() {
    if (!_isListening) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _startListening();
      });
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });

    if (result.finalResult) {
      _processAmount(_lastWords);
    }
  }

  void _processAmount(String input) {
    input = input.toLowerCase();

    // Extract number from speech
    final regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(input);

    if (match != null) {
      final amount = match.group(0)!;

      ref.read(amountProvider.notifier).state = amount;

      _speak(
          "You said $amount rupees. Swipe right to confirm or double tap to change amount.");
    } else {
      _speak("I didn't understand. Please say the amount clearly like 100 or 500.");
      _restartListening();
    }
  }

  void _speak(String text) {
    ref.read(accessibilityProvider.notifier).speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final amount = ref.watch(amountProvider);

    return AccessibleLayout(
      onActivateSpeak:
          "Enter amount using voice. Current amount is $amount rupees.",
      onSwipeRight: () {
        if (amount != "0") {
          Navigator.pushNamed(context, '/pin');
        } else {
          _speak("Please enter a valid amount first.");
        }
      },
      onSwipeLeft: () => Navigator.pop(context),
      onDoubleTap: _startListening,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AMOUNT DISPLAY
            Text(
              "₹$amount",
              style: GoogleFonts.inter(
                fontSize: 110,
                fontWeight: FontWeight.w900,
                color: Colors.yellow,
              ),
            ),

            const SizedBox(height: 40),

            // MIC ICON
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                size: 90,
                color: _isListening ? Colors.green : Colors.grey,
              ),
            ),

            const SizedBox(height: 20),

            // LIVE SPEECH TEXT
            Text(
              _lastWords.isEmpty ? "LISTENING..." : _lastWords.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 22,
                color: Colors.white.withOpacity(0.6),
                letterSpacing: 1.5,
              ),
            ),

            const SizedBox(height: 40),

            // FALLBACK BUTTON (for web/testing)
            ElevatedButton(
              onPressed: () => _processAmount("100"),
              child: const Text("Simulate 100 Rupees"),
            ),
          ],
        ),
      ),
    );
  }
}