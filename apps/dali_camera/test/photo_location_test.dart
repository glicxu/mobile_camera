import 'package:dali_camera/camera_controller.dart';
import 'package:dali_camera/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart' show FakeHost;

void main() {
  test(
    'Location defaults on, permission is requested once, and off persists',
    () async {
      SharedPreferences.setMockInitialValues({});
      final host = FakeHost()..locationStatus = 'permissionDenied';
      final camera = CameraController(host: host);
      await camera.initialize();
      expect(camera.photoLocationEnabled, isTrue);
      expect(host.locationRequests.last, (true, true));
      expect(
        camera.canCapture,
        isTrue,
        reason: 'Denied location must not block the shutter',
      );
      await camera.pause();
      await camera.start();
      expect(host.locationRequests.last, (true, false));
      await camera.setPhotoLocationEnabled(false);
      expect(host.locationRequests.last, (false, false));
      await camera.pause();
      camera.dispose();

      final restored = CameraController(host: host);
      await restored.initialize();
      expect(restored.photoLocationEnabled, isFalse);
      expect(host.locationRequests.last, (false, false));
      await restored.setPhotoLocationEnabled(true);
      expect(host.locationRequests.last, (true, true));
      await restored.pause();
      restored.dispose();
    },
  );

  testWidgets('Settings expose optional photo location and denial help', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final host = FakeHost()..locationStatus = 'permissionDenied';
    final camera = CameraController(host: host, register: false);
    await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appSettingsButton')));
    await tester.pumpAndSettle();
    expect(find.text('Save photo location'), findsOneWidget);
    expect(find.text('Open location permissions'), findsOneWidget);
    await tester.tap(find.byKey(const Key('photoLocationToggle')));
    await tester.pumpAndSettle();
    expect(camera.photoLocationEnabled, isFalse);
    expect(find.text('New photos will not include location.'), findsOneWidget);
    expect(find.text('Open location permissions'), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(camera.canCapture, isTrue);
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
  });
}
