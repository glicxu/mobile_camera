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
  PhotoHandle render(
    PhotoHandle original,
    double rotationDegrees,
    bool crop,
    double strength,
  );
  @async
  CameraSnapshot setControls(String configurationId, double ev, bool locked);
  void openSettings();
  @async
  bool setVoiceEnabled(bool enabled);
}

@FlutterApi()
abstract class CameraEvents {
  void analysis(String json);
  void state(CameraSnapshot snapshot);
  void error(String code, String message);
  void voiceShutter();
}
