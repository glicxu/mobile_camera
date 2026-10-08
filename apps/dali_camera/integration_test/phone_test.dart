import 'package:dali_camera/main.dart';
import 'package:dali_camera/camera_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real camera starts and references are selectable', (
    tester,
  ) async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final camera = CameraController();
    await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (tester
              .widget<FilledButton>(find.byKey(const Key('shutter')))
              .onPressed !=
          null) {
        break;
      }
    }
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('shutter'))).onPressed,
      isNotNull,
      reason:
          'Camera readiness: ${camera.cameraError}; ${camera.message}; starting=${camera.starting}; snapshot=${camera.snapshot?.ready}',
    );
    final previewSize = tester.getSize(find.byType(AspectRatio).first);
    expect(
      previewSize.width / previewSize.height,
      closeTo(camera.aspectRatio, .01),
      reason: 'Overlay surface must match the complete oriented camera image',
    );
    await tester.tap(find.text('Posture packages'));
    await tester.pumpAndSettle();
    expect(find.text('Male / Masculine'), findsOneWidget);
    await tester.tap(find.text('Male / Masculine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relaxed standing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this reference'));
    await tester.pumpAndSettle();
    expect(find.text('Done / Next'), findsOneWidget);
    await tester.ensureVisible(find.text('Natural'));
    await tester.tap(find.text('Natural'));
    await tester.pumpAndSettle();
    expect(camera.guidance.isActive, isFalse);
    await camera.switchLens();
    await tester.pumpAndSettle();
    expect(camera.snapshot?.front, isTrue);
    await camera.switchLens();
    await tester.pumpAndSettle();
    expect(camera.snapshot?.front, isFalse);
    await camera.capturePhoto();
    await tester.pumpAndSettle();
    expect(camera.reviewing, isTrue);
    expect(camera.original?.unsaved, isFalse, reason: camera.message);
    expect(find.text('Photo review'), findsOneWidget);
    await camera.variant(crop: true);
    await tester.pumpAndSettle();
    expect(camera.selected?.id, isNot(camera.original?.id));
    await camera.saveSelected();
    await tester.pumpAndSettle();
    expect(camera.message, contains('copy saved'));
    expect(tester.takeException(), isNull);
  });
}
