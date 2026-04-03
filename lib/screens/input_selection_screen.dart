import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/accessibility_provider.dart';
import '../widgets/accessible_layout.dart';

class InputSelectionScreen extends ConsumerStatefulWidget {
  const InputSelectionScreen({super.key});

  @override
  ConsumerState<InputSelectionScreen> createState() =>
      _InputSelectionScreenState();
}

class _InputSelectionScreenState extends ConsumerState<InputSelectionScreen> {
  final SpeechToText _stt = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _navigating = false; // prevent double navigation

  @override
  void initState() {
    super.initState();
    _initAndStartVoice();
  }

  Future<void> _initAndStartVoice() async {
    try {
      _speechEnabled = await _stt.initialize(
        onError: (error) {
          debugPrint("STT Error: $error");
          if (mounted && _isListening) {
            setState(() => _isListening = false);
            Future.delayed(const Duration(seconds: 1), _startListening);
          }
        },
        onStatus: (status) {
          debugPrint("STT Status: $status");
          if ((status == 'done' || status == 'notListening') &&
              mounted &&
              _isListening &&
              !_navigating) {
            setState(() => _isListening = false);
            Future.delayed(
                const Duration(milliseconds: 300), _startListening);
          }
        },
      );
    } catch (e) {
      debugPrint("STT init error: $e");
      _speechEnabled = false;
    }

    if (!mounted) return;

    if (_speechEnabled) {
      await ref.read(accessibilityProvider.notifier).speakAndWait(
          "How would you like to pay? Say Q.R. Scanner or U.P.I. I.D.");
      if (mounted && !_navigating) _startListening();
    } else {
      await ref.read(accessibilityProvider.notifier).speakAndWait(
          "Microphone not available. Please tap a button to continue.");
    }
  }

  void _startListening() async {
    if (!mounted || !_speechEnabled || _stt.isListening || _navigating) return;

    setState(() => _isListening = true);

    await _stt.listen(
      onResult: (result) {
        if (!mounted) return;
        // Stop TTS the moment user speaks
        if (result.recognizedWords.isNotEmpty) {
          ref.read(accessibilityProvider.notifier).stopSpeaking();
        }
        if (result.finalResult) {
          setState(() => _isListening = false);
          _handleVoiceInput(result.recognizedWords.toLowerCase());
        }
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      localeId: "en_IN",
      cancelOnError: true,
    );
  }

  Future<void> _handleVoiceInput(String input) async {
    if (_navigating) return;

    if (input.contains("qr") ||
        input.contains("scanner") ||
        input.contains("scan") ||
        input.contains("camera")) {
      _navigating = true;
      ref.read(accessibilityProvider.notifier).vibrateShort();
      await ref
          .read(accessibilityProvider.notifier)
          .speakAndWait("Opening QR Scanner.");
      if (mounted) Navigator.pushNamed(context, '/scanner');
    } else if (input.contains("upi") ||
        input.contains("id") ||
        input.contains("voice") ||
        input.contains("manual")) {
      _navigating = true;
      ref.read(accessibilityProvider.notifier).vibrateShort();
      await ref
          .read(accessibilityProvider.notifier)
          .speakAndWait("Opening U.P.I. I.D. entry.");
      if (mounted) Navigator.pushNamed(context, '/upi'); // ✅ FIXED: was '/amount'
    } else {
      await ref.read(accessibilityProvider.notifier).speakAndWait(
          "Sorry, I didn't catch that. Please say Q.R. Scanner or U.P.I. I.D.");
      if (mounted && !_navigating) _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccessibleLayout(
      onActivateSpeak: "Say Q.R. Scanner or U.P.I. I.D. to choose how to pay.",
      onSwipeLeft: () => Navigator.pop(context),
      onDoubleTap: _startListening,
      child: Column(
        children: [
          // QR Scanner — top half
          _buildGiantSection(
            icon: Icons.qr_code_scanner,
            label: "QR SCANNER",
            hint: 'Say "QR Scanner" or tap',
            color: Colors.yellow,
            onTap: () async {
              if (_navigating) return;
              _navigating = true;
              _stt.stop();
              ref.read(accessibilityProvider.notifier).vibrateShort();
              await ref
                  .read(accessibilityProvider.notifier)
                  .speakAndWait("Opening QR Scanner.");
              if (mounted) Navigator.pushNamed(context, '/scanner');
            },
          ),

          // UPI ID — bottom half
          _buildGiantSection(
            icon: Icons.mic,
            label: "UPI ID VOICE",
            hint: 'Say "UPI ID" or tap',
            color: Colors.white,
            onTap: () async {
              if (_navigating) return;
              _navigating = true;
              _stt.stop();
              ref.read(accessibilityProvider.notifier).vibrateShort();
              await ref
                  .read(accessibilityProvider.notifier)
                  .speakAndWait("Opening U.P.I. I.D. entry.");
              if (mounted) Navigator.pushNamed(context, '/upi'); // ✅ FIXED
            },
          ),

          // Listening indicator
          if (_isListening)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic, color: Colors.yellow, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    "Listening...",
                    style: GoogleFonts.inter(
                      color: Colors.yellow,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGiantSection({
    required IconData icon,
    required String label,
    required String hint,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          color: color,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: Colors.black),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hint,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stt.stop();
    super.dispose();
  }
}