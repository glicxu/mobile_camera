import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:test/test.dart';

DetectionBox box(double x, double y, double w, double h) => DetectionBox(
  rect: NormalizedRect(x: x, y: y, width: w, height: h),
  confidence: .9,
  label: 'fixture',
);
void main() {
  test('Auto requires consecutive candidates and holds ambiguous scenes', () {
    final classifier = SituationClassifier();
    final portrait = SituationSignals(person: box(.25, .2, .5, .6));
    expect(classifier.update(portrait), PhotographicSituation.personScene);
    classifier.update(const SituationSignals());
    classifier.update(portrait);
    expect(classifier.update(portrait), PhotographicSituation.personScene);
    expect(classifier.update(portrait), PhotographicSituation.portrait);
    expect(
      classifier.update(const SituationSignals()),
      PhotographicSituation.portrait,
    );
  });
  test(
    'Auto priority follows group, moving person, portrait, scenery and detail',
    () {
      expect(
        SituationClassifier.candidate(
          SituationSignals(
            person: box(.2, .1, .5, .8),
            faceCount: 2,
            subjectMotion: .3,
          ),
        ),
        PhotographicSituation.group,
      );
      expect(
        SituationClassifier.candidate(
          SituationSignals(person: box(.2, .1, .5, .8), subjectMotion: .3),
        ),
        PhotographicSituation.action,
      );
      expect(
        SituationClassifier.candidate(
          SituationSignals(person: box(.4, .4, .1, .2)),
        ),
        PhotographicSituation.personScene,
      );
      expect(
        SituationClassifier.candidate(
          const SituationSignals(horizonConfidence: .5),
        ),
        PhotographicSituation.landscape,
      );
      expect(
        SituationClassifier.candidate(
          SituationSignals(salientObject: box(.2, .2, .5, .5)),
        ),
        PhotographicSituation.closeUp,
      );
      expect(SituationClassifier.candidate(const SituationSignals()), isNull);
    },
  );
  test('Unsupported sensors and detectors never produce ready guidance', () {
    for (final mode in [
      PhotographicSituation.group,
      PhotographicSituation.action,
      PhotographicSituation.food,
      PhotographicSituation.closeUp,
    ]) {
      expect(
        situationGuidance(mode, const SituationSignals()).tone,
        AdviceTone.waiting,
      );
    }
    expect(
      situationGuidance(
        PhotographicSituation.landscape,
        const SituationSignals(
          motion: MotionAnalysis(rollDegrees: 8, magnitude: 0, stable: true),
        ),
      ).title,
      'Level the camera',
    );
  });
  test('Group edge and spacing rules use all multi-person boxes', () {
    final group = analyzeGroup(
      [box(.01, .1, .2, .6), box(.7, .1, .2, .6)],
      [box(.04, .1, .1, .1), box(.75, .1, .1, .1)],
    )!;
    expect(group.edgeCrowdingScore, greaterThan(.35));
    expect(group.peopleCount, 2);
    expect(
      situationGuidance(
        PhotographicSituation.group,
        SituationSignals(group: group),
      ).title,
      'Leave space at the edges',
    );
  });
  test(
    'Subject motion rejects old frames, camera movement and missing sensors',
    () {
      final tracker = SubjectMotionTracker();
      const motion = MotionAnalysis(rollDegrees: 0, magnitude: 0, stable: true);
      final start = DateTime.utc(2026);
      expect(
        tracker.update(
          SituationSignals(person: box(.1, .1, .2, .4), motion: motion),
          start,
        ),
        isNull,
      );
      expect(
        tracker.update(
          SituationSignals(person: box(.2, .1, .2, .4), motion: motion),
          start.add(const Duration(milliseconds: 200)),
        ),
        closeTo(.5, .001),
      );
      expect(
        tracker.update(
          SituationSignals(person: box(.3, .1, .2, .4), motion: motion),
          start.add(const Duration(seconds: 2)),
        ),
        isNull,
      );
      tracker.reset();
      expect(
        tracker.update(SituationSignals(person: box(.3, .1, .2, .4)), start),
        isNull,
      );
    },
  );
}
