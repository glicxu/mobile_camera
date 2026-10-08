# Remaining iOS-to-Flutter Porting Plan

Date: October 8, 2026  
Status: Implementation started; P0/P1/P2/P3/P4/P7 are in progress; physical iPhone comparison is the next acceptance dependency. Remaining work is not complete.  
Branch: `codex/cross-platform-20261007`  
Reference: native iOS app at `d53a977`. Starting Flutter source: `be9c765`.

## Current checkpoint — October 8, 2026

| Phase | Status | Evidence / next work |
| --- | --- | --- |
| P0 | In progress | [Initial UI/defaults audit](cross_platform_ui_inventory.md); physical reference screenshots and exhaustive action inventory still pending |
| P1 | In progress | Three selection controls before guidance; all situation choices; filter menu/settings; montage cards, native descriptions, angle/light reference grid; extracted widgets. Nine local Flutter tests pass. Physical styling and all Effects actions remain pending |
| P2 | In progress | Shared scene rules, three-frame Auto classifier, ambiguous hold, active-guidance freeze, scene resets, Action/Close-up Auto filters; real Swift transition comparison in CI. Full coaching fixtures/calibration pending |
| P3 | In progress | iOS full-body rectangles, saliency and optical horizon; group geometry and motion tracker; explicit availability. Android multi-person/scenic pipeline and richer face/pose analysis pending |
| P4 | In progress | Native iOS filter sequence/coefficients through the typed bridge. Android rendering approximation and full Enhance/Beautify remain pending |
| P5/P6 | Pending | Live depth/beautification and richer exposure/voice/settings parity remain pending |
| P7 | In progress | Previous/next/swipe review, pending-original guard, failed-render selected-copy preservation. Multi-import, rich treatments/analysis and per-photo settings remain pending |
| P8 | Pending | Current automated checks cover the first UI increment; full Android/iPhone acceptance is outstanding |

The attached Galaxy S10+ disconnected before device validation of this increment. The Samsung SM-T290 passed the updated camera integration flow in 66 seconds, including package browsing, Food selection, controls, timer/style, review/export, and burst. Its first attempt failed at camera readiness after a permission reset; rerun passed with camera permission granted. No physical iPhone validation is available in this Windows workspace.

Installation incident: Flutter's integration runner encountered a lower universal APK version than the previously installed ABI-split APK and automatically uninstalled the tablet app. This cleared private app data/settings; gallery photos are separate. An initial Gradle-property isolation probe also failed before APK-identity validation was added. The final Windows helper builds a separate `com.dalicamera.dali_camera.test` app and verifies its actual APK identity with aapt before invoking Flutter. Normal updates use only `adb install -r`, with no uninstall fallback. Use disposable private test data for integration tests and `adb install -r` for normal updates. The normal UI build is restored after testing.

