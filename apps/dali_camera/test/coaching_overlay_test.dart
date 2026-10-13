import 'package:dali_camera/coaching_overlay.dart';
import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget overlay(Advice advice) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 390,
        height: 600,
        child: CoachingOverlay(
          advice: advice,
          visualFirst: true,
          animate: false,
        ),
      ),
    ),
  );

  testWidgets('portrait guidance uses a visual cue without repeated text', (
    tester,
  ) async {
    await tester.pumpWidget(
      overlay(
        const Advice(
          type: 'subject_too_far',
          recipient: 'Photographer',
          instruction: 'Step closer',
          tone: AdviceTone.warning,
        ),
      ),
    );

    expect(find.byKey(const Key('portraitVisualDistance')), findsOneWidget);
    expect(find.text('Step closer'), findsNothing);
  });

  testWidgets('portrait guidance has distinct framing and ready states', (
    tester,
  ) async {
    await tester.pumpWidget(
      overlay(
        const Advice(
          type: 'subject_missing',
          recipient: 'Photographer',
          instruction: 'Frame the person',
          tone: AdviceTone.danger,
        ),
      ),
    );
    expect(find.byKey(const Key('portraitVisualFrame')), findsOneWidget);

    await tester.pumpWidget(
      overlay(
        const Advice(
          type: 'ready',
          recipient: 'Camera',
          instruction: 'Great shot',
          tone: AdviceTone.ready,
        ),
      ),
    );
    expect(find.byKey(const Key('portraitVisualReady')), findsOneWidget);
  });
}
