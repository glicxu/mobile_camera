import 'dart:convert';
import 'package:dali_camera_core/dali_camera_core.dart';
import 'package:dali_camera_platform/dali_camera_platform.dart';
import 'package:flutter/foundation.dart';

class CameraController extends ChangeNotifier implements CameraEvents {
  CameraController({CameraHostApi? host, bool register = true})
    : host = host ?? CameraHostApi() {
    livePreviewEnabled = register;
    if (register) CameraEvents.setUp(this);
    guidance = CatalogSession(null, catalog);
  }
  final CameraHostApi host;
  bool _disposed = false;
  late final bool livePreviewEnabled;
  final catalog = SharedCatalog();
  final engine = CoachingEngine();
  late CatalogSession guidance;
  CameraSnapshot? snapshot;
  PhotoHandle? original;
  PhotoHandle? selected;
  bool busy = false;
  bool reviewing = false;
  bool starting = false;
  bool foreground = true;
  bool front = false;
  bool landscape = false;
  bool debug = false;
  bool voice = false;
  String? message;
  String? cameraError;
  double aspectRatio = 0.75;
  Map<String, dynamic>? lastFrame;
  Advice advice = const Advice(
    type: 'waiting',
    recipient: 'Camera',
    instruction: 'Starting camera',
    tone: AdviceTone.waiting,
  );
  final List<Map<String, Object?>> log = [];
  bool get canCapture =>
      !busy &&
      !starting &&
      !reviewing &&
      snapshot?.ready == true &&
      original?.unsaved != true;

  Future<void> initialize() async {
    try {
      original = await host.recover();
      selected = original;
      reviewing = original != null;
    } catch (e) {
      message = 'Recovery needs attention: $e';
    }
    notifyListeners();
    if (!reviewing) await start();
  }

