import 'capture_feedback.dart';
import 'capture_result_preview.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'camera_controller.dart';
import 'capture_settings.dart';
import 'manual_preview_controls.dart';
import 'camera_selection_row.dart';
import 'reference_chooser.dart';
import 'reference_details.dart';
import 'photo_effect_controls.dart';
import 'review_comparison.dart';
import 'review_treatment_controls.dart';
import 'camera_header.dart';
import 'coaching_overlay.dart';
import 'live_guidance.dart';
import 'distance_swipe.dart';
import 'app_settings.dart';
import 'camera_tutorial.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DaliApp());
}

bool canLevelHorizon(Map<String, dynamic>? analysis) {
  final horizon = analysis?['horizon'];
  if (horizon is! Map) return false;
  final angle = horizon['angleDegrees'];
  final confidence = horizon['confidence'];
  return angle is num &&
      angle.abs() > 3 &&
      (confidence == null || (confidence is num && confidence > .55));
}

class DaliApp extends StatelessWidget {
  const DaliApp({super.key, this.controller, this.onboarding = true});
  final CameraController? controller;
  final bool onboarding;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dali Camera',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff2aafbc),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff080b0f),
      useMaterial3: true,
    ),
    home: CameraScreen(controller: controller, onboarding: onboarding),
  );
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.controller, this.onboarding = true});
  final CameraController? controller;
  final bool onboarding;
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  late final CameraController camera;
  bool compare = true;
  bool splitComparison = false;
  String? reviewSourceId;
  String? reviewVersionId;
  String? reviewTool;
  bool reviewSaveChooserOpen = false;
  String? reviewBeautifierChoice;
  bool initialized = false;
  bool manualToolsVisible = false;
  int presentedCameraSheets = 0;
  Orientation? orientation;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    camera = widget.controller ?? CameraController();
    camera.addListener(refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => initialize());
  }

  Future<void> initialize() async {
    if (widget.onboarding) {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      if (preferences.getBool('welcomeSeen') != true) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => const CameraTutorial(),
          ),
        );
        await preferences.setBool('welcomeSeen', true);
      }
    }
    if (mounted) {
      initialized = true;
      await camera.initialize();
    }
  }

  void refresh() {
    if (mounted) {
      setState(() {
        if (!camera.manualWorkspace) manualToolsVisible = false;
        final source = camera.original?.id;
        final version = camera.selected?.id;
        if (source != reviewSourceId) {
          reviewTool = null;
          reviewBeautifierChoice = null;
          compare = true;
          splitComparison = false;
        } else if (version != reviewVersionId) {
          compare = false;
          splitComparison = false;
        }
        reviewSourceId = source;
        reviewVersionId = version;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      camera.foreground = true;
      if (initialized) camera.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      camera.foreground = false;
      camera.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    camera.removeListener(refresh);
    if (widget.controller == null) {
      camera.pause();
      camera.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = MediaQuery.orientationOf(context);
    if (orientation != null && current != orientation && !camera.reviewing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) camera.start();
      });
    }
    orientation = current;
    return Scaffold(
      body: SafeArea(child: camera.reviewing ? review() : live(current)),
    );
  }

  Widget live(Orientation orientation) {
    final controls = Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (camera.cameraError != null) ...[
                  Text(camera.cameraError!),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: camera.start,
                        child: const Text('Retry camera'),
                      ),
                      TextButton(
                        onPressed: camera.host.openSettings,
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
                ],
                if (camera.coachingEnabled) ...[
                  CameraSelectionRow(
                    camera: camera,
                    onPackages: () => cameraSheet(chooser),
                    onEffects: () => cameraSheet(effects),
                  ),
                  LiveGuidancePanel(
                    camera: camera,
                    onExample: (entry) => cameraSheet(() => details(entry)),
                  ),
                ],
                if (camera.message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(camera.message!),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Open photo library',
                icon: camera.original == null
                    ? const Icon(Icons.photo_library_outlined, size: 26)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(camera.original!.path),
                          width: 52,
                          height: 52,
                          cacheWidth: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) => const Icon(
                            Icons.photo_library_outlined,
                            size: 26,
                          ),
                        ),
                      ),
                onPressed: camera.busy
                    ? null
                    : () => cameraSheet(openPhotoLibrary),
              ),
              Semantics(
                label: camera.takingPhoto
                    ? 'Taking photo'
                    : camera.busy
                    ? 'Photo processing'
                    : 'Take photo',
                button: true,
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: GestureDetector(
                    onLongPressStart: (_) => camera.beginLongPress(),
                    onLongPressEnd: (_) => camera.endLongPress(),
                    onLongPressCancel: camera.endLongPress,
                    child: FilledButton(
                      key: const Key('shutter'),
                      onPressed: camera.canCapture
                          ? camera.requestShutter
                          : null,
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.zero,
                      ),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: .35),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: camera.timerSeconds > 0
                                ? Text(
                                    '${camera.timerSeconds}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              HeaderAction(
                tooltip: 'Camera controls',
                size: 52,
                radius: 10,
                onPressed: camera.busy ? null : () => cameraSheet(settings),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_outlined, size: 20),
                    Text(
                      'Controls',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final preview = LayoutBuilder(
      builder: (context, bounds) => Center(
        child: AspectRatio(
          aspectRatio: camera.aspectRatio,
          child: LayoutBuilder(
            builder: (context, previewBounds) => GestureDetector(
              onTapUp:
                  camera.capturePreviewPath == null &&
                      camera.snapshot?.supportsTap == true
                  ? (details) => camera.meter(
                      details.localPosition.dx / previewBounds.maxWidth,
                      details.localPosition.dy / previewBounds.maxHeight,
                    )
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!camera.livePreviewEnabled)
                    const ColoredBox(color: Colors.black)
                  else if (Platform.isAndroid)
                    const AndroidView(viewType: 'dali/camera')
                  else if (Platform.isIOS)
                    const UiKitView(viewType: 'dali/camera')
                  else
                    const Center(child: Text('Use an Android or iOS phone.')),
                  if (camera.coachingEnabled &&
                      camera.activeSituation.showsPersonOverlay)
                    CoachingOverlay(
                      advice: camera.advice,
                      guidedAction: camera.canAdvanceGuidance
                          ? camera.guidance.currentAction
                          : null,
                      animate: camera.livePreviewEnabled,
                      frame: camera.debug ? camera.lastFrame : null,
                    ),
                  if (camera.watermark)
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: .86,
                          child: Image.asset(
                            'assets/branding/dali-cam-watermark.png',
                            width: 150,
                            semanticLabel: 'Dali Cam watermark preview',
                          ),
                        ),
                      ),
                    ),
                  if (camera.countdown > 0)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .72),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer, size: 32),
                            Text(
                              '${camera.countdown}',
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontSize: 88,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: camera.cancelSequence,
                              child: const Text('Cancel timer'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (camera.bursting)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: .82),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('BURST'),
                            Text(
                              '${camera.burstCount}',
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (camera.focusX != null && camera.focusY != null)
                    Positioned(
                      left: camera.focusX! * previewBounds.maxWidth - 36,
                      top: camera.focusY! * previewBounds.maxHeight - 36,
                      child: IgnorePointer(
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: cameraTeal,
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                ),
                              ),
                              if (!camera.manualWorkspace)
                                const Align(
                                  alignment: Alignment.bottomRight,
                                  child: Icon(
                                    Icons.wb_sunny,
                                    size: 20,
                                    color: Colors.yellow,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (camera.snapshot?.locked == true ||
                      camera.snapshot?.manualExposure == true)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .68),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            camera.snapshot?.manualExposure == true
                                ? 'M'
                                : 'AF-L  AE-L',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (camera.manualWorkspace &&
                      manualToolsVisible &&
                      camera.countdown == 0 &&
                      !camera.bursting)
                    ManualPreviewControls(camera: camera),
                  if (camera.capturePreviewPath != null && !camera.bursting)
                    CaptureResultPreview(
                      key: const Key('captureResultPreview'),
                      path: camera.capturePreviewPath!,
                      status: camera.capturePreviewStatus,
                      complete: !camera.busy,
                    ),
                  CaptureFeedback(sequence: camera.capturedPhotoSequence),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: CameraHeader(
        manualVisible: manualToolsVisible,
        manualMode: camera.manualWorkspace,
        coachingEnabled: camera.coachingEnabled,
        onManual: camera.busy || camera.controlBusy
            ? null
            : () async {
                if (!camera.manualWorkspace) await camera.enterManual();
                if (mounted && camera.manualWorkspace) {
                  setState(() => manualToolsVisible = !manualToolsVisible);
                }
              },
        onCoaching: () => camera.setCoachingEnabled(!camera.coachingEnabled),
        onSettings: () => cameraSheet(
          () => showAppSettings(context, onHelp: help, onImport: choosePhotos),
        ),
        onSwitch: camera.starting || camera.busy ? null : camera.switchLens,
      ),
    );
    if (orientation == Orientation.landscape) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: preview),
            const SizedBox(width: 12),
            SizedBox(
              width: (MediaQuery.sizeOf(context).width * .44).clamp(0, 360),
              child: Column(
                children: [
                  header,
                  const SizedBox(height: 8),
                  Expanded(child: controls),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        header,
        Expanded(
          child: Column(
            children: [
              Expanded(flex: 5, child: preview),
              if (camera.coachingEnabled)
                Expanded(flex: 4, child: controls)
              else
                SizedBox(height: 132, child: controls),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> cameraSheet(Future<void> Function() show) async {
    presentedCameraSheets++;
    camera.setControlsPresented(true);
    try {
      await show();
    } finally {
      presentedCameraSheets--;
      if (mounted) camera.setControlsPresented(presentedCameraSheets > 0);
    }
  }

  void openReviewTool(String tool) {
    if (camera.busy) return;
    setState(() {
      reviewTool = reviewTool == tool ? null : tool;
      if (tool == 'enhance') camera.reviewTreatment = 'enhance';
      if (tool == 'beautifier' &&
          camera.reviewTreatments.containsKey(reviewBeautifierChoice)) {
        camera.reviewTreatment = reviewBeautifierChoice!;
      }
    });
  }

  bool get hasReviewEdits =>
      camera.original != null &&
      camera.selected != null &&
      camera.selected!.id != camera.original!.id;

  Widget reviewComparisonControls() => ReviewModeControls(
    value: splitComparison
        ? 'split'
        : compare
        ? 'before'
        : 'after',
    onChanged: (value) => setState(() {
      compare = value == 'before';
      splitComparison = value == 'split';
    }),
  );

  Widget reviewEditor() {
    if (reviewTool == 'menu') {
      return Column(
        children: [
          for (final tool in [
            'auto',
            'enhance',
            'filters',
            'beautifier',
            'edit',
          ])
            ListTile(
              key: Key('reviewTool_$tool'),
              leading: Icon(
                {
                  'auto': Icons.auto_awesome,
                  'enhance': Icons.auto_fix_high,
                  'filters': Icons.filter_vintage,
                  'beautifier': Icons.face,
                  'edit': Icons.crop,
                }[tool],
              ),
              title: Text(
                {
                  'auto': 'Auto',
                  'enhance': 'General Enhancer',
                  'filters': 'Filter',
                  'beautifier': 'Beautifier',
                  'edit': 'Crop and Edit',
                }[tool]!,
              ),
              subtitle: Text(
                {
                  'auto': 'Automatically apply a balanced enhancement',
                  'enhance': 'Adjust tone, color and detail',
                  'filters': 'Apply a preset color style',
                  'beautifier': 'Choose a portrait or landscape polish',
                  'edit': 'Crop, rotate and straighten the photo',
                }[tool]!,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: camera.busy
                  ? null
                  : () {
                      openReviewTool(tool);
                      if (tool == 'auto') camera.autoEnhanceReview();
                    },
            ),
        ],
      );
    }
    if (reviewTool == 'auto') {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('Auto improves this photo using a balanced treatment.'),
            const SizedBox(height: 8),
            Text(
              'Suggested treatment: ${treatmentTitles[camera.autoReviewTreatment]}',
            ),
            TextButton.icon(
              onPressed: camera.busy ? null : camera.autoEnhanceReview,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Apply Auto'),
            ),
          ],
        ),
      );
    }
    if (reviewTool == 'filters') {
      return CaptureStyleControls(
        camera: camera,
        review: true,
        initiallyExpanded: true,
      );
    }
    if (reviewTool == 'beautifier') {
      return Column(
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey('reviewBeautifierChoice_$reviewBeautifierChoice'),
            initialValue: reviewBeautifierChoice,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Beautifier'),
            hint: const Text('Choose a beautifier'),
            items: [
              const DropdownMenuItem(
                value: 'original',
                child: Text('None (original)'),
              ),
              for (final item in treatmentTitles.entries)
                DropdownMenuItem(value: item.key, child: Text(item.value)),
            ],
            onChanged: camera.busy
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => reviewBeautifierChoice = value);
                    if (value == 'original') {
                      camera.variant();
                    } else {
                      final settings = camera.reviewTreatments[value]!;
                      if (settings['strength'] == 0) settings['strength'] = 3;
                      camera.requestReviewTreatment(value);
                    }
                  },
          ),
          if (camera.reviewTreatments.containsKey(reviewBeautifierChoice)) ...[
            ReviewTreatmentControls(
              camera: camera,
              showTreatmentSelector: false,
            ),
            PhotoEffectControls(
              camera: camera,
              review: true,
              showTreatmentSelector: false,
            ),
          ],
        ],
      );
    }
    if (reviewTool == 'enhance') {
      const kinds = ['enhance'];
      return Column(
        children: [
          ReviewTreatmentControls(
            camera: camera,
            allowedTreatments: kinds,
            showTreatmentSelector: false,
          ),
          PhotoEffectControls(
            camera: camera,
            review: true,
            allowedTreatments: kinds,
            showTreatmentSelector: false,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasReviewEdits) reviewComparisonControls(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: camera.busy ? null : () => camera.variant(crop: true),
              icon: const Icon(Icons.crop),
              label: const Text('Tighter crop'),
            ),
            OutlinedButton.icon(
              onPressed: camera.busy
                  ? null
                  : () => camera.variant(rotation: -90),
              icon: const Icon(Icons.rotate_left),
              label: const Text('Rotate left'),
            ),
            OutlinedButton.icon(
              onPressed: camera.busy
                  ? null
                  : () => camera.variant(rotation: 90),
              icon: const Icon(Icons.rotate_right),
              label: const Text('Rotate right'),
            ),
            for (final treatment in ['reframe', 'level'])
              OutlinedButton(
                onPressed:
                    camera.busy ||
                        camera.photoAnalysis?[treatment == 'reframe'
                                ? 'reframe'
                                : 'horizon'] ==
                            null ||
                        (treatment == 'level' &&
                            !canLevelHorizon(camera.photoAnalysis))
                    ? null
                    : () => camera.applyTreatment(treatment),
                child: Text(
                  treatment == 'reframe' ? 'Auto reframe' : 'Level horizon',
                ),
              ),
            TextButton.icon(
              onPressed: camera.busy ? null : () => camera.variant(),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset edits'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> saveReviewPhoto() async {
    if (reviewSaveChooserOpen ||
        camera.busy ||
        camera.original == null ||
        camera.selected == null) {
      return;
    }
    if (camera.original!.unsaved) {
      await camera.saveSelected();
      return;
    }
    setState(() => reviewSaveChooserOpen = true);
    try {
      final source = camera.original!;
      final edited = camera.selected!;
      String? target;
      try {
        target = await camera.host.replacementTarget(source);
      } catch (_) {
        // A read-only or unavailable source can still be saved as a new photo.
      }
      if (!mounted ||
          camera.original?.id != source.id ||
          camera.selected?.id != edited.id ||
          camera.busy) {
        return;
      }
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Save photo'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                key: const Key('replaceReviewPhoto'),
                leading: const Icon(Icons.save),
                title: const Text('Replace original'),
                subtitle: Text(
                  target == null
                      ? 'Unavailable for this source'
                      : 'Update the existing photo in Photos',
                ),
                enabled: target != null,
                onTap: target == null
                    ? null
                    : () => Navigator.pop(ctx, 'replace'),
              ),
              ListTile(
                key: const Key('saveReviewPhotoAs'),
                leading: const Icon(Icons.add_photo_alternate),
                title: const Text('Save as a new photo'),
                subtitle: const Text('Keep the original unchanged'),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (choice == null ||
          !mounted ||
          camera.original?.id != source.id ||
          camera.selected?.id != edited.id ||
          camera.busy) {
        return;
      }
      await camera.saveSelected(replaceId: choice == 'replace' ? target : null);
    } finally {
      if (mounted) setState(() => reviewSaveChooserOpen = false);
    }
  }

  Future<void> discardReviewPhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard unsaved photo?'),
        content: const Text(
          'This removes the recovery copy. Save it first to keep it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep photo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirm == true) await camera.discard();
  }

  Widget review() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back to camera',
              onPressed: camera.busy ? null : camera.returnToCamera,
              icon: const Icon(Icons.camera_alt_outlined),
            ),
            IconButton(
              tooltip: 'Previous photo',
              onPressed: camera.canPreviousPhoto ? camera.previousPhoto : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Column(
                children: [
                  const Text('Photo review'),
                  if (camera.reviewIndex >= 0)
                    Text(
                      '${camera.reviewIndex + 1} of ${camera.reviewCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Next photo',
              onPressed: camera.canNextPhoto ? camera.nextPhoto : null,
              icon: const Icon(Icons.chevron_right),
            ),
            PopupMenuButton<String>(
              tooltip: 'Photo options',
              enabled: !camera.busy,
              onSelected: (value) {
                switch (value) {
                  case 'pick':
                    camera.pick();
                  case 'recent':
                    recentPhotos();
                  case 'import':
                    choosePhotos();
                  case 'settings':
                    camera.host.openSettings();
                  case 'discard':
                    discardReviewPhoto();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'pick',
                  child: Text('Choose photos from library'),
                ),
                const PopupMenuItem(
                  value: 'recent',
                  child: Text('Recent photos'),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: Text('Import photos'),
                ),
                if (camera.original?.unsaved == true) ...[
                  const PopupMenuItem(
                    value: 'settings',
                    child: Text('Open Settings'),
                  ),
                  const PopupMenuItem(
                    value: 'discard',
                    child: Text('Discard unsaved photo'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: camera.original == null || camera.selected == null
            ? const Center(child: Text('Choose a photo to edit'))
            : DistanceSwipe(
                minimumDistance: 60,
                onSwipe: (offset) {
                  if (offset > 0) {
                    camera.nextPhoto();
                  } else {
                    camera.previousPhoto();
                  }
                },
                onTap: openFullScreen,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ReviewComparison(
                    before: camera.original!.path,
                    after: camera.selected!.path,
                    mode: splitComparison
                        ? 'split'
                        : compare
                        ? 'before'
                        : 'after',
                  ),
                ),
              ),
      ),
      if (hasReviewEdits)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: reviewComparisonControls(),
        ),
      if (camera.busy) const LinearProgressIndicator(),
      if (camera.message != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Semantics(
            liveRegion: true,
            child: Text(camera.message!, maxLines: 2),
          ),
        ),
      if (reviewTool != null)
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.sizeOf(context).height *
                (MediaQuery.sizeOf(context).width >
                        MediaQuery.sizeOf(context).height
                    ? (reviewTool == 'menu' ? .35 : .25)
                    : (reviewTool == 'menu' ? .54 : .32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      {
                        'menu': 'Enhance',
                        'auto': 'Auto',
                        'enhance': 'General Enhancer',
                        'filters': 'Filter',
                        'beautifier': 'Beautifier',
                        'edit': 'Crop and Edit',
                      }[reviewTool]!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close photo tools',
                    onPressed: () => setState(() => reviewTool = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  key: ValueKey('reviewEditor_$reviewTool'),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: reviewEditor(),
                ),
              ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            FilledButton.tonalIcon(
              key: const Key('reviewEnhanceButton'),
              onPressed: camera.busy ? null : () => openReviewTool('menu'),
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Enhance'),
            ),
            const Spacer(),
            const SizedBox(width: 8),
            if (camera.original?.unsaved == true ||
                (camera.selected != null &&
                    camera.selected?.id != camera.original?.id))
              FilledButton(
                key: const Key('saveReviewEdits'),
                onPressed:
                    camera.busy ||
                        reviewSaveChooserOpen ||
                        camera.selected == null ||
                        (camera.original?.unsaved != true &&
                            camera.selected?.id == camera.original?.id)
                    ? null
                    : saveReviewPhoto,
                child: Text(
                  camera.original?.unsaved == true ? 'Retry save' : 'Save',
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Future<void> openFullScreen({String? mode}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FullScreenReview(
        before: camera.original!.path,
        after: camera.selected!.path,
        initialMode:
            mode ??
            (splitComparison
                ? 'split'
                : compare
                ? 'before'
                : 'after'),
      ),
    ),
  );

  Future<void> openPhotoLibrary() async {
    final opened = await camera.openPhotoLibrary();
    if (!mounted) return;
    setState(() {
      compare = true;
      splitComparison = false;
    });
    if (!opened) await choosePhotos();
  }

  Future<void> choosePhotos() async {
    final folder = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  camera.message ??
                      'Import up to 20 photos, or 50 from a folder',
                ),
              ),
              if (camera.message?.contains('denied') == true)
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Open Photos settings'),
                  onTap: camera.host.openSettings,
                ),
              ListTile(
                key: const Key('importPhotos'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Select photos'),
                onTap: () => Navigator.pop(context, false),
              ),
              ListTile(
                key: const Key('importFolder'),
                leading: const Icon(Icons.folder_open),
                title: const Text('Open folder'),
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (folder == null || !mounted) return;
    await camera.pick(folder: folder);
    if (mounted) setState(() => compare = true);
  }

  Future<void> chooser() async {
    camera.cancelSequence();
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .85,
        child: ReferenceChooser(
          catalog: camera.catalog,
          kind: camera.catalogKind,
          selected: camera.guidance.entry,
          onExample: details,
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'natural') camera.choose(null);
    if (result is CatalogEntry) camera.choose(result);
  }

  Future<void> effects() {
    camera.cancelSequence();
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => AnimatedBuilder(
        animation: camera,
        builder: (ctx, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Effects'),
                trailing: IconButton(
                  tooltip: 'Close effects',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ),
              CaptureStyleControls(camera: camera, initiallyExpanded: true),
              PhotoEffectControls(camera: camera),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> details(CatalogEntry item) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * .85,
      child: ReferenceDetails(camera: camera, initial: item),
    ),
  );
  Future<void> recentPhotos() => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * .65,
      child: Column(
        children: [
          const ListTile(
            title: Text('Recent photos'),
            subtitle: Text(
              'Up to 25 saved originals. Gallery copies stay in Photos.',
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              children: camera.history
                  .map(
                    (photo) => InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        camera.openHistory(photo);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(photo.path),
                              cacheWidth: 320,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image),
                            ),
                            if (photo.unsaved)
                              const Align(
                                alignment: Alignment.bottomCenter,
                                child: Text('Save needed'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );

  Future<void> settings() {
    camera.cancelSequence();
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => AnimatedBuilder(
        animation: camera,
        builder: (ctx, _) {
          return SizedBox(
            height: MediaQuery.sizeOf(ctx).height * .85,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    'Camera controls',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  trailing: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ShutterSettings(camera: camera),
                        CaptureStyleControls(camera: camera),
                        PhotoEffectControls(camera: camera),
                        FocusExposureSettings(
                          camera: camera,
                          onManual: () async {
                            await camera.enterManual();
                            if (ctx.mounted && camera.manualWorkspace) {
                              manualToolsVisible = false;
                              Navigator.pop(ctx);
                              refresh();
                            }
                          },
                        ),
                        ExpansionTile(
                          title: const Text('Diagnostics'),
                          children: [
                            SwitchListTile(
                              title: const Text('Debug overlay'),
                              value: camera.debug,
                              onChanged: (value) {
                                camera.debug = value;
                                refresh();
                              },
                            ),
                            TextButton(
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: jsonEncode(camera.log)),
                              ),
                              child: const Text('Copy diagnostic log'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> help() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Take a photo with Dali'),
      content: const SingleChildScrollView(
        child: Text(
          'Frame your subject and follow one short cue at a time. Choose a posture, landscape, or Food reference for framing and light. Next confirms a posture step; Dali does not verify the pose.\n\nTap the shutter for one photo; hold for a paced burst. Timer and custom voice phrase are in Camera controls. Voice runs on device where your phone supports it.\n\nEffects has separate Filter and Beautifier Auto, Custom, and Off choices. Depth of focus softens the background around the detected subject or your focus point. Selected effects and the signature are applied before the final photo saves to Photos. A private original is retained for review and recovery.\n\nReview offers Original, Reframe, Level, General Enhance, Portrait Polish, and Landscape Polish when measurements are available. Before exports the original; After and Split export the selected version. Tap the photo to zoom and move the comparison split.\n\nImport up to 20 photos or 50 images from a folder for this review session. Folder import does not install reference packages. Recent photos keeps up to 25 saved originals. Failed processing or saves retain the private capture for retry.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

IconData directionIcon(String direction) => switch (direction) {
  'left' => Icons.arrow_back,
  'right' => Icons.arrow_forward,
  'up' => Icons.arrow_upward,
  'down' => Icons.arrow_downward,
  'closer' => Icons.zoom_in,
  'farther' => Icons.zoom_out,
  'rotateLeft' => Icons.rotate_left,
  _ => Icons.rotate_right,
};
