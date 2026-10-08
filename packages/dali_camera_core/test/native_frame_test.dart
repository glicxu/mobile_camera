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
