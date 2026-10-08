import 'dart:math' as math;
import 'models.dart';

/// Native reference geometry applied to either Vision or ML Kit normalized joints.
PoseAnalysis? analyzePose(
  Map<String, DetectionPoint> points,
  DetectionBox? person,
  DetectionBox? face,
) {
  if (points.isEmpty) return null;
  String normalized(String name) =>
      name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  DetectionPoint? point(List<String> names) {
    for (final name in names) {
      for (final entry in points.entries) {
        if (normalized(entry.key).contains(normalized(name))) {
          return entry.value;
        }
      }
    }
    return null;
  }

  DetectionPoint? midpoint(DetectionPoint? a, DetectionPoint? b) =>
      a == null || b == null
      ? null
      : DetectionPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, confidence: 1);
  double? distance(DetectionPoint? a, DetectionPoint? b) =>
      a == null || b == null
      ? null
      : math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  double? angle(DetectionPoint? a, DetectionPoint? b) => a == null || b == null
      ? null
      : math.atan2(b.y - a.y, b.x - a.x) * 180 / math.pi;
  double? fromRect(DetectionPoint? p, List<double>? bounds) {
    if (p == null || bounds == null) return null;
    final dx = math.max(bounds[0] - p.x, math.max(0.0, p.x - bounds[2]));
    final dy = math.max(bounds[1] - p.y, math.max(0.0, p.y - bounds[3]));
    return math.sqrt(dx * dx + dy * dy);
  }

  final ls = point(['leftShoulder']), rs = point(['rightShoulder']);
  final lh = point(['leftHip', 'leftUpLeg']),
      rh = point(['rightHip', 'rightUpLeg']);
  final lw = point(['leftWrist', 'leftHand']),
      rw = point(['rightWrist', 'rightHand']);
  final le = point(['leftElbow', 'leftForearm']),
      re = point(['rightElbow', 'rightForearm']);
  final la = point(['leftAnkle', 'leftFoot']),
      ra = point(['rightAnkle', 'rightFoot']);
  final shoulders = midpoint(ls, rs), hips = midpoint(lh, rh);
  final width = distance(ls, rs), hipWidth = distance(lh, rh);
  final square = width == null || hipWidth == null
      ? null
      : (width / math.max(.001, hipWidth) / 1.35).clamp(0.0, 1.0);
  final torsoPoints = [ls, rs, lh, rh].whereType<DetectionPoint>().toList();
  final torso = torsoPoints.isEmpty
      ? null
      : <double>[
          torsoPoints.map((p) => p.x).reduce(math.min),
          torsoPoints.map((p) => p.y).reduce(math.min),
          torsoPoints.map((p) => p.x).reduce(math.max),
          torsoPoints.map((p) => p.y).reduce(math.max),
        ];
  if (torso != null) {
    torso[2] = math.max(torso[2], torso[0] + .001);
    torso[3] = math.max(torso[3], torso[1] + .001);
  }
  final armDistances = [
    le,
    re,
    lw,
    rw,
  ].map((p) => fromRect(p, torso)).whereType<double>().toList();
  final faceRect = face?.rect;
  final wristFace = [lw, rw]
      .map(
        (p) => fromRect(
          p,
          faceRect == null
              ? null
              : [faceRect.minX, faceRect.minY, faceRect.maxX, faceRect.maxY],
        ),
      )
      .whereType<double>()
      .toList();
  final wrists = [lw, rw].whereType<DetectionPoint>().toList();
  final head =
      point(['nose', 'head']) ??
      (faceRect == null
          ? null
          : DetectionPoint(
              x: faceRect.x + faceRect.width / 2,
              y: faceRect.y + faceRect.height / 2,
              confidence: 1,
            ));
  final neck = point(['neck']) ?? shoulders;
  final torsoLength = distance(shoulders, hips);
  final torsoAngle = angle(shoulders, hips);
  final visible = points.values.where((p) => p.confidence > .2).toList();
  return PoseAnalysis(
    confidence: visible.isEmpty
        ? 0
        : visible.fold<double>(0, (sum, p) => sum + p.confidence) /
              visible.length,
    visibleKeypointCount: visible.length,
    shoulderLineAngleDegrees: angle(ls, rs),
    shoulderHeightAsymmetry: ls == null || rs == null
        ? null
        : (ls.y - rs.y).abs() / math.max(.001, person?.rect.height ?? 1),
    torsoAngleDegrees: torsoAngle == null ? null : torsoAngle - 90,
    wristToFaceDistance: wristFace.isEmpty ? null : wristFace.reduce(math.min),
    armVisibilityScore:
        [
          ls,
          rs,
          le,
          re,
          lw,
          rw,
        ].where((p) => (p?.confidence ?? 0) > .2).length /
        6,
    stanceWidth: distance(la, ra),
    headToTorsoRatio: faceRect == null || torsoLength == null
        ? null
        : faceRect.height / math.max(.001, torsoLength),
    shouldersHighScore: head == null || neck == null
        ? null
        : ((.16 -
                      (neck.y - head.y).abs() /
                          math.max(.001, person?.rect.height ?? 1)) /
                  .16)
              .clamp(0.0, 1.0),
    bodySquarenessScore: square,
    bodyProfileScore: square == null ? null : 1 - square,
    armsFlatAgainstBodyScore: armDistances.isEmpty
        ? null
        : ((.055 - armDistances.reduce((a, b) => a + b) / armDistances.length) /
                  .055)
              .clamp(0.0, 1.0),
    minWristEdgeDistance: wrists.isEmpty
        ? null
        : wrists
              .map(
                (p) => math.min(math.min(p.x, p.y), math.min(1 - p.x, 1 - p.y)),
              )
              .reduce(math.min),
  );
}
