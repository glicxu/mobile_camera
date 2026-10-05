import 'models.dart';

enum MeasurementStatus { unavailable, unsupported, lowConfidence, valid }

enum LensFacing { front, back, external }

enum DetectorState { ready, warmingUp, unavailable, unsupported, failed }

typedef JsonDecoder<T> = T Function(Object? json);
typedef JsonEncoder<T> = Object? Function(T value);

/// A measurement whose absence has a defined meaning across native adapters.
class Measured<T> {
  const Measured._({required this.status, this.value, this.confidence});

  const Measured.unavailable() : this._(status: MeasurementStatus.unavailable);

  const Measured.unsupported() : this._(status: MeasurementStatus.unsupported);

  const Measured.lowConfidence(T value, {required double confidence})
    : this._(
        status: MeasurementStatus.lowConfidence,
        value: value,
        confidence: confidence,
      );

  const Measured.valid(T value, {double? confidence})
    : this._(
        status: MeasurementStatus.valid,
        value: value,
        confidence: confidence,
      );

  factory Measured.fromJson(
    Map<String, Object?> json,
    JsonDecoder<T> decodeValue,
  ) {
    final status = MeasurementStatus.values.byName(json['status']! as String);
    final confidence = (json['confidence'] as num?)?.toDouble();
    return switch (status) {
      MeasurementStatus.unavailable => const Measured.unavailable(),
      MeasurementStatus.unsupported => const Measured.unsupported(),
      MeasurementStatus.lowConfidence => Measured.lowConfidence(
        decodeValue(json['value']),
        confidence: confidence!,
      ),
      MeasurementStatus.valid => Measured.valid(
        decodeValue(json['value']),
        confidence: confidence,
      ),
    };
  }

  final MeasurementStatus status;
  final T? value;
  final double? confidence;

  bool get isUsable =>
      status == MeasurementStatus.valid ||
      status == MeasurementStatus.lowConfidence;

  Map<String, Object?> toJson(JsonEncoder<T> encodeValue) => {
    'status': status.name,
    if (value != null) 'value': encodeValue(value as T),
    if (confidence != null) 'confidence': confidence,
  };
}

class HorizonAnalysis {
  const HorizonAnalysis({
    required this.angleDegrees,
    required this.normalizedY,
  });

  factory HorizonAnalysis.fromJson(Map<String, Object?> json) =>
      HorizonAnalysis(
        angleDegrees: (json['angleDegrees'] as num).toDouble(),
        normalizedY: (json['normalizedY'] as num).toDouble(),
      );

  final double angleDegrees;
  final double normalizedY;

  Map<String, Object?> toJson() => {
    'angleDegrees': angleDegrees,
    'normalizedY': normalizedY,
  };
}

class LuminanceAnalysis {
  const LuminanceAnalysis({this.face, this.background});

  factory LuminanceAnalysis.fromJson(Map<String, Object?> json) =>
      LuminanceAnalysis(
        face: (json['face'] as num?)?.toDouble(),
        background: (json['background'] as num?)?.toDouble(),
      );

  final double? face;
  final double? background;

  Map<String, Object?> toJson() => {
    if (face != null) 'face': face,
    if (background != null) 'background': background,
  };
}

class MotionAnalysis {
  const MotionAnalysis({
    required this.rollDegrees,
    required this.magnitude,
    required this.stable,
  });

  factory MotionAnalysis.fromJson(Map<String, Object?> json) => MotionAnalysis(
    rollDegrees: (json['rollDegrees'] as num).toDouble(),
    magnitude: (json['magnitude'] as num).toDouble(),
    stable: json['stable']! as bool,
  );

  final double rollDegrees;
  final double magnitude;
  final bool stable;

  Map<String, Object?> toJson() => {
    'rollDegrees': rollDegrees,
    'magnitude': magnitude,
    'stable': stable,
  };
}

/// Version 1 native-to-Dart contract. Coordinates are relative to the visible
/// preview: x grows left-to-right and y grows top-to-bottom.
class FrameAnalysis {
  const FrameAnalysis({
    required this.frameId,
    required this.timestamp,
    required this.imageWidth,
    required this.imageHeight,
    required this.displayRotationDegrees,
    required this.lensFacing,
    required this.mirrored,
    required this.people,
    required this.faces,
    required this.poseKeypoints,
    required this.groupAnalysis,
    required this.faceAnalysis,
    required this.horizon,
    required this.luminance,
    required this.openAreaRatio,
    required this.motion,
    required this.detectorStatus,
    this.schemaVersion = currentSchemaVersion,
  }) : assert(imageWidth > 0),
       assert(imageHeight > 0),
       assert(
         displayRotationDegrees == 0 ||
             displayRotationDegrees == 90 ||
             displayRotationDegrees == 180 ||
             displayRotationDegrees == 270,
       );

