import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:test/test.dart';

void main() {
  group('Swift coaching parity', () {
    test('Natural face direction preserves the measured side', () {
      for (final yaw in [0.55, -0.55]) {
        final issues = CoachingEngine().issues(
          _measurements(
            faceAnalysis: FaceAnalysis(
              confidence: 0.82,
              landmarkPointCount: 28,
              eyeVisibilityScore: 1,
              yawEstimate: yaw,
              pitchEstimate: 0.3,
              occlusionScore: 0.05,
            ),
          ),
        );
        expect(
          issues
              .firstWhere((issue) => issue.type == 'face_too_profile')
              .instruction,
          yaw > 0 ? 'Turn face slightly left' : 'Turn face slightly right',
        );
      }
    });
    test('subject missing produces danger issue', () {
      final issues = CoachingEngine().issues(_measurements(personBox: null));
      expect(issues.first.type, 'subject_missing');
      expect(issues.first.instruction, 'Frame the person');
      expect(issues.first.tone, AdviceTone.danger);
    });

    test('subject too close includes reason data', () {
      final issues = CoachingEngine().issues(
        _measurements(
          personBox: _box(0.08, 0.08, 0.78, 0.82, confidence: 0.9),
          faceBox: null,
        ),
      );
      final issue = issues.firstWhere(
        (item) => item.type == 'subject_too_close',
      );
      expect(issue.instruction, 'Step back');
      expect(issue.reasonData['person_area'], greaterThan(0.48));
    });

    test('horizon tilt uses horizon confidence', () {
      final issue = CoachingEngine()
          .issues(
            _measurements(horizonAngleDegrees: 5, horizonConfidence: 0.76),
          )
          .firstWhere((item) => item.type == 'horizon_tilted');
      expect(issue.instruction, 'Tilt left');
      expect(issue.confidence, 0.76);
    });

    test('lighting and posture rules match current vocabulary', () {
      final issues = CoachingEngine().issues(
        _measurements(
          faceLuminance: 45,
          backgroundLuminance: 150,
          poseAnalysis: const PoseAnalysis(
            confidence: 0.7,
            visibleKeypointCount: 8,
            wristToFaceDistance: 0.01,
            armVisibilityScore: 0.9,
            shouldersHighScore: 0.8,
          ),
          faceAnalysis: const FaceAnalysis(
            confidence: 0.82,
            landmarkPointCount: 28,
            eyeVisibilityScore: 0.5,
            yawEstimate: 0.55,
            pitchEstimate: 0.3,
            occlusionScore: 0.54,
          ),
        ),
      );
      expect(
        issues.firstWhere((item) => item.type == 'subject_backlit').instruction,
        'Face the light',
      );
      expect(
        issues.firstWhere((item) => item.type == 'hand_near_face').instruction,
        'Move hand from face',
      );
      expect(
        issues
            .firstWhere((item) => item.type == 'face_too_profile')
            .instruction,
        'Turn face slightly left',
      );
      expect(
        issues.firstWhere((item) => item.type == 'eyes_occluded').instruction,
        'Show your eyes',
      );
    });

    test('pose package changes advice vocabulary', () {
      const pose = PoseAnalysis(
        confidence: 0.7,
        visibleKeypointCount: 8,
        armVisibilityScore: 0.95,
        bodySquarenessScore: 0.95,
        armsFlatAgainstBodyScore: 0.82,
      );
      final feminine = CoachingEngine().issues(
        _measurements(poseAnalysis: pose),
        posePackage: PosePackageId.feminine,
      );
      final masculine = CoachingEngine().issues(
        _measurements(poseAnalysis: pose),
        posePackage: PosePackageId.masculine,
      );
      expect(
        feminine
            .firstWhere((item) => item.type == 'arms_flat_against_body')
            .instruction,
        'Create space at the waist',
      );
      expect(
        masculine
            .firstWhere((item) => item.type == 'body_too_square')
            .instruction,
        'Turn chin slightly, keep shoulders strong',
      );
    });

    test('group portrait package produces all group advice', () {
      final issues = CoachingEngine().issues(
        _measurements(
          groupAnalysis: const GroupAnalysis(
            peopleCount: 4,
            faceCount: 2,
            faceVisibilityRatio: 0.5,
            edgeCrowdingScore: 0.67,
            spacingScore: 2.1,
          ),
        ),
        posePackage: PosePackageId.groupPortrait,
      );
      expect(
        issues.map((issue) => issue.type),
        containsAll([
          'group_faces_missing',
          'group_edge_crowded',
          'group_spacing_wide',
        ]),
      );
    });

    test('ready advice waits for stable measurements', () {
      final engine = CoachingEngine();
      final start = DateTime.utc(2026);
      final unstable = engine.issues(
        _measurements(cameraMotion: 0.7, cameraStable: false),
      );
      expect(engine.selectAdvice(unstable, now: start).type, 'waiting');
      expect(
        engine
            .selectAdvice([], now: start.add(const Duration(milliseconds: 700)))
            .type,
        'waiting',
      );
      expect(
        engine
            .selectAdvice(
              [],
              now: start.add(const Duration(milliseconds: 1400)),
            )
            .type,
        'ready',
      );
    });
  });
}

const _defaultPerson = DetectionBox(
  rect: NormalizedRect(x: 0.32, y: 0.08, width: 0.3, height: 0.62),
  confidence: 0.88,
  label: 'person',
);
const _defaultFace = DetectionBox(
  rect: NormalizedRect(x: 0.41, y: 0.13, width: 0.1, height: 0.13),
  confidence: 0.82,
  label: 'face',
);

DetectionBox _box(
  double x,
  double y,
  double width,
  double height, {
  double confidence = 0.88,
}) => DetectionBox(
  rect: NormalizedRect(x: x, y: y, width: width, height: height),
  confidence: confidence,
  label: 'person',
);

CoachingMeasurements _measurements({
  DetectionBox? personBox = _defaultPerson,
  DetectionBox? faceBox = _defaultFace,
  GroupAnalysis? groupAnalysis,
  FaceAnalysis? faceAnalysis,
  PoseAnalysis? poseAnalysis,
  double? horizonAngleDegrees,
  double horizonConfidence = 0,
  double? faceLuminance = 120,
  double? backgroundLuminance = 130,
  double cameraMotion = 0.02,
  bool cameraStable = true,
}) => CoachingMeasurements(
  personBox: personBox,
  faceBox: faceBox,
  groupAnalysis: groupAnalysis,
  faceAnalysis: faceAnalysis,
  poseAnalysis: poseAnalysis,
  faceLuminance: faceLuminance,
  backgroundLuminance: backgroundLuminance,
  horizonAngleDegrees: horizonAngleDegrees,
  horizonConfidence: horizonConfidence,
  cameraRollDegrees: 0,
  cameraMotion: cameraMotion,
  cameraStable: cameraStable,
  skyOrOpenAreaRatio: 0.42,
);
