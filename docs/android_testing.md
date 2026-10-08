# Dali Camera: Android testing

The Flutter application is `apps/dali_camera`, separate from the native Xcode application. Android API 26+ is the current minimum; first device validation uses Samsung SM-G975U on Android 12. Flutter 3.44.8 / Dart 3.12.2, JDK 21, AGP 9.0.1, Gradle 9.1.0, compile/target SDK 36, Kotlin 2.3.20 and CameraX 1.5.3 are the initial toolchain.

## Build and install

```sh
cd apps/dali_camera
flutter pub get
flutter build apk --debug
adb -s YOUR_DEVICE_ID install -r build/app/outputs/flutter-apk/app-debug.apk
```

APK: `apps/dali_camera/build/app/outputs/flutter-apk/app-debug.apk`.
App identifier: `com.dalicamera.dali_camera`.

For a smaller download on the tested Samsung devices, use `app-arm64-v8a-debug.apk` in the same directory. Generate device-specific APKs with `flutter build apk --debug --split-per-abi`.

Open Dali Camera, dismiss Welcome and grant camera access. Android 10+ does not require broad gallery-read access to save this app's photos. Android 8/9 asks for storage permission when saving; denied access retains the original for retry. The system photo picker grants access to the selected file only.

For the physical iPhone comparison, see [Flutter iPhone testing](flutter_iphone_testing.md). For Flutter iOS, run `flutter build ios --debug --no-codesign` on a Mac, then open `apps/dali_camera/ios/Runner.xcworkspace`, select your signing team and iPhone, and Run. An unsigned CI build cannot be installed directly.

## First pass

1. Confirm rear-camera preview is upright and the shutter works even without a person detected.
2. Switch front/rear, rotate both ways, and enable Debug overlay. Confirm boxes follow visible subjects near every edge. Android currently uses a single-person pose extent, not the original iOS multi-person rectangle detector.
3. Capture a photo. Confirm it appears in Photos under Pictures/Dali, and compare saved orientation/mirroring with the preview.
4. Review Original and Tighter crop, compare with original, zoom fullscreen, save the selected version, then share. The original must remain unchanged.
5. Open Posture packages and select references from several of the eleven collections. Camera angle is supplied by the reference. Next and Skip advance manually; Natural clears the sequence.
6. Choose Landscape and try Mountains, Lakes, Plains and Plants. Read the light and location notes. Optical horizon detection is not yet available in the new adapters; sensor tilt is labeled camera tilt.
7. Adjust exposure, use lock when reported available, and return to Auto. Change cameras with a control sheet open and confirm stale settings cannot be applied.
8. Enable voice shutter only if you want microphone access. On-device speech depends on OS/device/locale availability. Unsupported devices keep manual capture available.
9. Deny camera access, open Settings, grant it, and return. Cancel a photo picker and confirm the live camera resumes.
10. Test larger text, TalkBack, background/foreground, rapid shutter taps and ten minutes of continuous use.

When a save fails, share/retry/discard actions stay attached to the original. To check relaunch recovery, leave an original unsaved, close the app and open it again. Do not uninstall or clear app storage while testing recovery: Android deletes private originals in that case.

## Automated checks

```sh
cd packages/dali_camera_core
dart pub get
dart analyze
dart test
cd ../../apps/dali_camera
flutter analyze
flutter test
flutter test integration_test/bridge_test.dart -d YOUR_DEVICE_ID
flutter test integration_test/phone_test.dart -d YOUR_DEVICE_ID
```

The phone integration test takes real photos for timer/style, original/crop and a short burst, leaving the gallery copies in Pictures/Dali. It expects camera permission already granted. Flutter's test runner may uninstall the test app afterwards; reinstall the normal debug APK for manual use. The Windows helper prepares permissions and reinstalls the normal app after tests:

Run the helper from the repo root with `./tools/test_android_camera.ps1 -DeviceId YOUR_DEVICE_ID -SoakSeconds 600` for a ten-minute live-analysis check. Use `-Flutter` to supply the Flutter executable when it is not on PATH. The test also checks supported exposure/lock controls and rejects settings from an old camera configuration.

CI publishes an Android debug APK and validates the Flutter iOS build, native bridge, shared tests, catalogs and Swift/Dart baseline fixtures. See [feature coverage and remaining parity work](cross_platform_parity.md). Report device/OS, lens, orientation, selected reference, exact steps and whether the output or preview is wrong.

## Main sync additions

Food recipes, recent-photo history, timer/burst, filters/watermark and supported tap focus/zoom/manual shutter/ISO are included. Follow [the additional acceptance steps and parity limits](cross_platform_main_sync.md).
