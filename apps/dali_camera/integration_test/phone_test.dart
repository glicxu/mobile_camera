import 'package:dali_camera/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real camera starts and references are selectable', (tester) async {
    await tester.pumpWidget(const DaliApp());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (tester.widget<FilledButton>(find.byKey(const Key('shutter'))).onPressed != null) break;
    }
    expect(tester.widget<FilledButton>(find.byKey(const Key('shutter'))).onPressed, isNotNull,
      reason: 'Camera readiness must be independent of subject detection');
    await tester.tap(find.text('Posture packages')); await tester.pumpAndSettle();
    expect(find.text('Male / Masculine'), findsOneWidget);
    await tester.tap(find.text('Male / Masculine')); await tester.pumpAndSettle();
    await tester.tap(find.text('Relaxed standing')); await tester.pumpAndSettle();
    await tester.tap(find.text('Use this reference')); await tester.pumpAndSettle();
    expect(find.text('Done / Next'), findsOneWidget);
    await tester.tap(find.text('Natural')); await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
