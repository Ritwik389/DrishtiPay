import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../providers/accessibility_provider.dart';
import '../utils/upi_validation.dart';
import '../utils/upi_voice_parser.dart';
import '../utils/voice_back.dart';
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
  bool _ttsPlaying = false;
  bool _handlingSpeech = false;
  bool _awaitingConfirmation = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _stt.initialize(
        onError: (error) => debugPrint('STT Error: $error'),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
            if (!_ttsPlaying && mounted) {
              Future.delayed(const Duration(milliseconds: 400), _restartListening);
            }
          } else if (status == 'listening') {
            if (mounted) setState(() => _isListening = true);
          }
        },
      );
    } catch (e, st) {
      debugPrint('STT init failed: $e\n$st');
      _speechEnabled = false;
    }

    if (!mounted) return;

    if (_speechEnabled) {
      await _speakThenListen(
        'Say the 10-digit mobile number, or a U P I I D like name at bank. '
        'I will repeat it and ask you to confirm. $kVoiceBackHint',
      );
    } else {
      await ref.read(accessibilityProvider.notifier).speakAndWait(
            'Microphone is not available. DrishtiPay needs the microphone to hear your U P I I D or mobile number. '
            'Swipe left to go back, enable the microphone in settings, then open this screen again. $kVoiceBackHint',
          );
    }
  }

  void _startListening() async {
    if (!_speechEnabled || _ttsPlaying || !mounted) return;
    try {
      await _stt.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
        localeId: 'en_IN',
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint('listen error: $e');
      if (mounted) setState(() => _isListening = false);
      return;
    }
    if (mounted) setState(() => _isListening = true);
  }

  void _restartListening() {
    if (!_speechEnabled || !mounted || _ttsPlaying) return;
    _startListening();
  }

  Future<void> _speakThenListen(String text) async {
    if (!mounted) return;
    setState(() => _ttsPlaying = true);
    try {
      await _stt.stop();
    } catch (_) {}
    await ref.read(accessibilityProvider.notifier).speakAndWait(text);
    if (!mounted) return;
    setState(() => _ttsPlaying = false);
    _startListening();
  }

  String _invalidPatternMessage() =>
      'That is not a valid 10-digit Indian mobile starting with six through nine, '
      'or a U P I I D. Try again: say digits clearly for mobile, or name at bank for U P I. $kVoiceBackHint';

  Future<void> _presentParsed(PayeeParseResult parsed) async {
    ref.read(upiIdProvider.notifier).state = parsed.normalized!;
    if (mounted) {
      setState(() => _awaitingConfirmation = true);
    } else {
      _awaitingConfirmation = true;
    }

    final label = parsed.kind == PayeeParseKind.mobile ? 'mobile number' : 'U P I I D';
    final spoken = parsed.kind == PayeeParseKind.mobile
        ? formatMobileForTts(parsed.normalized!)
        : formatVpaForTts(parsed.normalized!);

    await _speakThenListen(
      'I heard $label: $spoken. Say confirm if this is correct. '
      'Or say a new number or I D to change it. $kVoiceBackHint',
    );
  }

  Future<void> _onSpeechResult(SpeechRecognitionResult result) async {
    if (!result.finalResult || !mounted) return;
    if (_handlingSpeech || _ttsPlaying) return;

    final words = result.recognizedWords.trim();
    if (words.isEmpty) return;

    _handlingSpeech = true;
    try {
      if (isVoiceBackCommand(words)) {
        try {
          await _stt.stop();
        } catch (_) {}
        if (mounted) Navigator.pop(context);
        return;
      }

      if (_awaitingConfirmation && isConfirmUtterance(words)) {
        await _confirmUpi();
        return;
      }

      final parsed = parsePayeeFromSpeech(words);

      if (_awaitingConfirmation) {
        if (parsed.isValid) {
          await _presentParsed(parsed);
          return;
        }
        await _speakThenListen(
          'Say confirm to use this recipient, or clearly say a new mobile number or U P I I D. $kVoiceBackHint',
        );
        return;
      }

      if (isConfirmUtterance(words)) {
        await _speakThenListen(
          'Please say the mobile number or U P I I D first. $kVoiceBackHint',
        );
        return;
      }

      if (!parsed.isValid) {
        await _speakThenListen(_invalidPatternMessage());
        return;
      }

      await _presentParsed(parsed);
    } finally {
      if (mounted) _handlingSpeech = false;
    }
  }

  Future<void> _confirmUpi() async {
    final value = ref.read(upiIdProvider).trim();
    if (value.isEmpty) {
      await _speakThenListen(
        'I still need a valid mobile or U P I I D. Say the number or I D clearly. $kVoiceBackHint',
      );
      return;
    }

    final mobile = UpiValidation.normalizeIndianMobile(value);
    final vpa = mobile == null
        ? UpiValidation.normalizeVpa(value.replaceAll(RegExp(r'\s+'), ''))
        : null;

    if (mobile == null && vpa == null) {
      if (mounted) setState(() => _awaitingConfirmation = false);
      await _speakThenListen(_invalidPatternMessage());
      return;
    }

    if (mobile != null) {
      ref.read(upiIdProvider.notifier).state = mobile;
    } else if (vpa != null) {
      ref.read(upiIdProvider.notifier).state = vpa;
    }

    try {
      await _stt.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _ttsPlaying = true);

    final canonical = ref.read(upiIdProvider);
    final readable =
        mobile != null ? formatMobileForTts(canonical) : formatVpaForTts(canonical);
    await ref.read(accessibilityProvider.notifier).speakAndWait(
          'Confirming recipient $readable. Now say the payment amount.',
        );
    if (!mounted) return;
    setState(() => _ttsPlaying = false);
    Navigator.pushNamed(context, '/amount');
  }

  @override
  Widget build(BuildContext context) {
    final upi = ref.watch(upiIdProvider);
    final statusText =
        upi.isEmpty ? (_speechEnabled ? 'Listening' : 'Microphone off') : upi;
    final heading =
        _awaitingConfirmation ? 'Review — say confirm' : 'U P I or mobile';

    return AccessibleLayout(
      onActivateSpeak: _awaitingConfirmation
          ? 'Recipient set. Say confirm, or say BACK to go back. $kVoiceBackHint'
          : 'Say a 10-digit mobile or U P I I D. $kVoiceBackHint',
      onSwipeRight: _confirmUpi,
      onSwipeLeft: () {
        _stt.stop();
        Navigator.pop(context);
      },
      onDoubleTap: () async {
        if (_ttsPlaying || !_speechEnabled) return;
        try {
          await _stt.stop();
        } catch (_) {}
        _startListening();
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                header: true,
                child: Text(
                  heading.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                label: upi.isEmpty
                    ? 'No recipient yet. ${_speechEnabled ? 'Microphone is listening' : 'Microphone unavailable'}'
                    : 'Recipient: $upi',
                child: Text(
                  statusText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.yellow,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: _isListening
                    ? 'Microphone is on'
                    : 'Microphone is idle; double tap to listen again',
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 64,
                  color: _isListening ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                button: true,
                label:
                    'Confirm recipient and continue to amount. Or swipe right.',
                child: ElevatedButton.icon(
                  onPressed: _confirmUpi,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm recipient'),
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
