import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/accessibility_provider.dart';

class StandardWalletScreen extends ConsumerWidget {
  const StandardWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const paytmBlue = Color(0xFF00B9F1);
    const paytmDarkBlue = Color(0xFF002E6E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: paytmBlue,
        title: Text(
          'DrishtiPay Wallet',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search, color: Colors.white)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.person_outline, color: Colors.white)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: paytmBlue.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _serviceItem(Icons.qr_code_scanner, "Scan & Pay"),
                  _serviceItem(Icons.contact_phone, "To Mobile"),
                  _serviceItem(Icons.account_balance, "To Bank"),
                  _serviceItem(Icons.history, "History"),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Recharge & Bill Payments",
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: paytmDarkBlue),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildGrid(),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Material(
        color: paytmDarkBlue,
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            ref.read(accessibilityProvider.notifier).activateDrishtiPay();
            Navigator.pushNamed(context, '/selection');
          },
          child: const SizedBox(
            width: 72,
            height: 72,
            child: Icon(Icons.mic, size: 40, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _serviceItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Icon(icon, color: const Color(0xFF00B9F1), size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      padding: const EdgeInsets.all(16),
      children: [
        _gridItem(Icons.phone_android, "Mobile"),
        _gridItem(Icons.lightbulb, "Electricity"),
        _gridItem(Icons.tv, "DTH"),
        _gridItem(Icons.credit_card, "Credit Card"),
        _gridItem(Icons.water_drop, "Water"),
        _gridItem(Icons.gas_meter, "Gas"),
        _gridItem(Icons.wifi, "Broadband"),
        _gridItem(Icons.more_horiz, "More"),
      ],
    );
  }

  Widget _gridItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600], size: 24),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[800]), textAlign: TextAlign.center),
      ],
    );
  }
}