  factory FrameAnalysis.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion']! as int;
    if (schemaVersion != currentSchemaVersion) {
      throw FormatException('Unsupported FrameAnalysis schema $schemaVersion');
    }

    Map<String, Object?> objectMap(String key) =>
        json[key]! as Map<String, Object?>;

    return FrameAnalysis(
      schemaVersion: schemaVersion,
      frameId: json['frameId']! as String,
      timestamp: DateTime.parse(json['timestamp']! as String),
      imageWidth: json['imageWidth']! as int,
      imageHeight: json['imageHeight']! as int,
      displayRotationDegrees: json['displayRotationDegrees']! as int,
      lensFacing: LensFacing.values.byName(json['lensFacing']! as String),
      mirrored: json['mirrored']! as bool,
      people: Measured.fromJson(objectMap('people'), (value) {
        return (value! as List<Object?>)
            .map((item) => DetectionBox.fromJson(item! as Map<String, Object?>))
            .toList(growable: false);
      }),
      faces: Measured.fromJson(objectMap('faces'), (value) {
        return (value! as List<Object?>)
            .map((item) => DetectionBox.fromJson(item! as Map<String, Object?>))
            .toList(growable: false);
      }),
      poseKeypoints: Measured.fromJson(objectMap('poseKeypoints'), (value) {
        return (value! as Map<String, Object?>).map(
          (key, item) => MapEntry(
            key,
            DetectionPoint.fromJson(item! as Map<String, Object?>),
          ),
        );
      }),
      groupAnalysis: Measured.fromJson(
        objectMap('groupAnalysis'),
        (value) => GroupAnalysis.fromJson(value! as Map<String, Object?>),
      ),
      faceAnalysis: Measured.fromJson(
        objectMap('faceAnalysis'),
        (value) => FaceAnalysis.fromJson(value! as Map<String, Object?>),
      ),
      horizon: Measured.fromJson(
        objectMap('horizon'),
        (value) => HorizonAnalysis.fromJson(value! as Map<String, Object?>),
      ),
      luminance: Measured.fromJson(
        objectMap('luminance'),
        (value) => LuminanceAnalysis.fromJson(value! as Map<String, Object?>),
      ),
      openAreaRatio: Measured.fromJson(
        objectMap('openAreaRatio'),
        (value) => (value! as num).toDouble(),
      ),
      motion: Measured.fromJson(
        objectMap('motion'),
        (value) => MotionAnalysis.fromJson(value! as Map<String, Object?>),
      ),
      detectorStatus: (json['detectorStatus']! as Map<String, Object?>).map(
        (key, value) =>
            MapEntry(key, DetectorState.values.byName(value! as String)),
      ),
    );
  }

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String frameId;
  final DateTime timestamp;
  final int imageWidth;
  final int imageHeight;
  final int displayRotationDegrees;
  final LensFacing lensFacing;
  final bool mirrored;
  final Measured<List<DetectionBox>> people;
  final Measured<List<DetectionBox>> faces;
  final Measured<Map<String, DetectionPoint>> poseKeypoints;
  final Measured<GroupAnalysis> groupAnalysis;
  final Measured<FaceAnalysis> faceAnalysis;
  final Measured<HorizonAnalysis> horizon;
  final Measured<LuminanceAnalysis> luminance;
  final Measured<double> openAreaRatio;
  final Measured<MotionAnalysis> motion;
  final Map<String, DetectorState> detectorStatus;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'frameId': frameId,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'imageWidth': imageWidth,
    'imageHeight': imageHeight,
    'displayRotationDegrees': displayRotationDegrees,
    'lensFacing': lensFacing.name,
    'mirrored': mirrored,
    'people': people.toJson(
      (items) => items.map((item) => item.toJson()).toList(growable: false),
    ),
    'faces': faces.toJson(
      (items) => items.map((item) => item.toJson()).toList(growable: false),
    ),
    'poseKeypoints': poseKeypoints.toJson(
      (items) => items.map((key, value) => MapEntry(key, value.toJson())),
    ),
    'groupAnalysis': groupAnalysis.toJson((value) => value.toJson()),
    'faceAnalysis': faceAnalysis.toJson((value) => value.toJson()),
    'horizon': horizon.toJson((value) => value.toJson()),
    'luminance': luminance.toJson((value) => value.toJson()),
    'openAreaRatio': openAreaRatio.toJson((value) => value),
    'motion': motion.toJson((value) => value.toJson()),
    'detectorStatus': detectorStatus.map(
      (key, value) => MapEntry(key, value.name),
    ),
  };
}
