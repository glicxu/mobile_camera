import 'dart:io';
import 'dart:ui' as ui;
import 'package:dali_camera_platform/dali_camera_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native file rendering preserves original and crops selected copy',
    (tester) async {
      final host = CameraHostApi();
      // Exercises plugin registration and nullable result transport without camera hardware.
      await host.recover();
      final source = await rootBundle.load(
        'assets/catalog/pose-relaxed-standing.jpg',
      );
      final file = File('${Directory.systemTemp.path}/dali-bridge-fixture.jpg');
      final bytes = source.buffer.asUint8List(
        source.offsetInBytes,
        source.lengthInBytes,
      );
      await file.writeAsBytes(bytes, flush: true);
      final original = PhotoHandle(
        path: file.path,
        id: 'fixture',
        unsaved: false,
      );
      final derived = await host.render(original, 0, true, 0);
      expect(derived.id, isNot(original.id));
      expect(await file.readAsBytes(), bytes);
      final inputCodec = await ui.instantiateImageCodec(bytes);
      final input = (await inputCodec.getNextFrame()).image;
      final outputCodec = await ui.instantiateImageCodec(
        await File(derived.path).readAsBytes(),
      );
      final output = (await outputCodec.getNextFrame()).image;
      expect(output.width, lessThan(input.width));
      expect(output.height, lessThan(input.height));
      expect(
        output.width / output.height,
        closeTo(input.width / input.height, .02),
      );
      input.dispose();
      output.dispose();
      inputCodec.dispose();
      outputCodec.dispose();
      await file.delete();
      await File(derived.path).delete();
    },
  );
}
