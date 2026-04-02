import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Ink;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;
import 'package:signature/signature.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../providers/accessibility_provider.dart';
import '../utils/voice_back.dart';
import '../widgets/accessible_layout.dart';

/// BCP-47 tag for ML Kit digital ink — must match downloaded model.
const String _kDigitalInkLanguage = 'en-US';

class PinCanvasScreen extends ConsumerStatefulWidget {
  const PinCanvasScreen({super.key});

  @override
  ConsumerState<PinCanvasScreen> createState() => _PinCanvasScreenState();
}

class _PinCanvasScreenState extends ConsumerState<PinCanvasScreen> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 15,
    penColor: Colors.yellow,
    exportBackgroundColor: Colors.black,
  );

  mlkit.DigitalInkRecognizer? _recognizer;
  final mlkit.Ink _ink = mlkit.Ink();
  final List<String> _enteredDigits = [];
  int _digitCount = 0;
  bool _isProcessing = false;
  bool _isRecognizingStroke = false;

  /// ML Kit requires the remote model to be present; without it, recognition returns nothing.
  bool _inkModelReady = false;
  String? _inkSetupError;

  Size _writingAreaSize = const Size(320, 400);
  int _strokeTimeMs = 0;

  final SpeechToText _voiceBack = SpeechToText();
  bool _voiceReady = false;
  bool _voiceListening = false;
  bool _ttsBusy = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStrokeUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPinFlow());
  }

  Future<void> _initPinFlow() async {
    await _prepareDigitalInkModel();
    if (!mounted) return;
    await _bootVoice();
  }

  Future<void> _prepareDigitalInkModel() async {
    if (kIsWeb) {
      setState(() => _inkModelReady = true);
      return;
    }

    setState(() {
      _inkModelReady = false;
      _inkSetupError = null;
    });

    final manager = mlkit.DigitalInkRecognizerModelManager();
    try {
      final hasModel = await manager.isModelDownloaded(_kDigitalInkLanguage);
      if (!hasModel) {
        debugPrint(
          '[DrishtiPay] Digital ink: downloading model $_kDigitalInkLanguage (required for recognition)',
        );
        final ok = await manager.downloadModel(
          _kDigitalInkLanguage,
          isWifiRequired: false,
        );
        if (!ok) {
          throw Exception('Model download did not complete successfully');
        }
      } else {
        debugPrint('[DrishtiPay] Digital ink: model $_kDigitalInkLanguage already on device');
      }
      _recognizer = mlkit.DigitalInkRecognizer(languageCode: _kDigitalInkLanguage);
    } catch (e, st) {
      debugPrint('[DrishtiPay] Digital ink model error: $e\n$st');
      if (mounted) {
        setState(() => _inkSetupError = e.toString());
      }
      _recognizer = mlkit.DigitalInkRecognizer(languageCode: _kDigitalInkLanguage);
    }

    if (mounted) setState(() => _inkModelReady = true);
  }

  Future<void> _bootVoice() async {
    if (_inkSetupError != null && !kIsWeb) {
      await ref.read(accessibilityProvider.notifier).speakAndWait(
            'Handwriting model had a problem. You can still try drawing. '
            'If it fails, go back and try again when you have internet. Say back to go back.',
          );
    } else {
      await ref.read(accessibilityProvider.notifier).speakAndWait(
            'Draw 4 digits of your PIN one by one on the screen. Say back to go back.',
          );
    }
    if (!mounted) return;
    if (kIsWeb) return;
    try {
      _voiceReady = await _voiceBack.initialize(
        onError: (e) => debugPrint('PIN voice back: $e'),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _voiceListening = false;
            if (mounted && !_isProcessing && !_ttsBusy) {
              Future.delayed(const Duration(milliseconds: 400), _listenVoiceBack);
            }
          }
        },
      );
    } catch (e) {
      debugPrint('PIN voice back init: $e');
      _voiceReady = false;
    }
    if (_voiceReady && mounted) _listenVoiceBack();
  }

  void _listenVoiceBack() async {
    if (!_voiceReady || !mounted || _isProcessing || _ttsBusy || _voiceListening) return;
    _voiceListening = true;
    await _voiceBack.listen(
      onResult: _onVoiceBackResult,
      listenFor: const Duration(seconds: 120),
      pauseFor: const Duration(seconds: 5),
      listenMode: ListenMode.dictation,
      localeId: 'en_IN',
    );
  }

  void _onVoiceBackResult(SpeechRecognitionResult result) {
    if (!result.finalResult) return;
    if (!isVoiceBackCommand(result.recognizedWords)) return;
    _voiceBack.stop();
    if (mounted) Navigator.pop(context);
  }

  static String _asciiDigitsOnly(String input) {
    final out = StringBuffer();
    for (final r in input.runes) {
      if (r >= 0x30 && r <= 0x39) {
        out.writeCharCode(r);
        continue;
      }
      if (r >= 0xFF10 && r <= 0xFF19) {
        out.writeCharCode(r - 0xFF10 + 0x30);
        continue;
      }
      if (r >= 0x0660 && r <= 0x0669) {
        out.writeCharCode(r - 0x0660 + 0x30);
        continue;
      }
      if (r >= 0x0966 && r <= 0x096F) {
        out.writeCharCode(r - 0x0966 + 0x30);
        continue;
      }
    }
    return out.toString();
  }

  String? _singleDigitFromRecognition(String recognized) {
    final t = recognized.trim();
    if (t.isEmpty) return null;

    final fromChars = _asciiDigitsOnly(t);
    if (fromChars.isNotEmpty) {
      return fromChars[0];
    }

    var compact = t.replaceAll(RegExp(r'\s'), '').toLowerCase();
    if (RegExp(r'^\d$').hasMatch(compact)) return compact;

    const map = {
      'zero': '0',
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
    };
    for (final e in map.entries) {
      if (compact == e.key || compact.startsWith(e.key)) return e.value;
    }
    final lower = t.toLowerCase();
    for (final e in map.entries) {
      if (RegExp(r'\b${RegExp.escape(e.key)}\b').hasMatch(lower)) {
        return e.value;
      }
    }
    return null;
  }

  void _onStrokeUpdate() {}

  void _onPointerDown(PointerDownEvent event) {
    if (!_inkModelReady || _digitCount >= 4 || _isProcessing) return;
    _strokeTimeMs = DateTime.now().millisecondsSinceEpoch;
    _ink.strokes.add(mlkit.Stroke());
    _addPoint(event.localPosition);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_inkModelReady || _digitCount >= 4 || _isProcessing) return;
    if (_ink.strokes.isEmpty) return;
    _addPoint(event.localPosition);
  }

  void _addPoint(Offset localPosition) {
    _strokeTimeMs += 8;
    _ink.strokes.last.points.add(mlkit.StrokePoint(
      x: localPosition.dx,
      y: localPosition.dy,
      t: _strokeTimeMs,
    ));
  }

  void _onStrokeEnd() async {
    if (!_inkModelReady ||
        _recognizer == null ||
        _controller.isEmpty ||
        _digitCount >= 4 ||
        _isProcessing ||
        _isRecognizingStroke) {
      return;
    }
    _isRecognizingStroke = true;

    String? digit;
    try {
      if (_ink.strokes.isEmpty || _ink.strokes.last.points.isEmpty) {
        debugPrint('[DrishtiPay] PIN ink: empty stroke');
      } else {
        final w = _writingAreaSize.width;
        final h = _writingAreaSize.height;
        final inkContext = (w > 0 && h > 0)
            ? mlkit.DigitalInkRecognitionContext(
                writingArea: mlkit.WritingArea(width: w, height: h),
              )
            : null;

        final candidates = await _recognizer!.recognize(
          _ink,
          context: inkContext,
        );

        if (candidates.isEmpty) {
          debugPrint(
            '[DrishtiPay] PIN ink: no candidates (is model $_kDigitalInkLanguage downloaded?)',
          );
        }

        for (final c in candidates) {
          digit = _singleDigitFromRecognition(c.text);
          if (digit != null) break;
        }
        if (digit == null && candidates.isNotEmpty) {
          debugPrint(
            '[DrishtiPay] PIN ink rejected. Raw candidates: '
            '${candidates.map((c) => '"${c.text}"').join(', ')}',
          );
        }
      }
    } catch (e, st) {
      debugPrint('Recognition error: $e\n$st');
    } finally {
      _isRecognizingStroke = false;
    }

    if (digit == null) {
      await _voiceBack.stop();
      if (!mounted) return;
      setState(() => _ttsBusy = true);
      await ref.read(accessibilityProvider.notifier).speakAndWait(
            'Please draw a single digit from zero to nine, one number at a time.',
          );
      if (mounted) setState(() => _ttsBusy = false);
      _controller.clear();
      _ink.strokes.clear();
      _listenVoiceBack();
      return;
    }

    _enteredDigits.add(digit);
    debugPrint('[DrishtiPay] PIN digit recognized: $digit | PIN so far: ${_enteredDigits.join()}');

    if (!mounted) return;
    setState(() {
      _digitCount++;
      ref.read(pinStrokesProvider.notifier).state = _digitCount;
    });

    await ref.read(accessibilityProvider.notifier).vibrateShort();

    if (_digitCount >= 4) {
      debugPrint('[DrishtiPay] FULL PIN (4 digits): ${_enteredDigits.join()}');
      _finishPin();
    } else {
      await _voiceBack.stop();
      if (!mounted) return;
      setState(() => _ttsBusy = true);
      await ref
          .read(accessibilityProvider.notifier)
          .speakAndWait("Digit $_digitCount accepted.");
      if (mounted) setState(() => _ttsBusy = false);
      _controller.clear();
      _ink.strokes.clear();
      _listenVoiceBack();
    }
  }

  void _finishPin() async {
    setState(() => _isProcessing = true);
    await _voiceBack.stop();

    bool authenticated = kIsWeb ? true : await ref.read(accessibilityProvider.notifier).checkBiometrics();

    if (authenticated) {
      final amount = ref.read(amountProvider);
      final encrypted = ref.read(accessibilityProvider.notifier).encryptTransaction(amount);
      debugPrint('Transaction Encrypted: $encrypted');

      await ref.read(accessibilityProvider.notifier).speakAndWait(
            'PIN and Biometrics accepted. Processing encrypted payment.',
          );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/success');
      }
    } else {
      setState(() => _isProcessing = false);
      await ref
          .read(accessibilityProvider.notifier)
          .speakAndWait('Authentication failed. Please try again.');
      if (mounted) _listenVoiceBack();
    }
  }

  @override
  void dispose() {
    _voiceBack.stop();
    _controller.dispose();
    _recognizer?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AccessibleLayout(
      onActivateSpeak: 'Draw your 4 digit PIN on the screen. $_digitCount digits entered.',
      onSwipeLeft: () => Navigator.pop(context),
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 60),
              Text(
                'DRAW PIN',
                style: GoogleFonts.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _digitCount ? Colors.yellow : Colors.grey[900],
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  );
                }),
              ),
              const Spacer(),
              if (!_inkModelReady && !_isProcessing)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Colors.yellow),
                      SizedBox(height: 16),
                      Text(
                        'Preparing handwriting recognition…',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              else if (!_isProcessing)
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 400,
                      width: double.infinity,
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.yellow.withOpacity(0.3), width: 2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LayoutBuilder(
                          builder: (context, inner) {
                            final sz = Size(inner.maxWidth, inner.maxHeight);
                            if (sz.width != _writingAreaSize.width ||
                                sz.height != _writingAreaSize.height) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() => _writingAreaSize = sz);
                                }
                              });
                            }
                            return Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: _onPointerDown,
                              onPointerMove: _onPointerMove,
                              onPointerUp: (_) => _onStrokeEnd(),
                              child: Signature(
                                controller: _controller,
                                height: 400,
                                backgroundColor: Colors.black,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.yellow, strokeWidth: 8),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _isProcessing ? 'PROCESSING...' : 'DRAW DIGIT ${_digitCount + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    color: Colors.yellow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (kIsWeb)
            Positioned(
              top: 100,
              right: 20,
              child: ElevatedButton(
                onPressed: _finishPin,
                child: const Text('Simulate PIN Success'),
              ),
            ),
        ],
      ),
    );
  }
}
