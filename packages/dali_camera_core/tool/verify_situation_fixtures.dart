import 'dart:convert';
import 'dart:io';
import 'package:dali_camera_core/dali_camera_core.dart';

void main(List<String> args) {
  final fixtures = jsonDecode(File(args.single).readAsStringSync()) as List;
  final classifier = SituationClassifier();
  for (final row in fixtures) {
    DetectionBox? box(String key) => row[key] == null
        ? null
        : DetectionBox(
            rect: NormalizedRect.fromJson(
              (row[key] as Map).cast<String, Object?>(),
            ),
            confidence: .9,
            label: key,
          );
    final signals = SituationSignals(
      person: box('person'),
      faceCount: row['faceCount'] as int,
      subjectMotion: (row['subjectMotion'] as num).toDouble(),
      horizonConfidence: (row['horizonConfidence'] as num).toDouble(),
      salientObject: box('object'),
      openAreaRatio: (row['openAreaRatio'] as num).toDouble(),
    );
    final candidate = SituationClassifier.candidate(signals)?.name;
    final recommendation = classifier.update(signals).name;
    if (candidate != row['candidate'] ||
        recommendation != row['recommendation']) {
      throw StateError(
        '${row['name']}: Dart=$candidate/$recommendation Swift=${row['candidate']}/${row['recommendation']}',
      );
    }
  }
  stdout.writeln(
    '${fixtures.length} real Swift/Dart situation transitions match',
  );
}
