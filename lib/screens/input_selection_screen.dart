import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/accessibility_provider.dart';
import '../utils/voice_back.dart';
import '../widgets/accessible_layout.dart';

class InputSelectionScreen extends ConsumerStatefulWidget {
  const InputSelectionScreen({super.key});

  @override
  ConsumerState<InputSelectionScreen> createState() => _InputSelectionScreenState();
}

class _InputSelectionScreenState extends ConsumerState<InputSelectionScreen> {
  final SpeechToText _stt = SpeechToText();
  bool _speechEnabled = false;
  bool _showPaymentOptions = false;
  bool _sessionListening = false;
  bool _pauseListening = false;

  @override
  void initState() {
    super.initState();
    _initAndStartVoice();
  }

  void _initAndStartVoice() async {
    try {
      _speechEnabled = await _stt.initialize(
        onError: (error) => debugPrint("STT Error: $error"),
        onStatus: (status) {
          debugPrint("STT Status: $status");
          if (status == 'done' || status == 'notListening') {
            _sessionListening = false;
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted && _speechEnabled && !_pauseListening) _startListening();
            });
          }
        },
      );
    } catch (e) {
      debugPrint("STT Initialization Exception: $e");
      _speechEnabled = false;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_speechEnabled) {
        await ref.read(accessibilityProvider.notifier).speak(
            "Microphone initialization failed. Swipe left to go back, or check microphone permissions in settings. Say QR or U P I when the microphone works.");
        return;
      }
      await ref.read(accessibilityProvider.notifier).speakAndWait(
          "DrishtiPay active. Do you want to pay using Q.R. or U.P.I. I.D.? Please speak your choice. $kVoiceBackHint");
      if (mounted) _startListening();
    });
  }

  void _startListening() async {
    if (!_speechEnabled || !mounted || _sessionListening || _pauseListening) return;
    _sessionListening = true;
    try {
      await _stt.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
        listenMode: ListenMode.dictation,
        localeId: "en_IN",
        partialResults: true,
      );
    } catch (e) {
      debugPrint('Selection listen error: $e');
      _sessionListening = false;
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      _handleVoiceInput(result.recognizedWords.toLowerCase());
    }
  }

  Future<void> _handleVoiceInput(String input) async {
    if (isVoiceBackCommand(input)) {
      _pauseListening = true;
      await _stt.stop();
      if (mounted) Navigator.pop(context);
      return;
    }
    if (input.contains("payment") || input.contains("pay")) {
      setState(() => _showPaymentOptions = true);
      await _stt.stop();
      await ref.read(accessibilityProvider.notifier).speakAndWait(
          "You can pay using QR code or U P I I D. Say QR or U P I.");
      if (mounted) _startListening();
    } else if (input.contains("qr") || input.contains("scanner") || input.contains("scan")) {
      _pauseListening = true;
      await _stt.stop();
      ref.read(accessibilityProvider.notifier).vibrateShort();
      await ref.read(accessibilityProvider.notifier).speakAndWait("Opening QR Scanner.");
      if (!mounted) return;
      await Navigator.pushNamed(context, '/scanner');
      _pauseListening = false;
      _startListening();
    } else if (input.contains("upi") || input.contains("id") || input.contains("voice")) {
      _pauseListening = true;
      await _stt.stop();
      ref.read(accessibilityProvider.notifier).vibrateShort();
      await ref.read(accessibilityProvider.notifier).speakAndWait("Opening voice input for U.P.I. I.D.");
      if (!mounted) return;
      await Navigator.pushNamed(context, '/upi');
      _pauseListening = false;
      _startListening();
    } else {
      try {
        await _stt.stop();
      } catch (_) {}
      await ref.read(accessibilityProvider.notifier).speakAndWait(
          "I didn't catch that. Please say Q.R. or U.P.I. I.D.");
      if (mounted) _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccessibleLayout(
      onActivateSpeak: "Do you want to pay using Q.R. or U.P.I. I.D.?",
      onSwipeLeft: () => Navigator.pop(context),
      onDoubleTap: _startListening,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildGiantSection("QR SCANNER", Colors.yellow, () => _openRoutePaused('/scanner')),
            _buildGiantSection("UPI ID VOICE", Colors.white, () => _openRoutePaused('/upi')),
            if (_showPaymentOptions)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      "Select payment method",
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _handleVoiceInput("qr"),
                          icon: const Icon(Icons.qr_code),
                          label: const Text("QR Code"),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () => _handleVoiceInput("upi id"),
                          icon: const Icon(Icons.account_balance_wallet_outlined),
                          label: const Text("UPI ID/Number"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_stt.isListening)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Icon(Icons.mic, color: Colors.yellow, size: 80),
              ),
            // Mock controls for Web
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(onPressed: () => _handleVoiceInput("qr"), child: const Text("Mock QR")),
                  const SizedBox(width: 20),
                  ElevatedButton(onPressed: () => _handleVoiceInput("upi id"), child: const Text("Mock UPI")),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRoutePaused(String route) async {
    _pauseListening = true;
    await _stt.stop();
    if (!mounted) return;
    await Navigator.pushNamed(context, route);
    if (!mounted) return;
    _pauseListening = false;
    _startListening();
  }

  @override
  void dispose() {
    _stt.stop();
    super.dispose();
  }

  Widget _buildGiantSection(String text, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(accessibilityProvider.notifier).vibrateShort();
          onTap();
        },
        child: Container(
          width: double.infinity,
          color: color,
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
