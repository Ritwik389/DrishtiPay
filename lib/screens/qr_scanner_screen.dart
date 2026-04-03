import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../providers/accessibility_provider.dart';
import '../utils/voice_back.dart';
import '../widgets/accessible_layout.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: true,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final SpeechToText _voiceBack = SpeechToText();

  Timer? _heartbeatTimer;

  bool _isDetected = false;
  bool _navigated = false;
  bool _voiceReady = false;
  bool _voiceListening = false;
  bool _ttsBusy = false;

  String _guidanceText = "CENTERING...";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _startHeartbeat();
      await _speak("Camera active. Move your phone to align the QR code. $kVoiceBackHint");
      await _initVoiceBack();
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isDetected) {
        ref.read(accessibilityProvider.notifier).vibrateShort();
      }
    });
  }

  Future<void> _initVoiceBack() async {
    if (!mounted) return;
    try {
      _voiceReady = await _voiceBack.initialize(
        onError: (e) => debugPrint('QR back STT: $e'),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _voiceListening = false;
            if (mounted && !_isDetected && !_ttsBusy) {
              Future.delayed(const Duration(milliseconds: 500), _listenForBack);
            }
          }
        },
      );
    } catch (e) {
      debugPrint('QR back init error: $e');
      _voiceReady = false;
    }
    if (_voiceReady && mounted) {
      _listenForBack();
    }
  }

  Future<void> _listenForBack() async {
    if (!_voiceReady || !mounted || _voiceListening || _ttsBusy) return;
    _voiceListening = true;
    await _voiceBack.listen(
      onResult: _onVoiceBackResult,
      listenFor: const Duration(seconds: 120),
      pauseFor: const Duration(seconds: 5),
      localeId: 'en_IN',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _onVoiceBackResult(SpeechRecognitionResult result) {
    if (!result.finalResult || !mounted) return;
    if (!isVoiceBackCommand(result.recognizedWords)) return;
    _voiceBack.stop();
    Navigator.pop(context);
  }

  Future<void> _speak(String text) async {
    if (!mounted) return;
    setState(() => _ttsBusy = true);
    final notifier = ref.read(accessibilityProvider.notifier);
    await notifier.stop();
    await notifier.speakAndWait(text);
    if (mounted) {
      setState(() => _ttsBusy = false);
    }
    _listenForBack();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isDetected || !mounted) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final rawValue = barcode.rawValue!;
    if (rawValue.isEmpty) return;

    _scannerController.stop();
    _voiceBack.stop();
    _heartbeatTimer?.cancel();

    setState(() {
      _isDetected = true;
      _guidanceText = "QR DETECTED";
    });

    final upiParams = _parseUpiQr(rawValue);
    final upiId = upiParams['pa'] ?? rawValue;
    final merchantName = upiParams['pn'] ?? 'Merchant';

    ref.read(upiIdProvider.notifier).state = upiId;
    ref.read(merchantNameProvider.notifier).state = merchantName;

    ref.read(accessibilityProvider.notifier).vibrateLong();

    _speak("QR detected. Paying to $merchantName. Say the amount.").then((_) {
      if (mounted && !_navigated) {
        _navigated = true;
        Navigator.pushNamed(context, '/amount');
      }
    });
  }

  Map<String, String?> _parseUpiQr(String raw) {
    try {
      final uri = Uri.parse(raw);
      return {
        'pa': uri.queryParameters['pa'],
        'pn': uri.queryParameters['pn'],
        'am': uri.queryParameters['am'],
        'tn': uri.queryParameters['tn'],
      };
    } catch (_) {
      return {};
    }
  }

  @override
  void dispose() {
    _voiceBack.stop();
    _heartbeatTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AccessibleLayout(
      onActivateSpeak: _isDetected
          ? "QR detected. Swipe right to proceed."
          : "Align QR code in the center of the screen.",
      onSwipeRight: () {
        if (_isDetected && !_navigated) {
          _navigated = true;
          Navigator.pushNamed(context, '/amount');
        }
      },
      onSwipeLeft: () => Navigator.pop(context),
      child: Stack(
        children: [
          // Scanner fills entire screen
          MobileScanner(
            controller: _scannerController,
            onDetect: _onBarcodeDetected,
            errorBuilder: (context, error) {
              return Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined, color: Colors.yellow, size: 54),
                  const SizedBox(height: 12),
                  Text(
                    'Camera start failed. Tap retry.',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _scannerController.stop();
                      } catch (_) {}
                      try {
                        await _scannerController.start();
                        _startHeartbeat();
                      } catch (e) {
                        await _speak("Camera could not start. Please reopen this screen.");
                      }
                    },
                    child: const Text('Retry Camera'),
                  ),
                ],
              ),
              );
            },
          ),

          // Scan box overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isDetected ? Colors.green : Colors.yellow,
                  width: 6,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isDetected
                  ? const Icon(Icons.check_circle,
                      color: Colors.green, size: 100)
                  : null,
            ),
          ),

          // Guidance text
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black.withValues(alpha: 0.8),
              child: Text(
                _guidanceText,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _isDetected ? Colors.green : Colors.yellow,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}