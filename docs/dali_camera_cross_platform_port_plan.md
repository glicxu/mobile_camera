# Dali Camera Cross-Platform Port Plan

**Status:** Draft for review
**Primary target:** iOS and Android
**Recommended application framework:** Flutter
**Companion docs:** `docs/dali_camera.md`, `docs/dali_camera_implementation_plan.md`
**Purpose:** Move Dali Camera to a shared application architecture while preserving native-quality camera, detection, sensor, and image-processing behavior.

---

## 1. Objective

Create an Android version without building and maintaining two independent products.

The port should:

- keep the current iOS prototype usable during migration,
- share coaching behavior, application state, UI, logging, and tests,
- retain native camera performance and reliable on-device analysis,
- produce comparable measurements and advice on iPhone and Android,
- allow most future product work to be implemented once.

The target steady-state code split is:

| Area | Target share |
|---|---:|
| Shared Flutter/Dart application code | 70-80% |
| iOS-specific code | 10-15% |
| Android-specific code | 10-15% |

These percentages describe the end-state architecture. Existing Swift code will mostly be translated or adapted rather than copied directly.

---

## 2. Recommended Architecture

Use Flutter for the shared application, with thin native adapters for camera and analysis work that benefits from platform APIs.

```text
                    Shared Flutter/Dart
+----------------------------------------------------------+
| screens, overlays, coaching, state, review, and logging  |
| models, thresholds, configuration, diagnostics, and tests|
+----------------------------+-----------------------------+
                             | typed platform contract
              +--------------+--------------+
              |                             |
       iOS native adapter            Android native adapter
       AVFoundation                  CameraX
       Vision                        ML Kit / MediaPipe
       CoreMotion                    SensorManager
       Core Image                    GPU/image pipeline
       Photos                        MediaStore
```

The shared engine must consume normalized measurements rather than platform framework objects. Neither `VNObservation` nor Android detector types should cross the adapter boundary.

---

## 3. Shared And Native Boundaries

### Shared Flutter/Dart

- normalized geometry and measurement models,
- photography issue definitions,
- coaching rules, thresholds, ranking, hysteresis, and cooldowns,
- pose-package definitions and advice text,
- capture and review state machines,
- camera overlay rendering,
- configuration and debug screens,
- session logging schema and export orchestration,
- fixture replay and deterministic tests,
- localization and accessibility behavior,
- product analytics events, if added later.

### Native On iOS

- AVFoundation session and photo capture,
- Vision person, face, landmark, pose, and horizon analysis,
- CoreMotion sampling,
- Core Image processing where required,
- Photos permission and save operations,
- conversion from Vision coordinates to the normalized contract.

### Native On Android

- CameraX preview, image analysis, and photo capture,
- ML Kit or MediaPipe person, face, landmark, and pose analysis,
- SensorManager motion sampling,
- GPU or Android image-processing implementation,
- MediaStore permission and save operations,
- conversion from Android detector coordinates to the normalized contract.

---

## 4. Platform Contract

The first shared artifact should be a versioned `FrameAnalysis` contract. All coordinates use the visible preview frame:

```text
x: 0.0 left -> 1.0 right
y: 0.0 top  -> 1.0 bottom
```

Proposed top-level shape:

```text
FrameAnalysis
  schemaVersion
  frameId
  timestamp
  imageWidth
  imageHeight
  displayRotationDegrees
  lensFacing
  mirrored
  people[]
  faces[]
  poseKeypoints{}
  groupAnalysis?
  faceAnalysis?
  horizon?
  luminance?
  openAreaRatio?
  motion
  detectorStatus{}
```

Each detected value should carry a confidence when the underlying API provides one. Missing and unsupported measurements must be explicit; they must not be represented as valid zero values.

The contract should support JSON serialization for recorded fixture replay, while the live bridge may use a lower-overhead typed codec.

---

## 5. Migration Strategy

Use an incremental replacement rather than rewriting the complete iOS app before Android can run.

