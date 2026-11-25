import 'dart:convert';
import 'package:dali_camera/camera_controller.dart';
import 'package:dali_camera/main.dart';
import 'package:dali_camera/watermark_identity.dart';
import 'package:dali_camera/watermark_entitlement.dart';
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
      final camera = CameraController(
        host: host,
        register: false,
        watermarkEntitlement: FixedWatermarkEntitlement(),
      );
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
      final identity = parseDaliWatermarkIdentity(debug['hiddenWatermark']);
      expect(identity, isNotNull);
      expect(identity!.version, 2);
      expect(identity.ownerId, camera.watermarkOwnerId);
      expect(identity.photoId, isNotEmpty);
      expect(debug['pixelWatermarkPayload'], debug['hiddenWatermark']);
      expect(debug['captureRecipe']['hiddenWatermarkPixels'], isTrue);
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
    'Offline watermark profile persists and identifies new photos',
    () async {
      SharedPreferences.setMockInitialValues({});
      final host = FakeHost();
      final camera = CameraController(
        host: host,
        watermarkEntitlement: FixedWatermarkEntitlement(),
      );
      await camera.initialize();
      final ownerId = camera.watermarkOwnerId;
      expect(await camera.setWatermarkPublicId('GLICX-PHOTO'), isNull);
      camera.watermark = false;
      camera.filter = 'off';
      await camera.capturePhoto(review: false);
      final captured = jsonDecode(host.capturedDebug!) as Map;
      final identity = parseDaliWatermarkIdentity(captured['hiddenWatermark']);
      expect(identity?.version, 2);
      expect(identity?.ownerId, ownerId);
      expect(identity?.publicId, 'GLICX-PHOTO');
      expect(identity?.photoId, isNotEmpty);
      await camera.pause();
      camera.dispose();

      final restored = CameraController(
        host: host,
        watermarkEntitlement: FixedWatermarkEntitlement(),
      );
      await restored.initialize();
      expect(restored.watermarkOwnerId, ownerId);
      expect(restored.watermarkPublicId, 'GLICX-PHOTO');
      expect(
        await restored.setWatermarkPublicId('not valid spaces'),
        isNotNull,
      );
      expect(await restored.resetWatermarkProfile(), isTrue);
      final resetOwnerId = restored.watermarkOwnerId;
      expect(resetOwnerId, isNot(ownerId));
      expect(restored.watermarkPublicId, isEmpty);
      await restored.pause();
      restored.dispose();

      final afterReset = CameraController(
        host: host,
        watermarkEntitlement: FixedWatermarkEntitlement(),
      );
      await afterReset.initialize();
      expect(afterReset.watermarkOwnerId, resetOwnerId);
      expect(afterReset.watermarkPublicId, isEmpty);
      await afterReset.pause();
      afterReset.dispose();
    },
  );

  test(
    'Hidden guidance is not reported as shown and debug can be disabled persistently',
    () async {
      SharedPreferences.setMockInitialValues({});
      final host = FakeHost();
      final camera = CameraController(
        host: host,
        watermarkEntitlement: FixedWatermarkEntitlement(),
      );
      await camera.initialize();
      camera.watermark = false;
      camera.filter = 'off';
      await camera.capturePhoto(review: false);
      expect(jsonDecode(host.capturedDebug!)['instructionShown'], isNull);
      expect(jsonDecode(host.capturedDebug!)['guidanceVisible'], isFalse);
      await camera.setHiddenWatermarkMode('off');
      await camera.setSaveCaptureDebug(false);
      await camera.capturePhoto(review: false);
      expect(host.capturedDebug, isNull);
      await camera.pause();
      camera.dispose();
      final restored = CameraController(
        host: host,
        watermarkEntitlement: FixedWatermarkEntitlement(),
      );
      await restored.initialize();
      expect(restored.saveCaptureDebug, isFalse);
      expect(restored.hiddenWatermarkMode, 'off');
      await restored.pause();
      restored.dispose();
    },
  );

  test(
    'Locked watermark entitlement blocks capture payloads and profile edits',
    () async {
      SharedPreferences.setMockInitialValues({'hiddenWatermarkMode': 'both'});
      final host = FakeHost();
      final camera = CameraController(
        host: host,
        register: false,
        watermarkEntitlement: FixedWatermarkEntitlement(unlocked: false),
      );
      await camera.initialize();

      expect(camera.watermarkUnlocked, isFalse);
      expect(camera.metadataHiddenWatermarkEnabled, isFalse);
      expect(camera.pixelHiddenWatermarkEnabled, isFalse);
      expect(
        await camera.setWatermarkPublicId('LOCKED-PROFILE'),
        'Lifetime watermark access is required.',
      );

      camera.watermark = false;
      camera.filter = 'off';
      await camera.capturePhoto(review: false);
      final debug = jsonDecode(host.capturedDebug!) as Map;
      expect(debug['hiddenWatermark'], isNull);
      expect(debug['pixelWatermarkPayload'], isNull);
      expect(debug['hiddenWatermarkPixels'], isFalse);
      expect(debug['captureRecipe']['hiddenWatermarkPixels'], isFalse);
      camera.dispose();
    },
  );

  testWidgets('Locked watermark settings open the lifetime purchase gate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final camera = CameraController(
      host: FakeHost(),
      register: false,
      watermarkEntitlement: FixedWatermarkEntitlement(unlocked: false),
    );
    await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('photoSettingsGroup')));
    await tester.tap(find.byKey(const Key('photoSettingsGroup')));
    await tester.pumpAndSettle();
    expect(find.text('Lifetime unlock required'), findsOneWidget);
    expect(find.byKey(const Key('hiddenWatermarkMode')), findsNothing);

    await tester.tap(find.byKey(const Key('watermarkProfile')));
    await tester.pumpAndSettle();
    expect(find.text('Lifetime watermark unlock'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.byKey(const Key('purchaseWatermarkUnlock')), findsOneWidget);
    expect(find.text(r'Unlock · $9.99'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    camera.dispose();
  });

  testWidgets('Full metadata loads only on Info, without entering edit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final host = FakeHost();
    final camera = CameraController(
      host: host,
      register: false,
      watermarkEntitlement: FixedWatermarkEntitlement(),
    );
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

  testWidgets('Offline watermark profile is editable from Settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final camera = CameraController(
      host: FakeHost(),
      register: false,
      watermarkEntitlement: FixedWatermarkEntitlement(),
    );
    await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('photoSettingsGroup')));
    await tester.tap(find.byKey(const Key('photoSettingsGroup')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('watermarkProfile')));
    await tester.tap(find.byKey(const Key('watermarkProfile')));
    await tester.pumpAndSettle();

    expect(find.text('Offline watermark profile'), findsWidgets);
    expect(find.text('Generated owner ID'), findsOneWidget);
    expect(find.text(camera.watermarkOwnerId), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('watermarkPublicId')),
      'GLICX-PHOTO',
    );
    await tester.tap(find.byKey(const Key('saveWatermarkProfile')));
    await tester.pumpAndSettle();

    expect(camera.watermarkPublicId, 'GLICX-PHOTO');
    expect(find.textContaining('GLICX-PHOTO'), findsOneWidget);
    final previousOwnerId = camera.watermarkOwnerId;
    await tester.tap(find.byKey(const Key('watermarkProfile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resetWatermarkProfile')));
    await tester.pumpAndSettle();
    expect(find.text('Create a new identity?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmResetWatermarkProfile')));
    await tester.pumpAndSettle();
    expect(camera.watermarkOwnerId, isNot(previousOwnerId));
    expect(camera.watermarkPublicId, isEmpty);
    expect(find.textContaining('No public ID'), findsOneWidget);

    final recoveryCode = createDaliIdentityRecovery(
      ownerId: previousOwnerId,
      publicId: 'GLICX-PHOTO',
    );
    await tester.tap(find.byKey(const Key('watermarkProfile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restoreWatermarkProfile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('watermarkRecoveryCode')),
      recoveryCode,
    );
    await tester.tap(find.byKey(const Key('confirmRestoreWatermarkProfile')));
    await tester.pumpAndSettle();
    expect(camera.watermarkOwnerId, previousOwnerId);
    expect(camera.watermarkPublicId, 'GLICX-PHOTO');
    expect(find.textContaining('GLICX-PHOTO'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
  });
}
