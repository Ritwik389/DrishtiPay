import 'dart:async';
import 'package:flutter/foundation.dart';
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
  Timer? _heartbeatTimer;
  bool _isDetected = false;
  String _guidanceText = "CENTERING...";
  String? _lastSpoken;
  String? _qrPayload;
  bool _qrHandled = false;

  late final MobileScannerController _scannerController;

  final SpeechToText _stt = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(accessibilityProvider.notifier).speakAndWait(
          "Camera active. Please move your phone to align the QR code in the center.");
      await _initVoiceBack();
    });

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isDetected) {
        ref.read(accessibilityProvider.notifier).vibrateShort();
      }
    });
  }

  Future<void> _initVoiceBack() async {
    if (kIsWeb) return;
    try {
      _speechReady = await _stt.initialize(
        onError: (e) => debugPrint('QR screen STT: $e'),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _listening = false;
            if (mounted && !_isDetected) {
              Future.delayed(const Duration(milliseconds: 400), _listenForBack);
            }
          }
        },
      );
    } catch (e) {
      debugPrint('QR screen STT init: $e');
      _speechReady = false;
    }
    if (_speechReady && mounted) _listenForBack();
  }

  void _listenForBack() async {
    if (!_speechReady || !mounted || _isDetected || _listening) return;
    _listening = true;
    await _stt.listen(
      onResult: _onVoice,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
      listenMode: ListenMode.dictation,
      localeId: 'en_IN',
    );
  }

  void _onVoice(SpeechRecognitionResult result) {
    if (!result.finalResult) return;
    if (isVoiceBackCommand(result.recognizedWords)) {
      _stt.stop();
      if (mounted) Navigator.pop(context);
    }
  }

  Barcode? _firstValidQr(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      if (b.format == BarcodeFormat.qrCode &&
          b.rawValue != null &&
          b.rawValue!.trim().isNotEmpty) {
        return b;
      }
    }
    return null;
  }

  String _payeeNameFromPayload(String raw) {
    final trimmed = raw.trim();
    if (trimmed.toLowerCase().startsWith('upi://')) {
      final uri = Uri.tryParse(trimmed);
      final pn = uri?.queryParameters['pn'];
      if (pn != null && pn.isNotEmpty) {
        try {
          return Uri.decodeComponent(pn.replaceAll('+', ' '));
        } catch (_) {
          return pn;
        }
      }
    }
    return 'Scanned QR';
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isDetected) return;

    final barcode = _firstValidQr(capture);
    if (barcode == null) return;

    final corners = barcode.corners;
    if (corners.isEmpty) {
      _onDetected(barcode.rawValue!.trim());
      return;
    }

    _processAlignment(corners, barcode.rawValue!.trim());
  }

  void _processAlignment(List<Offset> corners, String payload) {
    double sumX = 0;
    for (var corner in corners) {
      sumX += corner.dx;
    }

    final centerX = sumX / corners.length;
    final screenWidth = MediaQuery.of(context).size.width;

    if (centerX < screenWidth * 0.4) {
      _updateGuidance("Move phone slightly right");
    } else if (centerX > screenWidth * 0.6) {
      _updateGuidance("Move phone slightly left");
    } else {
      _onDetected(payload);
    }
  }

  void _updateGuidance(String text) {
    if (_guidanceText == text) return;

    setState(() {
      _guidanceText = text;
    });

    if (_lastSpoken != text) {
      _lastSpoken = text;
      ref.read(accessibilityProvider.notifier).speak(text);
    }
  }

  Future<void> _onDetected(String payload) async {
    if (_isDetected || _qrHandled) return;
    _qrHandled = true;

    setState(() {
      _isDetected = true;
      _guidanceText = "QR DETECTED";
      _qrPayload = payload;
    });

    _heartbeatTimer?.cancel();
    await _stt.stop();

    ref.read(accessibilityProvider.notifier).vibrateLong();

    final merchant = _payeeNameFromPayload(payload);
    ref.read(merchantNameProvider.notifier).state = merchant;

    debugPrint('[DrishtiPay] QR decoded (${payload.length} chars): $payload');

    await ref.read(accessibilityProvider.notifier).speakAndWait(
        "QR code detected successfully. Payee is $merchant. Swipe right to enter amount.");
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _scannerController.dispose();
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AccessibleLayout(
      onActivateSpeak: _isDetected
          ? "QR detected. Swipe right to proceed."
          : "Align QR code in the center.",
      onSwipeRight: () {
        if (_isDetected) {
          Navigator.pushNamed(context, '/amount');
        }
      },
      onSwipeLeft: () => Navigator.pop(context),
      child: Stack(
        children: [
          if (!kIsWeb)
            MobileScanner(
              controller: _scannerController,
              onDetect: _handleBarcode,
            )
          else
            _buildWebMock(),

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

          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black.withOpacity(0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _guidanceText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: _isDetected ? Colors.green : Colors.yellow,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_qrPayload != null && _isDetected)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _qrPayload!.length > 80
                            ? '${_qrPayload!.substring(0, 80)}…'
                            : _qrPayload!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebMock() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Text(
          "Camera not available on web.\nUse mobile for full experience.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
      ),
    );
  }
}
