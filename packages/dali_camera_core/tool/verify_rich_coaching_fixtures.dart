import 'dart:convert';
import 'dart:io';
import 'package:dali_camera_core/dali_camera_core.dart';

void main(List<String> args) {
  final fixtures = jsonDecode(File(args.single).readAsStringSync()) as List;
  for (final fixture in fixtures.cast<Map>()) {
    final measurements = CoachingMeasurements(
      personBox: const DetectionBox(
        rect: NormalizedRect(x: .25, y: .1, width: .5, height: .8),
        confidence: .9,
        label: 'person',
      ),
      faceBox: const DetectionBox(
        rect: NormalizedRect(x: .4, y: .15, width: .2, height: .15),
        confidence: .9,
        label: 'face',
      ),
      poseAnalysis: PoseAnalysis.fromJson(
        (fixture['pose'] as Map).cast<String, Object?>(),
      ),
      faceAnalysis: FaceAnalysis.fromJson(
        (fixture['face'] as Map).cast<String, Object?>(),
      ),
      groupAnalysis: GroupAnalysis.fromJson(
        (fixture['group'] as Map).cast<String, Object?>(),
      ),
      faceLuminance: (fixture['luminance'] as num).toDouble(),
      backgroundLuminance: 200,
      horizonAngleDegrees: (fixture['horizon'] as num).toDouble(),
      horizonConfidence: .9,
      cameraRollDegrees: (fixture['roll'] as num).toDouble(),
      cameraMotion: 0,
      cameraStable: true,
      skyOrOpenAreaRatio: (fixture['openArea'] as num).toDouble(),
    );
    final issues = CoachingEngine().issues(
      measurements,
      posePackage: PosePackageId.values.byName(fixture['package'] as String),
    );
    final expected = fixture['issues'] as List;
    if (issues.length != expected.length) {
      throw StateError(
        '${fixture['name']}: ${issues.map((issue) => issue.type)} != ${expected.map((issue) => issue['type'])}',
      );
    }
    for (var i = 0; i < issues.length; i++) {
      final actual = issues[i];
      final reference = expected[i] as Map;
      if (actual.type != reference['type'] ||
          actual.recipient != reference['recipient'] ||
          actual.instruction != reference['instruction'] ||
          (actual.priority - (reference['priority'] as num)).abs() > 1e-8 ||
          (actual.severity - (reference['severity'] as num)).abs() > 1e-8 ||
          (actual.confidence - (reference['confidence'] as num)).abs() > 1e-8) {
        throw StateError(
          '${fixture['name']}: ${actual.type}/${actual.instruction}/${actual.priority} != $reference',
        );
      }
    }
  }
  stdout.writeln('${fixtures.length} native rich-coaching fixtures match');
}
