enum AdviceTone { waiting, ready, warning, danger }

class Advice {
  const Advice({
    required this.type,
    required this.recipient,
    required this.instruction,
    required this.tone,
  });

  final String type;
  final String recipient;
  final String instruction;
  final AdviceTone tone;

  @override
  bool operator ==(Object other) =>
      other is Advice &&
      type == other.type &&
      recipient == other.recipient &&
      instruction == other.instruction &&
      tone == other.tone;

  @override
  int get hashCode => Object.hash(type, recipient, instruction, tone);
}

class NormalizedRect {
  const NormalizedRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  }) : assert(x >= 0 && x <= 1),
       assert(y >= 0 && y <= 1),
       assert(width >= 0 && x + width <= 1),
       assert(height >= 0 && y + height <= 1);

  factory NormalizedRect.fromJson(Map<String, Object?> json) => NormalizedRect(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
  );

  final double x;
  final double y;
  final double width;
  final double height;

  double get minX => x;
  double get minY => y;
  double get maxX => x + width;
  double get maxY => y + height;
  double get area => width * height;

  Map<String, Object?> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class DetectionBox {
  const DetectionBox({
    required this.rect,
    required this.confidence,
    required this.label,
  });

  factory DetectionBox.fromJson(Map<String, Object?> json) => DetectionBox(
    rect: NormalizedRect.fromJson(json['rect']! as Map<String, Object?>),
    confidence: (json['confidence'] as num).toDouble(),
    label: json['label']! as String,
  );

  final NormalizedRect rect;
  final double confidence;
  final String label;

  Map<String, Object?> toJson() => {
    'rect': rect.toJson(),
    'confidence': confidence,
    'label': label,
  };
}

class DetectionPoint {
  const DetectionPoint({
    required this.x,
    required this.y,
    required this.confidence,
  });

  factory DetectionPoint.fromJson(Map<String, Object?> json) => DetectionPoint(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    confidence: (json['confidence'] as num).toDouble(),
  );

  final double x;
  final double y;
  final double confidence;

  Map<String, Object?> toJson() => {'x': x, 'y': y, 'confidence': confidence};
}

class GroupAnalysis {
  const GroupAnalysis({
    required this.peopleCount,
    required this.faceCount,
    required this.faceVisibilityRatio,
    required this.edgeCrowdingScore,
    this.groupBounds,
    this.spacingScore,
  });

  factory GroupAnalysis.fromJson(Map<String, Object?> json) => GroupAnalysis(
    peopleCount: json['peopleCount']! as int,
    faceCount: json['faceCount']! as int,
    groupBounds: json['groupBounds'] == null
        ? null
        : NormalizedRect.fromJson(json['groupBounds']! as Map<String, Object?>),
    faceVisibilityRatio: (json['faceVisibilityRatio'] as num).toDouble(),
    edgeCrowdingScore: (json['edgeCrowdingScore'] as num).toDouble(),
    spacingScore: (json['spacingScore'] as num?)?.toDouble(),
  );

  final int peopleCount;
  final int faceCount;
  final NormalizedRect? groupBounds;
  final double faceVisibilityRatio;
  final double edgeCrowdingScore;
  final double? spacingScore;

  Map<String, Object?> toJson() => {
    'peopleCount': peopleCount,
    'faceCount': faceCount,
    if (groupBounds != null) 'groupBounds': groupBounds!.toJson(),
    'faceVisibilityRatio': faceVisibilityRatio,
    'edgeCrowdingScore': edgeCrowdingScore,
    if (spacingScore != null) 'spacingScore': spacingScore,
  };
}

class FaceAnalysis {
  const FaceAnalysis({
    required this.confidence,
    required this.landmarkPointCount,
    required this.eyeVisibilityScore,
    required this.occlusionScore,
    this.yawEstimate,
    this.pitchEstimate,
  });

  factory FaceAnalysis.fromJson(Map<String, Object?> json) => FaceAnalysis(
    confidence: (json['confidence'] as num).toDouble(),
    landmarkPointCount: json['landmarkPointCount']! as int,
    eyeVisibilityScore: (json['eyeVisibilityScore'] as num).toDouble(),
    yawEstimate: (json['yawEstimate'] as num?)?.toDouble(),
    pitchEstimate: (json['pitchEstimate'] as num?)?.toDouble(),
    occlusionScore: (json['occlusionScore'] as num).toDouble(),
  );

  final double confidence;
  final int landmarkPointCount;
  final double eyeVisibilityScore;
  final double? yawEstimate;
  final double? pitchEstimate;
  final double occlusionScore;

  Map<String, Object?> toJson() => {
    'confidence': confidence,
    'landmarkPointCount': landmarkPointCount,
    'eyeVisibilityScore': eyeVisibilityScore,
    if (yawEstimate != null) 'yawEstimate': yawEstimate,
    if (pitchEstimate != null) 'pitchEstimate': pitchEstimate,
    'occlusionScore': occlusionScore,
  };
}

class PoseAnalysis {
  const PoseAnalysis({
    required this.confidence,
    required this.visibleKeypointCount,
    required this.armVisibilityScore,
    this.shoulderLineAngleDegrees,
    this.shoulderHeightAsymmetry,
    this.torsoAngleDegrees,
    this.wristToFaceDistance,
    this.stanceWidth,
    this.headToTorsoRatio,
    this.shouldersHighScore,
    this.bodySquarenessScore,
    this.bodyProfileScore,
    this.armsFlatAgainstBodyScore,
    this.minWristEdgeDistance,
  });

  final double confidence;
  final int visibleKeypointCount;
  final double? shoulderLineAngleDegrees;
  final double? shoulderHeightAsymmetry;
  final double? torsoAngleDegrees;
  final double? wristToFaceDistance;
  final double armVisibilityScore;
  final double? stanceWidth;
  final double? headToTorsoRatio;
  final double? shouldersHighScore;
  final double? bodySquarenessScore;
  final double? bodyProfileScore;
  final double? armsFlatAgainstBodyScore;
  final double? minWristEdgeDistance;
}

enum PosePackageId { neutral, feminine, masculine, professional, groupPortrait }

class CoachingMeasurements {
  const CoachingMeasurements({
    required this.cameraRollDegrees,
    required this.cameraMotion,
    required this.cameraStable,
    required this.skyOrOpenAreaRatio,
    this.personBox,
    this.faceBox,
    this.groupAnalysis,
    this.faceAnalysis,
    this.poseAnalysis,
    this.faceLuminance,
    this.backgroundLuminance,
    this.horizonAngleDegrees,
    this.horizonConfidence = 0,
  });

  final DetectionBox? personBox;
  final DetectionBox? faceBox;
  final GroupAnalysis? groupAnalysis;
  final FaceAnalysis? faceAnalysis;
  final PoseAnalysis? poseAnalysis;
  final double? faceLuminance;
  final double? backgroundLuminance;
  final double? horizonAngleDegrees;
  final double horizonConfidence;
  final double cameraRollDegrees;
  final double cameraMotion;
  final bool cameraStable;
  final double skyOrOpenAreaRatio;
}

class PhotoIssue {
  const PhotoIssue({
    required this.type,
    required this.severity,
    required this.confidence,
    required this.priority,
    required this.recipient,
    required this.instruction,
    required this.successCondition,
    required this.cooldownMilliseconds,
    required this.reasonData,
    required this.tone,
  });

  final String type;
  final double severity;
  final double confidence;
  final double priority;
  final String recipient;
  final String instruction;
  final String successCondition;
  final int cooldownMilliseconds;
  final Map<String, double> reasonData;
  final AdviceTone tone;
}
