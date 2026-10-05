# Dali Camera: iPhone testing

## Build to test

Use the `codex/phone-readiness-20261004` branch. The shared Xcode scheme is **DaliCamera**. The app supports iOS 17 or later.

On a Mac with Xcode installed, use a fresh checkout if your existing checkout has unrelated changes:

```sh
git clone --branch codex/phone-readiness-20261004 https://github.com/glicxu/mobile_camera.git mobile_camera-phone-test
cd mobile_camera-phone-test
open DaliCamera.xcodeproj
```

1. Connect your iPhone and enable Developer Mode if Xcode requests it.
2. Choose the **DaliCamera** scheme and your iPhone as the destination.
3. Under the app target's **Signing & Capabilities**, select your Apple development team. Automatic signing is enabled. If your team cannot use the existing bundle identifier, change it to a unique identifier.
4. Press **Run**. Grant camera access. Dismiss the short welcome sheet.

The CI device build is unsigned. Install through Xcode with your own signing team; the CI artifact is not a directly installable IPA.

## What changed

- The preview shows the complete camera frame, with black margins where needed. Overlay geometry uses that same frame instead of stretching detections over a cropped preview.
- Portrait, landscape, and front-camera mirroring are coordinated across preview, analysis, and capture. Vision receives already-oriented frames.
- Camera guidance and shutter controls have separate space. Advice scrolls on smaller screens and at larger text sizes; the shutter stays outside that scroll region.
- The latest thumbnail opens photo review. Review supports comparison, saving the selected version as a copy, and sharing.
- Unsaved captured originals have retry, share, Settings, and explicit discard controls, plus local recovery on relaunch.
- People Coach includes 10 optional poses and five camera positions. Creative steps are confirmed manually; the app does not claim to detect that a pose has been completed.
- Debug detection boxes and detailed measurements are off by default. Enable **Configure > Debug overlay** only when inspecting alignment.

## Ten-minute first pass

| Test | Expected result |
| --- | --- |
| Photograph one person with the rear camera | Preview is upright; capture saves and updates the thumbnail. |
| Turn the phone to both landscape orientations | Preview stays upright and controls remain reachable. |
| Switch to the front camera | Preview, detection boxes, and saved selfie use consistent mirroring. |
| Enable Debug overlay and move a person near each edge | Person/face boxes follow the visible image, including the margins. |
| Tap the latest thumbnail | That photo opens directly without searching the library. |
| Select an enhancement, compare, Save a copy, then Share | The output matches the selected preview and the original is preserved. |
| Open Poses & angles | Five masculine and five feminine examples and all five camera positions are available. |
| Start a pose with a camera position | Camera steps precede subject steps; Done / Next or Skip advances one step. |
| Remove the subject during guidance, then return them | Framing advice interrupts; the same uncompleted creative step resumes. |
| Choose Natural or a different sequence | The old creative instruction does not persist. |

## Recovery and accessibility checks

- Deny camera access, tap **Open Settings**, grant access, and return. The camera should recover without restarting the app.
- Deny Photos access on a capture. The original should remain available to share or retry. Close and relaunch the app: the unsaved original should be recovered.
- After granting Photos access, retry saving. Check Photos for the original before discarding any recovery copy.
- Cancel a share sheet. The original must remain available.
- Tap the shutter rapidly. The app must not start overlapping capture/save operations or overwrite an unsaved original.
- Background and foreground the app from the camera and photo review. Review should remain open; the camera should resume when you return to it.
- Increase text size and enable VoiceOver. Verify Help, Configure, Switch camera, Take photo, latest-photo review, variant selection, comparison, Save a copy, and Share.
- Try seated, walking, and over-shoulder poses. Skip anything uncomfortable. These are optional style prompts, not body-quality judgments.

## Automated checks

The **Phone readiness** GitHub Actions workflow builds the app, runs native unit/UI tests on an iPhone simulator, builds for physical iPhone without signing, and checks the Dart core. Test bundles and simulator screenshot attachments are uploaded as artifacts.

On a Mac, select **Product > Test** in Xcode to run the shared scheme. The simulator has no usable camera feed; shutter readiness and real Photos/camera behavior are part of the device checks above.

The Dart core can also be checked locally:

```sh
cd packages/dali_camera_core
dart pub get
dart analyze
dart test
```

The Dart package includes coaching, guidance, preview geometry, and an adapter-based photo recovery workflow. It is not a separate Flutter/Android camera app.

## Reporting a problem

Record the iPhone model, iOS version, front/rear camera, phone orientation, selected pose/position, and exact steps. A screenshot or short screen recording is useful. For coaching issues, enable Debug overlay and use Share Log; review its contents before sharing it.

Actual camera alignment, lighting quality, save permissions, VoiceOver interaction, and pose comfort still require the phone pass. Simulator and core tests cannot establish those real-world results.
