import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:test/test.dart';

Map<String, dynamic> packet() => {
  'schemaVersion': 1,
  'configurationId': 'session',
  'frameId': 'frame',
  'timestamp': 0,
  'imageWidth': 480,
  'imageHeight': 640,
  'displayRotationDegrees': 90,
  'front': true,
  'people': [],
  'faces': [],
  'peopleStatus': 'valid',
  'faceStatus': 'unavailable',
  'motionStatus': 'unsupported',
};
void main() {
  test(
    'Multi-face group coverage remains separate from a single pose extent',
    () {
      final data = packet()
        ..['faceStatus'] = 'valid'
        ..['groupScope'] = 'faces'
        ..['faces'] = [
          {
            'x': .2,
            'y': .2,
            'width': .1,
            'height': .1,
            'confidence': .9,
            'label': 'face',
          },
          {
            'x': .6,
            'y': .2,
            'width': .1,
            'height': .1,
            'confidence': .9,
            'label': 'face',
          },
        ];
      final frame = NativeFrame(data);
      expect(frame.groupAvailable, isTrue);
      expect(frame.measurements.groupAnalysis!.peopleCount, 2);
      expect(frame.measurements.groupAnalysis!.faceCount, 2);
      expect(
        SituationClassifier.candidate(frame.situationSignals),
        PhotographicSituation.group,
      );
      data['faceStatus'] = 'unavailable';
      expect(
        NativeFrame(data).frame.groupAnalysis.status,
        MeasurementStatus.unavailable,
      );
    },
  );
  test('Normalized joints and facial analysis reach coaching measurements', () {
    final data = packet()
      ..['poseStatus'] = 'valid'
      ..['poseKeypoints'] = {
        'leftShoulder': {'x': .3, 'y': .3, 'confidence': .9},
        'rightShoulder': {'x': .7, 'y': .4, 'confidence': .9},
      }
      ..['faceAnalysis'] = {
        'confidence': .9,
        'landmarkPointCount': 26,
        'eyeVisibilityScore': 1,
        'occlusionScore': 0,
        'yawEstimate': .1,
        'pitchEstimate': .2,
      };
    final frame = NativeFrame(data);
    expect(frame.frame.poseKeypoints.value!.length, 2);
    expect(
      frame.measurements.poseAnalysis!.shoulderLineAngleDegrees,
      closeTo(14.036243, 1e-6),
    );
    expect(
      frame.measurements.poseAnalysis!.shoulderHeightAsymmetry,
      closeTo(.1, 1e-9),
    );
    expect(frame.measurements.poseAnalysis!.wristToFaceDistance, isNull);
    expect(frame.measurements.faceAnalysis!.yawEstimate, .1);
  });
  test('Optional scene signals preserve availability and luminance units', () {
    final data = packet()
      ..['saliencyStatus'] = 'valid'
      ..['salientObject'] = {
        'x': .2,
        'y': .2,
        'width': .5,
        'height': .5,
        'confidence': .8,
        'label': 'object',
      }
      ..['horizonStatus'] = 'valid'
      ..['horizon'] = {'angleDegrees': 5, 'normalizedY': .5}
      ..['horizonConfidence'] = .8
      ..['backgroundLuminance'] = .5
      ..['luminanceScale'] = 1;
    final value = NativeFrame(data);
    expect(value.situationSignals.saliencyAvailable, isTrue);
    expect(value.situationSignals.salientObject!.rect.area, .25);
    expect(value.measurements.backgroundLuminance, 127.5);
    expect(value.measurements.horizonAngleDegrees, 5);
    expect(value.frame.groupAnalysis.status, MeasurementStatus.unsupported);
    data['horizonStatus'] = 'unavailable';
    expect(
      NativeFrame(data).frame.horizon.status,
      MeasurementStatus.unavailable,
    );
  });
  test(
    'Empty detection, unavailable detector and missing sensor remain distinct',
    () {
      final value = NativeFrame(packet());
      expect(value.frame.people.status, MeasurementStatus.valid);
      expect(value.frame.faces.status, MeasurementStatus.unavailable);
      expect(value.frame.motion.status, MeasurementStatus.unsupported);
      expect(value.frame.horizon.status, MeasurementStatus.unsupported);
      expect(value.aspectRatio, .75);
      expect(value.frame.mirrored, isTrue);
      expect(value.measurements.skyOrOpenAreaRatio, 1);
      expect(FrameAnalysis.fromJson(value.frame.toJson()).frameId, 'frame');
    },
  );
  test(
    'Unknown packet version is rejected rather than interpreted as no person',
    () {
      expect(
        () => NativeFrame(packet()..['schemaVersion'] = 2),
        throwsFormatException,
      );
    },
  );
}
