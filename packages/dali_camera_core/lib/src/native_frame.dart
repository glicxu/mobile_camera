import 'frame_analysis.dart';
import 'models.dart';
import 'situations.dart';
import 'pose_measurements.dart';

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
    final faceGroup = json['groupScope'] == 'faces';
    final supportsGroup = json['peopleScope'] == 'multiple' || faceGroup;
    final group = json['groupAnalysis'] != null
        ? GroupAnalysis.fromJson(
            (json['groupAnalysis'] as Map).cast<String, Object?>(),
          )
        : supportsGroup && (people.isUsable || faceGroup) && faces.isUsable
        ? analyzeGroup(faceGroup ? [] : people.value!, faces.value!)
        : null;
    final points =
        (json['poseKeypoints'] as Map?)?.map(
          (key, value) => MapEntry(
            key as String,
            DetectionPoint.fromJson((value as Map).cast<String, Object?>()),
          ),
        ) ??
        <String, DetectionPoint>{};
    poseAnalysis = json['poseAnalysis'] == null
        ? analyzePose(
            points,
            people.value?.firstOrNull,
            faces.value?.firstOrNull,
          )
        : PoseAnalysis.fromJson(
            (json['poseAnalysis'] as Map).cast<String, Object?>(),
          );
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
      poseKeypoints: json['poseStatus'] == 'valid'
          ? Measured.valid(points)
          : json['poseStatus'] == 'unavailable'
          ? const Measured.unavailable()
          : const Measured.unsupported(),
      groupAnalysis: !supportsGroup
          ? const Measured.unsupported()
          : group == null
          ? const Measured.unavailable()
          : Measured.valid(group),
      faceAnalysis: json['faceAnalysis'] != null
          ? Measured.valid(
              FaceAnalysis.fromJson(
                (json['faceAnalysis'] as Map).cast<String, Object?>(),
              ),
            )
          : json['faceStatus'] == 'valid'
          ? const Measured.unavailable()
          : const Measured.unsupported(),
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
  late final PoseAnalysis? poseAnalysis;
  bool get groupAvailable =>
      frame.groupAnalysis.status != MeasurementStatus.unsupported &&
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
    faceAnalysis: frame.faceAnalysis.value,
    poseAnalysis: poseAnalysis,
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
