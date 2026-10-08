import 'package:dali_camera/capture_feedback.dart';
import 'package:dali_camera/capture_result_preview.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dali_camera/main.dart';
import 'package:dali_camera/camera_controller.dart';
import 'package:dali_camera_platform/dali_camera_platform.dart';
import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dali_camera/review_comparison.dart';
import 'package:dali_camera/manual_preview_controls.dart';
import 'package:dali_camera/review_treatment_controls.dart';
import 'package:dali_camera/live_guidance.dart';
import 'package:dali_camera/distance_swipe.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FakeHost extends CameraHostApi {
  bool failSave = false;
  bool? lastFocusOnly;
  bool? lastResetFocus;
  bool failRender = false;
  bool voiceAvailable = false;
  List<double>? filterParameters;
  Map<String, dynamic>? effectsRecipe;
  int captures = 0;
  final List<String> savedIds = [];
  PhotoHandle? retained;
  int released = 0;
  final List<String> releasedIds = [];
  PhotoImport importResult = PhotoImport(photos: [], skipped: 0);
  bool failImport = false;
  int importRequests = 0;
  bool? importedFolder;
  @override
  Future<CameraSnapshot> start(bool front) async => CameraSnapshot(
    ready: true,
    front: front,
    configurationId: 'test',
    aspectRatio: .75,
    minimumEV: -2,
    maximumEV: 2,
    currentEV: 0,
    supportsTap: true,
    supportsLock: false,
    locked: false,
  );
  @override
  Future<CameraSnapshot> setManualExposure(
    String configurationId,
    double? seconds,
    double? iso,
    bool resetFocus,
  ) async => start(false);
  @override
  Future<CameraSnapshot> meter(
    String configurationId,
    double x,
    double y,
    bool focusOnly,
  ) async {
    lastFocusOnly = focusOnly;
    return start(false);
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> setVoicePhrase(String phrase) async {}
  @override
  Future<void> reconcilePrivatePhotos(List<String> retainedPaths) async {}
  @override
  Future<void> setDepthPreview(
    String configurationId,
    int level,
    String? subjectRect,
  ) async {}
  @override
  Future<bool> setVoiceEnabled(bool enabled) async => enabled && voiceAvailable;
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
    savedIds.add(photo.id);
    retained = null;
  }

  @override
  Future<void> saveCaptured(PhotoHandle original, PhotoHandle processed) async {
    await save(processed);
  }

  @override
  Future<void> discard(PhotoHandle photo) async {
    retained = null;
  }

  @override
  Future<void> releasePhoto(PhotoHandle photo) async {
    released++;
    releasedIds.add(photo.id);
  }

  PhotoLibrary libraryResult = PhotoLibrary(photos: [], status: 'empty');
  final List<String> loadedLibraryIds = [];
  String? failedLibraryId;
  @override
  Future<PhotoLibrary> listPhotoLibrary() async => libraryResult;
  @override
  Future<PhotoHandle> loadLibraryPhoto(String id) async {
    loadedLibraryIds.add(id);
    if (failedLibraryId == id) throw StateError('iCloud offline');
    return PhotoHandle(path: 'library-$id.jpg', id: 'copy-$id', unsaved: false);
  }

  @override
  Future<PhotoImport> pickPhotos(bool folder) async {
    importRequests++;
    importedFolder = folder;
    if (failImport) throw StateError('Provider unavailable');
    return importResult;
  }

  @override
  Future<void> share(PhotoHandle photo) async {}
  @override
  Future<String> analyzePhoto(PhotoHandle photo) async => jsonEncode({
    'schemaVersion': 1,
    'sourceId': photo.id,
    'faces': [],
    'poseKeypoints': {},
  });
  @override
  Future<PhotoHandle> renderEffects(PhotoHandle original, String recipe) async {
    if (failRender) throw StateError('Renderer unavailable');
    effectsRecipe = jsonDecode(recipe) as Map<String, dynamic>;
    filterParameters = (effectsRecipe!['filter'] as List?)
        ?.cast<num>()
        .map((v) => v.toDouble())
        .toList();
    return PhotoHandle(
      path: 'effects.jpg',
      id: 'effects-${original.id}',
      unsaved: false,
    );
  }

  @override
  Future<PhotoHandle> render(
    PhotoHandle original,
    double rotationDegrees,
    bool crop,
    double strength,
  ) async {
    if (failRender) throw StateError('Renderer unavailable');
    return PhotoHandle(
      path: 'derived.jpg',
      id: 'derived-${original.id}',
      unsaved: false,
    );
  }

  @override
  Future<PhotoHandle> renderFilter(
    PhotoHandle original,
    List<double> matrix,
    List<double> parameters,
    String? watermarkPath,
  ) async {
    if (failRender) throw StateError('Renderer unavailable');
    filterParameters = parameters;
    return PhotoHandle(
      path: 'filtered.jpg',
      id: 'filtered-${original.id}',
      unsaved: false,
    );
  }
}

