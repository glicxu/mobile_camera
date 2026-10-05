import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:test/test.dart';

void main() {
  test('all 10 poses and 5 camera positions advance manually', () {
    expect(GuidedPose.values.map((p) => p.id).toSet(), hasLength(10));
    expect(GuidedCameraPosition.values.map((p) => p.id).toSet(), hasLength(5));
    for (final pose in GuidedPose.values) {
      for (final position in GuidedCameraPosition.values) {
        final session = GuidedSession(pose: pose, position: position);
        final count = session.steps.length;
        expect(session.currentStep!.recipient, 'Photographer');
        for (var step = 0; step < count; step++) {
          expect(session.stepIndex, step);
          expect(session.isComplete, isFalse);
          expect(
            session.currentStep!.completion,
            GuidedCompletion.userConfirmed,
          );
          session.advance();
        }
        expect(session.isComplete, isTrue);
        session.advance();
        expect(session.stepIndex, count);
        expect(session.advice!.tone, AdviceTone.waiting);
      }
    }
  });

  test('urgent framing pauses and resumes the same creative step', () {
    final session = GuidedSession(pose: GuidedPose.walking);
    final engine = CoachingEngine();
    final now = DateTime(2026);
    final missing = engine.issues(
      const CoachingMeasurements(
        cameraRollDegrees: 0,
        cameraMotion: 0,
        cameraStable: true,
        skyOrOpenAreaRatio: 0,
      ),
    );
    engine.selectAdvice(
      session.prioritizedIssues(missing),
      now: now,
      fallback: session.advice,
    );
    expect(
      engine
          .selectAdvice(
            missing,
            now: now.add(const Duration(seconds: 2)),
            fallback: session.advice,
          )
          .type,
      'subject_missing',
    );
    expect(session.stepIndex, 0);
    engine.selectAdvice(
      [],
      now: now.add(const Duration(seconds: 4)),
      fallback: session.advice,
    );
    expect(
      engine.selectAdvice(
        [],
        now: now.add(const Duration(seconds: 6)),
        fallback: session.advice,
      ),
      session.advice,
    );
    expect(session.stepIndex, 0);
  });

  test('Natural and direction alternatives are explicit', () {
    expect(GuidedSession().advice, isNull);
    expect(
      GuidedCameraPosition.side.steps().last.instruction,
      contains('your left'),
    );
    expect(
      GuidedCameraPosition.side.steps(moveRight: true).last.instruction,
      contains('your right'),
    );
    expect(GuidedPose.overShoulder.conflicts, contains('face_missing'));
    expect(GuidedPose.walking.conflicts, contains('camera_unstable'));
    expect(GuidedPose.seatedAngle.conflicts, contains('feet_cropped'));
  });

  test('reset drops the previous sequence instruction', () {
    final engine = CoachingEngine();
    final now = DateTime(2026);
    final first = GuidedSession(pose: GuidedPose.walking);
    engine.selectAdvice([], now: now, fallback: first.advice);
    engine.selectAdvice(
      [],
      now: now.add(const Duration(seconds: 2)),
      fallback: first.advice,
    );
    engine.reset();
    final second = GuidedSession(pose: GuidedPose.overShoulder);
    expect(
      engine.selectAdvice(
        [],
        now: now.add(const Duration(seconds: 3)),
        fallback: second.advice,
      ),
      isNot(first.advice),
    );
    expect(
      engine.selectAdvice(
        [],
        now: now.add(const Duration(seconds: 5)),
        fallback: second.advice,
      ),
      second.advice,
    );
  });
}
