import 'frame_analysis.dart';
import 'models.dart';
import 'situations.dart';

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
    final group =
        json['peopleScope'] == 'multiple' && people.isUsable && faces.isUsable
        ? analyzeGroup(people.value!, faces.value!)
        : null;
    double? luminance(String key) => json[key] == null
        ? null
        : (json[key] as num).toDouble() *
              (json['luminanceScale'] == 255 ? 1 : 255);
    salientObject = json['salientObject'] == null
        ? null
        : DetectionBox(
            rect: NormalizedRect.fromJson(
              (json['salientObject'] as Map).cast<String, Object?>(),
            ),
            confidence: (json['salientObject']['confidence'] as num).toDouble(),
            label: json['salientObject']['label'] as String,
          );
    saliencyAvailable = json['saliencyStatus'] == 'valid';
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
      groupAnalysis: json['peopleScope'] != 'multiple'
          ? const Measured.unsupported()
          : group == null
          ? const Measured.unavailable()
          : Measured.valid(group),
      faceAnalysis: const Measured.unsupported(),
      horizon: json['horizonStatus'] == 'valid' && json['horizon'] != null
          ? Measured.valid(
              HorizonAnalysis.fromJson(
                (json['horizon'] as Map).cast<String, Object?>(),
              ),
              confidence: (json['horizonConfidence'] as num?)?.toDouble(),
            )
          : json['horizonStatus'] == 'unavailable'
          ? const Measured.unavailable()
          : const Measured.unsupported(),
      luminance:
          json['backgroundLuminance'] == null && json['faceLuminance'] == null
          ? const Measured.unavailable()
          : Measured.valid(
              LuminanceAnalysis(
                background: luminance('backgroundLuminance'),
                face: luminance('faceLuminance'),
              ),
            ),
      openAreaRatio:
          json['openAreaStatus'] == 'valid' && json['openAreaRatio'] != null
          ? Measured.valid((json['openAreaRatio'] as num).toDouble())
          : const Measured.unsupported(),
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
  late final DetectionBox? salientObject;
  late final bool saliencyAvailable;
  bool get groupAvailable =>
      frame.groupAnalysis.status != MeasurementStatus.unsupported &&
      frame.people.isUsable &&
      frame.faces.isUsable;
  SituationSignals get situationSignals => SituationSignals(
    person: frame.people.value?.firstOrNull,
    face: frame.faces.value?.firstOrNull,
    peopleAvailable: frame.people.isUsable,
    groupAvailable: groupAvailable,
    faceCount: frame.faces.value?.length ?? 0,
    group: frame.groupAnalysis.value,
    salientObject: salientObject,
    saliencyAvailable: saliencyAvailable,
    motion: frame.motion.value,
    horizon: frame.horizon.value,
    horizonConfidence: frame.horizon.confidence ?? 0,
    openAreaRatio: frame.openAreaRatio.value,
  );
  double get aspectRatio => frame.imageWidth / frame.imageHeight;
  CoachingMeasurements get measurements => CoachingMeasurements(
    personBox: frame.people.value?.firstOrNull,
    faceBox: frame.faces.value?.firstOrNull,
    groupAnalysis: frame.groupAnalysis.value,
    faceLuminance: frame.luminance.value?.face,
    horizonAngleDegrees: frame.horizon.value?.angleDegrees,
    horizonConfidence: frame.horizon.confidence ?? 0,
    backgroundLuminance: frame.luminance.value?.background,
    cameraRollDegrees: frame.motion.value?.rollDegrees ?? 0,
    cameraMotion: frame.motion.value?.magnitude ?? 0,
    cameraStable: frame.motion.value?.stable ?? true,
    // Unsupported scenic measurement must not become a false "scene excluded".
    skyOrOpenAreaRatio: frame.openAreaRatio.value ?? 1,
  );
}
