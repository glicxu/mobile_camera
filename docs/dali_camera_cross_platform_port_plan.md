# Dali Camera Cross-Platform Implementation Plan

Date: October 7, 2026
Status: Ready to implement; Android application and native adapters are not implemented.
Baseline: `da72a5d` on `main`.
Targets: Android and iOS, using Flutter UI and the existing Dart core with native camera services.

## Outcome and scope

Deliver an installable Android development build first, then an equivalent Flutter-based iPhone build. Preserve the existing native iOS app throughout migration. The first Android handoff includes preview, capture, review, save/share, recovery, and basic live coaching. Full parity adds the current catalogs, camera controls, voice shutter, and enhancement workflow.

This plan replaces the earlier draft. Planned features in the product documents are not automatically part of migration: reproduce implemented behavior first. Store publication, automatic pose verification, new package recommendations, advanced manual controls, RAW/ProRAW, and new beautification features are outside this implementation scope.

Companion references: [posture packages](posture_packages.md), [landscape packages](landscape_packages.md), [camera controls](camera_control.md), and [current iPhone testing](phone_testing.md).

## Current state

| Area | Existing implementation | Remaining work |
| --- | --- | --- |
| Native app | SwiftUI, AVFoundation, Vision, CoreMotion, Photos, Core Image | Extract services for Flutter; implement Android equivalents |
| Shared core | `packages/dali_camera_core`: frame contract, coaching, geometry, guidance, recovery/export state | Update to current native behavior and establish parity fixtures |
| Shared validation | 20 Dart tests and clean analysis at the baseline review | These tests do not establish Android hardware support or full current Swift parity |
| People catalog | 76 poses across 11 collections, reference images, cues, angles, lighting and context | Dart still has the original 10 poses; migrate all current metadata and assets |
| Landscape catalog | Four packages, 24 recipes and reference images | Shared catalog and landscape UI |
| Camera controls | Runtime capabilities, exposure compensation, focus/exposure lock, reset to Auto | Shared capability contract and supported Android controls |
| Voice shutter | Apple Speech and audio session integration | Shared state/UI and Android speech adapter |
| Android application | No app project, manifest, Gradle build or APK | Scaffold, implement, build and test |
| CI | Dart and native iOS tests/builds | Flutter, Android and Flutter-iOS validation |

## Architecture decisions