### Phase 0: Baseline And Contracts

Goal: freeze the behavior that the port must preserve.

- record representative `Measurements`, issues, and selected advice,
- convert current coaching tests into platform-neutral fixture cases,
- define `FrameAnalysis` and coordinate conventions,
- document front-camera mirroring and device-rotation rules,
- capture basic performance and thermal baselines on an iPhone.

Acceptance criteria:

- fixture data covers every current issue type,
- expected advice is deterministic,
- the contract distinguishes unavailable, low-confidence, and valid values.

### Phase 1: Shared Dart Engine

Goal: move portable behavior into a standalone, camera-independent Dart package.

- port models from `Models.swift`,
- port `CoachingEngine.swift`, thresholds, and pose packages,
- port session event schemas,
- port unit tests and fixture replay,
- compare Dart output with current Swift output.

Acceptance criteria:

- shared tests cover every existing coaching rule,
- Swift and Dart select the same top issue and advice for the baseline fixtures,
- the shared package has no Flutter or platform dependencies.

### Phase 2: Flutter Application Shell

Goal: reproduce the core capture experience using shared UI.

- create Flutter navigation, configuration, and capture state,
- implement advice cards and debug overlay,
- implement review-mode controls,
- connect the UI to a fake/replay camera adapter first,
- preserve the native iOS app as a reference implementation.

Acceptance criteria:

- fixture replay drives a complete coaching session,
- overlay alignment is testable at multiple aspect ratios,
- the application remains useful without a live native adapter.

### Phase 3: Android Vertical Slice

Goal: get a phone-testable Android build quickly without porting every advanced feature.

- CameraX preview and back/front switching,
- camera permission and lifecycle handling,
- person and face detection,
- basic pose points,
- motion and camera roll,
- normalized measurement delivery to Dart,
- shared advice overlay,
- still capture and MediaStore save.

Initial Android issue coverage:

- subject missing,
- too close or too far,
- headroom,
- edge cropping,
- camera tilt,
- camera stability,
- ready state.

Acceptance criteria:

- installs and runs on the Samsung test phone,
- preview and overlay remain aligned through rotation and camera switching,
- sustained analysis is usable for at least ten minutes,
- no camera frames are sent off-device.

### Phase 4: iOS Adapter Under Flutter

Goal: connect the shared app to the proven iOS measurement stack.

- wrap the existing AVFoundation session,
- adapt Vision results into `FrameAnalysis`,
- connect CoreMotion and photo capture,
- move remaining SwiftUI flows to Flutter,
- compare with the original prototype before retiring it.

Acceptance criteria:

- current iOS prototype capabilities remain available,
- baseline fixtures produce equivalent advice,
- camera startup, capture latency, and thermal behavior do not regress materially.

### Phase 5: Feature Parity And Tuning

Goal: close detector and image-processing gaps.

- horizon behavior,
- luminance and backlighting,
- group analysis,
- open-area/scenic heuristics,
- reframe and level suggestions,
- beautification pipeline,
- log export and saved-photo review.

Tune platform-specific measurement calibration before changing shared coaching thresholds. A detector difference should not silently become a product-rule difference.

---

## 6. Proposed Repository Shape

Keep migration work in this repository so fixtures and behavior stay synchronized.

```text
mobile_camera/
  app/                         Flutter application
    lib/
      camera_contract/
      coaching/
      capture/
      review/
      diagnostics/
    test/
    integration_test/
    android/                   Android native adapter
    ios/                       iOS native adapter
  fixtures/
    frame_analysis/
    expected_advice/
  legacy_ios/                  current Swift prototype during migration
  docs/
```

The exact move of the existing Xcode project should happen only after the Flutter shell builds successfully. Until then, leave the current paths intact.

---

## 7. Testing Strategy

### Shared Tests

- one unit test per issue type,
- priority conflict tests,
- confidence and missing-data tests,
- hysteresis and cooldown tests using a fake clock,
- pose-package override tests,
- JSON contract compatibility tests,
- golden overlay tests for common aspect ratios.

