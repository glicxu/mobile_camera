import 'package:dali_camera/main.dart';
import 'package:dali_camera/camera_controller.dart';
import 'package:dali_camera_platform/dali_camera_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHost extends CameraHostApi {
  bool failSave = false;
  int captures = 0;
  PhotoHandle? retained;
  @override Future<CameraSnapshot> start(bool front) async => CameraSnapshot(ready: true, front: front, configurationId: 'test', aspectRatio: .75, minimumEV: -2, maximumEV: 2, currentEV: 0, supportsLock: false, locked: false);
  @override Future<void> stop() async {}
  @override Future<bool> setVoiceEnabled(bool enabled) async => false;
  @override Future<PhotoHandle?> recover() async => retained;
  @override Future<PhotoHandle> capture() async { captures++; return retained = PhotoHandle(path: 'fixture.jpg', id: 'original', unsaved: true); }
  @override Future<void> save(PhotoHandle photo) async { if (failSave) throw StateError('Denied'); retained = null; }
  @override Future<void> discard(PhotoHandle photo) async { retained = null; }
  @override Future<void> share(PhotoHandle photo) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Failed original save blocks capture and survives a controller recreation', () async {
    final host = FakeHost()..failSave = true;
    final camera = CameraController(host: host, register: false);
    await camera.initialize(); await camera.capturePhoto();
    expect(camera.original!.unsaved, isTrue); expect(camera.canCapture, isFalse);
    expect(host.captures, 1);
    final restored = CameraController(host: host, register: false);
    await restored.initialize(); expect(restored.reviewing, isTrue);
    host.failSave = false; await restored.saveSelected();
    expect(restored.original!.unsaved, isFalse); expect(host.retained, isNull);
  });
  test('Stale session measurements cannot replace current advice', () async {
    final camera = CameraController(host: FakeHost(), register: false);
    await camera.initialize();
    camera.analysis('{"configurationId":"old"}');
    expect(camera.lastFrame, isNull);
    final entry = camera.catalog.entries.first;
    camera.choose(entry); camera.next();
    expect(camera.advice.recipient, entry.recipient);
    camera.choose(null); expect(camera.guidance.isActive, isFalse);
  });
  testWidgets('Shutter, Help and settings remain reachable at large text sizes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final camera = CameraController(host: FakeHost(), register: false);
    await tester.pumpWidget(MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(2.5)), child: DaliApp(controller: camera)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shutter')), findsOneWidget);
    await tester.tap(find.byTooltip('Help')); await tester.pumpAndSettle();
    expect(find.text('Take a photo with Dali'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
