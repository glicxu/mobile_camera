import 'dart:convert';
import 'package:dali_camera/camera_controller.dart';
import 'package:dali_camera/main.dart';
import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:dali_camera_platform/dali_camera_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_test.dart' show FakeHost, DelayedCaptureHost;

void main() {
  test(
    'Guidance and effective capture recipe freeze before capture completes',
    () async {
      final host = DelayedCaptureHost();
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      camera.watermark = false;
      camera.filter = 'off';
      camera.guidanceOverlayVisible = true;
      camera.advice = const Advice(
        type: 'move_left',
        recipient: 'Photographer',
        instruction: 'Move left',
        tone: AdviceTone.warning,
      );
      await camera.selectBeautifierPreset('portrait', 'Glam');
      final capture = camera.capturePhoto(review: false);
      final debug = jsonDecode(host.capturedDebug!) as Map;
      expect(debug['instructionShown'], 'Move left');
      expect(debug['beautifierPreset'], 'Glam');
      expect(debug['captureRecipe']['treatment'], 'portrait');
      expect(debug['captureRecipe']['strength'], 5);
      expect(debug['captureRecipe']['filter'], everyElement(0));
      camera.advice = const Advice(
        type: 'ready',
        recipient: 'Camera',
        instruction: 'Looks good',
        tone: AdviceTone.ready,
      );
      camera.beautifier = 'off';
      host.captureReply.complete(
        PhotoHandle(path: 'fixture.jpg', id: 'frozen', unsaved: true),
      );
      await host.savingStarted.future;
      host.finishSaving.complete();
      await capture;
      expect(jsonDecode(host.capturedDebug!)['instructionShown'], 'Move left');
      expect(host.effectsRecipe!['treatment'], 'portrait');
      expect(host.effectsRecipe!['capturePipeline'], isTrue);
      camera.dispose();
    },
  );

  test(
    'Hidden guidance is not reported as shown and debug can be disabled persistently',
    () async {
      SharedPreferences.setMockInitialValues({});
      final host = FakeHost();
      final camera = CameraController(host: host);
      await camera.initialize();
      camera.watermark = false;
      camera.filter = 'off';
      await camera.capturePhoto(review: false);
      expect(jsonDecode(host.capturedDebug!)['instructionShown'], isNull);
      expect(jsonDecode(host.capturedDebug!)['guidanceVisible'], isFalse);
      await camera.setSaveCaptureDebug(false);
      await camera.capturePhoto(review: false);
      expect(host.capturedDebug, isNull);
      await camera.pause();
      camera.dispose();
      final restored = CameraController(host: host);
      await restored.initialize();
      expect(restored.saveCaptureDebug, isFalse);
      await restored.pause();
      restored.dispose();
    },
  );

  testWidgets('Full metadata loads only on Info, without entering edit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final host = FakeHost();
    final camera = CameraController(host: host, register: false);
    await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
    await tester.pumpAndSettle();
    camera.watermark = false;
    camera.filter = 'off';
    camera.beautifier = 'off';
    await camera.capturePhoto();
    await tester.pumpAndSettle();
    expect(host.metadataRequests, 0);
    await tester.tap(find.byTooltip('Info'));
    await tester.pumpAndSettle();
    expect(host.metadataRequests, 1);
    expect(find.text('Test camera'), findsOneWidget);
    expect(find.text('ISO'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(camera.styled, isFalse);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
  });
}
