import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/accessibility_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _initAndStartVoice();
  }

  void _initAndStartVoice() async {
    try {
      _speechEnabled = await _stt.initialize(
        onError: (error) => debugPrint("STT Error: $error"),
        onStatus: (status) => debugPrint("STT Status: $status"),
      );
    } catch (e) {
      debugPrint("STT Initialization Exception: $e");
      _speechEnabled = false;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(accessibilityProvider.notifier).speak(
          "DrishtiPay active. Do you want to pay using Q.R. or U.P.I. I.D.? Please speak your choice.");
      
      if (_speechEnabled) {
        // Wait for TTS to finish before listening
        Future.delayed(const Duration(seconds: 4), () => _startListening());
      } else {
        ref.read(accessibilityProvider.notifier).speak(
            "Microphone initialization failed. Please use the buttons on the screen or check browser permissions.");
      }
    });
  }

  void _startListening() async {
    await _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          _handleVoiceInput(result.recognizedWords.toLowerCase());
        }
      },
      listenFor: const Duration(seconds: 5),
      localeId: "en_IN",
    );
  }

  void _handleVoiceInput(String input) {
    if (input.contains("payment") || input.contains("pay")) {
      setState(() => _showPaymentOptions = true);
      ref.read(accessibilityProvider.notifier).speak(
          "You can pay using QR code or U.P.I. I.D. Say QR or U.P.I., or tap one of the buttons on screen.");
    } else if (input.contains("qr") || input.contains("scanner") || input.contains("scan")) {
      ref.read(accessibilityProvider.notifier).vibrateShort();
      ref.read(accessibilityProvider.notifier).speak("Opening QR Scanner.");
      Navigator.pushNamed(context, '/scanner');
    } else if (input.contains("upi") || input.contains("id") || input.contains("voice")) {
      ref.read(accessibilityProvider.notifier).vibrateShort();
      ref.read(accessibilityProvider.notifier).speak("Opening voice input for U.P.I. I.D.");
      Navigator.pushNamed(context, '/upi');
    } else {
      ref.read(accessibilityProvider.notifier).speak("I didn't catch that. Please say Q.R. or U.P.I. I.D.");
      _startListening();
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
            _buildGiantSection("QR SCANNER", Colors.yellow, () => Navigator.pushNamed(context, '/scanner')),
            _buildGiantSection("UPI ID VOICE", Colors.white, () => Navigator.pushNamed(context, '/amount')),
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
