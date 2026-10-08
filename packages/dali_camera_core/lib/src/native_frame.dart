import 'frame_analysis.dart';
import 'models.dart';

/// Compact bridge payload v1 is converted into the existing public contract.
/// An unavailable detector is different from a successful empty detection.
class NativeFrame {
  NativeFrame(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported native frame schema');
    }
    configurationId = json['configurationId'] as String;
    Measured<List<DetectionBox>> boxes(String key, String status) {
      if (json[status] == 'unsupported') return const Measured.unsupported();
      if (json[status] != 'valid') return const Measured.unavailable();
      return Measured.valid(
        (json[key] as List).map((value) {
          final box = value as Map<String, dynamic>;
          return DetectionBox(
            rect: NormalizedRect.fromJson(box),
            confidence: (box['confidence'] as num).toDouble(),
            label: box['label'] as String,
          );
        }).toList(),
      );
    }

    final people = boxes('people', 'peopleStatus');
    final faces = boxes('faces', 'faceStatus');
    DetectorState detector(Measured<List<DetectionBox>> value) => value.isUsable
        ? DetectorState.ready
        : value.status == MeasurementStatus.unsupported
        ? DetectorState.unsupported
        : DetectorState.unavailable;
    frame = FrameAnalysis(
      frameId: json['frameId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int,
        isUtc: true,
      ),
      imageWidth: json['imageWidth'] as int,
      imageHeight: json['imageHeight'] as int,
      displayRotationDegrees: json['displayRotationDegrees'] as int,
      lensFacing: json['front'] == true ? LensFacing.front : LensFacing.back,
      mirrored: json['front'] == true,
      people: people,
      faces: faces,
      poseKeypoints: const Measured.unsupported(),
      groupAnalysis: const Measured.unsupported(),
      faceAnalysis: const Measured.unsupported(),
      horizon: const Measured.unsupported(),
      luminance: json['backgroundLuminance'] == null
          ? const Measured.unavailable()
          : Measured.valid(
              LuminanceAnalysis(
                background: (json['backgroundLuminance'] as num).toDouble(),
              ),
            ),
      openAreaRatio: const Measured.unsupported(),
      motion: json['motionStatus'] == 'valid'
          ? Measured.valid(
              MotionAnalysis(
                rollDegrees: (json['roll'] as num).toDouble(),
                magnitude: (json['motion'] as num).toDouble(),
                stable: json['stable'] as bool,
              ),
            )
          : const Measured.unsupported(),
      detectorStatus: {'people': detector(people), 'faces': detector(faces)},
    );
  }
  late final String configurationId;
  late final FrameAnalysis frame;
  double get aspectRatio => frame.imageWidth / frame.imageHeight;
  CoachingMeasurements get measurements => CoachingMeasurements(
    personBox: frame.people.value?.firstOrNull,
    faceBox: frame.faces.value?.firstOrNull,
    backgroundLuminance: frame.luminance.value?.background,
    cameraRollDegrees: frame.motion.value?.rollDegrees ?? 0,
    cameraMotion: frame.motion.value?.magnitude ?? 0,
    cameraStable: frame.motion.value?.stable ?? true,
    // Unsupported scenic measurement must not become a false "scene excluded".
    skyOrOpenAreaRatio: 1,
  );
}
