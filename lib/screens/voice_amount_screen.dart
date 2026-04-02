import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/accessibility_provider.dart';
import '../utils/voice_back.dart';
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
  bool _ttsPlaying = false;
  bool _processingUtterance = false;

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

        if (status == "done" || status == "notListening") {
          if (mounted) setState(() => _isListening = false);
          if (!_ttsPlaying && mounted) {
            Future.delayed(const Duration(milliseconds: 400), _restartListening);
          }
        } else if (status == "listening") {
          if (mounted) setState(() => _isListening = true);
        }
      },
    );

    if (_speechEnabled) {
      await _speakAndResume(
          "Listening for amount. Please say the amount in rupees. $kVoiceBackHint");
    } else {
      await ref
          .read(accessibilityProvider.notifier)
          .speakAndWait("Microphone not available. Please allow microphone access.");
    }
  }

  void _startListening() async {
    if (!_speechEnabled || _ttsPlaying) return;

    await _stt.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
      listenMode: ListenMode.dictation,
      localeId: "en_IN",
      partialResults: true,
    );

    if (mounted) {
      setState(() {
        _isListening = true;
      });
    }
  }

  void _restartListening() {
    if (!_speechEnabled || !mounted || _ttsPlaying) return;
    _startListening();
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _lastWords = result.recognizedWords;
    });

    if (result.finalResult) {
      _processAmount(_lastWords);
    }
  }

  Future<void> _processAmount(String input) async {
    if (_processingUtterance || _ttsPlaying) return;
    _processingUtterance = true;
    try {
      input = input.toLowerCase();

      if (isVoiceBackCommand(input)) {
        await _stt.stop();
        if (mounted) Navigator.pop(context);
        return;
      }

      final regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(input);

    if (match != null) {
      final amount = match.group(0)!;

      ref.read(amountProvider.notifier).state = amount;

      await _speakAndResume(
          "You said $amount rupees. Swipe right to confirm, or double tap to say a different amount.");
    } else {
      await _speakAndResume(
          "I didn't understand. Please say the amount clearly like 100 or 500.");
    }
    } finally {
      if (mounted) _processingUtterance = false;
    }
  }

  Future<void> _speakAndResume(String text) async {
    setState(() => _ttsPlaying = true);
    await _stt.stop();
    await ref.read(accessibilityProvider.notifier).speakAndWait(text);
    if (!mounted) return;
    setState(() => _ttsPlaying = false);
    _startListening();
  }

  @override
  Widget build(BuildContext context) {
    final amount = ref.watch(amountProvider);

    return AccessibleLayout(
      onActivateSpeak:
          "Say the amount in rupees using your voice. Current amount is $amount rupees.",
      onSwipeRight: _confirmAmount,
      onSwipeLeft: () => Navigator.pop(context),
      onDoubleTap: () async {
        if (_ttsPlaying) return;
        await _stt.stop();
        _startListening();
      },
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

            const SizedBox(height: 16),

            // Voice/CTA confirm
            ElevatedButton.icon(
              onPressed: _confirmAmount,
              icon: const Icon(Icons.check),
              label: const Text("Confirm"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAmount() async {
    final amount = ref.read(amountProvider);
    if (amount != "0") {
      setState(() => _ttsPlaying = true);
      await _stt.stop();
      await ref
          .read(accessibilityProvider.notifier)
          .speakAndWait("Confirming payment of $amount rupees.");
      if (mounted) {
        setState(() => _ttsPlaying = false);
        Navigator.pushNamed(context, '/pin');
      }
    } else {
      await _speakAndResume("Please enter a valid amount first.");
    }
  }

  @override
  void dispose() {
    _stt.stop();
    super.dispose();
  }
}
