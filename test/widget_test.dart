import 'package:flutter_test/flutter_test.dart';
import 'package:drishtipay/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('DrishtiPay home renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DrishtiPayApp()));

    expect(find.text('DrishtiPay Wallet'), findsOneWidget);
    expect(find.text('Scan & Pay'), findsOneWidget);
  });
}
