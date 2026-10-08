import 'package:dali_camera/main.dart';
import 'package:dali_camera/camera_controller.dart';
import 'package:dali_camera_platform/dali_camera_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHost extends CameraHostApi {
  bool failSave = false;
  int captures = 0;
  PhotoHandle? retained;
  int released = 0;
  @override
  Future<CameraSnapshot> start(bool front) async => CameraSnapshot(
    ready: true,
    front: front,
    configurationId: 'test',
    aspectRatio: .75,
    minimumEV: -2,
    maximumEV: 2,
    currentEV: 0,
    supportsLock: false,
    locked: false,
  );
  @override
  Future<void> stop() async {}
  @override
  Future<bool> setVoiceEnabled(bool enabled) async => false;
  @override
  Future<PhotoHandle?> recover() async => retained;
  @override
  Future<PhotoHandle> capture() async {
    captures++;
    return retained = PhotoHandle(
      path: 'fixture.jpg',
      id: 'original-$captures',
      unsaved: true,
    );
  }

  @override
  Future<void> save(PhotoHandle photo) async {
    if (failSave) throw StateError('Denied');
    retained = null;
  }

  @override
  Future<void> discard(PhotoHandle photo) async {
    retained = null;
  }

  @override
  Future<void> releasePhoto(PhotoHandle photo) async {
    released++;
  }

  @override
  Future<void> share(PhotoHandle photo) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Failed original save blocks capture and survives a controller recreation',
    () async {
      final host = FakeHost()..failSave = true;
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      await camera.capturePhoto();
      expect(camera.original!.unsaved, isTrue);
      expect(camera.canCapture, isFalse);
      expect(host.captures, 1);
      final restored = CameraController(host: host, register: false);
      await restored.initialize();
      expect(restored.reviewing, isTrue);
      host.failSave = false;
      await restored.saveSelected();
      expect(restored.original!.unsaved, isFalse);
      expect(host.retained, isNull);
    },
  );
  test('Stale session measurements cannot replace current advice', () async {
    final camera = CameraController(host: FakeHost(), register: false);
    await camera.initialize();
    camera.analysis('{"configurationId":"old"}');
    expect(camera.lastFrame, isNull);
    final entry = camera.catalog.entries.first;
    camera.choose(entry);
    camera.next();
    expect(camera.advice.recipient, entry.recipient);
    camera.choose(null);
    expect(camera.guidance.isActive, isFalse);
  });
  testWidgets('Timer cancellation prevents background and duplicate captures', (
    tester,
  ) async {
    final host = FakeHost();
    final camera = CameraController(host: host, register: false);
    await camera.initialize();
    camera.timerSeconds = 3;
    final first = camera.requestShutter();
    await tester.pump(const Duration(seconds: 1));
    expect(camera.countdown, 2);
    await camera.requestShutter();
    camera.foreground = false;
    await camera.pause();
    await tester.pump(const Duration(seconds: 3));
    await first;
    expect(host.captures, 0);
    expect(camera.countdown, 0);
    camera.foreground = true;
    await camera.start();
    final second = camera.requestShutter();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await second;
    expect(host.captures, 1);
    expect(camera.reviewing, isFalse);
    expect(camera.history.length, 1);
    expect(camera.canCapture, isTrue);
    camera.dispose();
  });
  testWidgets('Burst stops on release and cannot overwrite a failed save', (
    tester,
  ) async {
    final host = FakeHost();
    final camera = CameraController(host: host, register: false);
    await camera.initialize();
    final burst = camera.beginLongPress();
    await tester.pump();
    expect(host.captures, 1);
    camera.endLongPress();
    await tester.pump(const Duration(milliseconds: 350));
    await burst;
    expect(host.captures, 1);
    expect(camera.bursting, isFalse);
    host.failSave = true;
    final failed = camera.beginLongPress();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await failed;
    expect(host.captures, 2);
    expect(camera.original!.unsaved, isTrue);
    expect(camera.reviewing, isTrue);
    expect(camera.canCapture, isFalse);
    expect(camera.history.first.unsaved, isTrue);
    camera.dispose();
  });
  test(
    'Recent history retains 25 saved originals and prunes private copies',
    () async {
      final host = FakeHost();
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      for (var i = 0; i < 28; i++) {
        await camera.capturePhoto(review: false);
      }
      expect(camera.history.length, 25);
      expect(host.released, 3);
      await camera.openHistory(camera.history.last);
      expect(camera.reviewing, isTrue);
      expect(camera.original!.id, 'original-4');
      camera.dispose();
    },
  );
  testWidgets(
    'Shutter, Help and settings remain reachable at large text sizes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final camera = CameraController(host: FakeHost(), register: false);
      await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
      await tester.pumpAndSettle();
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byKey(const Key('shutter'))),
        ).scale(10),
        25,
      );
      expect(find.byKey(const Key('shutter')), findsOneWidget);
      await tester.tap(find.byTooltip('Help'));
      await tester.pumpAndSettle();
      expect(find.text('Take a photo with Dali'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
