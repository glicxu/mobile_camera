import 'dart:convert';
import 'dart:io';
import 'package:dali_camera_core/dali_camera_core.dart';

void main(List<String> args) {
  final fixtures = jsonDecode(File(args.single).readAsStringSync()) as List;
  final catalog = SharedCatalog();
  final poses = catalog.entries.where((entry) => entry.kind == 'pose').toList();
  if (fixtures.length != poses.length) {
    throw StateError(
      'Native posture count differs: ${fixtures.length}/${poses.length}',
    );
  }
  for (final fixture in fixtures.cast<Map>()) {
    final entry = poses.singleWhere((entry) => entry.id == fixture['id']);
    final session = CatalogSession(entry, catalog);
    final steps = fixture['steps'] as List;
    if ((session.position?.id ?? 'none') != fixture['position'] ||
        session.cues.length != steps.length) {
      throw StateError('${entry.id}: camera position or step count differs');
    }
    for (final step in steps.cast<Map>()) {
      final advice = session.advice!;
      if (advice.instruction != step['instruction'] ||
          advice.recipient != step['recipient'] ||
          session.currentAction?.name != step['action']) {
        throw StateError(
          '${entry.id} step ${session.index}: $step differs from ${advice.instruction}/${advice.recipient}/${session.currentAction}',
        );
      }
      session.advance();
    }
    if (!session.complete ||
        session.currentAction != null ||
        session.advice!.recipient != 'Camera') {
      throw StateError('${entry.id}: completed sequence is inconsistent');
    }
  }
  print(
    '${fixtures.length} native posture sequences match the runtime catalog.',
  );
}
