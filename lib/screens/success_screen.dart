import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/accessibility_provider.dart';
import '../widgets/accessible_layout.dart';

class SuccessScreen extends ConsumerStatefulWidget {
  const SuccessScreen({super.key});

  @override
  ConsumerState<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends ConsumerState<SuccessScreen> {
  @override
  void initState() {
    super.initState();
    _triggerSuccess();
  }

  void _triggerSuccess() {
    final amount = ref.read(amountProvider);
    final merchant = ref.read(merchantNameProvider);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accessibilityProvider.notifier).vibrateLong();
      ref.read(accessibilityProvider.notifier).speak(
          "Payment of $amount rupees to $merchant successful.");
    });
  }

  @override
  Widget build(BuildContext context) {
    final amount = ref.watch(amountProvider);
    final merchant = ref.watch(merchantNameProvider);

    return AccessibleLayout(
      onActivateSpeak: "Payment of $amount rupees to $merchant successful. Swipe left to return to wallet.",
      onSwipeLeft: () {
        ref.read(accessibilityProvider.notifier).deactivateDrishtiPay();
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      },
      child: Container(
        width: double.infinity,
        color: const Color(0xFF2E7D32), // Bright Success Green
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 200,
            ),
            const SizedBox(height: 40),
            Text(
              "PAYMENT\nSUCCESSFUL",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    "₹$amount",
                    style: GoogleFonts.inter(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "TO $merchant".toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text(
                "SWIPE LEFT TO RETURN",
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
