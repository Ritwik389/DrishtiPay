import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' show ListenMode;
import '../providers/accessibility_provider.dart';
import '../services/app_speech_recognizer.dart';

class StandardWalletScreen extends ConsumerStatefulWidget {
  const StandardWalletScreen({super.key});

  @override
  ConsumerState<StandardWalletScreen> createState() =>
      _StandardWalletScreenState();
}

class _StandardWalletScreenState extends ConsumerState<StandardWalletScreen> {
  final AppSpeechRecognizer _speechRecognizer = AppSpeechRecognizer();
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isActivating = false;
  String _lastHeard = '';
  DateTime? _lastRetryPromptAt;

  @override
  void initState() {
    super.initState();
    _initWakeWordListening();
  }

  Future<void> _initWakeWordListening() async {
    try {
      _speechEnabled = await _speechRecognizer.initialize(
        onError: (error) {
          debugPrint("Wake word STT Error: $error");
          _restartListening();
        },
        onStatus: (status) {
          debugPrint("Wake word STT Status: $status");
          final activelyListening = status == 'listening';
          if (mounted) {
            setState(() {
              _isListening = activelyListening;
            });
          }
          if ((status == 'done' || status == 'notListening') && !_isActivating) {
            _restartListening();
          }
        },
      );
    } catch (e) {
      debugPrint("Wake word initialization exception: $e");
      _speechEnabled = false;
    }

    if (_speechEnabled) {
      _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled || _isActivating || _speechRecognizer.isListening) {
      return;
    }

    await _speechRecognizer.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 5),
      localeId: "en_IN",
      partialResults: true,
      cancelOnError: false,
      listenMode: ListenMode.dictation,
    );

    if (mounted) {
      setState(() {
        _isListening = true;
      });
    }
  }

  void _restartListening() {
    if (!_speechEnabled || _isActivating) return;

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && !_speechRecognizer.isListening) {
        _startListening();
      }
    });
  }

  Future<void> _handleScreenTap() async {
    if (!_speechEnabled || _isActivating) return;

    await _speechRecognizer.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
    _restartListening();
  }

  void _onSpeechResult(String transcript, bool isFinal) {
    final heardText = transcript.trim();
    if (_isLikelyNoise(heardText)) {
      if (isFinal) {
        _handleWakePhraseMiss();
      }
      return;
    }

    if (mounted) {
      setState(() {
        _lastHeard = heardText;
      });
    }

    if (_matchesWakePhrase(heardText)) {
      _activateDrishtiPay();
      return;
    }

    if (isFinal) {
      _handleWakePhraseMiss();
    }
  }

  bool _isLikelyNoise(String text) {
    if (text.isEmpty) return true;

    final normalized = text.toLowerCase().trim();
    final compact = normalized.replaceAll(RegExp(r'[^a-z]'), '');
    final words = normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);

    const commonNoise = {
      'uh',
      'um',
      'hmm',
      'mm',
      'ah',
      'oh',
      'background',
      'noise',
      'static',
    };

    if (compact.length <= 1) return true;
    if (compact.length <= 3 && !compact.contains('sta')) return true;
    if (words.length == 1 && commonNoise.contains(normalized)) return true;
    if (RegExp(r'^(ha|he|hi|ho|hu)+$').hasMatch(compact)) return true;

    return false;
  }

  Future<void> _handleWakePhraseMiss() async {
    if (_isActivating) return;

    setState(() {
      _isListening = false;
    });

    await _speechRecognizer.stop();
    _speakRetryPrompt();
    _restartListening();
  }

  void _speakRetryPrompt() {
    final now = DateTime.now();
    if (_lastRetryPromptAt != null &&
        now.difference(_lastRetryPromptAt!) < const Duration(seconds: 4)) {
      return;
    }

    _lastRetryPromptAt = now;
    ref.read(accessibilityProvider.notifier).speak(
      "Didn't catch that. Still listening for DrishtiPay.",
    );
  }

  bool _matchesWakePhrase(String text) {
    final normalized = text.toLowerCase();
    final compact = normalized.replaceAll(RegExp(r'[^a-z]'), '');

    const brandVariants = [
      'drishtipay',
      'drishti pay',
      'drishty pe',
      'dristhi pe',
      'drishtipay app',
    ];

    for (final variant in brandVariants) {
      final compactVariant = variant.replaceAll(' ', '');
      if (normalized.contains(variant) || compact.contains(compactVariant)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _activateDrishtiPay() async {
    if (_isActivating) return;

    setState(() {
      _isActivating = true;
      _isListening = false;
    });

    await _speechRecognizer.stop();
    ref.read(accessibilityProvider.notifier).activateDrishtiPay();

    if (mounted) {
      Navigator.pushNamed(context, '/selection').then((_) {
        if (!mounted) return;
        setState(() {
          _isActivating = false;
          _lastHeard = '';
        });
        _restartListening();
      });
    }
  }

  @override
  void dispose() {
    _speechRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const paytmBlue = Color(0xFF00B9F1);
    const paytmDarkBlue = Color(0xFF002E6E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: paytmBlue,
        title: Text(
          'DrishtiPay Wallet',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search, color: Colors.white),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person_outline, color: Colors.white),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleScreenTap,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                color: paytmBlue.withValues(alpha: 0.1),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _serviceItem(Icons.qr_code_scanner, "Scan & Pay"),
                        _serviceItem(Icons.contact_phone, "To Mobile"),
                        _serviceItem(Icons.account_balance, "To Bank"),
                        _serviceItem(Icons.history, "History"),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: paytmDarkBlue,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _speechEnabled
                                      ? 'Say "DrishtiPay" or tap anywhere'
                                      : 'Microphone permission needed for voice activation',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: paytmDarkBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isListening
                                ? 'Listening for the wake phrase'
                                : 'Voice activation paused',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (_isListening || _lastHeard.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: paytmBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _lastHeard.isNotEmpty
                                    ? 'Heard phrase: $_lastHeard'
                                    : 'Heard phrase: ...',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: paytmDarkBlue,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _activateDrishtiPay,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: paytmDarkBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(
                                'Open DrishtiPay',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Recharge & Bill Payments",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: paytmDarkBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF00B9F1), size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      padding: const EdgeInsets.all(16),
      children: [
        _gridItem(Icons.phone_android, "Mobile"),
        _gridItem(Icons.lightbulb, "Electricity"),
        _gridItem(Icons.tv, "DTH"),
        _gridItem(Icons.credit_card, "Credit Card"),
        _gridItem(Icons.water_drop, "Water"),
        _gridItem(Icons.gas_meter, "Gas"),
        _gridItem(Icons.wifi, "Broadband"),
        _gridItem(Icons.more_horiz, "More"),
      ],
    );
  }

  Widget _gridItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600], size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[800]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
