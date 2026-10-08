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
                label: 'Take photo',
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
                      child: camera.busy
                          ? const CircularProgressIndicator()
                          : SizedBox(
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
              onTapUp: camera.snapshot?.supportsTap == true
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

  Widget review() {
    final photo = compare ? camera.original : camera.selected;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              HeaderAction(
                tooltip: 'Back to camera',
                selected: true,
                onPressed: camera.busy ? null : camera.returnToCamera,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 20),
                    Text(
                      'Camera',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HeaderAction(
                tooltip: 'Previous photo',
                onPressed: camera.canPreviousPhoto
                    ? camera.previousPhoto
                    : null,
                child: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      camera.reviewIndex >= 0
                          ? 'Photo ${camera.reviewIndex + 1} of ${camera.reviewCount}'
                          : 'Captured photo',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: cameraTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Photo review',
                      style: TextStyle(fontSize: 10, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              HeaderAction(
                tooltip: 'Next photo',
                onPressed: camera.canNextPhoto ? camera.nextPhoto : null,
                child: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 8),
              HeaderAction(
                tooltip: 'Choose photos from library',
                selected: true,
                onPressed: camera.busy ? null : () => camera.pick(),
                child: const Icon(Icons.photo_library_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReviewModeControls(
                  value: splitComparison
                      ? 'split'
                      : compare
                      ? 'before'
                      : 'after',
                  onChanged: (value) => setState(() {
                    compare = value == 'before';
                    splitComparison = value == 'split';
                  }),
                ),
                if (photo != null)
                  DistanceSwipe(
                    minimumDistance: 60,
                    onSwipe: (offset) {
                      setState(() => compare = false);
                      if (offset > 0) {
                        camera.nextPhoto();
                      } else {
                        camera.previousPhoto();
                      }
                    },
                    onTap: openFullScreen,
                    child: SizedBox(
                      height: MediaQuery.sizeOf(context).height * .52,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ReviewComparison(
                            before: camera.original!.path,
                            after: camera.selected!.path,
                            mode: splitComparison
                                ? 'split'
                                : compare
                                ? 'before'
                                : 'after',
                          ),
                          Positioned(
                            top: 10,
                            left: 12,
                            right: 68,
                            child: IgnorePointer(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .58),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        (compare && !splitComparison
                                                ? 'Original'
                                                : treatmentTitles[camera
                                                          .selectedTreatment] ??
                                                      {
                                                        'original': 'Original',
                                                        'crop': 'Tighter crop',
                                                        'styled': 'Filtered',
                                                        'reframe': 'Reframed',
                                                        'level': 'Leveled',
                                                      }[camera
                                                          .selectedTreatment] ??
                                                      'After')
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        camera.reviewingLibrary
                                            ? camera.reviewTitle
                                            : camera.reviewingImport
                                            ? 'Imported photo'
                                            : 'Current capture',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 12,
                            child: IconButton.filledTonal(
                              tooltip: 'Open full-screen photo',
                              icon: const Icon(Icons.open_in_full),
                              onPressed: openFullScreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (camera.message != null)
                  Semantics(liveRegion: true, child: Text(camera.message!)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed:
                          camera.busy ||
                              camera.selected?.id == camera.original?.id
                          ? null
                          : () => openFullScreen(mode: 'split'),
                      child: const Text('Compare'),
                    ),
                    FilledButton(
                      onPressed: camera.busy
                          ? null
                          : () => camera.saveSelected(
                              originalView: compare && !splitComparison,
                            ),
                      child: Text(
                        camera.original?.unsaved == true &&
                                camera.selected?.id == camera.original?.id
                            ? 'Retry save original'
                            : 'Save a copy',
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: camera.busy
                          ? null
                          : () => camera.shareSelected(
                              originalView: compare && !splitComparison,
                            ),
                      child: const Text('Share'),
                    ),
                    if (camera.original?.unsaved == true) ...[
                      TextButton(
                        onPressed: camera.host.openSettings,
                        child: const Text('Open Settings'),
                      ),
                      TextButton(
                        onPressed: camera.busy
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text(
                                      'Discard unsaved original?',
                                    ),
                                    content: const Text(
                                      'This removes the recovery copy. Share or save it first if you want to keep it.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Keep photo'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Discard'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) camera.discard();
                              },
                        child: const Text('Discard original'),
                      ),
                    ],
                  ],
                ),
                FilledButton.icon(
                  onPressed: camera.busy ? null : camera.returnToCamera,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Back to Camera'),
                ),
                ReviewTreatmentControls(camera: camera),
                ExpansionTile(
                  title: const Text('Versions and imports'),
                  children: [
                    Text(
                      'Choose a version',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Original'),
                          selected: camera.selected?.id == camera.original?.id,
                          onSelected: camera.busy
                              ? null
                              : (_) {
                                  camera.variant();
                                },
                        ),
                        ChoiceChip(
                          label: const Text('Tighter crop'),
                          selected:
                              !camera.styled &&
                              camera.selected?.id != camera.original?.id,
                          onSelected: camera.busy
                              ? null
                              : (_) {
                                  camera.variant(crop: true);
                                },
                        ),
                      ],
                    ),
                    CaptureStyleControls(camera: camera, review: true),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final treatment in ['reframe', 'level'])
                          ChoiceChip(
                            label: Text(
                              treatment == 'reframe'
                                  ? 'Auto reframe'
                                  : 'Level horizon',
                            ),
                            selected: camera.selectedTreatment == treatment,
                            onSelected:
                                camera.busy ||
                                    camera.photoAnalysis?[treatment == 'reframe'
                                            ? 'reframe'
                                            : 'horizon'] ==
                                        null ||
                                    (treatment == 'level' &&
                                        !canLevelHorizon(camera.photoAnalysis))
                                ? null
                                : (_) => camera.applyTreatment(treatment),
                          ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: camera.busy ? null : recentPhotos,
                          child: const Text('Recent photos'),
                        ),
                        TextButton(
                          onPressed: camera.busy ? null : choosePhotos,
                          child: const Text('Import photos'),
                        ),
                      ],
                    ),
                  ],
                ),
                if (camera.debug) ...[
                  PhotoEffectControls(camera: camera, review: true),
                  PhotoAnalysisCard(camera: camera),
                ],
                if (camera.busy) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
          'Frame your subject and follow one short cue at a time. Choose a posture, landscape, or Food reference for framing and light. Next confirms a posture step; Dali does not verify the pose.\n\nTap the shutter for one photo; hold for a paced burst. Timer and custom voice phrase are in Camera controls. Voice runs on device where your phone supports it.\n\nEffects has separate Filter and Beautifier Auto, Custom, and Off choices. Depth of focus softens the background around the detected subject or your focus point. The original saves first; save the prepared copy separately.\n\nReview offers Original, Reframe, Level, General Enhance, Portrait Polish, and Landscape Polish when measurements are available. Before exports the original; After and Split export the selected version. Tap the photo to zoom and move the comparison split.\n\nImport up to 20 photos or 50 images from a folder for this review session. Folder import does not install reference packages. Recent photos keeps up to 25 saved originals. Failed original saves remain available for retry.',
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
