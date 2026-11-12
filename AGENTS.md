# Dali Camera agent notes

## Android Play testing from Rainier

- Package: `com.dalifin.camera`; use the existing `internal` testing track.
- Publisher credentials: `C:/Users/glicx/.config/google-play/dalifin-play-publisher.json`.
- The existing Camera upload certificate matches the shared Dalifin key configured
  in `B:/src/workspaces/mobile_app/interprete/android/key.properties`. Resolve its
  `storeFile` relative to that project's `android/app` directory. Read passwords
  into the build process environment; never print or commit them.
- Expected upload certificate SHA-256:
  `3F:6B:34:90:27:DF:2B:54:18:89:92:9B:17:8F:50:54:8B:CF:3F:08:8C:1B:01:D1:6F:05:64:BF:71:F9:8F:3D`.
  Dali Audio's separately stored upload key does not match Camera.
- Supply the four `DALI_ANDROID_UPLOAD_*` variables required by
  `apps/dali_camera/android/app/build.gradle.kts`, and leave
  `DALI_ANDROID_TEST_APP` unset for Play builds.
- Query Play before choosing the Android build number. Its history includes
  `2026101301`, so the smaller shared iOS/pubspec build number is not the Android
  release default. Pass an explicit unused, increasing `--build-number` and
  `--target lib/main.dart` to `flutter build appbundle --release`.

## Installing on Alayna's iPhone

Do not rely on automatic signing for this phone. Automatic signing may select the generic `iOS Team Provisioning Profile: com.dalifin.camera`, which currently excludes Alayna's device and causes installation error `0xe8008012` (the provisioning profile cannot be installed on this device).

Known device and signing values:

- Device: `Alayna's iPhone` (iPhone 13 Pro)
- Device UDID: `00008110-000909522246801E`
- Bundle identifier: `com.dalifin.camera`
- Development team: `33W2562W9S`
- Signing identity: `Apple Development: GANG LI (S3SPY2JQ5R)`
- Provisioning profile name: `Dali Camera Alayna Dev 20261004`
- Provisioning profile UUID: `93e00eb1-b0c0-4a9f-a455-b77c83cec3a5`
- Cached profile: `~/Library/Developer/Xcode/UserData/Provisioning Profiles/93e00eb1-b0c0-4a9f-a455-b77c83cec3a5.mobileprovision`
- Profile expiration: October 4, 2027

First confirm that the intended phone is available:

```sh
xcrun devicectl list devices
```

Build with manual signing and explicitly pin the Alayna profile:

```sh
xcodebuild \
  -project DaliCamera.xcodeproj \
  -scheme DaliCamera \
  -configuration Debug \
  -destination 'id=00008110-000909522246801E' \
  -derivedDataPath /tmp/dali-camera-alayna-profile-build \
  DEVELOPMENT_TEAM=33W2562W9S \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='Apple Development' \
  PROVISIONING_PROFILE_SPECIFIER='Dali Camera Alayna Dev 20261004' \
  PROVISIONING_PROFILE=93e00eb1-b0c0-4a9f-a455-b77c83cec3a5 \
  build
```

Install and verify:

```sh
xcrun devicectl device install app \
  --device 00008110-000909522246801E \
  /tmp/dali-camera-alayna-profile-build/Build/Products/Debug-iphoneos/DaliCamera.app

xcrun devicectl device info apps \
  --device 00008110-000909522246801E \
  --bundle-id com.dalifin.camera
```

If the profile is missing or expired, do not switch silently to another device or profile. Report that the dedicated Alayna profile must be restored or regenerated.

## Flutter physical review-return testing

Use profile mode on Alayna's iPhone. For `flutter drive`, pass `--keep-app-running` so test cleanup does not uninstall the production bundle and reset its permissions. The test binary must then be replaced with a fresh normal build using `flutter build ios --profile --target lib/main.dart` before handing the phone back. Never install the shared build artifact after an integration test without rebuilding the normal entry point.

`apps/dali_camera/integration_test/review_return_test.dart` checks that iOS's native preview remains actively displaying and its attachment count stays unchanged across three photo-review return cycles. Coaching analysis events are not a measure of preview readiness.
