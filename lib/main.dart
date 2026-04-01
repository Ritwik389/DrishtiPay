import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/standard_wallet_screen.dart';
import 'screens/input_selection_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/voice_amount_screen.dart';
import 'screens/pin_canvas_screen.dart';
import 'screens/success_screen.dart';

void main() {
  runApp(const ProviderScope(child: DrishtiPayApp()));
}

class DrishtiPayApp extends StatelessWidget {
  const DrishtiPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DrishtiPay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const StandardWalletScreen(),
        '/selection': (context) => const InputSelectionScreen(),
        '/scanner': (context) => const QrScannerScreen(),
        '/amount': (context) => const VoiceAmountScreen(),
        '/pin': (context) => const PinCanvasScreen(),
        '/success': (context) => const SuccessScreen(),
      },
    );
  }
}
