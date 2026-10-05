import 'dart:convert';

import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:test/test.dart';

void main() {
  test('FrameAnalysis v1 JSON round-trips explicit measurement states', () {
    final frame = FrameAnalysis(
      frameId: 'ios-42',
      timestamp: DateTime.utc(2026, 8, 24, 12, 30),
      imageWidth: 1920,
      imageHeight: 1080,
      displayRotationDegrees: 90,
      lensFacing: LensFacing.front,
      mirrored: true,
      people: const Measured.valid([
        DetectionBox(
          rect: NormalizedRect(x: 0.2, y: 0.1, width: 0.5, height: 0.8),
          confidence: 0.91,
          label: 'person',
        ),
      ], confidence: 0.91),
      faces: const Measured.lowConfidence([], confidence: 0.2),
      poseKeypoints: const Measured.unsupported(),
      groupAnalysis: const Measured.unavailable(),
      faceAnalysis: const Measured.unavailable(),
      horizon: const Measured.unsupported(),
      luminance: const Measured.valid(
        LuminanceAnalysis(face: 80, background: 100),
      ),
      openAreaRatio: const Measured.valid(0.32, confidence: 0.7),
      motion: const Measured.valid(
        MotionAnalysis(rollDegrees: 1.2, magnitude: 0.02, stable: true),
      ),
      detectorStatus: const {
        'person': DetectorState.ready,
        'pose': DetectorState.unsupported,
      },
    );

    final json = jsonDecode(jsonEncode(frame.toJson())) as Map<String, Object?>;
    final decoded = FrameAnalysis.fromJson(json);

    expect(decoded.schemaVersion, 1);
    expect(decoded.people.value!.single.rect.maxY, closeTo(0.9, 0.000001));
    expect(decoded.faces.status, MeasurementStatus.lowConfidence);
    expect(decoded.poseKeypoints.status, MeasurementStatus.unsupported);
    expect(decoded.groupAnalysis.status, MeasurementStatus.unavailable);
    expect(decoded.mirrored, isTrue);
    expect(decoded.detectorStatus['pose'], DetectorState.unsupported);
  });

  test('unknown schemas fail instead of being silently accepted', () {
    expect(
      () => FrameAnalysis.fromJson({'schemaVersion': 2}),
      throwsFormatException,
    );
  });
}
