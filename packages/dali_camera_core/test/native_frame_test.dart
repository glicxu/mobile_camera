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
