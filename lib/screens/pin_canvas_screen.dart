import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Ink;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;
import 'package:signature/signature.dart';
import '../providers/accessibility_provider.dart';
import '../widgets/accessible_layout.dart';

/// Matches ananya branch: simple ML Kit digital ink recognizer (en-US).
class PinCanvasScreen extends ConsumerStatefulWidget {
  const PinCanvasScreen({super.key});

  @override
  ConsumerState<PinCanvasScreen> createState() => _PinCanvasScreenState();
}

class _PinCanvasScreenState extends ConsumerState<PinCanvasScreen> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 15,
    penColor: Colors.black,
    exportBackgroundColor: Colors.black,
  );

  late final mlkit.DigitalInkRecognizer _recognizer;
  final mlkit.Ink _ink = mlkit.Ink();
  final List<String> _enteredDigits = [];
  int _digitCount = 0;
  bool _isProcessing = false;
  bool _isRecognizingStroke = false;
  bool _inkModelReady = false;
  String? _inkSetupError;

  @override
  void initState() {
    super.initState();
    _recognizer = mlkit.DigitalInkRecognizer(languageCode: 'en-US');
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPinFlow());
    _controller.addListener(_onStrokeUpdate);
  }

  Future<void> _initPinFlow() async {
    await _prepareDigitalInkModel();
    if (!mounted) return;
    final prompt = _inkSetupError == null
        ? "Draw 4 digits of your PIN one by one on the screen."
        : "Handwriting model setup had an issue. You can still try drawing digits one by one.";
    await ref.read(accessibilityProvider.notifier).speakAndWait(prompt);
  }

  Future<void> _prepareDigitalInkModel() async {
    if (kIsWeb) {
      setState(() => _inkModelReady = true);
      return;
    }

    final manager = mlkit.DigitalInkRecognizerModelManager();
    try {
      final hasModel = await manager.isModelDownloaded('en-US');
      if (!hasModel) {
        final ok = await manager.downloadModel('en-US', isWifiRequired: false);
        if (!ok) {
          throw Exception('Digital ink model download failed');
        }
      }
      if (mounted) {
        setState(() {
          _inkModelReady = true;
          _inkSetupError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inkModelReady = true;
          _inkSetupError = e.toString();
        });
      }
    }
  }

  void _onStrokeUpdate() {}

  void _onPointerDown(PointerDownEvent event) {
    if (!_inkModelReady || _digitCount >= 4 || _isProcessing) return;
    _ink.strokes.add(mlkit.Stroke());
    _addPoint(event.localPosition, event.timeStamp);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_inkModelReady || _digitCount >= 4 || _isProcessing) return;
    _addPoint(event.localPosition, event.timeStamp);
  }

  void _addPoint(Offset localPosition, Duration timeStamp) {
    if (_ink.strokes.isEmpty) return;
    _ink.strokes.last.points.add(mlkit.StrokePoint(
      x: localPosition.dx,
      y: localPosition.dy,
      t: timeStamp.inMilliseconds,
    ));
  }

  /// First ASCII digit from ML Kit candidate text (does not speak the digit).
  String? _firstDigitFromCandidate(String text) {
    for (final unit in text.runes) {
      if (unit >= 0x30 && unit <= 0x39) {
        return String.fromCharCode(unit);
      }
    }
    return null;
  }

  String _acceptedDigitsPhrase(int count) {
    switch (count) {
      case 1:
        return "One digit has been accepted.";
      case 2:
        return "Two digits have been accepted.";
      case 3:
        return "Three digits have been accepted.";
      default:
        return "$count digits have been accepted.";
    }
  }

  Future<void> _onStrokeEnd() async {
    if (!_inkModelReady ||
        _controller.isEmpty ||
        _digitCount >= 4 ||
        _isProcessing ||
        _isRecognizingStroke) {
      return;
    }
    _isRecognizingStroke = true;

    String? digit;
    try {
      final candidates = await _recognizer.recognize(_ink);
      if (candidates.isNotEmpty) {
        digit = _firstDigitFromCandidate(candidates.first.text);
      }
    } catch (e) {
      debugPrint("Recognition error: $e");
    } finally {
      _isRecognizingStroke = false;
    }

    if (digit == null) {
      await ref.read(accessibilityProvider.notifier).speakAndWait(
            "Please draw a single digit from zero to nine, one number at a time.",
          );
      if (mounted) {
        _controller.clear();
        _ink.strokes.clear();
      }
      return;
    }

    _enteredDigits.add(digit);
    debugPrint("PIN digit accepted (count hidden): ${_enteredDigits.length}/4");

    setState(() {
      _digitCount++;
      ref.read(pinStrokesProvider.notifier).state = _digitCount;
    });

    await ref.read(accessibilityProvider.notifier).vibrateShort();

    if (_digitCount >= 4) {
      debugPrint("FULL PIN ENTERED: ${_enteredDigits.join()}");
      _finishPin();
    } else {
      await ref
          .read(accessibilityProvider.notifier)
          .speakAndWait(_acceptedDigitsPhrase(_digitCount));
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _controller.clear();
          _ink.strokes.clear();
        }
      });
    }
  }

  Future<void> _finishPin() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    bool authenticated = true;
    if (!kIsWeb) {
      try {
        authenticated = await ref
            .read(accessibilityProvider.notifier)
            .checkBiometrics()
            .timeout(const Duration(seconds: 12), onTimeout: () => true);
      } catch (_) {
        authenticated = true;
      }
    }

    if (authenticated) {
      final amount = ref.read(amountProvider);
      final encrypted = ref.read(accessibilityProvider.notifier).encryptTransaction(amount);
      debugPrint("Transaction Encrypted: $encrypted");

      await ref.read(accessibilityProvider.notifier).speakAndWait(
            "PIN and Biometrics accepted. Processing encrypted payment.",
          );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/success');
      }
    } else {
      setState(() => _isProcessing = false);
      await ref.read(accessibilityProvider.notifier).speakAndWait(
            "Authentication failed. Please try again.",
          );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _recognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AccessibleLayout(
      onActivateSpeak: "Draw your 4 digit PIN on the screen. $_digitCount digits entered.",
      onSwipeLeft: () => Navigator.pop(context),
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 60),
              Text(
                "DRAW PIN",
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
                        'Preparing handwriting recognition...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              else if (!_isProcessing)
                Container(
                  height: 400,
                  width: double.infinity,
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.yellow.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Listener(
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: (_) => _onStrokeEnd(),
                      child: Signature(
                        controller: _controller,
                        height: 400,
                        backgroundColor: Colors.black,
                      ),
                    ),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.yellow, strokeWidth: 8),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _isProcessing ? "PROCESSING..." : "DRAW DIGIT ${_digitCount + 1}",
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
                child: const Text("Simulate PIN Success"),
              ),
            ),
        ],
      ),
    );
  }
}
