import 'package:dali_camera/camera_controller.dart';
import 'package:dali_camera/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const diagnostics = MethodChannel('dali/preview-diagnostics');

  testWidgets('photo review preserves the live native preview', (tester) async {
    final camera = CameraController();
    await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
    for (var i = 0; i < 240 && !camera.canCapture && !camera.reviewing; i++) {
      await tester.pump(const Duration(milliseconds: 125));
    }
    if (camera.reviewing) {
      await camera.returnToCamera();
      await tester.pump();
    }
    expect(
      camera.canCapture,
      isTrue,
      reason: '${camera.cameraError}; ${camera.message}',
    );
    final initial = (await diagnostics.invokeMapMethod<String, dynamic>(
      'status',
    ))!;
    expect(initial['previewReady'], isTrue);
    final preview = tester.element(find.byType(UiKitView));

    for (var cycle = 0; cycle < 3; cycle++) {
      expect(await camera.openPhotoLibrary(), isTrue, reason: camera.message);
      await tester.pump();
      expect(camera.reviewingLibrary, isTrue, reason: camera.message);
      expect(tester.element(find.byType(UiKitView)), same(preview));
      final during = (await diagnostics.invokeMapMethod<String, dynamic>(
        'status',
      ))!;
      expect(during['previewReady'], isTrue);

      final timer = Stopwatch()..start();
      await tester.tap(find.byTooltip('Back to camera'));
      await tester.pump();
      final after = (await diagnostics.invokeMapMethod<String, dynamic>(
        'status',
      ))!;
      debugPrint(
        'DEVICE_RETURN_CYCLE=$cycle MS=${timer.elapsedMilliseconds} NATIVE=$after',
      );
      expect(camera.reviewing, isFalse);
      expect(camera.canCapture, isTrue);
      expect(find.byKey(const Key('shutter')), findsOneWidget);
      expect(tester.element(find.byType(UiKitView)), same(preview));
      expect(after['attachments'], initial['attachments']);
      expect(after['sessionRunning'], isTrue);
      expect(after['previewReady'], isTrue);
      expect(timer.elapsedMilliseconds, lessThan(500));
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
