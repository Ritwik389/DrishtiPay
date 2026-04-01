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
  bool _isFinal = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _stt.initialize(
        onError: (error) => debugPrint("STT Error: $error"),
        onStatus: (status) => debugPrint("STT Status: $status"),
      );
    } catch (e) {
      debugPrint("STT Init Exception: $e");
      _speechEnabled = false;
    }

    if (_speechEnabled) {
      _startListening();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(accessibilityProvider.notifier).speak("Microphone not available. Please use the simulated button or check permissions.");
      });
    }
  }

  void _startListening() async {
    await _stt.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 10),
      localeId: "en_IN",
    );
    setState(() {
      _isFinal = false;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      _isFinal = result.finalResult;
    });

    if (_isFinal) {
      _processAmount(_lastWords);
    }
  }

  void _processAmount(String input) {
    // Basic regex to find numbers in speech
    final regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(input);
    if (match != null) {
      final amount = match.group(0)!;
      ref.read(amountProvider.notifier).state = amount;
      ref.read(accessibilityProvider.notifier).speak(
          "You entered $amount rupees. Swipe right to confirm and enter PIN.");
    } else {
      ref.read(accessibilityProvider.notifier).speak("I didn't catch that. Please speak the amount again.");
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = ref.watch(amountProvider);

    return AccessibleLayout(
      onActivateSpeak: "Enter amount using voice. Currently set to $amount rupees. Swipe right to confirm.",
      onSwipeRight: () {
        if (amount != "0") {
          Navigator.pushNamed(context, '/pin');
        }
      },
      onSwipeLeft: () => Navigator.pop(context),
      onDoubleTap: _startListening,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "₹$amount",
              style: GoogleFonts.inter(
                fontSize: 120,
                fontWeight: FontWeight.w900,
                color: Colors.yellow,
              ),
            ),
            const SizedBox(height: 40),
            if (_stt.isListening)
              const Icon(Icons.mic, size: 80, color: Colors.white)
            else
              IconButton(
                onPressed: _startListening,
                icon: const Icon(Icons.mic_none, size: 80, color: Colors.grey),
              ),
            const SizedBox(height: 20),
            Text(
              _lastWords.isEmpty ? "LISTENING..." : _lastWords.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 24,
                color: Colors.white.withOpacity(0.5),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 40),
            // Mock Trigger for Web
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
