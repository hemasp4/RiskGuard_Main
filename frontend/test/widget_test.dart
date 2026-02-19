import 'package:flutter_test/flutter_test.dart';
import 'package:personal/main.dart';

void main() {
  testWidgets('RiskGuard app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RiskGuardApp());

    // Verify that RiskGuard title is displayed.
    expect(find.text('RiskGuard'), findsOneWidget);
  });
}
