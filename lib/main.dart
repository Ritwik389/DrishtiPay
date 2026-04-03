import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/standard_wallet_screen.dart';
import 'screens/input_selection_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/voice_amount_screen.dart';
import 'screens/pin_canvas_screen.dart';
import 'screens/success_screen.dart';
import 'screens/upi_id_screen.dart';

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
        '/': (context) => const SplashScreen(),        // ← NEW entry point
        '/home': (context) => const StandardWalletScreen(), // ← was '/'
        '/selection': (context) => const InputSelectionScreen(),
        '/scanner': (context) => const QrScannerScreen(),
        '/upi': (context) => const UpiIdScreen(),
        '/amount': (context) => const VoiceAmountScreen(),
        '/pin': (context) => const PinCanvasScreen(),
        '/success': (context) => const SuccessScreen(),
      },
    );
  }
}