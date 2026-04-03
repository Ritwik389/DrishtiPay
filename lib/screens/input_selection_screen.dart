import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/accessibility_provider.dart';
import '../services/app_speech_recognizer.dart';
import '../widgets/accessible_layout.dart';

class InputSelectionScreen extends ConsumerStatefulWidget {
  const InputSelectionScreen({super.key});

  @override
  ConsumerState<InputSelectionScreen> createState() => _InputSelectionScreenState();
}

class _InputSelectionScreenState extends ConsumerState<InputSelectionScreen> {
  final AppSpeechRecognizer _speechRecognizer = AppSpeechRecognizer();
  bool _speechEnabled = false;
  bool _showPaymentOptions = false;
  bool _isListening = false;
  bool _ttsBusy = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _initAndStartVoice();
  }

  Future<void> _initAndStartVoice() async {
    try {
      _speechEnabled = await _speechRecognizer.initialize(
        onError: (error) => debugPrint("STT Error: $error"),
        onStatus: (status) {
          debugPrint("STT Status: $status");
          if (mounted) {
            setState(() {
              _isListening = status == 'listening';
            });
          }
        },
      );
    } catch (e) {
      debugPrint("STT Initialization Exception: $e");
      _speechEnabled = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _speakAndWait(
        "DrishtiPay active. Do you want to pay using Q.R. or U.P.I. I.D.? Please speak your choice.",
      );

      if (_speechEnabled) {
        _startListening();
      } else {
        await _speakAndWait(
          "Microphone initialization failed. Please use the buttons on the screen or check browser permissions.",
        );
      }
    });
  }

  Future<void> _speakAndWait(String text) async {
    if (!mounted) return;
    setState(() => _ttsBusy = true);
    await ref.read(accessibilityProvider.notifier).speakAndWait(text);
    if (mounted) {
      setState(() => _ttsBusy = false);
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled || _ttsBusy || _navigating) return;
    await _speechRecognizer.listen(
      onResult: (text, isFinal) {
        if (!_navigating && text.trim().isNotEmpty) {
          ref.read(accessibilityProvider.notifier).stopSpeaking();
        }
        if (mounted) {
          setState(() {
            _isListening = true;
          });
        }
        if (isFinal) {
          _handleVoiceInput(text.toLowerCase().trim());
        }
      },
      listenFor: const Duration(seconds: 8),
      localeId: "en_IN",
    );
  }

  bool _isQrIntent(String input) {
    return RegExp(r'\b(qr|scanner|scan|camera)\b').hasMatch(input);
  }

  bool _isUpiIntent(String input) {
    return input.contains('upi') ||
        input.contains('u p i') ||
        input.contains('@') ||
        RegExp(r'\bmobile\b').hasMatch(input) ||
        RegExp(r'\bnumber\b').hasMatch(input);
  }

  Future<void> _goTo(String route, String speech) async {
    if (_navigating) return;
    _navigating = true;
    await _speechRecognizer.stop();
    await ref.read(accessibilityProvider.notifier).stopSpeaking();
    await ref.read(accessibilityProvider.notifier).vibrateShort();
    await _speakAndWait(speech);
    if (mounted) {
      Navigator.pushNamed(context, route).then((_) {
        _navigating = false;
        if (mounted && _speechEnabled) {
          _startListening();
        }
      });
    }
  }

  Future<void> _handleVoiceInput(String input) async {
    if (_navigating) return;
    if (input.contains("payment") || RegExp(r'\bpay\b').hasMatch(input)) {
      setState(() => _showPaymentOptions = true);
      await _speakAndWait(
        "You can pay using QR code or U.P.I. I.D. Say QR or U.P.I., or tap one of the buttons on screen.",
      );
      _startListening();
    } else if (_isQrIntent(input)) {
      await _goTo('/scanner', "Opening QR Scanner.");
    } else if (_isUpiIntent(input)) {
      await _goTo('/upi', "Opening voice input for U.P.I. I.D.");
    } else {
      await _speakAndWait("I didn't catch that. Please say Q.R. or U.P.I. I.D.");
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccessibleLayout(
      onActivateSpeak: "Do you want to pay using Q.R. or U.P.I. I.D.?",
      onSwipeLeft: () => Navigator.pop(context),
      onDoubleTap: () => _startListening(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildGiantSection(
              "QR SCANNER",
              Colors.yellow,
              () => _goTo('/scanner', "Opening QR Scanner."),
            ),
            _buildGiantSection(
              "UPI ID VOICE",
              Colors.white,
              () => _goTo('/upi', "Opening voice input for U.P.I. I.D."),
            ),
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
                          onPressed: () => _handleVoiceInput("upi"),
                          icon: const Icon(Icons.account_balance_wallet_outlined),
                          label: const Text("UPI ID/Number"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_isListening)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Icon(Icons.mic, color: Colors.yellow, size: 80),
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(onPressed: () => _handleVoiceInput("qr"), child: const Text("Mock QR")),
                  const SizedBox(width: 20),
                  ElevatedButton(onPressed: () => _handleVoiceInput("upi"), child: const Text("Mock UPI")),
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

  @override
  void dispose() {
    _speechRecognizer.dispose();
    super.dispose();
  }
}
