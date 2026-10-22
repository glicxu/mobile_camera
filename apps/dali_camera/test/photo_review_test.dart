import 'dart:async';
import 'package:dali_camera/camera_controller.dart';
import 'package:dali_camera/main.dart';
import 'package:dali_camera/review_comparison.dart';
import 'package:dali_camera_platform/dali_camera_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'widget_test.dart' show FakeHost;

class DelayedReviewHost extends FakeHost {
  final pending = Completer<PhotoHandle>();
  bool delayPreview = false;
  bool delayFull = false;
  @override
  Future<PhotoHandle> loadPhotoPreview(String id, int maximumSize) =>
      delayPreview ? pending.future : super.loadPhotoPreview(id, maximumSize);
  @override
  Future<PhotoHandle> loadLibraryPhoto(String id) =>
      delayFull ? pending.future : super.loadLibraryPhoto(id);
}

void main() {
  test(
    'Leaving a pending preview prevents a late result reopening review',
    () async {
      final host = DelayedReviewHost()
        ..delayPreview = true
        ..libraryResult = PhotoLibrary(
          status: 'authorized',
          photos: [LibraryPhoto(id: 'one', title: 'One')],
        );
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      final opening = camera.openPhotoLibrary();
      await Future<void>.delayed(Duration.zero);
      expect(camera.reviewLoading, isTrue);
      await camera.returnToCamera();
      expect(camera.reviewing, isFalse);
      host.pending.complete(
        PhotoHandle(path: 'late.jpg', id: 'late', unsaved: false),
      );
      await opening;
      expect(camera.reviewing, isFalse);
      expect(camera.reviewLoading, isFalse);
      expect(host.releasedIds, contains('late'));
      expect(host.analyses, 0);
      camera.dispose();
    },
  );

  test(
    'Full resolution is deferred and can be abandoned without changing the camera',
    () async {
      final host = DelayedReviewHost()
        ..libraryResult = PhotoLibrary(
          status: 'authorized',
          photos: [LibraryPhoto(id: 'one', title: 'One')],
        );
      final camera = CameraController(host: host, register: false);
      await camera.initialize();
      await camera.openPhotoLibrary();
      expect(host.fullLoads, 0);
      host.delayFull = true;
      final editing = camera.prepareReviewEdit(analyze: true);
      await Future<void>.delayed(Duration.zero);
      await camera.returnToCamera();
      host.pending.complete(
        PhotoHandle(path: 'full.jpg', id: 'full', unsaved: false),
      );
      expect(await editing, isFalse);
      expect(camera.reviewing, isFalse);
      expect(host.analyses, 0);
      expect(host.releasedIds, contains('full'));
      camera.dispose();
    },
  );

  testWidgets(
    'Review uses the full viewport width and exposes passive actions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final host = FakeHost();
      final camera = CameraController(host: host, register: false);
      await tester.pumpWidget(DaliApp(controller: camera, onboarding: false));
      await tester.pumpAndSettle();
      camera.watermark = false;
      await camera.capturePhoto(review: false);
      await camera.openLatest();
      await tester.pumpAndSettle();
      final image = tester.getRect(find.byType(ReviewPhotoViewer));
      expect(image.left, 0);
      expect(image.width, 390);
      for (final action in ['Share', 'Favorite', 'Edit', 'Info', 'Delete']) {
        expect(find.byTooltip(action), findsOneWidget);
      }
      expect(find.byType(ReviewModeControls), findsNothing);
      expect(host.analyses, 0);
      expect(find.byKey(const Key('saveReviewEdits')), findsNothing);
      camera.dispose();
    },
  );

  testWidgets('A zoomed pan does not change photos', (tester) async {
    var swipes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewPhotoViewer(
            before: 'missing.jpg',
            after: 'missing.jpg',
            mode: 'before',
            onSwipe: (_) => swipes++,
            onZoom: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final viewer = find.byType(ReviewPhotoViewer);
    await tester.drag(viewer, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(swipes, 1);
    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(viewer);
    await tester.pumpAndSettle();
    await tester.drag(viewer, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(swipes, 1);
  });
}
