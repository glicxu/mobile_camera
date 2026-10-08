import 'package:dali_camera/main.dart';
import 'package:dali_camera/camera_controller.dart';
import 'package:dali_camera_platform/dali_camera_platform.dart';
import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHost extends CameraHostApi {
  bool failSave = false;
  bool failRender = false;
  List<double>? filterParameters;
  int captures = 0;
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
    releasedIds.add(photo.id);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Imported selection wraps, preserves captures and cleans only copies',
    () async {
      final host = FakeHost();
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
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
      expect(camera.original!.unsaved, isFalse);
      expect(camera.selected, same(camera.original));
      expect(camera.styled, isFalse);
      expect(camera.canCapture, isTrue);
      camera.dispose();
    },
  );
  test(
    'Review navigation protects pending originals and failed variants',
    () async {
      final host = FakeHost();
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      for (var i = 0; i < 3; i++) {
        await camera.capturePhoto(review: false);
      }
      await camera.openHistory(camera.history.first);
      expect(camera.canPreviousPhoto, isFalse);
      expect(camera.canNextPhoto, isTrue);
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
    await tester.ensureVisible(find.text('Use this reference'));
    await tester.tap(find.text('Use this reference'));
    await tester.pumpAndSettle();
    expect(camera.guidance.entry!.kind, 'food');

    await tester.tap(find.byKey(const Key('effectsMenu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Auto'),
        matching: find.byType(CheckedPopupMenuItem<String>),
      ),
    );
    await tester.pumpAndSettle();
    expect(camera.filter, 'auto');
    expect(find.text('Filters Auto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('effectsMenu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Custom'),
        matching: find.byType(CheckedPopupMenuItem<String>),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Filters and watermark'), findsOneWidget);
    expect(find.text('Dali watermark'), findsOneWidget);
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
    await tester.tap(find.byTooltip('Import photos'));
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
      await tester.tap(find.byTooltip('Help'));
      await tester.pumpAndSettle();
      expect(find.text('Take a photo with Dali'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
