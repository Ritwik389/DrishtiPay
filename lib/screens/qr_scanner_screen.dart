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
  String? _lastGuidance;

  @override
  void initState() {
    super.initState();
    _startHeartbeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accessibilityProvider.notifier).speak("Camera active. Align the QR code in the center.");
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!_isDetected) {
        ref.read(accessibilityProvider.notifier).vibrateShort();
      }
    });
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isDetected) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final corners = barcode.corners;
    if (corners == null || corners.isEmpty) return;

    // TFLite Mock Inference: Analyze frame for alignment
    _runTFLiteInference(corners);
  }

  void _runTFLiteInference(List<Offset> corners) {
    double sumX = 0;
    for (var corner in corners) {
      sumX += corner.dx;
    }
    final centerX = sumX / corners.length;
    
    // Simulate TFLite confidence score
    final confidence = 0.95; 

    if (centerX < 350) {
      _triggerGuidance("AI Suggestions: Move Left");
    } else if (centerX > 650) {
      _triggerGuidance("AI Suggestions: Move Right");
    } else {
      if (confidence > 0.9) {
        _onDetected();
      }
    }
  }

  void _triggerGuidance(String guidance) {
    if (_lastGuidance == guidance) return;
    _lastGuidance = guidance;
    ref.read(accessibilityProvider.notifier).speak(guidance);
  }

  void _onDetected() {
    setState(() => _isDetected = true);
    _heartbeatTimer?.cancel();
    ref.read(accessibilityProvider.notifier).vibrateLong();
    ref.read(accessibilityProvider.notifier).speak(
        "QR Detected using M.L. Kit. Merchant is Sharma Grocery. Swipe right to enter amount.");
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
          ? "QR Detected. Merchant is Sharma Grocery. Swipe right to enter amount."
          : "Camera active. Align the QR code in the center.",
      onSwipeRight: () {
        if (_isDetected) {
          Navigator.pushNamed(context, '/amount');
        }
      },
      onSwipeLeft: () => Navigator.pop(context),
      child: Stack(
        children: [
          // Camera Feed
          if (!kIsWeb)
            MobileScanner(
              onDetect: _handleBarcode,
            )
          else
            _buildWebMock(),

          // Overlay Reticle
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isDetected ? Colors.green : Colors.yellow,
                  width: 8,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: _isDetected
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 100)
                  : null,
            ),
          ),

          // Guidance Text (Visible for sighted observers)
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black.withOpacity(0.8),
              child: Text(
                _isDetected ? "SHARMA GROCERY\nSWIPE RIGHT TO PAY" : (_lastGuidance ?? "CENTERING..."),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _isDetected ? Colors.green : Colors.yellow,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Web Mock Controls
          if (kIsWeb) _buildWebControls(),
        ],
      ),
    );
  }

  Widget _buildWebMock() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Icon(Icons.camera_alt, color: Colors.white.withOpacity(0.2), size: 150),
      ),
    );
  }

  Widget _buildWebControls() {
    return Positioned(
      top: 100,
      right: 20,
      child: Column(
        children: [
          _mockBtn("Mock Left", () => _triggerGuidance("Move Left")),
          const SizedBox(height: 10),
          _mockBtn("Mock Right", () => _triggerGuidance("Move Right")),
          const SizedBox(height: 10),
          _mockBtn("Mock Success", _onDetected),
        ],
      ),
    );
  }

  Widget _mockBtn(String text, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2)),
      onPressed: onPressed,
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}