Earlier P1 normal ARM64 debug APK (superseded by subsequent builds): `apps/dali_camera/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, SHA-256 `57efd5f929d87d598ffcf7f8f3d58b92d3c29849bd37b3f1b37d534cc671e620`. Installed on the tablet with `adb install -r`; build and tests are local evidence, not physical iPhone or CI acceptance. This supersedes the earlier APK for this UI checkpoint only.

Current code checkpoint: `16aac8f`. Local shared analysis/33 tests and Flutter analysis/eight tests pass. The isolated tablet camera flow passes (81 seconds), followed by the extended native bridge suite including the new filter API (19 seconds). The normal APK was rebuilt and updated using `adb install -r`: SHA-256 `15930f49d0272f0902b931c3eec32eec4cc6100f64836bfa282ec097d1ba59e9`, package `com.dalicamera.dali_camera`, version code 2001. These checks do not establish full detector/rendering parity. The new UI, classifier and Vision requests need the [physical Mac/iPhone checkpoint](cross_platform_iphone_checkpoint.md) before calibration can be accepted.

A ninth local Flutter regression check also passes: capture routes the situation-specific Auto filter parameters to the typed bridge, and a failed filter render retains the saved original while manual capture remains available. The Mac/iPhone comparison is requested from the user, who will run it locally.

[CI run 37818899173](https://github.com/glicxu/mobile_camera/actions/runs/37818899173) passed all jobs for production source `16aac8fb710a88f8573f362a8bd676c31432756f`: catalog validation, shared analysis/33 tests, Flutter analysis/eight tests, Android APK build, unsigned iOS device build, 51 native iOS unit tests, iPhone simulator bridge checks, nine native coaching fixtures and 24 native situation-transition fixtures. The ninth Flutter regression test was added and verified locally after this run's source checkpoint. Physical iPhone comparison and Galaxy phone validation remain pending; successful CI does not close the remaining phases.

## Goal and completion rules

Make the Flutter Android and iOS apps match the implemented native iOS product in screen structure, navigation, settings, coaching, capture, effects, and review. Start with the visible camera-screen differences reported during Android testing.

The current Android build is a working partial port. A successful merge, build, or automated test does not establish UI or feature parity. Mark an item complete only when its implementation and acceptance evidence are recorded. A hardware-limited item needs a verified capability check, a truthful user-facing fallback, and an explanation in the coverage inventory. An unimplemented software feature remains pending.

This plan supersedes the remaining-work order and outdated scope exclusions in the [original migration plan](dali_camera_cross_platform_port_plan.md). Use [current coverage](cross_platform_parity.md) and the [main sync inventory](cross_platform_main_sync.md) as starting evidence, not as proof of full parity. New native-main changes must be inventoried separately before updating this frozen reference.

## What is already available

Keep the working preview, capture/original recovery, save/share, basic coaching, catalogs, timer/burst, voice commands, recent originals, watermark, tap focus, zoom, and capability-gated manual shutter/ISO. The shared catalog already contains 76 people references in 11 packages, 24 landscape recipes in four packages, and six Food recipes. Catalog content being present does not mean its browsing UI matches iOS.

Android filters approximate the native render using a color matrix and spatial processing. iOS now uses the native Core Image filter sequence; physical comparison is pending. Current effects appear in review copies. Advanced beautification, depth, complete situation guidance, and the full native review workflow are not ported.

## Ordered implementation phases

### P0 — Freeze a screen and behavior inventory

Dependencies: none.

- [ ] Enumerate every implemented menu, settings section, screen, action, default, persisted value, and transition in `DaliCamera/ContentView.swift` and `Models.swift`.
- [ ] Record matching iOS screenshots for camera, all three selection controls, package browsing, capture settings, manual controls, review, and onboarding/help. Obtain physical iPhone evidence on the Mac; use deterministic replay states for repeatable Flutter screenshots.
- [ ] Expand the coverage inventory into rows for individual behaviors, with reference source, Flutter status, Android/iOS availability, and evidence links.
- [ ] Specify detector contracts and rendering outputs required by later phases. Distinguish planned native features from features actually implemented at the frozen reference.

Acceptance: every reference action has a tracked destination or an explicit pending entry. Existing fixture matches are labeled with their actual scope; they do not substitute for the complete inventory.

### P1 — Match the camera screen and navigation

Dependencies: P0 UI inventory. Implement this first; richer detection and rendering can follow.

- [ ] Match the iOS hierarchy: viewport and overlays, selection row directly below the viewport, guidance/status, and capture controls. Match spacing, typography, selected values, icons, and menu behavior while retaining readable platform-appropriate controls.
- [ ] Replace the People/Landscape/Food chip arrangement with the three iOS-style controls described below.
- [ ] Match package browsing: package overview cards/montages, package detail reference grid, selected-reference indication, reference details, and return navigation. Preserve reference-driven camera angles, lighting, and safety notes.
- [ ] Match latest-photo access, settings/help placement, guidance Next/Skip/Natural actions, and Manual workspace visibility behavior.
- [ ] Extract camera, selection, catalog, settings, and review widgets from the large Flutter screen so subsequent parity work can be reviewed independently.

| Control below viewport | Required behavior |
| --- | --- |
| Situation | Show current selection and all native choices: Auto, Portrait, Group, Person + Scene, Landscape, Action, Close-up, Food. Preserve native ordering and selection semantics. |
| Effects | Match quick Both Auto/Both Off choices and separate Filter/Beautifier Auto/Custom/Off selections. Connect working filters immediately; Beautifier actions remain explicitly unavailable until P4 supplies processing. Do not mark this control complete while those actions are placeholders. |
| Posture / Landscape / Food | Follow the native active-situation visibility rules and selected-reference/Natural label. Open the corresponding package/recipe flow. Match the native behavior for Auto and Close-up rather than forcing a third button where the reference does not show one. |

Acceptance: side-by-side screenshots and interaction checks confirm the camera structure and package flow. Both Android devices, small-screen layouts, landscape orientation, and large text retain reachable controls without overflow. Opening a menu does not disrupt preview or capture. P1 layout can be delivered independently, but full Effects parity depends on P4/P5.

### P2 — Port situations, coaching, and shared state

Dependencies: P0 contracts; connect to P1 controls.

- [ ] Replace the two scene booleans with explicit situation and active-situation models matching native semantics. Port Auto classification, stability/hysteresis, per-situation guidance, overlays, and reference-reset behavior.
- [ ] Port situation-specific angle choices and guidance without reintroducing a standalone angle picker absent from the reference flow.
- [ ] Port the remaining native issue selection, priorities, cooldowns, interruptions, recipient selection, missing-measurement handling, and manual creative progression into Dart.
- [ ] Export fixtures from the frozen Swift reference for all eight situations, classifier transitions, guidance replacement, Natural, missing signals, and urgent framing interruptions.
- [ ] Define which choices persist across restart and which reset on lens, situation, reference, lifecycle, or review transitions; match native behavior.

Acceptance: identical normalized inputs produce the same advice and transitions in Swift and Dart. Situation selections affect behavior, rather than only labels. Unsupported measurements never yield invented corrections or a false ready state. Physical guidance acceptance waits for P3 calibration.

### P3 — Complete detection and measurement services

Dependencies: P0 contract and P2 rule requirements.

- [ ] Reuse/extract the reference Vision/CoreMotion pipeline in the Flutter iOS service, preserving the separate native app and one camera-session owner.
- [ ] Add Android equivalents for required multi-person/group signals, pose landmarks, face landmarks/analysis, face and background luminance/backlighting, scenic composition, optical horizon, and subject/saliency segmentation.
- [ ] Evaluate Android detector coverage, offline operation, model size, licensing, and speed before pinning additional dependencies. Record per-signal limitations and tested fallbacks.
- [ ] Extend the typed bridge with confidence, availability, timestamps, session/configuration IDs, and normalized geometry. Keep large frames and segmentation buffers native.
- [ ] Calibrate against annotated images and matched physical scenes across front/rear cameras, rotation, skin tones, low light, groups, and partial subjects. Keep optical horizon distinct from device roll.
- [ ] Bound analysis queues, discard stale results, and schedule expensive analysis/effects without blocking preview or shutter feedback.

Acceptance: calibrated tolerances and supported-signal tables are recorded. Physical overlays align at edges and corners; group behavior is not inferred from a single-person bounding box. Detector outputs may differ across engines, but downstream guidance must meet the agreed scene acceptance cases.

### P4 — Port still-photo effects and enhancement

Dependencies: P0 rendering inventory; P3 landmarks/masks for subject-aware operations.

- [ ] Expose the existing iOS filter, Enhance, and Beautify engines through the Flutter iOS service. Preserve filter operation ordering, presets, parameter ranges, defaults, Auto choices, and watermark placement.
- [ ] Implement Android equivalents for temperature/tint, vibrance, shadows/highlights, noise reduction, clarity, and the remaining native filter operations; replace the current color-matrix approximation where it is insufficient.
- [ ] Port General Enhance, Portrait Polish, and Landscape Polish with native strength levels/presets and individual settings. Include landmark-aware face brightness, skin/blemish processing, feature geometry, and landscape/sky treatment implemented by the reference.
- [ ] Match separate Filter and Beautifier Auto/Custom/Off state, Both Auto/Both Off actions, settings persistence, and capture-time application behavior.
- [ ] Define and preserve the native processing order between filters, polish, geometry adjustments, and watermark. Render from an immutable original; key results by source and settings so stale work cannot replace a newer selection.
- [ ] Address the current Android derivative resolution limit. Test a full-resolution processing path within a measured memory budget; any remaining limitation must be visible and recorded rather than silently presented as parity.

Acceptance: approved fixture images cover all presets and strengths, faces/no faces, sky/no sky, low light, and watermark on/off. Record visual tolerances before accepting Android equivalents; exact cross-engine bytes are not required. Off preserves original appearance, failed processing preserves the original, and save/share exports the selected result.

### P5 — Port live effects and depth

Dependencies: P3 segmentation/landmarks and P4 effect definitions.

- [ ] Inventory the actual native live-preview effect path and match its supported effect/settings behavior in both services.
- [ ] Implement subject-aware depth/background blur, masking, edge handling, and the reference's preview-versus-capture behavior. Avoid representing a whole-frame blur as depth.
- [ ] Keep preview and overlays on one geometry transform; synchronize masks with their source frame and reject stale masks after lens/session changes.
- [ ] Implement capability/performance fallback states and release rendering resources on pause, review, or camera changes. Manual capture remains available during processing failure.

Acceptance: physical front/rear-camera tests demonstrate stable subject edges, correct mirroring/rotation, and no delayed masks after switching cameras. Compare live appearance with saved output and the reference. Meet measured performance targets; record lower-tier-device limitations explicitly.

### P6 — Complete camera controls, settings, and voice behavior

Dependencies: P0 control inventory; may run before P4/P5 once shared contracts are stable.

- [ ] Match manual/Auto workspace layout, Auto entry state, shutter/ISO changes, lock interactions, reset behavior, and displayed actual camera values.
- [ ] Port implemented Tv/Av priority, linked ISO, exposure meter/recommendations, and aperture behavior when supported by the active camera and OS/SDK. Keep fixed apertures informational; do not simulate adjustable hardware or advertise unavailable priority modes.
- [ ] Verify EV, focus/exposure lock, tap metering, zoom, capture setting retention, and lens-specific capability refresh under concurrent actions and lifecycle interruptions.
- [ ] Match voice preference versus actual listening state, foreground resumption policy, audio interruptions, custom phrase persistence, command deduplication, and permission/error messaging. Retain on-device-only availability behavior.
- [ ] Match remaining implemented settings/defaults and help text. Hardware focus distance, custom white balance, RAW, and other reference roadmap features enter this plan only if implemented in the frozen baseline.

Acceptance: supported commands change actual sensor behavior, observed values agree with capture metadata, unsupported commands are unavailable, and stale commands are rejected. Both camera backends return completely to Auto. Voice/timer/burst cannot bypass pending-save or capture guards.

### P7 — Complete review, import, and storage workflows

Dependencies: P3 still-image analysis and P4 processed variants; navigation can start after P1.

- [ ] Match native slideshow/swipe navigation, multiple-photo and folder import where supported, per-photo selection/settings, and comparison modes.
- [ ] Port complete original/reframe/level/enhance/beautify treatment selection, strength controls, analysis/status cards, pose/lighting summaries, and diagnostic details from the reference.
- [ ] Preserve full-resolution originals, orientation and mirror semantics. Keep review progress and exports associated with the correct photo during rapid navigation and processing.
- [ ] Harden interrupted save reconciliation, recent-history retention, pending-original recovery, derived-copy cleanup, and disk-full behavior. Document the iOS Photos crash window and tested duplicate-avoidance limits.
- [ ] Match save/share/copy output selection and cancellation/error/retry messaging. Folder access must use each platform's supported picker and permission model.

Acceptance: review navigation, imports, comparisons, and selected exports match the reference. Injected processing/storage failures and process death do not lose originals, export another photo, or delete gallery content. Multi-photo work remains bounded in memory.

### P8 — Close acceptance gaps and deliver phone builds

Dependencies: preceding phases complete or explicitly hardware-limited with accepted evidence.

- [ ] Update onboarding/help, semantics, reading order, focus behavior, large text, and TalkBack/VoiceOver for the final UI.
- [ ] Run meaningful core parity, geometry, rendering, widget, bridge, and failure/recovery checks in CI; continue building/testing the native iOS reference.
- [ ] Compare native iOS and Flutter iOS on the same physical iPhone using the Mac. Test Android on the attached Galaxy S10+ and tablet, plus a second vendor when available; record any device coverage still missing.
- [ ] Exercise denied/re-enabled permissions, background/foreground and audio interruption, repeated lens changes, rapid captures, rotation, share cancellation, process death, and storage failures.
- [ ] Measure startup, shutter feedback, capture/processing completion, preview/analysis throughput, memory, and thermal behavior in matched ten-minute sessions. Establish a physical iPhone baseline; the existing Android debug soak is not a release performance guarantee.
- [ ] Record source SHA, device/OS matrix, screenshot comparisons, test evidence, limitations, APK checksum, and Mac/iPhone install steps. Reinstall final Android builds without clearing user data.

Acceptance: no unresolved original-loss, wrong-export, preview-alignment, or permission-recovery defects. Every baseline feature is implemented and verified, or has a documented hardware limitation with working fallback. UI comparison is explicitly signed off during user testing. Keep the native iOS app available until a separate retirement decision.

## Implementation locations

| Area | Starting source / destination |
| --- | --- |
| Screen/menu/review reference | `DaliCamera/ContentView.swift`, `DaliCamera/Models.swift` |
| Native measurements and camera behavior | `DaliCamera/CameraModel.swift` and its engine dependencies |
| Native effects | `DaliCamera/EnhanceEngine.swift`, `DaliCamera/BeautifyEngine.swift`, reference filter/depth code located during P0 |
| Shared UI and state | `apps/dali_camera/lib/main.dart`, `camera_controller.dart`, `capture_settings.dart`; extract focused widgets/services as phases proceed |
| Shared models/coaching/catalogs | `packages/dali_camera_core` |
| Typed commands and native services | `packages/dali_camera_platform/pigeons`, `lib`, `android`, `ios`; regenerate bridge bindings after contract changes |
| Evidence and coverage | `docs/cross_platform_parity.md`, tests/fixtures, Android and Flutter iPhone testing guides |

## Delivery checkpoints

1. **UI comparison build:** P0/P1 layout and navigation, with working current features and explicit unfinished effects. Install on Android for early visual feedback; this is not full parity.
2. **Situation/coaching build:** P2/P3, with calibrated guidance and replay evidence.
3. **Effects and review build:** P4/P5/P7, with visual fixture comparisons and safe selected exports.
4. **Parity candidate:** P6 and all remaining checks complete; physical Android and iPhone acceptance in P8.

Work continues on the separate cross-platform branch. Do not retire the native app, change production identifiers, publish stores, or treat this planning document as authorization to claim completed parity. No delivery date is assigned before the detector/rendering investigation and physical iPhone baseline. Update this document and coverage evidence at each checkpoint.
