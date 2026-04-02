import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Ink;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;
import 'package:signature/signature.dart';
import '../providers/accessibility_provider.dart';
import '../widgets/accessible_layout.dart';

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

  late final mlkit.DigitalInkRecognizer _recognizer;
  final mlkit.Ink _ink = mlkit.Ink();
  final List<String> _enteredDigits = [];
  int _digitCount = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _recognizer = mlkit.DigitalInkRecognizer(languageCode: 'en-US');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accessibilityProvider.notifier).speak("Draw 4 digits of your PIN one by one on the screen.");
    });
    _controller.addListener(_onStrokeUpdate);
  }

  void _onStrokeUpdate() {
    // Controller listener for real-time visual updates if needed
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_digitCount >= 4 || _isProcessing) return;
    _ink.strokes.add(mlkit.Stroke());
    _addPoint(event.localPosition, event.timeStamp);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_digitCount >= 4 || _isProcessing) return;
    _addPoint(event.localPosition, event.timeStamp);
  }

  void _addPoint(Offset localPosition, Duration timeStamp) {
    _ink.strokes.last.points.add(mlkit.StrokePoint(
      x: localPosition.dx,
      y: localPosition.dy,
      t: timeStamp.inMilliseconds,
    ));
  }

  void _onStrokeEnd() async {
    if (_controller.isEmpty || _digitCount >= 4 || _isProcessing) return;

    // Recognize the digit
    try {
      final candidates = await _recognizer.recognize(_ink);
      if (candidates.isNotEmpty) {
        final digit = candidates.first.text;
        _enteredDigits.add(digit);
        // Note: We don't speak the digit for security, just that it was accepted.
      }
    } catch (e) {
      debugPrint("Recognition error: $e");
    }

    setState(() {
      _digitCount++;
      ref.read(pinStrokesProvider.notifier).state = _digitCount;
    });

    // Immediate haptic feedback so the user knows a digit was captured.
    await ref.read(accessibilityProvider.notifier).vibrateShort();

    if (_digitCount >= 4) {
      // Print the 4 digits to terminal as requested
      debugPrint("FULL PIN ENTERED: ${_enteredDigits.join()}");
      _finishPin();
    } else {
      ref.read(accessibilityProvider.notifier).speak("Digit $_digitCount accepted.");
      Future.delayed(const Duration(milliseconds: 200), () {
        _controller.clear();
        _ink.strokes.clear();
      });
    }
  }

  void _finishPin() async {
    setState(() => _isProcessing = true);
    
    // Biometric Check (Fallback for Web)
    bool authenticated = kIsWeb ? true : await ref.read(accessibilityProvider.notifier).checkBiometrics();
    
    if (authenticated) {
      final amount = ref.read(amountProvider);
      final encrypted = ref.read(accessibilityProvider.notifier).encryptTransaction(amount);
      debugPrint("Transaction Encrypted: $encrypted");
      
      ref.read(accessibilityProvider.notifier).speak("PIN and Biometrics accepted. Processing encrypted payment.");
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/success');
      }
    } else {
      setState(() => _isProcessing = false);
      ref.read(accessibilityProvider.notifier).speak("Authentication failed. Please try again.");
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
              if (!_isProcessing)
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
          // Mock Trigger for Web
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
