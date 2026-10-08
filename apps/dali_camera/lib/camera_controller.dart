import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool food = false;
  String get catalogKind => food
      ? 'food'
      : landscape
      ? 'landscape'
      : 'pose';
  int timerSeconds = 0;
  int countdown = 0;
  int _sequence = 0;
  bool bursting = false;
  int burstCount = 0;
  String longPress = 'burst';
  String voicePhrase = '';
  String filter = 'off';
  Map<String, int> customStyle = {};
  bool watermark = false;
  bool styled = false;
  final List<PhotoHandle> history = [];
  PhotoStyle get style => filter == 'custom'
      ? PhotoStyle(customStyle)
      : PhotoStyle.preset(catalog, filter, catalogKind);
  bool get sequenceActive => countdown > 0 || bursting;
  bool debug = false;
  bool voice = false;
  bool controlBusy = false;
  bool manualWorkspace = false;
  double? focusX;
  double? focusY;
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
  bool get canCapture => _captureReady && !sequenceActive;
  bool get _captureReady =>
      foreground &&
      !busy &&
      !controlBusy &&
      !starting &&
      !reviewing &&
      snapshot?.ready == true &&
      original?.unsaved != true;

  Future<void> initialize() async {
    if (livePreviewEnabled) await _loadPreferences();
    try {
      original = await host.recover();
      selected = original;
      reviewing = original != null;
      if (original != null) {
        history.removeWhere((photo) => photo.id == original!.id);
        history.insert(0, original!);
      }
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
      manualWorkspace = false;
      focusX = null;
      focusY = null;
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
    cancelSequence();
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
    cancelSequence();
    front = !front;
    await start();
  }

  Future<void> capturePhoto({
    bool review = true,
    bool fromSequence = false,
  }) async {
    if (fromSequence ? !_captureReady : !canCapture) return;
    busy = true;
    message = 'Taking photo…';
    notifyListeners();
    try {
      final prior = selected;
      original = await host.capture();
      if (prior != null &&
          prior.id != history.firstOrNull?.id &&
          !history.any((p) => p.id == prior.id)) {
        await _release(prior);
      }
      selected = original;
      styled = false;
      message = 'Saving original…';
      notifyListeners();
      await _saveOriginal();
      history.removeWhere((photo) => photo.id == original!.id);
      history.insert(0, original!);
      await _persistHistory();
      if ((style.active || watermark) && original?.unsaved != true) {
        try {
          selected = await _renderStyle(original!);
          styled = true;
        } catch (e) {
          message = 'Original saved. Style could not be prepared: $e';
        }
      }
      reviewing = review || original?.unsaved == true;
      if (reviewing) await pause();
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
      await _persistHistory();
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
      history.removeWhere((photo) => photo.id == original!.id);
      await _persistHistory();
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
    cancelSequence();
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
        await _releaseVariant();
        original = picked;
        selected = picked;
        styled = false;
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
      await _releaseVariant();
      styled = false;
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

  void cancelSequence() {
    _sequence++;
    countdown = 0;
    bursting = false;
    notifyListeners();
  }

  Future<void> requestShutter({bool forceTimer = false}) async {
    if (!canCapture) return;
    final epoch = ++_sequence;
    final configuration = snapshot?.configurationId;
    countdown = forceTimer && timerSeconds == 0 ? 3 : timerSeconds;
    while (countdown > 0) {
      notifyListeners();
      await Future<void>.delayed(const Duration(seconds: 1));
      if (_disposed || epoch != _sequence) return;
      if (!foreground ||
          reviewing ||
          snapshot?.configurationId != configuration) {
        cancelSequence();
        return;
      }
      countdown--;
    }
    notifyListeners();
    if (epoch == _sequence) await capturePhoto(review: false);
  }

  Future<void> beginLongPress() async {
    if (!canCapture) return;
    if (longPress == 'timer') {
      await requestShutter(forceTimer: true);
      return;
    }
    if (longPress != 'burst') return;
    final epoch = ++_sequence;
    bursting = true;
    burstCount = 0;
    notifyListeners();
    while (!_disposed &&
        bursting &&
        epoch == _sequence &&
        _captureReady &&
        burstCount < 25) {
      final prior = original?.id;
      await capturePhoto(review: false, fromSequence: true);
      if (original?.id != prior && original?.unsaved != true) {
        burstCount++;
      } else {
        break;
      }
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (epoch == _sequence) {
      bursting = false;
      message = '$burstCount burst photos saved';
      notifyListeners();
    }
  }

  void endLongPress() {
    if (longPress == 'burst') cancelSequence();
  }

  Future<void> openHistory(PhotoHandle photo) async {
    if (busy || (original?.unsaved == true && original?.id != photo.id)) return;
    cancelSequence();
    await _releaseVariant();
    original = photo;
    selected = photo;
    styled = false;
    reviewing = true;
    await pause();
  }

  Future<void> applyStyle() async {
    if (busy || original == null) return;
    busy = true;
    notifyListeners();
    try {
      final result = await _renderStyle(original!);
      await _releaseVariant();
      selected = result;
      styled = true;
      message = 'Styled copy ready. Original retained.';
    } catch (e) {
      message = 'Could not style photo: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<PhotoHandle> _renderStyle(PhotoHandle source) async {
    String? markPath;
    if (watermark) {
      final bytes = await rootBundle.load(
        'assets/branding/dali-cam-watermark.png',
      );
      final file = File('${Directory.systemTemp.path}/dali-watermark.png');
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      markPath = file.path;
    }
    final selectedStyle = style;
    return host.renderStyle(
      source,
      selectedStyle.matrix,
      selectedStyle.value('softness').toDouble(),
      selectedStyle.value('detail').toDouble(),
      markPath,
    );
  }

  Future<void> _release(PhotoHandle photo) async {
    try {
      await host.releasePhoto(photo);
    } catch (_) {
      /* Retain on cleanup failure. */
    }
  }

  Future<void> _releaseVariant() async {
    final photo = selected;
    if (photo != null &&
        photo.id != original?.id &&
        !history.any((p) => p.id == photo.id)) {
      await _release(photo);
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      timerSeconds = [0, 3, 5, 10].contains(prefs.getInt('timerSeconds'))
          ? prefs.getInt('timerSeconds')!
          : 0;
      longPress = prefs.getString('longPress') ?? 'burst';
      voicePhrase = prefs.getString('voicePhrase') ?? '';
      final savedFilter = prefs.getString('filter') ?? 'off';
      filter =
          [
            'auto',
            'off',
            'custom',
            ...(catalog.data['filters'] as Map).keys,
          ].contains(savedFilter)
          ? savedFilter
          : 'off';
      watermark = prefs.getBool('watermark') ?? false;
      final styleData =
          jsonDecode(prefs.getString('customStyle') ?? '{}') as Map;
      customStyle = styleData.map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      );
      for (final data
          in jsonDecode(prefs.getString('history') ?? '[]') as List) {
        if (File(data['path'] as String).existsSync()) {
          history.add(
            PhotoHandle(
              path: data['path'] as String,
              id: data['id'] as String,
              unsaved: data['unsaved'] == true,
              mimeType: data['mimeType'] as String?,
            ),
          );
        }
      }
      await host.setVoicePhrase(voicePhrase);
    } catch (e) {
      message = 'Saved settings could not be restored: $e';
    }
  }

  Future<void> persistSettings() async {
    notifyListeners();
    if (!livePreviewEnabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('timerSeconds', timerSeconds);
      await prefs.setString('longPress', longPress);
      await prefs.setString('filter', filter);
      await prefs.setString('voicePhrase', voicePhrase);
      await prefs.setBool('watermark', watermark);
      await prefs.setString('customStyle', jsonEncode(customStyle));
      await host.setVoicePhrase(voicePhrase);
    } catch (e) {
      message = 'Could not save settings: $e';
      notifyListeners();
    }
  }

  Future<void> _persistHistory() async {
    // Commit the retained list before removing private saved copies.
    final keep = history.where((p) => p.unsaved).toList();
    keep.addAll(history.where((p) => !p.unsaved).take(25));
    if (livePreviewEnabled) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = await prefs.setString(
          'history',
          jsonEncode(
            keep
                .map(
                  (p) => {
                    'path': p.path,
                    'id': p.id,
                    'unsaved': p.unsaved,
                    'mimeType': p.mimeType,
                  },
                )
                .toList(),
          ),
        );
        if (!saved) return;
      } catch (_) {
        return;
      }
    }
    final dropped = history.where((p) => !keep.contains(p)).toList();
    history
      ..clear()
      ..addAll(keep);
    for (final photo in dropped) {
      await _release(photo);
    }
  }

  void choose(CatalogEntry? entry) {
    cancelSequence();
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

  Future<void> _control(
    Future<CameraSnapshot> Function(CameraSnapshot) action,
  ) async {
    final current = snapshot;
    if (current == null || busy || controlBusy || starting) return;
    controlBusy = true;
    notifyListeners();
    try {
      final result = await action(current);
      if (foreground && snapshot?.configurationId == result.configurationId) {
        snapshot = result;
      }
    } catch (e) {
      message = 'Camera control failed: $e';
    } finally {
      controlBusy = false;
      notifyListeners();
    }
  }

  Future<void> controls(double ev, bool locked) => _control(
    (current) => host.setControls(current.configurationId, ev, locked),
  );
  Future<void> zoom(double value) =>
      _control((current) => host.setZoom(current.configurationId, value));
  Future<void> meter(double x, double y) async {
    if (snapshot?.supportsTap != true || controlBusy || busy || reviewing) {
      return;
    }
    focusX = x.clamp(0, 1);
    focusY = y.clamp(0, 1);
    await _control((current) => host.meter(current.configurationId, x, y));
  }

  Future<void> manual(double seconds, double iso) => _control(
    (current) => host.setManualExposure(current.configurationId, seconds, iso),
  );
  Future<void> returnAuto({bool stayInManual = false}) async {
    await _control(
      (current) => host.setManualExposure(current.configurationId, null, null),
    );
    if (snapshot?.manualExposure != true) {
      manualWorkspace = stayInManual;
      focusX = null;
      focusY = null;
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
      if (landscape || food) {
        advice = roll.abs() > 3
            ? Advice(
                type: 'camera_tilted',
                recipient: 'Photographer',
                instruction: roll > 0 ? 'Tilt left' : 'Tilt right',
                tone: AdviceTone.warning,
              )
            : guidance.advice ??
                  Advice(
                    type: catalogKind,
                    recipient: 'Photographer',
                    instruction: food
                        ? 'Choose a Food recipe or frame your dish.'
                        : 'Choose a composition or frame your scene.',
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
    if (voice && canCapture) requestShutter();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    cancelSequence();
    _disposed = true;
    CameraEvents.setUp(null);
    super.dispose();
  }
}
