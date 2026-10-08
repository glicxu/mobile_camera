import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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
  PhotographicSituation shootingMode = PhotographicSituation.auto;
  final situationClassifier = SituationClassifier();
  final subjectMotionTracker = SubjectMotionTracker();
  PhotographicSituation get activeSituation =>
      shootingMode == PhotographicSituation.auto
      ? situationClassifier.recommendation
      : shootingMode;
  // Compatibility for existing capture tests and stored filter selection.
  bool get landscape => activeSituation == PhotographicSituation.landscape;
  set landscape(bool value) => setSituation(
    value ? PhotographicSituation.landscape : PhotographicSituation.portrait,
  );
  bool get food => activeSituation == PhotographicSituation.food;
  set food(bool value) => setSituation(
    value ? PhotographicSituation.food : PhotographicSituation.portrait,
  );
  String get catalogKind => activeSituation.catalogKind ?? 'pose';
  String guidanceDetail = '';
  void setSituation(PhotographicSituation value) {
    if (shootingMode == value) return;
    shootingMode = value;
    subjectMotionTracker.reset();
    choose(null);
    if (lastFrame != null) analysis(jsonEncode(lastFrame));
  }

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
  String beautifier = 'off';
  String customBeautifier = 'portrait';
  int depthLevel = 0;
  String selectedTreatment = 'original';
  Map<String, dynamic>? photoAnalysis;
  String? analysisError;
  final Map<String, Map<String, dynamic>> captureTreatments = {
    'enhance': {'strength': 3, 'flags': <String, bool>{}},
    'portrait': {
      'strength': 3,
      'flags': <String, bool>{'lipPlumping': false},
    },
    'landscape': {'strength': 3, 'flags': <String, bool>{}},
  };
  final Map<String, Map<String, dynamic>> reviewTreatments = {
    'enhance': {'strength': 0, 'flags': <String, bool>{}},
    'portrait': {
      'strength': 0,
      'flags': <String, bool>{'lipPlumping': true},
    },
    'landscape': {'strength': 0, 'flags': <String, bool>{}},
  };
  String reviewTreatment = 'enhance';
  PosePackageId coachingPackage = PosePackageId.neutral;
  String get captureTreatment => beautifier == 'off'
      ? 'original'
      : beautifier == 'custom'
      ? customBeautifier
      : switch (activeSituation) {
          PhotographicSituation.portrait ||
          PhotographicSituation.group ||
          PhotographicSituation.personScene => 'portrait',
          PhotographicSituation.landscape => 'landscape',
          _ => 'enhance',
        };
  final List<PhotoHandle> history = [];
  final List<PhotoHandle> importedPhotos = [];
  bool get reviewingImport =>
      importedPhotos.any((photo) => photo.id == original?.id);
  List<PhotoHandle> get reviewPhotos =>
      reviewingImport ? importedPhotos : history;
  int get reviewIndex =>
      reviewPhotos.indexWhere((photo) => photo.id == original?.id);
  bool get canPreviousPhoto =>
      !busy &&
      original?.unsaved != true &&
      (reviewIndex > 0 || (reviewingImport && importedPhotos.length > 1));
  bool get canNextPhoto =>
      !busy &&
      original?.unsaved != true &&
      reviewIndex >= 0 &&
      (reviewIndex < reviewPhotos.length - 1 ||
          (reviewingImport && importedPhotos.length > 1));
  Future<void> previousPhoto() async {
    if (canPreviousPhoto) {
      await openHistory(reviewPhotos[(reviewIndex - 1) % reviewPhotos.length]);
    }
  }

  Future<void> nextPhoto() async {
    if (canNextPhoto) {
      await openHistory(reviewPhotos[(reviewIndex + 1) % reviewPhotos.length]);
    }
  }

  PhotoStyle get style => filter == 'custom'
      ? PhotoStyle(customStyle)
      : PhotoStyle.preset(catalog, filter, activeSituation.name);
  bool get sequenceActive => countdown > 0 || bursting;
  bool debug = false;
  bool voice = false;
  bool voicePreferred = false;
  String voiceStatus = 'Off';
  bool _depthUpdating = false;
  bool controlBusy = false;
  bool manualWorkspace = false;
  bool linkedISO = false;
  double linkedExposureProduct = 100 / 125;
  double linkedEV = 0;
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
      await host.reconcilePrivatePhotos(
        history.map((photo) => photo.path).toList(),
      );
    } catch (e) {
      message = 'Recovery needs attention: $e';
    }
    notifyListeners();
    if (!reviewing) {
      await start();
    } else {
      await _analyzeStill();
    }
  }

  Future<void> start() async {
    if (starting || reviewing || !foreground || busy) return;
    starting = true;
    cameraError = null;
    lastFrame = null;
    engine.reset();
    subjectMotionTracker.reset();
    notifyListeners();
    try {
      snapshot = await host.start(front);
      manualWorkspace = false;
      focusX = null;
      focusY = null;
      aspectRatio = snapshot!.aspectRatio;
      if (voicePreferred && foreground && !reviewing) await _resumeVoice();
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
      selectedTreatment = 'original';
      photoAnalysis = null;
      analysisError = null;
      message = 'Saving original…';
      notifyListeners();
      await _saveOriginal();
      history.removeWhere((photo) => photo.id == original!.id);
      history.insert(0, original!);
      await _persistHistory();
      if ((style.active ||
              watermark ||
              beautifier != 'off' ||
              depthLevel > 0) &&
          original?.unsaved != true) {
        try {
          selected = await _renderStyle(original!);
          styled = true;
          selectedTreatment = 'styled';
        } catch (e) {
          message = 'Original saved. Style could not be prepared: $e';
        }
      }
      reviewing = review || original?.unsaved == true;
      if (reviewing) {
        await pause();
        await _analyzeStill();
      }
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

  Future<void> pick({bool folder = false}) async {
    if (busy) return;
    cancelSequence();
    if (original?.unsaved == true) {
      message =
          'Save or discard the retained original before choosing other photos.';
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    try {
      final result = await host.pickPhotos(folder);
      if (_disposed) {
        for (final photo in result.photos) {
          await _release(photo);
        }
        return;
      }
      if (result.photos.isNotEmpty) {
        await _releaseVariant();
        await _clearImportedPhotos();
        importedPhotos.addAll(result.photos);
        original = importedPhotos.first;
        selected = original;
        styled = false;
        selectedTreatment = 'original';
        reviewing = true;
        await pause();
        await _analyzeStill();
        message = result.skipped > 0
            ? '${result.photos.length} photos opened; ${result.skipped} skipped. Imports are limited to 50 photos.'
            : '${result.photos.length} ${result.photos.length == 1 ? 'photo' : 'photos'} opened';
      }
    } catch (e) {
      message = 'Could not open photos: $e';
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
    await _analyzeStill();
    notifyListeners();
  }

  Future<void> returnToCamera() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      if (reviewingImport) {
        await _releaseVariant();
        await _clearImportedPhotos();
        original = history.firstOrNull;
        selected = original;
        styled = false;
      }
    } finally {
      busy = false;
    }
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
      final result = rotation == 0 && !crop && strength == 0
          ? original
          : await host.render(original!, rotation, crop, strength);
      await _releaseVariant();
      styled = false;
      selected = result;
      selectedTreatment = crop ? 'crop' : 'original';
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
    busy = true;
    notifyListeners();
    try {
      await _releaseVariant();
      original = photo;
      selected = photo;
      styled = false;
      selectedTreatment = 'original';
      if (!reviewingImport) await _clearImportedPhotos();
      reviewing = true;
      await pause();
      await _analyzeStill();
    } finally {
      busy = false;
      notifyListeners();
    }
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
      selectedTreatment = 'styled';
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
    if (beautifier != 'off' || depthLevel > 0) {
      final settings = captureTreatments[captureTreatment];
      return host.renderEffects(
        source,
        jsonEncode({
          'version': 1,
          'treatment': captureTreatment,
          'strength': settings?['strength'] ?? 0,
          'flags': settings?['flags'] ?? {},
          'filter': PhotoStyle.fields
              .map((field) => selectedStyle.value(field).toDouble())
              .toList(),
          'depth': depthLevel,
          if (focusX != null && focusY != null)
            'focus': {'x': focusX, 'y': focusY},
          'watermarkPath': ?markPath,
        }),
      );
    }
    return host.renderFilter(
      source,
      selectedStyle.matrix,
      PhotoStyle.fields
          .map((field) => selectedStyle.value(field).toDouble())
          .toList(),
      markPath,
    );
  }

  Future<void> _analyzeStill() async {
    final source = original;
    photoAnalysis = null;
    analysisError = null;
    if (source == null) return;
    try {
      final result =
          jsonDecode(await host.analyzePhoto(source)) as Map<String, dynamic>;
      if (original?.id == source.id && result['sourceId'] == source.id) {
        if (result['imageWidth'] != null) {
          final measured = NativeFrame(result);
          if (measured.poseAnalysis != null)
            result['poseAnalysis'] = measured.poseAnalysis!.toJson();
          result['issues'] = engine
              .issues(
                measured.measurements,
                includePosture: true,
                posePackage: coachingPackage,
              )
              .where(
                (issue) =>
                    !(issue.type == 'face_missing' &&
                        result['faceStatus'] != 'valid'),
              )
              .map(
                (issue) => {
                  'type': issue.type,
                  'instruction': issue.instruction,
                  'recipient': issue.recipient,
                  'severity': issue.severity,
                },
              )
              .toList();
        }
        photoAnalysis = result;
      }
    } catch (error) {
      if (original?.id == source.id) {
        analysisError = 'Photo analysis unavailable: $error';
      }
    }
    notifyListeners();
  }

  Future<void> applyTreatment(String treatment) async {
    if (busy || original == null) return;
    busy = true;
    notifyListeners();
    try {
      final settings = reviewTreatments[treatment];
      final result = await host.renderEffects(
        original!,
        jsonEncode({
          'version': 1,
          'treatment': treatment,
          'strength': settings?['strength'] ?? 0,
          'flags': settings?['flags'] ?? {},
        }),
      );
      await _releaseVariant();
      selected = result;
      selectedTreatment = treatment;
      styled = false;
      message = 'Selected version ready. Original retained.';
    } catch (error) {
      message = 'Could not prepare this version: $error';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void setCoachingPackage(PosePackageId value) {
    coachingPackage = value;
    final analysis = photoAnalysis;
    if (analysis != null && analysis['imageWidth'] != null) {
      analysis['issues'] = engine
          .issues(
            NativeFrame(analysis).measurements,
            includePosture: true,
            posePackage: value,
          )
          .where(
            (issue) =>
                !(issue.type == 'face_missing' &&
                    analysis['faceStatus'] != 'valid'),
          )
          .map(
            (issue) => {
              'type': issue.type,
              'instruction': issue.instruction,
              'recipient': issue.recipient,
              'severity': issue.severity,
            },
          )
          .toList();
    }
    persistSettings();
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
        !history.any((p) => p.id == photo.id) &&
        !importedPhotos.any((p) => p.id == photo.id)) {
      await _release(photo);
    }
  }

  Future<void> _clearImportedPhotos() async {
    final previous = List<PhotoHandle>.of(importedPhotos);
    importedPhotos.clear();
    for (final photo in previous) {
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
      voicePreferred = prefs.getBool('voicePreferred') ?? false;
      final savedFilter = prefs.getString('filter') ?? 'auto';
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
      final savedBeauty = prefs.getString('beautifier');
      beautifier = ['auto', 'custom', 'off'].contains(savedBeauty)
          ? savedBeauty!
          : 'off';
      customBeautifier = prefs.getString('customBeautifier') ?? 'portrait';
      if (!captureTreatments.containsKey(customBeautifier)) {
        customBeautifier = 'portrait';
      }
      reviewTreatment = prefs.getString('reviewTreatment') ?? 'enhance';
      final savedPackage = prefs.getString('coachingPackage');
      coachingPackage =
          PosePackageId.values
              .where((value) => value.name == savedPackage)
              .firstOrNull ??
          PosePackageId.neutral;
      if (!reviewTreatments.containsKey(reviewTreatment)) {
        reviewTreatment = 'enhance';
      }
      depthLevel = (prefs.getInt('depthLevel') ?? 0).clamp(0, 5);
      for (final entry in {
        'captureTreatments': captureTreatments,
        'reviewTreatments': reviewTreatments,
      }.entries) {
        final saved = jsonDecode(prefs.getString(entry.key) ?? '{}') as Map;
        for (final key in entry.value.keys) {
          final profile = saved[key];
          if (profile is Map) {
            entry.value[key] = {
              'strength': ((profile['strength'] as num?)?.toInt() ?? 0).clamp(
                0,
                5,
              ),
              'flags': Map<String, bool>.from(profile['flags'] as Map? ?? {}),
            };
          }
        }
      }
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
      await prefs.setBool('voicePreferred', voicePreferred);
      await prefs.setBool('watermark', watermark);
      await prefs.setString('customStyle', jsonEncode(customStyle));
      await prefs.setString('beautifier', beautifier);
      await prefs.setString('customBeautifier', customBeautifier);
      await prefs.setString('reviewTreatment', reviewTreatment);
      await prefs.setString('coachingPackage', coachingPackage.name);
      await prefs.setInt('depthLevel', depthLevel);
      await prefs.setString('captureTreatments', jsonEncode(captureTreatments));
      await prefs.setString('reviewTreatments', jsonEncode(reviewTreatments));
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
    guidanceDetail = '';
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
  void setLinkedISO(bool value) {
    linkedISO = value;
    linkedExposureProduct =
        (snapshot?.currentISO ?? 100) * (snapshot?.currentShutter ?? 1 / 125);
    linkedEV = 0;
    notifyListeners();
  }

  Future<void> changeShutter(double seconds) => manual(
    seconds,
    linkedISO
        ? (linkedExposureProduct / seconds * math.pow(2, linkedEV))
              .clamp(snapshot!.minimumISO!, snapshot!.maximumISO!)
              .toDouble()
        : snapshot?.currentISO ?? 100,
  );
  Future<void> changeISO(double iso) {
    linkedExposureProduct = iso * (snapshot?.currentShutter ?? 1 / 125);
    linkedEV = 0;
    return manual(snapshot?.currentShutter ?? 1 / 125, iso);
  }

  Future<void> changeLinkedEV(double ev) {
    linkedEV = ev;
    return changeShutter(snapshot?.currentShutter ?? 1 / 125);
  }

  Future<void> returnAuto({bool stayInManual = false}) async {
    await _control(
      (current) => host.setManualExposure(current.configurationId, null, null),
    );
    if (snapshot?.manualExposure != true) {
      linkedISO = false;
      linkedEV = 0;
      manualWorkspace = stayInManual;
      focusX = null;
      focusY = null;
    }
    notifyListeners();
  }

  Future<void> setVoice(bool value) async {
    voicePreferred = value;
    await persistSettings();
    await _resumeVoice();
  }

  Future<void> _resumeVoice() async {
    final value = voicePreferred && foreground && !reviewing;
    try {
      voice = await host.setVoiceEnabled(value);
      voiceStatus = voice
          ? 'Listening on device'
          : value
          ? 'Unavailable on this phone'
          : 'Off';
      if (value && !voice) {
        message = 'On-device voice shutter is unavailable on this phone.';
      }
    } catch (e) {
      message = 'Voice shutter: $e';
      voice = false;
      voiceStatus = 'Voice shutter unavailable';
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
      unawaited(updateDepthPreview());
      aspectRatio = packet.aspectRatio;
      var signals = packet.situationSignals;
      signals = signals.withSubjectMotion(
        subjectMotionTracker.update(signals, packet.frame.timestamp),
      );
      if (shootingMode == PhotographicSituation.auto &&
          !busy &&
          !sequenceActive &&
          !guidance.isActive) {
        final previous = activeSituation;
        situationClassifier.update(signals);
        if (previous != activeSituation) {
          cancelSequence();
          guidance = CatalogSession(null, catalog);
          engine.reset();
        }
      }
      guidanceDetail = '';
      if (!activeSituation.supportsPoseGuidance) {
        final situation = situationGuidance(activeSituation, signals);
        guidanceDetail = situation.detail;
        advice = guidance.advice ?? situation.advice;
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
      if (activeSituation.supportsPoseGuidance) {
        guidanceDetail = advice.recipient == 'Photographer'
            ? 'Adjust the camera position or framing.'
            : advice.recipient == 'Subject'
            ? 'Ask the subject to make this adjustment.'
            : 'Dali is analyzing the live camera view.';
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
    if (voicePreferred && canCapture) requestShutter();
  }

  @override
  void voiceState(bool listening, String status) {
    voice = listening && foreground && !reviewing;
    voiceStatus = status;
    notifyListeners();
  }

  Future<void> updateDepthPreview() async {
    final current = snapshot;
    if (_depthUpdating ||
        current == null ||
        reviewing ||
        lastFrame?['configurationId'] != current.configurationId)
      return;
    _depthUpdating = true;
    try {
      Map? subject;
      final people = lastFrame?['people'] as List? ?? [];
      final faces = lastFrame?['faces'] as List? ?? [];
      final candidates = [
        ...people.whereType<Map>(),
        if (lastFrame?['salientObject'] is Map)
          lastFrame!['salientObject'] as Map,
        ...faces.whereType<Map>(),
      ];
      if (focusX != null && focusY != null) {
        subject = candidates
            .where(
              (r) =>
                  focusX! >= (r['x'] as num) - .04 &&
                  focusX! <= (r['x'] as num) + (r['width'] as num) + .04 &&
                  focusY! >= (r['y'] as num) - .04 &&
                  focusY! <= (r['y'] as num) + (r['height'] as num) + .04,
            )
            .firstOrNull;
      }
      final focused = subject != null;
      subject ??= people.whereType<Map>().firstOrNull;
      final faceOnly = subject == null && faces.isNotEmpty;
      subject ??= faces.whereType<Map>().firstOrNull;
      Map<String, double>? rect;
      if (subject != null) {
        final x = (subject['x'] as num).toDouble();
        final y = (subject['y'] as num).toDouble();
        final w = (subject['width'] as num).toDouble();
        final h = (subject['height'] as num).toDouble();
        final dx = focused
            ? .22
            : faceOnly
            ? 1.1
            : .16;
        final dy = focused
            ? .18
            : faceOnly
            ? .45
            : .10;
        final left = (x - w * dx).clamp(0.0, 1.0);
        final top = (y - h * dy).clamp(0.0, 1.0);
        final right = (x + w * (faceOnly ? 2.1 : 1 + dx)).clamp(left, 1.0);
        final bottom = (y + h * (faceOnly ? 4.25 : 1 + dy)).clamp(top, 1.0);
        rect = {
          'x': left,
          'y': top,
          'width': right - left,
          'height': bottom - top,
        };
      } else if (focusX != null && focusY != null) {
        final left = (focusX! - .18).clamp(0.0, 1.0);
        final top = (focusY! - .24).clamp(0.0, 1.0);
        rect = {
          'x': left,
          'y': top,
          'width': .36.clamp(0.0, 1 - left),
          'height': .48.clamp(0.0, 1 - top),
        };
      }
      await host.setDepthPreview(
        current.configurationId,
        depthLevel,
        rect == null ? null : jsonEncode(rect),
      );
    } catch (_) {
      // Saved-photo processing remains available when a preview backend fails.
    } finally {
      _depthUpdating = false;
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    cancelSequence();
    _disposed = true;
    unawaited(_releaseVariant().then((_) => _clearImportedPhotos()));
    CameraEvents.setUp(null);
    super.dispose();
  }
}