### Native Adapter Tests

- coordinate normalization,
- mirroring and rotation,
- detector result conversion,
- permission denial and recovery,
- camera lifecycle interruption,
- still capture and save failure handling.

### Cross-Platform Parity Tests

Run recorded fixtures through both platforms and compare normalized outputs within documented tolerances. Advice should match even when raw detector confidences differ slightly.

### Device Matrix

Start with:

- the current iPhone development device,
- Samsung SM-G975U,
- one newer mid-range Android device before release,
- one small-screen iPhone and one small-screen Android emulator for UI checks.

---

## 8. Performance Budgets

Initial targets:

| Operation | Target |
|---|---:|
| Camera preview | 30 FPS minimum |
| Lightweight detection | 10-15 FPS |
| Heavier pose analysis | 5-10 FPS |
| Advice refresh | 1-5 Hz |
| Capture button response | under 200 ms perceived latency |
| Native-to-Dart analysis payload | bounded; latest frame wins |

The bridge must use backpressure. If Dart is busy, native analysis should replace an old unpublished result rather than queueing frames indefinitely.

---

## 9. Key Risks And Mitigations

### Detector Differences

Vision and Android detectors will not return identical landmarks or confidence values.

Mitigation: normalize semantics in native adapters, use tolerance-based parity tests, and calibrate measurements per platform before applying shared rules.

### Preview Coordinate Errors

Crop mode, rotation, mirroring, and device aspect ratio can misalign overlays.

Mitigation: make preview transforms part of the contract and build visual fixtures for each rotation and lens direction.

### Real-Time Performance

Sending full camera frames through Flutter can cause memory pressure and latency.

Mitigation: analyze frames natively and send only compact normalized results to Dart.

### Migration Scope

Rebuilding every review and beautify feature before testing Android would delay useful feedback.

Mitigation: deliver the Android vertical slice before parity work, while keeping the native iOS prototype available.

### Rule Drift

Maintaining Swift, Dart, and temporary Android rules simultaneously can produce different behavior.

Mitigation: establish Dart as the single rule implementation during Phase 1 and use the original Swift engine only as a parity oracle until migration completes.

---

## 10. Open Decisions

- Android vision stack: ML Kit, MediaPipe, or a combination.
- Native bridge implementation: Flutter platform channels, Pigeon, or a custom plugin API.
- Whether live horizon detection ships in the first Android slice.
- Cross-platform beautification implementation and acceptable visual differences.
- Minimum supported Android API and iOS version.
- Whether saved-photo analysis should precede or follow live Android analysis.
- App identifiers, signing, store configuration, and release channels.

Recommended early defaults:

- use Pigeon or another generated typed contract,
- use CameraX for Android capture,
- evaluate ML Kit first for face detection and MediaPipe for pose,
- defer beautification parity until the live coaching slice is proven,
- keep all production inference on-device.

---

## 11. First Working Milestone

The first milestone should produce an installable Android development build that:

1. opens a CameraX preview,
2. detects one person and face,
3. reports normalized measurements,
4. runs the shared Dart coaching engine,
5. displays one stable instruction at a time,
6. draws aligned debug boxes,
7. switches front and back cameras,
8. captures and saves a photo,
9. exports a diagnostic session log.

Advanced pose coaching, reframe comparison, beautification, and full review-mode parity are explicitly outside this first milestone.

---

## 12. Immediate Next Steps

1. Approve the Flutter-plus-native-adapters architecture.
2. Decide the minimum supported Android and iOS versions.
3. Add baseline fixture JSON generated from current Swift measurements.
4. Define the versioned `FrameAnalysis` schema.
5. Scaffold the shared Dart engine and port the existing coaching tests.
6. Scaffold the Flutter app using replay data.
7. Build the Android CameraX adapter and install the vertical slice on the Samsung test phone.