class DelayedCaptureHost extends FakeHost {
  final captureReply = Completer<PhotoHandle>();
  final savingStarted = Completer<void>();
  final finishSaving = Completer<void>();
  @override
  Future<PhotoHandle> capture() => captureReply.future;
  @override
  Future<void> save(PhotoHandle photo) async {
    savingStarted.complete();
    await finishSaving.future;
    await super.save(photo);
  }
}

class DelayedEffectsHost extends FakeHost {
  final renderingStarted = Completer<void>();
  final finishRendering = Completer<void>();
  @override
  Future<PhotoHandle> renderEffects(PhotoHandle original, String recipe) async {
    renderingStarted.complete();
    await finishRendering.future;
    return super.renderEffects(original, recipe);
  }
}

class ManualHost extends FakeHost {
  @override
  Future<CameraSnapshot> start(bool front) async => (await super.start(front))
    ..minimumISO = 20
    ..maximumISO = 1600
    ..currentISO = 100
    ..minimumShutter = 1 / 4000
    ..maximumShutter = .5
    ..currentShutter = 1 / 125;
  @override
  Future<CameraSnapshot> setManualExposure(
    String configurationId,
    double? seconds,
    double? iso,
    bool resetFocus,
  ) async {
    lastResetFocus = resetFocus;
    return (await start(false))
      ..manualExposure = seconds != null
      ..currentISO = iso ?? 100
      ..currentShutter = seconds ?? 1 / 125;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Successful capture flashes before saving finishes without spinning shutter',
    (tester) async {
      final host = DelayedCaptureHost();
      final camera = CameraController(host: host, register: false);
      await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
      await tester.pumpAndSettle();
      camera.watermark = false;
      camera.beautifier = 'off';
      camera.filter = 'off';
      final capture = camera.capturePhoto(review: false);
      await tester.pump();
      expect(camera.takingPhoto, isTrue);
      expect(camera.capturedPhotoSequence, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      host.captureReply.complete(
        PhotoHandle(path: 'fixture.jpg', id: 'capture-ack', unsaved: true),
      );
      await host.savingStarted.future;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(camera.takingPhoto, isFalse);
      expect(camera.busy, isTrue);
      expect(camera.capturedPhotoSequence, 1);
      expect(find.text('Photo taken'), findsOneWidget);
      expect(
        tester.widget<Opacity>(find.byKey(const Key('captureFlash'))).opacity,
        greaterThan(0),
      );
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('shutter'))).onPressed,
        isNull,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.widget<Opacity>(find.byKey(const Key('captureFlash'))).opacity,
        0,
      );
      host.finishSaving.complete();
      await capture;
      await tester.pumpAndSettle();
      expect(find.text('Photo taken'), findsNothing);
    },
  );
  test(
    'Failed capture does not acknowledge a photo and resets capture state',
    () async {
      final host = DelayedCaptureHost();
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      final capture = camera.capturePhoto();
      host.captureReply.completeError(StateError('Camera capture failed'));
      await capture;
      expect(camera.capturedPhotoSequence, 0);
      expect(camera.takingPhoto, isFalse);
      expect(camera.busy, isFalse);
      camera.dispose();
    },
  );
  testWidgets('Reduced motion uses Photo taken confirmation without flashing', (
    tester,
  ) async {
    Widget feedback(int sequence) => MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CaptureFeedback(sequence: sequence),
        ),
      ),
    );
    await tester.pumpWidget(feedback(0));
    await tester.pumpWidget(feedback(1));
    await tester.pump();
    expect(find.text('Photo taken'), findsOneWidget);
    expect(find.byKey(const Key('captureFlash')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Photo taken'), findsNothing);
  });

  test(
    'Capture is processed before its only gallery save and controls stay guarded',
    () async {
      final host = DelayedEffectsHost();
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      camera.watermark = false;
      camera.filter = 'fresh';
      camera.beautifier = 'off';
      final capture = camera.capturePhoto();
      await host.renderingStarted.future;
      expect(camera.reviewing, isTrue);
      expect(camera.original!.unsaved, isTrue);
      expect(camera.selected!.id, camera.original!.id);
      expect(camera.busy, isTrue);
      expect(camera.canCapture, isFalse);
      expect(camera.message, 'Photo taken. Preparing effects...');
      expect(host.savedIds, isEmpty);
      expect(camera.original!.unsaved, isTrue);
      host.finishRendering.complete();
      await capture;
      expect(camera.busy, isFalse);
      expect(camera.selected!.id, isNot(camera.original!.id));
      expect(camera.original!.unsaved, isFalse);
      expect(host.savedIds, ['original-1-final']);
      expect(host.retained, isNull);
      camera.dispose();
    },
  );

  testWidgets(
    'Viewport shows original during processing then finished result',
    (tester) async {
      final host = DelayedEffectsHost();
      final camera = CameraController(host: host, register: false);
      await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
      await tester.pumpAndSettle();
      camera.filter = 'fresh';
      camera.beautifier = 'off';
      camera.watermark = false;
      final capture = camera.capturePhoto(review: false);
      await host.renderingStarted.future;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      var preview = tester.widget<CaptureResultPreview>(
        find.byKey(const Key('captureResultPreview')),
      );
      expect(preview.path, camera.original!.path);
      expect(preview.complete, isFalse);
      expect(find.text('Processing photo...'), findsOneWidget);
      expect(find.text('Back to camera'), findsNothing);
      expect(camera.canCapture, isFalse);
      expect(host.savedIds, isEmpty);
      host.finishRendering.complete();
      await capture;
      await tester.pumpAndSettle();
      preview = tester.widget<CaptureResultPreview>(
        find.byKey(const Key('captureResultPreview')),
      );
      expect(preview.path, camera.selected!.path);
      expect(preview.path, isNot(camera.original!.path));
      expect(preview.complete, isTrue);
      expect(find.text('Photo saved'), findsOneWidget);
      await tester.tap(find.text('Back to camera'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('captureResultPreview')), findsNothing);
      expect(camera.canCapture, isTrue);
    },
  );

  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'Dali Camera',
      packageName: 'com.dalicamera.dali_camera',
      version: '0.1.0',
      buildNumber: '2001',
      buildSignature: '',
    ),
  );

  testWidgets('Native header exposes Manual, coaching and App Settings', (
    tester,
  ) async {
    final host = FakeHost();
    final camera = CameraController(host: host, register: false);
    await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
    await tester.pumpAndSettle();
    expect(find.text('Dali Cam'), findsOneWidget);
    expect(find.byTooltip('Help'), findsNothing);
    final headerKeys = [
      'manualControlsButton',
      'coachingToggle',
      'appSettingsButton',
      'switchCamera',
    ];
    for (var i = 1; i < headerKeys.length; i++) {
      expect(
        tester.getCenter(find.byKey(Key(headerKeys[i]))).dx,
        greaterThan(tester.getCenter(find.byKey(Key(headerKeys[i - 1]))).dx),
      );
    }
    await tester.tap(find.byKey(const Key('manualControlsButton')));
    await tester.pumpAndSettle();
    expect(camera.manualWorkspace, isTrue);
    expect(find.byType(ManualPreviewControls), findsOneWidget);
    await tester.tap(find.byKey(const Key('manualControlsButton')));
    await tester.pumpAndSettle();
    expect(find.byType(ManualPreviewControls), findsNothing);
    await tester.tap(find.byKey(const Key('coachingToggle')));
    await tester.pumpAndSettle();
    expect(camera.coachingEnabled, isFalse);
    expect(find.byKey(const Key('situationMenu')), findsNothing);
    expect(camera.canCapture, isTrue);
    await tester.tap(find.byKey(const Key('coachingToggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('situationMenu')), findsOneWidget);
    await tester.tap(find.byKey(const Key('appSettingsButton')));
    await tester.pumpAndSettle();
    expect(find.text('App Settings'), findsOneWidget);
    expect(find.text('0.1.0 (2001)'), findsOneWidget);
    expect(camera.canCapture, isFalse);
    camera.voicePreferred = true;
    camera.voiceShutter();
    await tester.pumpAndSettle();
    expect(
      host.captures,
      0,
      reason: 'A settings sheet must block voice capture',
    );
    await tester.tap(find.text('Quick camera tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your shot'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Review and return'), findsOneWidget);
    await tester.tap(find.text('Start taking photos'));
    await tester.pumpAndSettle();
    expect(camera.canCapture, isTrue);
    await tester.tap(find.byTooltip('Camera controls'));
    await tester.pumpAndSettle();
    expect(find.text('Camera controls'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Manual opens native rail and one live editor at a time', (
    tester,
  ) async {
    final host = ManualHost();
    final camera = CameraController(host: host, register: false);
    await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manualControlsButton')));
    await tester.pumpAndSettle();
    expect(camera.snapshot!.manualExposure, isFalse);
    expect(find.byKey(const Key('manualToolFocus')), findsOneWidget);
    expect(find.byKey(const Key('manualFocusPrompt')), findsNothing);
    final preview = tester.getRect(find.byType(AspectRatio).first);
    expect(
      tester.getRect(find.byKey(const Key('manualToolFocus'))).right,
      closeTo(preview.right - 8, .1),
    );
    await tester.tap(find.byKey(const Key('manualToolFocus')));
    await tester.pumpAndSettle();
    expect(
      find.text('Tap a point in the preview to focus there.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('manualFocusPrompt')));
    await tester.pumpAndSettle();
    expect(
      host.lastFocusOnly,
      isNull,
      reason: 'An editor tap must not refocus the live camera behind it',
    );
    await camera.meter(.4, .5);
    await tester.pumpAndSettle();
    expect(host.lastFocusOnly, isTrue);
    await tester.tap(find.byKey(const Key('manualToolDepth')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manualFocusPrompt')), findsNothing);
    tester
        .widget<Slider>(find.byKey(const Key('digitalDepthOfFocus')))
        .onChanged!(3);
    await tester.pumpAndSettle();
    expect(camera.effectiveDepth, 3);
    await tester.tap(find.byKey(const Key('manualToolExposure')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('digitalDepthOfFocus')), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('resetExposureAdjustment')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('manualShutterAuto')));
    await tester.pumpAndSettle();
    expect(camera.snapshot!.manualExposure, isTrue);
    expect(find.byKey(const Key('previewShutterSlider')), findsOneWidget);
    await camera.changeLinkedEV(1);
    await tester.pumpAndSettle();
    expect(camera.snapshot!.currentISO, 200);
    await tester.tap(find.byKey(const Key('resetExposureAdjustment')));
    await tester.pumpAndSettle();
    expect(camera.linkedEV, 0);
    expect(camera.snapshot!.currentISO, 100);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('resetExposureAdjustment')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('manualShutterAuto')));
    await tester.pumpAndSettle();
    expect(camera.focusX, .4);
    expect(host.lastResetFocus, isFalse);
    await tester.tap(find.byKey(const Key('returnToAutoFromPreview')));
    await tester.pumpAndSettle();
    expect(camera.manualWorkspace, isFalse);
    expect(camera.effectiveDepth, 0);
    expect(camera.focusX, isNull);
    expect(host.lastResetFocus, isTrue);
    expect(find.byKey(const Key('manualPreviewControls')), findsNothing);
    await tester.tap(find.byKey(const Key('manualControlsButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manualPreviewControls')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Manual editors and review treatment remain usable at large text',
    (tester) async {
      final camera = CameraController(host: ManualHost(), register: false);
      await camera.initialize();
      await camera.enterManual();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 400,
                  height: 210,
                  child: AnimatedBuilder(
                    animation: camera,
                    builder: (_, _) => ManualPreviewControls(camera: camera),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (final name in ['Focus', 'Depth', 'Exposure']) {
        await tester.tap(find.byKey(Key('manualTool$name')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: name);
        expect(
          find.byKey(Key('manualEditor_${name.toLowerCase()}')),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: ReviewTreatmentControls(camera: camera),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('reviewTreatmentStrength')), findsOneWidget);
      camera.dispose();
    },
  );

  testWidgets(
    'Coaching hierarchy and deliberate slow swipes follow native reference',
    (tester) async {
      final camera = CameraController(host: FakeHost(), register: false);
      await camera.initialize();
      final poses = camera.catalog.entries
          .where((e) => e.kind == 'pose' && e.package == 'masculine')
          .toList();
      camera.choose(poses.first);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedBuilder(
                animation: camera,
                builder: (_, _) =>
                    LiveGuidancePanel(camera: camera, onExample: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activeReferenceCard')), findsOneWidget);
      expect(find.byKey(const Key('situationGuidanceCard')), findsNothing);
      expect(find.text(poses.first.cues.join(' ')), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      camera.advice = const Advice(
        type: 'subject_missing',
        recipient: 'Photographer',
        instruction: 'Find the subject',
        tone: AdviceTone.warning,
      );
      await tester.pump();
      expect(camera.canAdvanceGuidance, isFalse);
      camera.next();
      expect(
        camera.guidance.index,
        0,
        reason: 'Urgent framing cannot confirm a creative step',
      );
      camera.choose(poses.first);
      await tester.pump();
      await tester.timedDrag(
        find.byKey(const Key('activeReferenceCard')),
        const Offset(-100, 0),
        const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();
      expect(camera.guidance.entry!.id, poses[1].id);
      final afterSlowSwipe = camera.guidance.entry!.id;
      await tester.timedDrag(
        find.byKey(const Key('activeReferenceCard')),
        const Offset(-30, 0),
        const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();
      expect(camera.guidance.entry!.id, afterSlowSwipe);
      camera.setSituation(PhotographicSituation.food);
      camera.choose(camera.catalog.entries.firstWhere((e) => e.kind == 'food'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activeReferenceCard')), findsOneWidget);
      expect(find.byKey(const Key('situationGuidanceCard')), findsOneWidget);
      expect(find.byKey(const Key('guidedControls')), findsNothing);
      camera.dispose();
    },
  );

  testWidgets(
    'Review slow swipe uses native distance and does not require a flick',
    (tester) async {
      final offsets = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DistanceSwipe(
              minimumDistance: 60,
              onSwipe: offsets.add,
              child: const SizedBox(width: 300, height: 200),
            ),
          ),
        ),
      );
      await tester.timedDrag(
        find.byType(DistanceSwipe),
        const Offset(-80, 0),
        const Duration(seconds: 2),
      );
      expect(offsets, [1]);
      await tester.timedDrag(
        find.byType(DistanceSwipe),
        const Offset(45, 0),
        const Duration(seconds: 2),
      );
      expect(offsets, [1]);
      await tester.timedDrag(
        find.byType(DistanceSwipe),
        const Offset(90, 0),
        const Duration(seconds: 2),
      );
      expect(offsets, [1, -1]);
    },
  );

  test('Review edits automatically coalesce to the latest settings', () async {
    final host = FakeHost();
    final camera = CameraController(host: host, register: false);
    camera.original = PhotoHandle(
      path: 'fixture.jpg',
      id: 'source',
      unsaved: false,
    );
    camera.selected = camera.original;
    camera.reviewing = true;
    camera.reviewTreatments['portrait']!['strength'] = 2;
    camera.requestReviewTreatment('portrait');
    camera.reviewTreatments['portrait']!['strength'] = 5;
    camera.requestReviewTreatment('portrait');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(host.effectsRecipe!['strength'], 5);
    expect(camera.selectedTreatment, 'portrait');
    expect(camera.original!.id, 'source');
    camera.reviewTreatments['portrait']!['strength'] = 0;
    camera.requestReviewTreatment('portrait');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(host.effectsRecipe!['strength'], 0);
    camera.dispose();
  });

  test(
    'Library loads lazily, wraps, retains failed selection and releases copies',
    () async {
      final host = FakeHost()
        ..libraryResult = PhotoLibrary(
          status: 'limited',
          photos: [
            for (var i = 0; i < 8; i++)
              LibraryPhoto(id: '$i', title: 'Photo $i'),
          ],
        );
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      expect(await camera.openPhotoLibrary(), isTrue);
      expect(camera.reviewCount, 8);
      expect(host.loadedLibraryIds, ['0']);
      expect(camera.message, contains('allowed'));
      await camera.previousPhoto();
      expect(camera.reviewIndex, 7);
      await camera.nextPhoto();
      expect(camera.reviewIndex, 0);
      expect(host.loadedLibraryIds, ['0', '7']);
      host.failedLibraryId = '1';
      await camera.nextPhoto();
      expect(camera.reviewIndex, 0);
      expect(camera.original!.id, 'copy-0');
      expect(camera.message, contains('retained'));
      host.failedLibraryId = '0';
      expect(await camera.openPhotoLibrary(), isTrue);
      expect(camera.original!.id, 'copy-0');
      expect(camera.reviewCount, 8);
      host.failedLibraryId = null;
      await camera.nextPhoto();
      await camera.nextPhoto();
      await camera.nextPhoto();
      expect(host.releasedIds.length, 2);
      await camera.returnToCamera();
      expect(camera.reviewingLibrary, isFalse);
      expect(camera.libraryPhotos, isEmpty);
      expect(host.releasedIds.toSet(), {
        'copy-0',
        'copy-7',
        'copy-1',
        'copy-2',
        'copy-3',
      });
      camera.dispose();
    },
  );

  test(
    'Denied library falls back to history and cannot replace an unsaved original',
    () async {
      final host = FakeHost()
        ..libraryResult = PhotoLibrary(photos: [], status: 'denied');
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      expect(await camera.openPhotoLibrary(), isFalse);
      expect(camera.message, contains('denied'));
      final saved = PhotoHandle(path: 'saved.jpg', id: 'saved', unsaved: false);
      camera.history.add(saved);
      expect(await camera.openPhotoLibrary(), isTrue);
      expect(camera.original, saved);
      await camera.returnToCamera();
      camera.original = PhotoHandle(
        path: 'pending.jpg',
        id: 'pending',
        unsaved: true,
      );
      expect(await camera.openPhotoLibrary(), isTrue);
      expect(camera.original!.id, 'pending');
      expect(host.loadedLibraryIds, isEmpty);
      camera.dispose();
    },
  );

  test('Filter application modes preserve the custom preset and settings', () {
    final camera = CameraController(host: FakeHost(), register: false);
    camera.filter = 'fresh';
    final values = PhotoStyle.fields.map(camera.style.value).toList();
    camera.useFilterMode('off');
    expect(camera.style.active, isFalse);
    camera.useFilterMode('auto');
    camera.useFilterMode('custom');
    expect(camera.filter, 'fresh');
    expect(PhotoStyle.fields.map(camera.style.value).toList(), values);
    camera.customStyle['exposure'] = 3;
    camera.filter = 'custom';
    camera.useFilterMode('off');
    camera.useFilterMode('custom');
    expect(camera.style.value('exposure'), 3);
    camera.dispose();
  });
  testWidgets('Comparison choices remain usable at large text', (tester) async {
    var mode = 'before';
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SizedBox(
              width: 280,
              child: StatefulBuilder(
                builder: (context, update) => ReviewModeControls(
                  value: mode,
                  onChanged: (value) => update(() => mode = value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Split'));
    await tester.pump();
    expect(mode, 'split');
    expect(tester.takeException(), isNull);
  });
  test(
    'Before exports the original and a failed copy does not become pending',
    () async {
      final host = FakeHost();
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      await camera.capturePhoto();
      await camera.applyTreatment('enhance');
      await camera.saveSelected(originalView: true);
      expect(host.savedIds.last, camera.original!.id);
      await camera.saveSelected();
      expect(host.savedIds.last, camera.selected!.id);
      host.failSave = true;
      await camera.saveSelected(originalView: true);
      expect(camera.original!.unsaved, isFalse);
      expect(camera.selectedTreatment, 'enhance');
      camera.dispose();
    },
  );
  test('Linked ISO preserves exposure and resets in Auto', () async {
    final camera = CameraController(host: ManualHost(), register: false);
    await camera.initialize();
    camera.setLinkedISO(true);
    await camera.changeShutter(1 / 250);
    expect(camera.snapshot!.currentISO, 200);
    await camera.changeLinkedEV(1);
    expect(camera.snapshot!.currentISO, 400);
    await camera.returnAuto();
    expect(camera.linkedISO, isFalse);
    expect(camera.snapshot!.manualExposure, isFalse);
    camera.dispose();
  });
  test(
    'Voice command completes after listening ends and preference survives pause',
    () async {
      final host = FakeHost()..voiceAvailable = true;
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      camera.watermark =
          false; // Voice sequencing does not depend on asset/file rendering.
      await camera.setVoice(true);
      camera.voiceState(false, 'Processing voice command');
      camera.voiceShutter();
      for (var i = 0; i < 100 && camera.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(camera.busy, isFalse);
      expect(host.captures, 1);
      expect(camera.voicePreferred, isTrue);
      await camera.returnToCamera();
      expect(camera.voice, isTrue);
      await camera.setVoice(false);
      camera.voiceShutter();
      expect(host.captures, 1);
      camera.dispose();
    },
  );
  test(
    'Capture and review effects retain originals and use separate settings',
    () async {
      final host = FakeHost();
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      camera.beautifier = 'auto';
      camera.setSituation(PhotographicSituation.landscape);
      await camera.capturePhoto();
      expect(host.effectsRecipe!['treatment'], 'landscape');
      expect(host.effectsRecipe!['strength'], 3);
      expect(camera.photoAnalysis!['sourceId'], camera.original!.id);
      camera.reviewTreatments['portrait']!['strength'] = 4;
      await camera.applyTreatment('portrait');
      expect(host.effectsRecipe!['strength'], 4);
      expect(camera.selectedTreatment, 'portrait');
      final selected = camera.selected;
      host.failRender = true;
      await camera.applyTreatment('enhance');
      expect(camera.selected, same(selected));
      expect(camera.original!.id, 'original-1');
      expect(camera.original!.unsaved, isFalse);
      camera.dispose();
    },
  );
  test(
    'Imported selection wraps, preserves captures and cleans only copies',
    () async {
      final host = FakeHost();
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      camera.watermark =
          false; // Isolate original/derived cleanup from capture styling.
      await camera.capturePhoto(review: false);
      final captured = camera.original;
      final first = PhotoHandle(path: 'one.png', id: 'one', unsaved: false);
      final second = PhotoHandle(path: 'two.heic', id: 'two', unsaved: false);
      host.importResult = PhotoImport(photos: [first, second], skipped: 1);
      await camera.pick(folder: true);
      expect(host.importedFolder, isTrue);
      expect(camera.reviewPhotos, [first, second]);
      expect(camera.history, [captured]);
      expect(camera.message, contains('1 skipped'));
      await camera.previousPhoto();
      expect(camera.original, same(second));
      await camera.nextPhoto();
      expect(camera.original, same(first));
      await camera.variant(crop: true);
      await camera.nextPhoto();
      expect(host.releasedIds, ['derived-one']);
      host.importResult = PhotoImport(photos: [], skipped: 0);
      await camera.pick();
      expect(camera.original, same(second));
      expect(host.releasedIds, ['derived-one']);
      host.failImport = true;
      await camera.pick();
      expect(camera.original, same(second));
      expect(camera.busy, isFalse);
      expect(camera.message, contains('Could not open photos'));
      await camera.returnToCamera();
      expect(host.releasedIds, ['derived-one', 'one', 'two']);
      expect(camera.original, same(captured));
      expect(camera.importedPhotos, isEmpty);
      expect(camera.canCapture, isTrue);
      camera.dispose();
    },
  );
  test('Import cannot replace a pending original', () async {
    final host = FakeHost()..failSave = true;
    final camera = CameraController(host: host, register: false);
    await camera.initialize();
    await camera.capturePhoto();
    final pending = camera.original;
    await camera.pick(folder: true);
    expect(host.importRequests, 0);
    expect(camera.original, same(pending));
    expect(camera.original!.unsaved, isTrue);
    camera.dispose();
  });
  test(
    'Capture routes situation Auto parameters and retains original on filter failure',
    () async {
      final host = FakeHost();
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      camera.setSituation(PhotographicSituation.action);
      camera.filter = 'auto';
      await camera.capturePhoto(review: false);
      final expected = PhotoStyle.preset(camera.catalog, 'vivid', 'action');
      expect(
        host.filterParameters,
        PhotoStyle.fields
            .map((field) => expected.value(field).toDouble())
            .toList(),
      );
      expect(camera.styled, isTrue);
      expect(camera.original!.unsaved, isFalse);
      host.failRender = true;
      await camera.capturePhoto(review: false);
      expect(camera.original!.id, 'original-2');
      expect(camera.original!.unsaved, isTrue);
      expect(host.savedIds, ['original-1-final']);
      expect(camera.selected, same(camera.original));
      expect(camera.styled, isFalse);
      expect(camera.canCapture, isFalse);
      host.failRender = false;
      camera.filter = 'off'; // Retry keeps the frozen capture effects.
      await camera.saveSelected();
      expect(host.savedIds, ['original-1-final', 'original-2-final']);
      expect(
        host.filterParameters,
        PhotoStyle.fields
            .map((field) => expected.value(field).toDouble())
            .toList(),
      );
      expect(camera.original!.unsaved, isFalse);
      camera.dispose();
    },
  );
  test(
    'Review navigation protects pending originals and failed variants',
    () async {
      final host = FakeHost();
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      camera.watermark =
          false; // Isolate original/derived cleanup from capture styling.
      for (var i = 0; i < 3; i++) {
        await camera.capturePhoto(review: false);
      }
      await camera.openHistory(camera.history.first);
      expect(camera.canPreviousPhoto, isTrue);
      expect(camera.canNextPhoto, isTrue);
      await camera.previousPhoto();
      expect(camera.original!.id, 'original-1');
      await camera.nextPhoto();
      expect(camera.original!.id, 'original-3');
      await camera.nextPhoto();
      expect(camera.original!.id, 'original-2');
      await camera.variant(crop: true);
      final prior = camera.selected;
      host.failRender = true;
      await camera.variant(rotation: 2);
      expect(camera.selected, same(prior));
      expect(host.released, 0);
      await camera.previousPhoto();
      expect(camera.original!.id, 'original-3');
      expect(host.released, 1);
      camera.original!.unsaved = true;
      expect(camera.canNextPhoto, isFalse);
      await camera.nextPhoto();
      expect(camera.original!.id, 'original-3');
      camera.dispose();
    },
  );
  testWidgets('Selection row switches scenes, filters and package navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final camera = CameraController(host: FakeHost(), register: false);
    await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
    await tester.pumpAndSettle();
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
    expect(find.text('Situation'), findsOneWidget);
    expect(find.text('Effects'), findsOneWidget);
    expect(find.text('Posture'), findsOneWidget);

    await tester.tap(find.byKey(const Key('referenceMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male / Masculine'));
    await tester.pumpAndSettle();
    expect(find.text('Relaxed standing'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to packages'));
    await tester.pumpAndSettle();
    expect(find.text('Posture packages'), findsOneWidget);
    await tester.tap(find.byTooltip('Close packages'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('situationMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Group'));
    await tester.pumpAndSettle();
    expect(camera.activeSituation, PhotographicSituation.group);
    await tester.tap(find.byKey(const Key('situationMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(camera.food, isTrue);
    await tester.tap(find.byKey(const Key('referenceMenu')));
    await tester.pumpAndSettle();
    expect(find.text('Hero plate'), findsOneWidget);
    await tester.tap(find.text('Hero plate'));
    await tester.pumpAndSettle();
    expect(camera.guidance.entry!.kind, 'food');

    await tester.tap(find.byKey(const Key('effectsMenu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .ancestor(
            of: find.text('Auto'),
            matching: find.byType(CheckedPopupMenuItem<String>),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(camera.filter, 'auto');
    expect(find.text('Filters Auto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('effectsMenu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .ancestor(
            of: find.text('Custom'),
            matching: find.byType(CheckedPopupMenuItem<String>),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Filter preset'), findsOneWidget);
    expect(find.text('Individual settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
  test('References preserve contextual advice and person overlays', () async {
    final camera = CameraController(host: FakeHost(), register: false);
    await camera.initialize();
    final frame = jsonEncode({
      'schemaVersion': 1,
      'configurationId': 'test',
      'frameId': 'context',
      'timestamp': 100000,
      'imageWidth': 480,
      'imageHeight': 640,
      'displayRotationDegrees': 0,
      'front': false,
      'peopleStatus': 'valid',
      'people': [],
      'peopleScope': 'multiple',
      'faceStatus': 'valid',
      'faces': [],
      'poseStatus': 'unsupported',
    });
    for (final situation in [
      PhotographicSituation.food,
      PhotographicSituation.landscape,
    ]) {
      camera.setSituation(situation);
      camera.choose(
        camera.catalog.entries.firstWhere(
          (entry) => entry.kind == situation.catalogKind,
        ),
      );
      camera.analysis(frame);
      expect(
        camera.advice.type,
        'situation',
        reason: 'Recipe instructions must not replace measured scene advice',
      );
      expect(camera.contextualGuidance, isNotNull);
      expect(camera.message, isNull);
    }
    for (final situation in [
      PhotographicSituation.group,
      PhotographicSituation.action,
    ]) {
      camera.setSituation(situation);
      camera.choose(
        camera.catalog.entries.firstWhere((entry) => entry.kind == 'pose'),
      );
      camera.analysis(frame);
      expect(camera.advice.type, isNot('situation'));
      expect(
        camera.canAdvanceGuidance,
        isFalse,
        reason:
            'Missing subject must interrupt group/action posture progression',
      );
      expect(camera.contextualGuidance, isNotNull);
      expect(camera.message, isNull);
    }
    camera.dispose();
  });
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
    camera.watermark = false; // This check isolates capture sequencing/history.
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
    camera.watermark = false; // This check isolates capture sequencing/history.
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
      camera.watermark =
          false; // This check isolates capture sequencing/history.
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
  testWidgets('Folder import remains reachable in landscape with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final host = FakeHost();
    final camera = CameraController(host: host, register: false);
    await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open photo library'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('importFolder')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('importFolder')));
    await tester.pumpAndSettle();
    expect(host.importedFolder, isTrue);
    expect(tester.takeException(), isNull);
  });
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
      await tester.tap(find.byKey(const Key('appSettingsButton')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Help'));
      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();
      expect(find.text('Take a photo with Dali'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
