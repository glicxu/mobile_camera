import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Off is identity; Auto resolves to the situation-specific native presets',
    () {
      final catalog = SharedCatalog();
      expect(
        PhotoStyle.preset(catalog, 'off', 'pose').matrix,
        PhotoStyle.identity,
      );
      for (final entry in {
        'pose': 'natural',
        'landscape': 'blueSky',
        'food': 'fresh',
        'action': 'vivid',
        'closeUp': 'bright',
      }.entries) {
        expect(
          PhotoStyle.preset(catalog, 'auto', entry.key).values,
          PhotoStyle.preset(catalog, entry.value, entry.key).values,
        );
      }
    },
  );
  test(
    'Every exported named filter has a finite transform and bounded custom controls',
    () {
      final catalog = SharedCatalog();
      expect((catalog.data['filters'] as Map).length, 8);
      for (final name in (catalog.data['filters'] as Map).keys.cast<String>()) {
        final matrix = PhotoStyle.preset(catalog, name, 'food').matrix;
        expect(matrix.length, 20);
        expect(matrix.every((value) => value.isFinite), isTrue);
        expect(matrix.sublist(15), [0, 0, 0, 1, 0]);
      }
      expect(
        const PhotoStyle({'exposure': -99, 'color': 99}).value('exposure'),
        -5,
      );
      expect(
        const PhotoStyle({'exposure': -99, 'color': 99}).value('color'),
        5,
      );
    },
  );
  test('Directional cues and coaching status match the reference app', () {
    Advice cue(
      String text, {
      String type = 'cue',
      AdviceTone tone = AdviceTone.warning,
    }) => Advice(
      type: type,
      recipient: 'Photographer',
      instruction: text,
      tone: tone,
    );
    expect(cue('Move a little left').direction, 'left');
    expect(cue('Tilt right').direction, 'rotateRight');
    expect(cue('Step closer').direction, 'closer');
    expect(cue('Include feet', type: 'feet_cropped').direction, 'farther');
    expect(cue('Take photo', tone: AdviceTone.ready).statusTitle, 'Looks good');
    expect(cue('Wait', tone: AdviceTone.waiting).statusTitle, 'Checking');
  });
}
