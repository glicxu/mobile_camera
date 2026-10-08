import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'dali_camera_platform',
    dartOut: 'lib/src/camera_api.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/dalicamera/dali_camera_platform/CameraApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.dalicamera.dali_camera_platform',
    ),
    swiftOut:
        'ios/dali_camera_platform/Sources/dali_camera_platform/CameraApi.g.swift',
  ),
)
class CameraSnapshot {
  CameraSnapshot({
    required this.ready,
    required this.front,
    required this.configurationId,
    required this.aspectRatio,
    required this.minimumEV,
    required this.maximumEV,
    required this.currentEV,
    required this.supportsLock,
    required this.locked,
    this.minimumZoom,
    this.maximumZoom,
    this.currentZoom,
    this.supportsTap,
    this.minimumISO,
    this.maximumISO,
    this.minimumShutter,
    this.maximumShutter,
    this.currentISO,
    this.currentShutter,
    this.manualExposure,
    this.currentAperture,
    this.exposureOffset,
  });
  bool ready;
  bool front;
  String configurationId;
  double aspectRatio;
  double minimumEV;
  double maximumEV;
  double currentEV;
  bool supportsLock;
  bool locked;
  double? minimumZoom;
  double? maximumZoom;
  double? currentZoom;
  bool? supportsTap;
  double? minimumISO;
  double? maximumISO;
  double? minimumShutter;
  double? maximumShutter;
  double? currentISO;
  double? currentShutter;
  bool? manualExposure;
  double? currentAperture;
  double? exposureOffset;
}

class PhotoHandle {
  PhotoHandle({
    required this.path,
    required this.id,
    required this.unsaved,
    this.mimeType,
  });
  String path;
  String id;
  bool unsaved;
  String? mimeType;
}

class PhotoImport {
  PhotoImport({required this.photos, required this.skipped});
  List<PhotoHandle> photos;
  int skipped;
}

@HostApi()
abstract class CameraHostApi {
  @async
  CameraSnapshot start(bool front);
  void stop();
  @async
  PhotoHandle capture();
  PhotoHandle? recover();
  @async
  void save(PhotoHandle photo);
  void discard(PhotoHandle photo);
  @async
  void share(PhotoHandle photo);
  @async
  PhotoHandle? pickPhoto();
  @async
  PhotoImport pickPhotos(bool folder);
  @async
  String analyzePhoto(PhotoHandle photo);
  @async
  PhotoHandle renderEffects(PhotoHandle original, String recipe);
  @async
  PhotoHandle render(
    PhotoHandle original,
    double rotationDegrees,
    bool crop,
    double strength,
  );
  @async
  CameraSnapshot setControls(String configurationId, double ev, bool locked);
  @async
  PhotoHandle renderStyle(
    PhotoHandle original,
    List<double> matrix,
    double softness,
    double detail,
    String? watermarkPath,
  );
  @async
  PhotoHandle renderFilter(
    PhotoHandle original,
    List<double> matrix,
    List<double> parameters,
    String? watermarkPath,
  );
  void setVoicePhrase(String phrase);
  void releasePhoto(PhotoHandle photo);
  @async
  void reconcilePrivatePhotos(List<String> retainedPaths);
  @async
  CameraSnapshot setZoom(String configurationId, double zoom);
  @async
  CameraSnapshot meter(String configurationId, double x, double y);
  @async
  CameraSnapshot setManualExposure(
    String configurationId,
    double? seconds,
    double? iso,
  );
  void openSettings();
  @async
  bool setVoiceEnabled(bool enabled);
  void setDepthPreview(String configurationId, int level, String? subjectRect);
}

@FlutterApi()
abstract class CameraEvents {
  void analysis(String json);
  void state(CameraSnapshot snapshot);
  void error(String code, String message);
  void voiceShutter();
  void voiceState(bool listening, String status);
}
