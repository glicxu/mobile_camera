import 'dart:convert';
import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:test/test.dart';

void main() {
  final catalog = SharedCatalog();
  test(
    'Current native catalogs have complete unique references and metadata',
    () {
      expect(catalog.entries.where((e) => e.kind == 'pose').length, 76);
      expect(catalog.entries.where((e) => e.kind == 'landscape').length, 24);
      expect(catalog.entries.where((e) => e.kind == 'food').length, 6);
      expect(catalog.packages('food'), {'food': 'Food photography'});
      expect(catalog.packages('pose').length, 11);
      expect(catalog.packages('landscape').length, 4);
      expect(catalog.entries.map((e) => e.key).toSet().length, 106);
      for (final entry in catalog.entries) {
        expect(entry.cues.length, 2);
        expect(catalog.angleInstruction(entry), isNotEmpty);
        expect(catalog.lightDescription(entry), isNotEmpty);
        expect(entry.asset.endsWith('.jpg'), isTrue);
      }
      expect(jsonEncode(catalog.data), contains('Caregiver'));
    },
  );
  test(
    'Each creative session uses manual progression and preserves recipients',
    () {
      for (final entry in catalog.entries) {
        final session = CatalogSession(entry, catalog);
        expect(session.advice!.recipient, 'Photographer');
        session.advance();
        expect(session.advice!.recipient, entry.recipient);
        expect(session.complete, isFalse);
        session.advance();
        session.advance();
        expect(session.complete, isTrue);
        expect(session.advice!.tone, AdviceTone.waiting);
      }
    },
  );
}
