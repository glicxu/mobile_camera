import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:dali_camera_platform/dali_camera_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  bridgeStage('main registered');
  testWidgets(
    'Native file rendering preserves original and crops selected copy',
    (tester) async {
      bridgeStage('test started: recovery');
      final host = CameraHostApi();
      // Exercises plugin registration and nullable result transport without camera hardware.
      expect(
        await host.recover().timeout(const Duration(seconds: 20)),
        isNull,
        reason: 'Recovery fixture requires an empty test app',
      );
      bridgeStage('bundle fixture');
      final source = await rootBundle.load(
        'assets/catalog/pose-relaxed-standing.jpg',
      );
      final file = File('${Directory.systemTemp.path}/dali-bridge-fixture.jpg');
      final bytes = source.buffer.asUint8List(
        source.offsetInBytes,
        source.lengthInBytes,
      );
      await file.writeAsBytes(bytes, flush: true);
      if (const bool.fromEnvironment('DALI_TEST_LIBRARY')) {
        bridgeStage('listing Photos library');
        final library = await host.listPhotoLibrary().timeout(
          const Duration(seconds: 30),
        );
        expect(library.status, 'authorized');
        expect(
          library.photos,
          hasLength(1),
          reason:
              'Disposable simulator is seeded with one public repository fixture',
        );
        bridgeStage('loading Photos asset');
        final copy = await host
            .loadLibraryPhoto(library.photos.single.id)
            .timeout(const Duration(seconds: 30));
        expect(copy.unsaved, isFalse);
        expect(
          await File(copy.path).readAsBytes(),
          orderedEquals(bytes),
          reason: 'Library import must preserve original provider bytes',
        );
        await host.releasePhoto(copy);
        expect(File(copy.path).existsSync(), isFalse);
        expect(
          (await host.listPhotoLibrary()).photos,
          hasLength(1),
          reason: 'Private cleanup must not delete a Photos asset',
        );
        await expectLater(
          host.loadLibraryPhoto('missing-library-asset'),
          throwsA(isA<PlatformException>()),
        );
      }

      final original = PhotoHandle(
        path: file.path,
        id: 'fixture',
        unsaved: false,
      );
      bridgeStage('analyzing portrait');
      final analysis =
          jsonDecode(
                await host
                    .analyzePhoto(original)
                    .timeout(const Duration(seconds: 45)),
              )
              as Map;
      expect(analysis['sourceId'], 'fixture');
      expect(analysis['schemaVersion'], 1);
      expect(analysis['poseKeypoints'], isA<Map>());
      NativeFrame(analysis.cast<String, dynamic>());
      if (Platform.isAndroid) {
        expect((analysis['faces'] as List), isNotEmpty);
        expect((analysis['people'] as List), isNotEmpty);
        if ((analysis['poseKeypoints'] as Map).length < 6) {
          expect(
            (analysis['people'] as List).first['label'],
            'person_estimated',
          );
        }
      }
      // Exercise each new spatial processing path on a real, bundled portrait.
      for (final recipe in [
        {'version': 1, 'treatment': 'portrait', 'strength': 3},
        {'version': 1, 'treatment': 'landscape', 'strength': 3},
        {'version': 1, 'treatment': 'original', 'depth': 3},
      ]) {
        bridgeStage('rendering ${recipe["treatment"]}');
        final copy = await host
            .renderEffects(original, jsonEncode(recipe))
            .timeout(const Duration(seconds: 60));
        final sourceCodec = await ui.instantiateImageCodec(bytes);
        final sourceImage = (await sourceCodec.getNextFrame()).image;
        final copyCodec = await ui.instantiateImageCodec(
          await File(copy.path).readAsBytes(),
        );
        final copyImage = (await copyCodec.getNextFrame()).image;
        expect(copyImage.width, sourceImage.width);
        expect(copyImage.height, sourceImage.height);
        expect(await file.readAsBytes(), bytes);
        copyImage.dispose();
        sourceImage.dispose();
        copyCodec.dispose();
        sourceCodec.dispose();
        await host.releasePhoto(copy);
        expect(await File(copy.path).exists(), isFalse);
      }
      if (Platform.isAndroid) {
        // A tilted two-tone scene exercises the actual optical horizon contract
        // and correction, independently of phone roll and person detection.
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(const ui.Color(0xff80bfff), ui.BlendMode.src);
        canvas.drawPath(
          ui.Path()
            ..moveTo(0, 100)
            ..lineTo(480, 228)
            ..lineTo(480, 360)
            ..lineTo(0, 360)
            ..close(),
          ui.Paint()..color = const ui.Color(0xff304020),
        );
        final picture = recorder.endRecording();
        final scene = await picture.toImage(480, 360);
        final sceneBytes = (await scene.toByteData(
          format: ui.ImageByteFormat.png,
        ))!;
        final sceneFile = File('${Directory.systemTemp.path}/dali-horizon.png');
        await sceneFile.writeAsBytes(sceneBytes.buffer.asUint8List());
        final sceneHandle = PhotoHandle(
          path: sceneFile.path,
          id: 'horizon',
          unsaved: false,
        );
        final sceneAnalysis =
            (jsonDecode(await host.analyzePhoto(sceneHandle)) as Map)
                .cast<String, dynamic>();
        final parsed = NativeFrame(sceneAnalysis);
        expect(parsed.frame.horizon.value?.angleDegrees, closeTo(15, 2));
        expect(
          parsed.frame.horizon.value?.normalizedY,
          inInclusiveRange(0.0, 1.0),
        );
        final leveled = await host.renderEffects(
          sceneHandle,
          jsonEncode({'version': 1, 'treatment': 'level'}),
        );
        final corrected = NativeFrame(
          (jsonDecode(await host.analyzePhoto(leveled)) as Map)
              .cast<String, dynamic>(),
        );
        expect(corrected.frame.horizon.value?.angleDegrees, closeTo(0, 2));
        await host.releasePhoto(leveled);
        await sceneFile.delete();
        scene.dispose();
        picture.dispose();
      }
      final enhanced = await host.renderEffects(
        original,
        jsonEncode({'version': 1, 'treatment': 'enhance', 'strength': 3}),
      );
      expect(enhanced.id, isNot(original.id));
      expect(await File(enhanced.path).exists(), isTrue);
      expect(await file.readAsBytes(), bytes);
      final enhancedCodec = await ui.instantiateImageCodec(
        await File(enhanced.path).readAsBytes(),
      );
      final enhancedImage = (await enhancedCodec.getNextFrame()).image;
      final originalCodec = await ui.instantiateImageCodec(bytes);
      final originalImage = (await originalCodec.getNextFrame()).image;
      expect(enhancedImage.width, originalImage.width);
      expect(enhancedImage.height, originalImage.height);
      final effectOriginalPixels = await originalImage.toByteData();
      final enhancedPixels = await enhancedImage.toByteData();
      expect(
        enhancedPixels!.buffer.asUint8List(),
        isNot(effectOriginalPixels!.buffer.asUint8List()),
      );
      enhancedImage.dispose();
      originalImage.dispose();
      enhancedCodec.dispose();
      originalCodec.dispose();
      await host.releasePhoto(enhanced);
      expect(await File(enhanced.path).exists(), isFalse);
      await expectLater(
        host.renderEffects(
          original,
          jsonEncode({'version': 1, 'treatment': 'unknown'}),
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(await file.readAsBytes(), bytes);
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
      final style = await host.renderStyle(
        original,
        PhotoStyle.preset(SharedCatalog(), 'fresh', 'food').matrix,
        0,
        1,
        null,
      );
      expect(await file.readAsBytes(), bytes);
      final styleCodec = await ui.instantiateImageCodec(
        await File(style.path).readAsBytes(),
      );
      final styled = (await styleCodec.getNextFrame()).image;
      expect(styled.width, input.width);
      expect(styled.height, input.height);
      final originalPixels = await input.toByteData();
      final stylePixels = await styled.toByteData();
      expect(
        pixelDifference(
          originalPixels!,
          stylePixels!,
          input.width,
          0,
          0,
          input.width,
          input.height,
        ),
        greaterThan(1),
        reason: 'Style must visibly change decoded pixels',
      );
      styled.dispose();
      styleCodec.dispose();
      await host.releasePhoto(style);
      expect(await File(style.path).exists(), isFalse);
      final preset = PhotoStyle.preset(SharedCatalog(), 'fresh', 'food');
      final filtered = await host.renderFilter(
        original,
        preset.matrix,
        PhotoStyle.fields
            .map((field) => preset.value(field).toDouble())
            .toList(),
        null,
      );
      final filterCodec = await ui.instantiateImageCodec(
        await File(filtered.path).readAsBytes(),
      );
      final filterImage = (await filterCodec.getNextFrame()).image;
      expect(filterImage.width, input.width);
      expect(filterImage.height, input.height);
      expect(
        pixelDifference(
          originalPixels,
          (await filterImage.toByteData())!,
          input.width,
          0,
          0,
          input.width,
          input.height,
        ),
        greaterThan(1),
      );
      expect(await file.readAsBytes(), bytes);
      filterImage.dispose();
      filterCodec.dispose();
      await host.releasePhoto(filtered);
      await expectLater(
        host.renderFilter(original, preset.matrix, [0], null),
        throwsA(isA<PlatformException>()),
      );
      await host.releasePhoto(original);
      expect(
        await file.exists(),
        isTrue,
        reason:
            'Cleanup cannot delete a file outside the private photo directory',
      );
      await expectLater(
        host.renderStyle(original, [1], 0, 0, null),
        throwsA(isA<PlatformException>()),
      );
      final watermarkAsset = await rootBundle.load(
        'assets/branding/dali-cam-watermark.png',
      );
      final markFile = File(
        '${Directory.systemTemp.path}/dali-bridge-watermark.png',
      );
      await markFile.writeAsBytes(
        watermarkAsset.buffer.asUint8List(
          watermarkAsset.offsetInBytes,
          watermarkAsset.lengthInBytes,
        ),
      );
      final plain = await host.renderStyle(
        original,
        PhotoStyle.identity,
        0,
        0,
        null,
      );
      final plainCodec = await ui.instantiateImageCodec(
        await File(plain.path).readAsBytes(),
      );
      final plainImage = (await plainCodec.getNextFrame()).image;
      final plainPixels = (await plainImage.toByteData())!;
      final watermarked = await host.renderStyle(
        original,
        PhotoStyle.identity,
        0,
        0,
        markFile.path,
      );
      final markCodec = await ui.instantiateImageCodec(
        await File(watermarked.path).readAsBytes(),
      );
      final markImage = (await markCodec.getNextFrame()).image;
      final markPixels = await markImage.toByteData();
      expect(
        pixelDifference(
          plainPixels,
          markPixels!,
          input.width,
          (input.width * .65).toInt(),
          (input.height * .80).toInt(),
          input.width,
          input.height,
        ),
        greaterThan(.2),
        reason: 'Watermark must appear in the bottom-right region',
      );
      expect(
        pixelDifference(
          plainPixels,
          markPixels,
          input.width,
          0,
          0,
          input.width ~/ 2,
          input.height ~/ 2,
        ),
        lessThan(1),
        reason: 'Watermark must not alter the top-left photo region',
      );
      plainImage.dispose();
      plainCodec.dispose();
      await host.releasePhoto(plain);
      markImage.dispose();
      markCodec.dispose();
      await host.releasePhoto(watermarked);
      await markFile.delete();
      input.dispose();
      output.dispose();
      inputCodec.dispose();
      outputCodec.dispose();
      // Test the native recovery reader using an owned fixture, not a user capture.
      final manifest = File('${File(derived.path).parent.path}/pending.json');
      await manifest.writeAsString(
        jsonEncode({'path': derived.path, 'id': derived.id}),
        flush: true,
      );
      if (Platform.isAndroid) {
        // AtomicFile must restore its backup after an interrupted replacement.
        await manifest.rename('${manifest.path}.bak');
      }
      final recovered = await host.recover();
      expect(recovered?.id, derived.id);
      expect(recovered?.unsaved, isTrue);
      await host.releasePhoto(recovered!);
      final orphan = await host.renderEffects(
        original,
        jsonEncode({'version': 1, 'treatment': 'original'}),
      );
      await host.reconcilePrivatePhotos([]);
      expect(await File(orphan.path).exists(), isFalse);
      expect(await file.readAsBytes(), bytes);
      expect(
        await File(derived.path).exists(),
        isTrue,
        reason: 'Pending original must survive history cleanup',
      );
      await host.discard(recovered);
      expect(await host.recover(), isNull);
      expect(await File(derived.path).exists(), isFalse);
      await file.delete();
      // A 3.84 MP source exceeds the old derivative cap and bounded analysis size.
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 2400, 1600),
        ui.Paint()..color = const ui.Color(0xff606060),
      );
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 800, 2400, 800),
        ui.Paint()..color = const ui.Color(0xff406040),
      );
      final picture = recorder.endRecording();
      final largeImage = await picture.toImage(2400, 1600);
      picture.dispose();
      final largeData = await largeImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      largeImage.dispose();
      final largeBytes = largeData!.buffer.asUint8List(
        largeData.offsetInBytes,
        largeData.lengthInBytes,
      );
      final largeFile = File(
        '${Directory.systemTemp.path}/dali-full-resolution.png',
      );
      await largeFile.writeAsBytes(largeBytes, flush: true);
      final largeSource = PhotoHandle(
        path: largeFile.path,
        id: 'large-fixture',
        unsaved: false,
        mimeType: 'image/png',
      );
      bridgeStage('full-resolution treatment');
      final largeResult = await host.renderEffects(
        largeSource,
        jsonEncode({'version': 1, 'treatment': 'enhance', 'strength': 3}),
      );
      final largeCodec = await ui.instantiateImageCodec(
        await File(largeResult.path).readAsBytes(),
      );
      final resultImage = (await largeCodec.getNextFrame()).image;
      expect(resultImage.width, 2400);
      expect(resultImage.height, 1600);
      resultImage.dispose();
      largeCodec.dispose();
      expect(
        await largeFile.readAsBytes(),
        orderedEquals(largeBytes),
        reason: 'High-resolution treatment must not overwrite its source',
      );
      await host.releasePhoto(largeResult);
      await largeFile.delete();
      bridgeStage('completed');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

// Persist progress even when the remote test stream stops forwarding output.
void bridgeStage(String stage) {
  File(
    '${Directory.systemTemp.path}/dali-bridge-progress.txt',
  ).writeAsStringSync(stage, flush: true);
  debugPrint('BRIDGE_STAGE: $stage');
}

// Mean absolute RGB difference in a region; alpha and JPEG byte changes are excluded.
double pixelDifference(
  ByteData a,
  ByteData b,
  int width,
  int x1,
  int y1,
  int x2,
  int y2,
) {
  var total = 0;
  var channels = 0;
  for (var y = y1; y < y2; y++) {
    for (var x = x1; x < x2; x++) {
      final index = (y * width + x) * 4;
      for (var c = 0; c < 3; c++) {
        total += (a.getUint8(index + c) - b.getUint8(index + c)).abs();
        channels++;
      }
    }
  }
  return total / channels;
}
