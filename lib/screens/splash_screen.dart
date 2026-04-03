import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/accessibility_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _speechAvailable = false;
  String _statusText = 'Initializing...';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Delay so the widget tree is fully built before calling providers
    WidgetsBinding.instance.addPostFrameCallback((_) => _initApp());
  }

  Future<void> _initApp() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => _onSpeechError(e.errorMsg),
      onStatus: (s) => _onSpeechStatus(s),
    );

    // speakAndWait: blocks until TTS finishes, THEN we start listening
    await ref
        .read(accessibilityProvider.notifier)
        .speakAndWait('DrishtiPay opened');

    if (mounted) {
      setState(() => _statusText = 'Say "Activate DrishtiPay"');
      _startListening();
    }
  }

  void _startListening() async {
    if (!_speechAvailable || !mounted) return;

    setState(() {
      _isListening = true;
      _statusText = 'Listening... Say "Activate DrishtiPay"';
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        // Stop TTS the moment user speaks
        if (result.recognizedWords.isNotEmpty) {
          ref.read(accessibilityProvider.notifier).stopSpeaking();
        }
        if (result.finalResult) {
          _onSpeechResult(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_IN',
      listenMode: stt.ListenMode.confirmation,
      cancelOnError: true,
    );
  }

  void _onSpeechResult(String words) {
    if (!mounted) return;
    _speech.stop();
    setState(() => _isListening = false);

    final normalized = words.toLowerCase().trim();
    final isActivate = normalized.contains('activate') ||
        normalized.contains('drishti') ||
        normalized.contains('open') ||
        normalized.contains('start');

    if (isActivate) {
      ref.read(accessibilityProvider.notifier).activateDrishtiPay();
      _navigateToSelection();
    } else {
      setState(() => _statusText = 'Not recognized. Try again.');
      Future.delayed(const Duration(milliseconds: 600), _startListening);
    }
  }

  void _onSpeechError(String error) {
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _statusText = 'Say "Activate DrishtiPay"';
    });
    Future.delayed(const Duration(seconds: 1), _startListening);
  }

  void _onSpeechStatus(String status) {
    if ((status == 'done' || status == 'notListening') &&
        mounted &&
        _isListening) {
      setState(() => _isListening = false);
      Future.delayed(const Duration(milliseconds: 300), _startListening);
    }
  }

  void _navigateToSelection() {
    _speech.stop();
    Navigator.pushReplacementNamed(context, '/selection');
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing logo — matches your app's yellow/black style
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.yellow,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.yellow.withOpacity(0.35),
                        blurRadius: 48,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.currency_rupee_rounded,
                    color: Colors.black,
                    size: 80,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Text(
                'DrishtiPay',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Voice-Powered Payments',
                style: GoogleFonts.inter(
                  color: Colors.yellow,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 64),

              // Mic indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isListening ? 80 : 68,
                height: _isListening ? 80 : 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.yellow : Colors.grey[900],
                  border: Border.all(color: Colors.yellow, width: 2),
                  boxShadow: _isListening
                      ? [
                          BoxShadow(
                            color: Colors.yellow.withOpacity(0.5),
                            blurRadius: 24,
                            spreadRadius: 6,
                          )
                        ]
                      : [],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.black : Colors.white,
                  size: 34,
                ),
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 52),

              // Tap fallback
              GestureDetector(
                onTap: () {
                  ref
                      .read(accessibilityProvider.notifier)
                      .activateDrishtiPay();
                  _navigateToSelection();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.yellow,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Text(
                    'TAP TO ACTIVATE',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}