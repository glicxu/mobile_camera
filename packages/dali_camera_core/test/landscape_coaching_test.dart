import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:test/test.dart';

void main() {
  test('Landscape instruments stabilize warnings and hold a green result', () {
    final state = LandscapeInstrumentState();
    final start = DateTime.utc(2026);
    SituationSignals signals(double angle, double motion) => SituationSignals(
      horizon: HorizonAnalysis(angleDegrees: angle, normalizedY: .5),
      horizonConfidence: .8,
      motion: MotionAnalysis(
        rollDegrees: angle,
        magnitude: motion,
        stable: motion < .22,
      ),
    );

    state.update(signals(4, .3), backgroundLuminance: 40, now: start);
    expect(state.horizonNeedsAttention, isFalse);
    expect(state.stabilityNeedsAttention, isFalse);
    expect(state.exposureNeedsAttention, isFalse);

    state.update(
      signals(4, .3),
      backgroundLuminance: 40,
      now: start.add(const Duration(seconds: 1)),
    );
    expect(state.horizonNeedsAttention, isTrue);
    expect(state.stabilityNeedsAttention, isTrue);
    expect(state.exposureNeedsAttention, isTrue);

    for (var index = 0; index < 4; index++) {
      state.update(
        signals(0, 0),
        backgroundLuminance: 128,
        now: start.add(Duration(milliseconds: 2000 + index * 100)),
      );
    }
    state.update(
      signals(0, 0),
      backgroundLuminance: 128,
      now: start.add(const Duration(milliseconds: 3400)),
    );
    expect(state.horizonNeedsAttention, isFalse);
    expect(state.stabilityNeedsAttention, isFalse);
    expect(state.exposureNeedsAttention, isFalse);

    state.update(
      signals(12, .4),
      backgroundLuminance: 230,
      now: start.add(const Duration(milliseconds: 3500)),
    );
    expect(
      state.horizonNeedsAttention,
      isFalse,
      reason: 'A newly green state is held instead of flickering amber',
    );
  });

  test(
    'Landscape creative suggestion changes only after a sustained scene',
    () {
      final coach = LandscapeCreativeCoach();
      final start = DateTime.utc(2026);
      expect(
        coach.update(const SituationSignals(), now: start).title,
        'Build depth in the scene',
      );
      const open = SituationSignals(openAreaRatio: .8);
      expect(
        coach.update(open, now: start.add(const Duration(seconds: 3))).title,
        'Build depth in the scene',
      );
      expect(
        coach.update(open, now: start.add(const Duration(seconds: 8))).title,
        'Use the open sky deliberately',
      );
      expect(
        coach
            .update(
              const SituationSignals(openAreaRatio: .55),
              now: start.add(const Duration(seconds: 20)),
            )
            .title,
        'Use the open sky deliberately',
        reason: 'Open-sky hysteresis prevents threshold chatter',
      );
    },
  );
}