- Keep coaching, catalogs, workflow state and geometry in the platform-independent Dart package.
- Put shared UI in `apps/dali_camera`. Native services belong in a local Flutter plugin at `packages/dali_camera_platform`.
- Use a generated typed bridge, initially Pigeon, for commands/results. Flutter documents this approach for structured native communication: [platform channels](https://docs.flutter.dev/platform-integration/platform-channels).
- Use Kotlin/CameraX for Android preview, analysis and capture; Swift/AVFoundation for iOS. Keep one camera-session owner per app. Do not run a second camera plugin alongside the custom session.
- Analyze live frames natively and send compact measurements to Dart. Use latest-frame backpressure and release analysis buffers promptly; CameraX documents the nonblocking strategy in [image analysis](https://developer.android.com/media/camera/camerax/analyze).
- Use a native preview surface/platform view initially. Validate transforms, overlays, gestures and performance before considering a texture implementation.
- Preserve the full-frame fit behavior. Normalize detection coordinates to the oriented, mirrored image; map that image into the letterboxed Flutter preview once.
- Keep inference on-device. Evaluate Android detector candidates against required signals and real device speed before selecting and pinning dependencies. Unsupported measurements remain explicitly unavailable.
- Keep the current iOS 17 minimum. Provisionally target Android API 26+, subject to the actual test phone and dependency validation in M0. Select compile/target SDK and pinned tooling in M0 from then-current requirements.
- Use separate development app identifiers so Flutter and native iOS builds can coexist. Do not migrate production identifiers or delete the native app in this work.

Proposed additions; existing Xcode paths remain unchanged:

```text
apps/dali_camera/
  lib/{camera,review,guidance,settings,diagnostics}/
  assets/catalog/
  test/
  integration_test/
  android/
  ios/
packages/dali_camera_core/         existing pure Dart logic
packages/dali_camera_platform/
  pigeons/
  lib/
  android/                        Kotlin services
  ios/                            Swift services
fixtures/{analysis,advice,geometry}/
docs/android_testing.md
docs/cross_platform_parity.md
```

## Platform contract and ownership

Extend the existing `FrameAnalysis` contract with backward-compatible fields where possible; version incompatible changes and preserve fixture readers.

| Contract | Required behavior |
| --- | --- |
| Session | Start/stop, lens switch, lifecycle state, permission status, structured errors, session/configuration ID |
| Preview | Image dimensions, display rotation, mirror state, fit rectangle/transform; identical mapping for overlays and taps |
| Analysis | Frame/time/session IDs, normalized detections, motion, luminance, capability and confidence states; discard stale results |
| Capture | Request ID, durable original file reference, dimensions/orientation/MIME type, capture settings and save state |
| Storage/export | Save original or selected variant, retry, share, explicit discard; return an authoritative result for each request |
| Controls | Per-camera supported ranges and lock states; reject commands calculated for an old configuration |
| Speech | Availability, consent/permission, listening/error state and recognized shutter intent; capability-dependent availability |

The native adapter owns camera resources and file I/O. Dart owns capture/review/save state and manual guidance progression. Extend the current byte-based recovery interfaces to file-backed handles for full-resolution photos; avoid repeated image copies across the bridge. Persist a capture before reporting it recoverable, keep its manifest and original together, and reconcile interrupted operations on launch. Do not delete originals on share cancellation or save failure. Define save request IDs and recovery behavior for a process crash between gallery insertion and completion acknowledgement.

## Ordered implementation milestones

All tasks below are pending unless marked as an existing foundation. Each milestone ends with a usable build or a verified artifact.

### M0 — Freeze behavior and validate dependencies

Dependencies: none.

- [ ] Inventory implemented Swift features, controls, catalog IDs and assets in `docs/cross_platform_parity.md`; distinguish implemented, planned and unsupported behavior.
- [ ] Export fixtures from the current Swift engine for issue selection, priority, cooldown, interruption, Natural mode, missing measurements and guidance replacement.
- [ ] Record current iPhone startup/capture latency and ten-minute session behavior as the performance baseline.
- [ ] Confirm available Android/iPhone test devices, OS versions and development signing setup. The Samsung SM-G975U named in the old draft is an intended test candidate, not verified hardware availability.
- [ ] Pin Flutter/Dart, JDK, Gradle, Android SDK and Xcode versions; verify compatibility with the existing Dart SDK constraint.
- [ ] Spike CameraX preview plus analysis and one capture. Evaluate detector signal coverage, bundled/offline model availability, licensing, startup and speed. Record the selected detector stack and gaps.
- [ ] Confirm native-preview composition and the typed bridge work on both platforms.

Exit: checked-in parity inventory, fixtures and dependency decisions; camera feasibility demonstrated on Android. Missing optional detector signals have explicit fallback behavior.

### M1 — Update the shared core and catalogs

Dependencies: M0 contracts and baseline fixtures.

- [ ] Port current Swift coaching changes into Dart, using identical-input fixtures to detect differences.
- [ ] Migrate all 76 people poses, 11 collections, 24 landscape recipes, angle mappings, light/context/safety metadata and stable IDs.
- [ ] Preserve current UI semantics: posture selection supplies the recommended angle; do not restore the removed standalone Angle chooser merely because the older Dart catalog has five positions.
- [ ] Establish one versioned catalog source and asset manifest. Generate or validate Swift/Dart representations during coexistence to prevent drift.
- [ ] Package the existing reference JPEGs for Flutter, preserving attribution where applicable, dimensions and the existing under-100-KB asset limit.
- [ ] Add capability/configuration models, file-backed recovery contracts and capture/export transition coverage.

Exit: shared fixture advice matches Swift for identical normalized input; catalog IDs/counts/metadata/assets validate; missing signals never produce false success; all shared tests and analysis pass.

### M2 — Build the Flutter application with replay services

Dependencies: M1 contracts; can start layout after M0.

- [ ] Scaffold `apps/dali_camera` and the local platform plugin, using separate development identifiers.
- [ ] Implement welcome, camera screen, fixed shutter, latest-photo review, photo picker, settings and permission recovery UI.
- [ ] Implement selected-photo review, original comparison, save/share status and retry/discard actions using fake services first.
- [ ] Build situation/package navigation, catalog cards and optional manually confirmed guidance with Natural/reset behavior.
- [ ] Implement accessible labels, TalkBack/VoiceOver reading order, scalable text and portrait/landscape layouts.
- [ ] Add a fixture/replay service for deterministic UI tests without camera hardware.

Exit: replay-driven capture → review → save/retry/share flows pass widget/integration tests; controls remain reachable on small screens and at large text sizes; Android and iOS shell builds succeed.

### M3 — First Android phone-testing build

Dependencies: M0 camera spike, M1 core, M2 shell.

- [ ] Bind CameraX preview, capture and analysis to lifecycle; handle permissions, background/foreground, interruptions and front/rear switching.
- [ ] Implement rotation, mirroring and fit transforms, then prove overlay alignment using edge/corner fixtures and physical photos.
- [ ] Deliver person/face measurements and motion/roll to Dart for basic framing, crop, tilt and stability advice; report unsupported signals explicitly.
- [ ] Capture to durable app storage, restore unsaved captures after process death, and implement MediaStore save, system photo selection and sharing with OS-appropriate permissions.
- [ ] Connect duplicate-capture guards, retry/error states and direct latest-photo review. Verify exported originals remain intact.
- [ ] Export user-initiated diagnostic logs with device/build/session information, avoiding photo payloads by default.
- [ ] Produce a debug APK and `docs/android_testing.md` with installation, permissions, feature coverage and known limitations.

Exit: APK installs on a physical Android phone; capture → review → save/share works; failed save recovery survives relaunch; lens/orientation changes remain aligned; ten minutes of use does not crash, stall or grow queues without bound. Advanced enhancement and voice parity are not required for this first handoff and must be labeled unavailable.

### M4 — Connect the Flutter iOS app

Dependencies: stable M3 contract and M2 UI.

- [ ] Extract camera, analysis, motion and persistence services from `CameraModel.swift` without moving/removing the existing Xcode project.
- [ ] Adapt Vision/CoreMotion measurements into the shared contract and route coaching through Dart in the Flutter app.
- [ ] Connect Photos/picker/share, original recovery, session lifecycle and permissions to the shared workflow.
- [ ] Preserve capture settings, orientation, mirror semantics and stale-result protections.
- [ ] Run the Flutter app beside the native reference using separate identifiers; compare behavior on the same device and fixtures.

Exit: Flutter iOS capture/review/export and basic coaching pass device acceptance with no unexplained baseline regression. The original iOS app continues to build and run.

### M5 — Close current feature gaps on both platforms

Dependencies: M3 and M4; prioritize gaps using the parity inventory.

- [ ] Complete landscape and people guidance, group/pose/face measurements, luminance/backlighting and horizon behavior where supported.
- [ ] Separate true visual-horizon estimates from sensor roll; never substitute one silently for the other.
- [ ] Port current reframe, level, compare and beautify behavior behind an image-processing interface. Agree fixture-based visual tolerances; retain original by default and export exactly the selected variant.
- [ ] Implement capability-driven exposure compensation, focus/exposure lock and return to Auto. Hide or explain unavailable controls and invalidate stale settings after a camera change.
- [ ] Port voice shutter with opt-in microphone/speech access, cancellation, deduplication and capture-state guards. Declare on-device speech availability; do not silently fall back to remote recognition.
- [ ] Complete current logging/settings behavior and synchronize all catalog assets/metadata.

Exit: every implemented feature in the baseline parity inventory is passed or explicitly capability-limited with tested fallback. Planned RAW, additional manual controls and automatic recommendations remain separate future work.

### M6 — Validate and hand off both platforms

Dependencies: M5.

- [ ] Add CI for Dart analysis/tests, Flutter analysis/widget tests, Android native tests/debug APK, Flutter iOS simulator tests and unsigned device build. Keep native iOS checks during migration.
- [ ] Run changes on PRs and `main`, replacing the current restriction that only runs push validation on the phone-readiness branch pattern.
- [ ] Run device acceptance on the primary iPhone, primary Android and a second Android vendor/device tier. Use small-screen emulators for layout coverage.
- [ ] Verify camera denial/re-enable, save failure/storage exhaustion, process death, share cancellation, rapid taps, rotation during capture, repeated lens changes and session interruption.
- [ ] Validate TalkBack/VoiceOver, large text, comfortable optional pose guidance and ten-minute performance/thermal behavior.
- [ ] Record exact source SHA, device/OS matrix, passing checks, known limitations and APK/install instructions. Sign iPhone builds with the user's development team; an unsigned build is not an installable IPA.

Exit: both apps are ready for user phone testing with reproducible builds and no unresolved capture-loss, permission-recovery or preview-alignment defects. Retirement of the native SwiftUI app requires a later acceptance decision and is not automatic.

## Test strategy and performance gates

| Layer | Evidence required |
| --- | --- |
| Core parity | Identical normalized fixtures yield matching issue/recipient/instruction and scheduler transitions in Swift/Dart |
| Detector calibration | Annotated images and device scenes establish per-signal tolerances; raw confidence/landmarks need not be identical across engines |
| Geometry | Four rotations, both lenses, differing aspect ratios, preview margins, corner targets and exported orientation |
| Workflow | Injected disk/gallery failures, duplicate actions, interrupted saves and relaunch recovery; original and selected export bytes/images checked |
| UI | Replay-based navigation, catalogs, comparison, permissions and accessibility layouts |
| Device | Real sensor/camera alignment, audio interruption, permissions, gallery output, performance and thermal behavior |

Initial engineering targets, to confirm in M0: 30 FPS preview on reference devices; basic analysis around 10 Hz with adaptive throttling; visible shutter feedback within 200 ms; no unbounded frame/result queues. Record startup and capture-completion median/p95 rather than equating shutter feedback with file-save latency. Investigate regressions above 20% against the iPhone baseline under matched conditions; document justified exceptions before acceptance. No promise of detector equivalence or performance is established by desktop unit tests.

## Risks and responses

| Risk | Response |
| --- | --- |
| Swift/Dart drift while iOS continues development | Freeze a baseline, require shared catalog validation, and update parity fixtures with behavior changes |
| Android hardware/detector variability | Capability model, explicit missing measurements, reference devices and calibration before changing shared thresholds |
| Flutter/native preview mismatch | One transform contract, physical edge checks and one camera owner |
| Original loss or duplicate export after a crash | Durable manifest, request IDs, fault-injection tests and startup reconciliation |
| Large-image memory pressure | File-backed handles, native processing and bounded preview/analysis buffers |
| Speech unavailable/offline unsupported | Visible unavailable state; manual shutter stays usable |
| Migration grows into new product development | M3 first Android handoff; parity limited to implemented baseline features |

## Starting work order

1. Create the M0 parity inventory and baseline fixture exporter.
2. Pin the toolchain and validate the Android camera/bridge spike.
3. Update the shared catalogs and coaching tests.
4. Scaffold replay-based Flutter capture/review screens.
5. Connect Android storage/camera services and deliver the M3 APK.
6. Add the iOS adapter, complete parity, then run the two-platform acceptance matrix.

Track completion with the milestone checkboxes and evidence links. Calendar estimates should follow the M0 camera/detector spike and available device access; no unsupported delivery date is assumed here.
