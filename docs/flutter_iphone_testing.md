# Flutter Dali Camera: iPhone comparison

Use `codex/cross-platform-20261007` for the new Flutter app. It uses a separate identifier from the native reference app and requires iOS 17 or later. The existing `DaliCamera.xcodeproj` remains the reference.

## Install on a physical iPhone

On a Mac with Xcode 16.4 and Flutter 3.44.8:

```sh
git clone --branch codex/cross-platform-20261007 https://github.com/glicxu/mobile_camera.git mobile-camera-flutter
cd mobile-camera-flutter/apps/dali_camera
flutter pub get
flutter build ios --debug --no-codesign
open ios/Runner.xcworkspace
```

Select the Runner scheme and your connected iPhone. Set your development team under Signing & Capabilities, enable Developer Mode if prompted, and Run. The development bundle ID is `com.dalicamera.daliCamera`; change it locally if your team needs a unique ID. CI's unsigned app validates compilation and cannot be installed directly.

Build the reference from the root `DaliCamera.xcodeproj` with its DaliCamera scheme. When installing the native app on Alayna?s iPhone, follow the dedicated manual-signing instructions in [AGENTS.md](../AGENTS.md); that profile is for the native bundle ID and cannot sign the separate Flutter bundle. Both apps can coexist. Do not uninstall either app while it contains an unsaved original.

## Comparison needed before further calibration

Record the iPhone model, iOS version and source commit. Use the same scene and lens for both apps:

1. Start each app three times. Record time to preview and shutter readiness.
2. In portrait and both landscape orientations, frame a person near each edge. Enable the debug overlay and check that rectangles follow the visible subject. Compare both rear and front cameras.
3. Capture one photo per orientation/lens. Compare exported orientation, mirroring, visible edges and framing with the preview.
4. Select a posture, advance a cue, choose Natural, and switch lenses. Check that old advice or exposure settings do not carry over incorrectly.
5. Capture, review, compare Original/Tighter crop, save and share the selected copy. Confirm the original remains intact. Cancel the photo picker and return from the background.
6. Deny camera or Photos access, grant it in Settings, then retry. An unsaved original must survive closing and reopening the app.
7. Try exposure, lock/Auto and optional voice shutter where available. Voice recognition requires explicit permissions and on-device support.
8. Run ten minutes of preview/coaching, then capture. Note stalls, heat, response time, VoiceOver and large-text problems.

Send the model/OS, commit, failing step and a preview/output comparison when alignment differs. This evidence is needed to accept M4 and set meaningful detector and enhancement tolerances for M5.

The current Flutter build offers basic framing, tilt/stability, all 106 catalog references, recent originals, timer/burst, filters/watermark review copies, tap focus/zoom and supported manual shutter/ISO. Rich pose/face/horizon measurements, other situation modes, and native beautify/reframe/level parity remain tracked in [feature coverage](cross_platform_parity.md).

Follow the additional Food, timer/burst, filter/watermark and Manual checks in [main sync testing](cross_platform_main_sync.md#phone-test-additions).
