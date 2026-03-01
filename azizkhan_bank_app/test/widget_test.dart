import 'package:flutter_test/flutter_test.dart';

import 'package:azizkhan_bank_app/main.dart';

void main() {
  testWidgets('Phone screen is displayed', (WidgetTester tester) async {
    await tester.pumpWidget(const AzizkhanBankApp());

    expect(find.text('Phone Login'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
  });
}
