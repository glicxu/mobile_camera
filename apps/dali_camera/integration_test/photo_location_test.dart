import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'package:dali_camera_platform/dali_camera_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// A generated 40x32 solid-color JPEG. Coordinates are invented, not device data.
const fixture =
    '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';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native effects and edits preserve capture metadata without requesting location',
    (tester) async {
      final host = CameraHostApi();
      final files = <String>[];
      try {
        expect(await host.configurePhotoLocation(false, false), 'off');
        final path = '${Directory.systemTemp.path}/dali-synthetic-location.jpg';
        files.add(path);
        await File(path).writeAsBytes(base64Decode(fixture));
        var photo = PhotoHandle(
          path: path,
          id: 'synthetic-location',
          unsaved: false,
        );
        const identity = <double>[
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
        final stages = <Future<PhotoHandle> Function(PhotoHandle)>[
          (p) => host.renderEffects(
            p,
            jsonEncode({
              'version': 1,
              'treatment': 'original',
              'strength': 0,
              'capturePipeline': true,
            }),
          ),
          (p) => host.render(p, 90, true, 0),
          (p) =>
              host.renderFilter(p, identity, List<double>.filled(7, 0), null),
          (p) => host.renderStyle(p, identity, 0, 0, null),
        ];
        expect(gps(await File(path).readAsBytes()), [-12.5, -45.25]);
        for (var i = 0; i < stages.length; i++) {
          photo = await stages[i](photo);
          files.add(photo.path);
          final metadata =
              jsonDecode(await host.photoMetadata(photo.path, false)) as Map;
          expect(metadata['make'], 'Fixture Camera');
          expect(metadata['model'], 'Fixture Model');
          expect(metadata['lensModel'], 'Fixture Lens');
          expect(metadata['dateOriginal'], '2024:04:05 06:07:08');
          expect(metadata['timeZone'], '-07:00');
          expect('${metadata['iso']}', '200');
          expect(metadata['exposureSeconds'], closeTo(1 / 125, .000001));
          expect(metadata['aperture'], closeTo(2.8, .000001));
          expect(metadata['focalLength'], closeTo(4.3, .000001));
          expect(metadata['orientation'], 1);
          expect(metadata['software'], startsWith('Dali Camera '));
          final debug = jsonDecode(metadata['debug'] as String) as Map;
          expect(debug['instructionShown'], 'Move left - \u4fdd\u6301');
          expect(debug['captureRecipe']['strength'], 4);
          expect(debug['captureEffectsApplied'], isTrue);
          final bytes = await File(photo.path).readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          expect(metadata['width'], frame.image.width);
          expect(metadata['height'], frame.image.height);
          frame.image.dispose();
          codec.dispose();

          expect(
            gps(await File(photo.path).readAsBytes()),
            [-12.5, -45.25],
            reason: 'GPS lost at processing stage $i',
          );
        }
        final clean =
            '${Directory.systemTemp.path}/dali-synthetic-no-location.jpg';
        files.add(clean);
        final data = base64Decode(fixture);
        final segment = exifSegment(data)!;
        await File(clean).writeAsBytes([
          ...data.sublist(0, segment.$1),
          ...data.sublist(segment.$2),
        ]);
        final untagged = await host.renderEffects(
          PhotoHandle(path: clean, id: 'no-location', unsaved: false),
          jsonEncode({'version': 1, 'treatment': 'original'}),
        );
        files.add(untagged.path);
        expect(
          gps(await File(untagged.path).readAsBytes()),
          isNull,
          reason: 'Processing must never add the current device location',
        );
        final cleanInfo =
            jsonDecode(await host.photoMetadata(untagged.path, false)) as Map;
        expect(cleanInfo['debug'], isNull);
        expect(cleanInfo['dateOriginal'], isNull);
        debugPrint(
          'CAPTURE_METADATA_TEST: PASS (four render paths; dates, camera, exposure, GPS, Unicode debug, software, dimensions)',
        );
      } finally {
        for (final path in files) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      }
    },
  );
}

// Independent JPEG/TIFF reader used only to verify the output bytes.
(int, int)? exifSegment(Uint8List bytes) {
  var offset = 2;
  while (offset + 4 <= bytes.length && bytes[offset] == 0xff) {
    final marker = bytes[offset + 1];
    if (marker == 0xda || marker == 0xd9) return null;
    final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
    final end = offset + 2 + length;
    if (length < 2 || end > bytes.length) return null;
    if (marker == 0xe1 &&
        length >= 8 &&
        ascii.decode(
              bytes.sublist(offset + 4, offset + 8),
              allowInvalid: true,
            ) ==
            'Exif') {
      return (offset, end);
    }
    offset = end;
  }
  return null;
}

List<double>? gps(Uint8List bytes) {
  final segment = exifSegment(bytes);
  if (segment == null) return null;
  final data = ByteData.sublistView(bytes, segment.$1 + 10, segment.$2);
  final order = data.getUint8(0) == 0x49 ? Endian.little : Endian.big;
  int short(int offset) => data.getUint16(offset, order);
  int word(int offset) => data.getUint32(offset, order);
  Map<int, int> entries(int offset) => {
    for (var i = 0; i < short(offset); i++)
      short(offset + 2 + i * 12): offset + 2 + i * 12,
  };
  final pointer = entries(word(4))[0x8825];
  if (pointer == null) return null;
  final tags = entries(word(pointer + 8));
  if (![1, 2, 3, 4].every(tags.containsKey)) return null;
  double degrees(int tag) {
    final offset = word(tags[tag]! + 8);
    double rational(int i) => word(offset + i * 8) / word(offset + i * 8 + 4);
    return rational(0) + rational(1) / 60 + rational(2) / 3600;
  }

  final south = data.getUint8(tags[1]! + 8) == 0x53;
  final west = data.getUint8(tags[3]! + 8) == 0x57;
  return [degrees(2) * (south ? -1 : 1), degrees(4) * (west ? -1 : 1)];
}
