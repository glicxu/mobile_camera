import 'dart:convert';
import 'dart:io';
import 'package:dali_camera_core/dali_camera_core.dart';

void main(List<String> args) {
  final fixtures = jsonDecode(File(args.single).readAsStringSync()) as List;
  final epoch = DateTime.fromMillisecondsSinceEpoch(100000);
  for (final value in fixtures) {
    final fixture = value as Map<String, dynamic>;
    DetectionBox? box(String key) => fixture[key] == null
        ? null
        : DetectionBox(
            rect: NormalizedRect.fromJson(
              (fixture[key] as Map).cast<String, Object?>(),
            ),
            confidence: .9,
            label: key,
          );
    final measures = CoachingMeasurements(
      personBox: box('person'),
      faceBox: box('face'),
      cameraRollDegrees: (fixture['roll'] as num).toDouble(),
      cameraMotion: fixture['stable'] == true ? 0 : .2,
      cameraStable: fixture['stable'] as bool,
      skyOrOpenAreaRatio: 1,
    );
    final engine = CoachingEngine();
    final issues = engine.issues(measures, includePosture: false);
    engine.selectAdvice(issues, now: epoch);
    final advice = engine.selectAdvice(
      issues,
      now: epoch.add(const Duration(seconds: 4)),
    );
    final actual = {
      'type': advice.type,
      'recipient': advice.recipient,
      'instruction': advice.instruction,
    };
    if (jsonEncode(issues.map((i) => i.type).toList()) !=
            jsonEncode(fixture['issues']) ||
        actual.entries.any(
          (entry) => fixture['advice'][entry.key] != entry.value,
        )) {
      throw StateError(
        '${fixture['name']}: Dart=$actual Swift=${fixture['advice']}',
      );
    }
  }
  stdout.writeln('${fixtures.length} real Swift/Dart baseline fixtures match');
}
