import 'dart:convert';
import 'dart:io';
import 'package:dali_camera_core/dali_camera_core.dart';

void main(List<String> args) {
  final fixtures = jsonDecode(File(args.single).readAsStringSync()) as List;
  for (final fixture in fixtures.cast<Map>()) {
    final points = (fixture['points'] as Map).map(
      (key, value) => MapEntry(
        key as String,
        DetectionPoint.fromJson((value as Map).cast<String, Object?>()),
      ),
    );
    final person = fixture['hasPerson'] == true
        ? const DetectionBox(
            rect: NormalizedRect(x: .25, y: .1, width: .5, height: .85),
            confidence: .9,
            label: 'person',
          )
        : null;
    final face = fixture['hasFace'] == true
        ? const DetectionBox(
            rect: NormalizedRect(x: .43, y: .12, width: .14, height: .14),
            confidence: .9,
            label: 'face',
          )
        : null;
    final actual = analyzePose(points, person, face)?.toJson();
    final expected = fixture['expected'] as Map?;
    if ((actual == null) != (expected == null)) {
      throw StateError('${fixture['name']}: missing pose mismatch');
    }
    if (expected == null) continue;
    for (final entry in expected.entries) {
      final a = actual![entry.key];
      final e = entry.value;
      if ((a == null) != (e == null) ||
          (a is num && e is num && (a - e).abs() > 1e-8)) {
        throw StateError('${fixture['name']} ${entry.key}: Dart=$a Swift=$e');
      }
    }
  }
  stdout.writeln('${fixtures.length} real Swift/Dart pose fixtures match');
}
