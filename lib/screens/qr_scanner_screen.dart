import 'dart:async';
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
  final MobileScannerController _scannerController = MobileScannerController();

  Timer? _heartbeatTimer;

  bool _isDetected = false;
  bool _navigated = false;

  String _guidanceText = "CENTERING...";

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _speak("Camera active. Move your phone to align the QR code.");

      _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (!_isDetected) {
          ref.read(accessibilityProvider.notifier).vibrateShort();
        }
      });
    });
  }

  Future<void> _speak(String text) async {
    final notifier = ref.read(accessibilityProvider.notifier);
    await notifier.stop();
    await notifier.speakAndWait(text);
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isDetected || !mounted) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final rawValue = barcode.rawValue!;
    if (rawValue.isEmpty) return;

    _scannerController.stop();
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