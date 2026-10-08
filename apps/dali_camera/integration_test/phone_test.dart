import 'package:dali_camera/main.dart';
import 'package:dali_camera/camera_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Real camera, references, controls and exports work',
    (tester) async {
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
      const soakSeconds = int.fromEnvironment('DALI_SOAK_SECONDS');
      final soak = Stopwatch()..start();
      String? previousFrame;
      var receivedUpdates = 0;
      while (soak.elapsed.inSeconds < soakSeconds) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump();
        expect(camera.canCapture, isTrue, reason: camera.cameraError);
        expect(tester.takeException(), isNull);
        final frame = camera.lastFrame?['frameId'] as String?;
        if (frame != null && frame != previousFrame) receivedUpdates++;
        previousFrame = frame;
      }
      if (soakSeconds > 0) {
        expect(
          receivedUpdates,
          greaterThan(soakSeconds * .8),
          reason: 'Analysis must keep delivering fresh frames',
        );
        debugPrint(
          'SOAK: ${soak.elapsed.inSeconds}s, $receivedUpdates fresh one-second samples',
        );
      }
      await tester.ensureVisible(find.text('Posture packages'));
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
      final controls = camera.snapshot!;
      if (controls.minimumEV < controls.maximumEV) {
        await camera.controls(controls.maximumEV, false);
        expect(
          camera.snapshot!.currentEV,
          closeTo(controls.maximumEV, .1),
          reason: camera.message,
        );
        if (camera.snapshot!.supportsLock) {
          await camera.controls(0, true);
          expect(camera.snapshot!.locked, isTrue, reason: camera.message);
        }
        await camera.controls(0, false);
        expect(camera.snapshot!.currentEV, closeTo(0, .1));
        expect(camera.snapshot!.locked, isFalse);
      }
      final capabilities = camera.snapshot!;
      debugPrint(
        'DEVICE_CONTROLS: tap=${capabilities.supportsTap}; manual=${capabilities.minimumISO != null && capabilities.minimumShutter != null}; zoom=${capabilities.minimumZoom}..${capabilities.maximumZoom}',
      );
      if (capabilities.supportsTap == true) {
        final result = await camera.host.meter(
          capabilities.configurationId,
          .5,
          .5,
        );
        expect(result.ready, isTrue);
      }
      if (capabilities.maximumZoom != null &&
          capabilities.maximumZoom! > capabilities.minimumZoom!) {
        await camera.zoom(
          (capabilities.minimumZoom! + .5).clamp(
            capabilities.minimumZoom!,
            capabilities.maximumZoom!,
          ),
        );
        expect(
          camera.snapshot!.currentZoom,
          greaterThanOrEqualTo(capabilities.minimumZoom!),
        );
        await camera.zoom(1);
      }
      if (capabilities.minimumISO != null &&
          capabilities.minimumShutter != null) {
        final seconds = (1 / 125).clamp(
          capabilities.minimumShutter!,
          capabilities.maximumShutter!,
        );
        final iso = 100.0.clamp(
          capabilities.minimumISO!,
          capabilities.maximumISO!,
        );
        await camera.manual(seconds, iso);
        expect(camera.snapshot!.manualExposure, isTrue, reason: camera.message);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump();
        final applied = await camera.host.setManualExposure(
          capabilities.configurationId,
          seconds,
          iso,
        );
        expect(
          applied.currentShutter,
          closeTo(seconds, .002),
          reason: 'Sensor must report the requested shutter time',
        );
        expect(
          applied.currentISO,
          closeTo(iso, 10),
          reason: 'Sensor must report the requested ISO',
        );
        await camera.returnAuto();
        expect(camera.snapshot!.manualExposure, isFalse);
        expect(camera.snapshot!.currentEV, closeTo(0, .1));
      }
      await tester.ensureVisible(find.text('Food'));
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Food recipes'));
      await tester.tap(find.text('Food recipes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food photography'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hero plate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('steam and serving traffic'), findsOneWidget);
      await tester.tap(find.text('Use this reference'));
      await tester.pumpAndSettle();
      expect(camera.guidance.entry!.kind, 'food');
      camera.filter = 'fresh';
      camera.watermark = true;
      camera.timerSeconds = 3;
      await camera.requestShutter();
      expect(camera.reviewing, isFalse);
      expect(camera.original!.unsaved, isFalse);
      expect(camera.styled, isTrue, reason: camera.message);
      expect(camera.selected!.id, isNot(camera.original!.id));
      await camera.saveSelected();
      expect(camera.message, 'Selected copy saved to Photos');
      expect(camera.history, isNotEmpty);
      camera.filter = 'off';
      camera.watermark = false;
      camera.timerSeconds = 0;
      camera.food = false;
      camera.choose(null);
      await camera.switchLens();
      await tester.pumpAndSettle();
      expect(camera.snapshot?.front, isTrue);
      await expectLater(
        camera.host.setControls(controls.configurationId, 0, false),
        throwsA(isA<PlatformException>()),
      );
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
      await camera.returnToCamera();
      await tester.pumpAndSettle();
      final beforeBurst = camera.history.length;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('shutter'))),
      );
      await tester.pump(const Duration(milliseconds: 700));
      for (var i = 0; i < 30 && camera.history.length < beforeBurst + 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      for (var i = 0; i < 30 && camera.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pump();
      }
      expect(
        camera.bursting,
        isFalse,
        reason: 'Releasing the actual shutter gesture must stop burst',
      );
      expect(camera.history.length, greaterThanOrEqualTo(beforeBurst + 2));
      final afterBurst = camera.history.length;
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
      expect(
        camera.history.length,
        afterBurst,
        reason: 'No extra captures after release',
      );
      await camera.openHistory(camera.history.last);
      await tester.pumpAndSettle();
      expect(find.text('Photo review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