  Future<void> start() async {
    if (starting || reviewing || !foreground || busy) return;
    starting = true;
    cameraError = null;
    engine.reset();
    notifyListeners();
    try {
      snapshot = await host.start(front);
      aspectRatio = snapshot!.aspectRatio;
      if (!foreground || reviewing) {
        await host.stop();
        snapshot = null;
      }
    } catch (e) {
      cameraError = '$e';
      snapshot = null;
    } finally {
      starting = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    snapshot = null;
    try {
      await host.setVoiceEnabled(false);
      await host.stop();
    } catch (_) {}
    voice = false;
    notifyListeners();
  }

  Future<void> switchLens() async {
    if (busy || starting || reviewing) return;
    front = !front;
    await start();
  }

  Future<void> capturePhoto() async {
    if (!canCapture) return;
    busy = true;
    message = 'Taking photo…';
    notifyListeners();
    try {
      original = await host.capture();
      selected = original;
      message = 'Saving original…';
      notifyListeners();
      await _saveOriginal();
      reviewing = true;
      await pause();
    } catch (e) {
      message = 'Photo could not be completed: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _saveOriginal() async {
    final photo = original;
    if (photo == null) return;
    try {
      await host.save(photo);
      photo.unsaved = false;
      message = 'Original saved to Photos';
    } catch (e) {
      photo.unsaved = true;
      message = 'Original retained. Save failed: $e';
    }
  }

  Future<void> saveSelected() async {
    if (busy || selected == null) return;
    busy = true;
    notifyListeners();
    try {
      if (selected?.id == original?.id) {
        await _saveOriginal();
      } else {
        await host.save(selected!);
        message = 'Selected copy saved to Photos';
      }
    } catch (e) {
      message = 'Save failed. Your original is retained: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> shareSelected() async {
    if (busy || selected == null) return;
    try {
      await host.share(selected!);
    } catch (e) {
      message = 'Share failed: $e';
      notifyListeners();
    }
  }

  Future<void> discard() async {
    if (busy || original == null) return;
    try {
      await host.discard(original!);
      original = null;
      selected = null;
      await returnToCamera();
    } catch (e) {
      message = 'Could not discard: $e';
      notifyListeners();
    }
  }

  Future<void> pick() async {
    if (busy) return;
    if (original?.unsaved == true) {
      message =
          'Save or discard the retained original before choosing another photo.';
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    try {
      final picked = await host.pickPhoto();
      if (picked != null) {
        original = picked;
        selected = picked;
        reviewing = true;
        await host.stop();
        snapshot = null;
      }
    } catch (e) {
      message = 'Could not open photo: $e';
    } finally {
      busy = false;
      notifyListeners();
      if (!reviewing) await start();
    }
  }

  Future<void> openLatest() async {
    if (original == null || busy) return;
    reviewing = true;
    await pause();
    notifyListeners();
  }

  Future<void> returnToCamera() async {
    if (busy) return;
    reviewing = false;
    await start();
    notifyListeners();
  }

  Future<void> variant({
    double rotation = 0,
    bool crop = false,
    double strength = 0,
  }) async {
    if (busy || original == null) return;
    busy = true;
    notifyListeners();
    try {
      selected = rotation == 0 && !crop && strength == 0
          ? original
          : await host.render(original!, rotation, crop, strength);
      message = null;
    } catch (e) {
      message = 'Could not prepare this version: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void choose(CatalogEntry? entry) {
    guidance = CatalogSession(entry, catalog);
    engine.reset();
    advice =
        guidance.advice ??
        const Advice(
          type: 'waiting',
          recipient: 'Camera',
          instruction: 'Frame your scene. Take a photo when you are ready.',
          tone: AdviceTone.waiting,
        );
    notifyListeners();
  }

  void next() {
    guidance.advance();
    engine.reset();
    advice = guidance.advice ?? advice;
    notifyListeners();
  }

  Future<void> controls(double ev, bool locked) async {
    final current = snapshot;
    if (current == null || busy) return;
    try {
      snapshot = await host.setControls(current.configurationId, ev, locked);
    } catch (e) {
      message = 'Camera control failed: $e';
    }
    notifyListeners();
  }

  Future<void> setVoice(bool value) async {
    try {
      voice = await host.setVoiceEnabled(value);
      if (value && !voice) {
        message = 'On-device voice shutter is unavailable on this phone.';
      }
    } catch (e) {
      message = 'Voice shutter: $e';
      voice = false;
    }
    notifyListeners();
  }

  @override
  void analysis(String json) {
    if (reviewing || !foreground || snapshot == null) return;
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      if (data['configurationId'] != snapshot!.configurationId) return;
      final packet = NativeFrame(data);
      lastFrame = data;
      aspectRatio = packet.aspectRatio;
      final roll = packet.measurements.cameraRollDegrees;
      if (landscape) {
        advice = roll.abs() > 3
            ? Advice(
                type: 'camera_tilted',
                recipient: 'Photographer',
                instruction: roll > 0 ? 'Tilt left' : 'Tilt right',
                tone: AdviceTone.warning,
              )
            : guidance.advice ??
                  const Advice(
                    type: 'landscape',
                    recipient: 'Photographer',
                    instruction: 'Choose a composition or frame your scene.',
                    tone: AdviceTone.waiting,
                  );
      } else if (data['peopleStatus'] == 'unavailable') {
        advice = const Advice(
          type: 'detector_unavailable',
          recipient: 'Camera',
          instruction: 'Detection unavailable. You can still take a photo.',
          tone: AdviceTone.waiting,
        );
      } else {
        final measures = packet.measurements;
        final issues = engine
            .issues(measures, includePosture: false)
            .where(
              (issue) =>
                  !(issue.type == 'face_missing' &&
                      data['faceStatus'] == 'unavailable'),
            )
            .toList();
        advice = engine.selectAdvice(
          guidance.prioritize(issues),
          fallback: guidance.advice,
        );
      }
      if (log.isEmpty || log.last['instruction'] != advice.instruction) {
        log.add({
          'time': DateTime.now().toIso8601String(),
          'instruction': advice.instruction,
          'type': advice.type,
        });
        if (log.length > 200) log.removeAt(0);
      }
      notifyListeners();
    } catch (e) {
      message = 'Analysis format error: $e';
      notifyListeners();
    }
  }

  @override
  void state(CameraSnapshot value) {
    if (!reviewing &&
        foreground &&
        !starting &&
        snapshot?.configurationId == value.configurationId) {
      snapshot = value;
      aspectRatio = value.aspectRatio;
      notifyListeners();
    }
  }

  @override
  void error(String code, String value) {
    message = '$code: $value';
    notifyListeners();
  }

  @override
  void voiceShutter() {
    if (voice && canCapture) capturePhoto();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    CameraEvents.setUp(null);
    super.dispose();
  }
}
