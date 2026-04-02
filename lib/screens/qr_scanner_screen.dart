import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/accessibility_provider.dart';
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

  @override
  void initState() {
    super.initState();

    // Initial voice instruction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accessibilityProvider.notifier).speak(
          "Camera active. Please move your phone to align the QR code in the center.");
    });

    // Continuous vibration feedback
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isDetected) {
        ref.read(accessibilityProvider.notifier).vibrateShort();
      }
    });
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isDetected) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final corners = barcode.corners;

    if (corners.isEmpty) return;

    _processAlignment(corners);
  }

  void _processAlignment(List<Offset> corners) {
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
      _onDetected();
    }
  }

  void _updateGuidance(String text) {
    if (_guidanceText == text) return;

    setState(() {
      _guidanceText = text;
    });

    // Avoid repeating same speech
    if (_lastSpoken != text) {
      _lastSpoken = text;
      ref.read(accessibilityProvider.notifier).speak(text);
    }
  }

  void _onDetected() {
    setState(() {
      _isDetected = true;
      _guidanceText = "QR DETECTED";
    });

    _heartbeatTimer?.cancel();

    ref.read(accessibilityProvider.notifier).vibrateLong();

    ref.read(accessibilityProvider.notifier).speak(
        "QR code detected successfully. Merchant is Sharma Grocery. Swipe right to enter amount.");
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
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
          // CAMERA
          if (!kIsWeb)
            MobileScanner(
              onDetect: _handleBarcode,
            )
          else
            _buildWebMock(),

          // SCAN BOX
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

          // GUIDANCE TEXT
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

  Widget _buildWebMock() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Text(
          "Camera not available on web.\nUse mobile for full experience.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
