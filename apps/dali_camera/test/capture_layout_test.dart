import 'package:dali_camera/camera_controller.dart';
import 'package:dali_camera/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show FakeHost;

void main() {
  testWidgets('Small capture screen keeps guidance scrollable at large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final camera = CameraController(host: FakeHost(), register: false);
    await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
    await tester.pumpAndSettle();
    final viewport = tester.getRect(find.byKey(const Key('captureViewport')));
    await tester.tap(find.byKey(const Key('coachingToggle')));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('captureViewport'))), viewport);
    expect(camera.canCapture, isTrue);
    expect(find.byKey(const Key('shutter')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('coachingToggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('captureGuidanceOverlay')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
  });

  testWidgets(
    'Capture anchors survive both rotations and guidance never resizes the scene',
    (tester) async {
      var turns = 0;
      const channel = MethodChannel('dali/capture_layout');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => turns,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final host = FakeHost();
      final camera = CameraController(host: host, register: false);
      await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
      await tester.pumpAndSettle();
      final starts = host.starts;
      final filters = camera.filterEnabled;
      final beauty = camera.beautifierEnabled;
      final viewport = find.byKey(const Key('captureViewport'));
      final shutter = find.byKey(const Key('shutter'));
      final portraitShutter = tester.getCenter(shutter);
      final portraitBounds = tester.getRect(viewport);
      expect(portraitBounds.width, 390);
      expect(find.byKey(const Key('captureGuidanceOverlay')), findsNothing);
      await tester.tap(find.byKey(const Key('coachingToggle')));
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport), portraitBounds);
      expect(tester.getCenter(shutter), portraitShutter);
      expect(camera.canCapture, isTrue);
      expect(camera.focusX, isNull);
      await tester.tap(find.text('Guidance'));
      await tester.pumpAndSettle();
      expect(
        camera.focusX,
        isNull,
        reason: 'Overlay taps must not reach metering',
      );

      for (final rotation in [1, 3, 0]) {
        turns = rotation;
        // A metrics notification also occurs when rotating between landscape sides.
        tester.view.physicalSize = rotation == 0
            ? const Size(390, 844)
            : const Size(844, 390);
        tester.binding.handleMetricsChanged();
        await tester.pumpAndSettle();
        final center = tester.getCenter(shutter);
        if (rotation == 1) {
          expect(center.dx, closeTo(portraitShutter.dy, .01));
          expect(center.dy, closeTo(390 - portraitShutter.dx, .01));
        } else if (rotation == 3) {
          expect(center.dx, closeTo(844 - portraitShutter.dy, .01));
          expect(center.dy, closeTo(portraitShutter.dx, .01));
        } else {
          expect(center, portraitShutter);
        }
        final before = tester.getRect(viewport);
        await tester.tap(find.byKey(const Key('coachingToggle')));
        await tester.pumpAndSettle();
        expect(tester.getRect(viewport), before);
        expect(camera.canCapture, isTrue);
        expect(tester.takeException(), isNull);
      }
      expect(
        host.starts,
        starts,
        reason: 'Rotation must not restart the camera',
      );
      expect(camera.filterEnabled, filters);
      expect(camera.beautifierEnabled, beauty);
      expect(camera.snapshot!.currentZoom, 1);
      await tester.tapAt(
        tester.getRect(viewport).topLeft + const Offset(80, 80),
      );
      await tester.pumpAndSettle();
      expect(camera.focusX, isNotNull);
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
    },
  );
}
