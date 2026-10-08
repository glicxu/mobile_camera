# Remaining iOS-to-Flutter Porting Plan

Date: October 8, 2026
Status: Comprehensive source/action audit and software corrections in progress. Parity is not complete.
Branch: `codex/cross-platform-20261007`
Reference: native iOS app at `d53a977`. Starting Flutter source: `be9c765`.

Current per-action contract: [comprehensive source/action audit](cross_platform_action_audit.md). Its destinations and state transitions supersede the historical aggregate checks below. Current software additions: lazy Photos library, native beautifier dropdown/disclosures, image labels/fullscreen, actual lens metadata and active pose swipes. Device and final iOS validation are running.

## Comprehensive implementation run ? October 8, 2026

The user found that the Manual workspace still did not match iOS. The previous aggregate ?connected? status was insufficient: working services and passing tests did not establish complete screen/action parity. This run follows the complete P0?P8 plan below, using reachable native views and actions as the reference. Software omissions stay open until implemented and verified; physical comparison is a separate acceptance step.

Current corrections: compact Focus/Depth/Exposure preview rail and mutually exclusive editors; focus-only Manual tapping and separate exposure-Auto/full-Auto resets; session-only depth; native Camera controls sections including Beautifier; named filter fine-tuning; automatic review treatment updates and Reset; review navigation/action hierarchy; native preview coaching light/direction cues, countdown/burst overlays and watermark; direct reference selection with separate examples and adjacent posture navigation; tutorial illustrations. Analyzer and 21 Flutter tests pass at the initial correction checkpoint. Device/build validation follows after the library work.

Additional audit gap: the lower-left native button browses all accessible system Photos with lazy loading. Flutter only opened a private latest capture/picker. Library listing, lazy loading, permission/limited-access fallback and wrap navigation are being ported next. Do not label P1/P7 complete while that destination differs.

The remaining physical iPhone/screenshots, cross-engine rendering tolerances, permission/audio/accessibility scenarios, second Android vendor and ten-minute release performance sessions remain P8 acceptance work. Source helpers that are never called (`proExposureControls`, Auto-assistance card/lock bindings) do not establish an implemented reference screen; retain supported service capabilities without inventing reference UI.

| Phase | Implementation status | Verification / remaining acceptance |
| --- | --- | --- |
| P0 | Reference behavior and defaults inventoried | Updated [UI inventory](cross_platform_ui_inventory.md); matched physical screenshots pending |
| P1 | **In progress:** native header (Manual/coaching/App Settings/switch), seven-step tutorial, landscape sidebar, three selection controls, contextual packages, montages, details, navigation and large-text layouts implemented | Widget navigation checks; physical typography/spacing comparison pending |
| P2 | Eight situations, stable Auto classification, issue selection and creative guidance implemented | Nine baseline, 24 transition and 150 rich native coaching fixtures pass |
| P3 | Face/pose/group geometry, luminance, saliency and optical horizon connected | 16 native pose fixtures pass; Android uses multi-face group coverage and single-body pose. Matched real-scene calibration pending |
| P4 | Separate Filter/Beautifier modes, seven filter controls, Enhance/Portrait/Landscape, strengths/presets/options and capture sequence implemented | Immutable original/full-resolution bridge checks; Android cross-engine visual tolerances pending |
| P5 | Reference subject-region depth preview and saved feathered blur implemented | Not semantic segmentation; front/rear depth edges and low-tier performance need joint testing |
| P6 | **In validation:** native Manual rail/editors and linked ISO, actual aperture, metering/locks/zoom, settings and persistent voice preference implemented | Capability-gated controls; Android live exposure-offset meter unavailable. Native Tv/Av requires the reference's disabled iOS 27 compile gate and is outside the Xcode 16.4 baseline |
| P7 | **In progress:** system Photos browser plus Before/After/Split with zoom, analysis, reframe/level and polish, slideshow, imports, exports and cleanup implemented | Photos max 20; folder max 50 intentionally retained. Treatment settings are global in the reference, not persisted per photo. Save/share/recovery checks included |
| P8 | App Settings/About/version/native placeholder sections, Help, semantics, automated checks and test instructions updated | Physical iPhone, matched visual comparison, accessibility/audio/permission cases and longer thermal sessions remain acceptance work |

Header correction: the user identified an omitted native header flow in the earlier parity candidate. The implementation now includes the coaching toggle and App Settings/tutorial, keeps camera controls beside the shutter, and guards shutter/voice capture while these screens are presented. Local analyzer and 19 Flutter tests pass, including large-text portrait/landscape navigation. Tablet (107 seconds) and Galaxy (44 seconds) full camera flows pass with the corrected header. Both normal apps are updated without clearing data, with installed hashes verified. Shared checks and Android/unsigned iOS builds pass; The clean-boot run subsequently failed at Flutter VM-service discovery; current CI validation is tracked below.

Read [joint phone testing](cross_platform_joint_testing.md) for the acceptance order and [Mac/iPhone setup](cross_platform_iphone_checkpoint.md) for signing/install steps. External posture/landscape package loading with image instructions is a future product feature; folder import currently opens photos for this review session.

Known limits: Android saliency is a color-contrast estimator, horizon is a gradient-line estimator and skin/blur/filter rendering differs from Core Image. Availability is explicit and manual capture remains available. iOS simulator body pose may be unavailable; independent detector failures do not disable the other treatments. An iOS Photos commit followed by process death before private pending-state completion can still produce a duplicate on retry because add-only permission cannot reconcile gallery identity; the original remains recoverable. No gallery deletion is used for private cleanup.

### Historical implementation checkpoints

## Current checkpoint — October 8, 2026

Active full-parity run: review analysis and Original/Reframe/Level/Enhance/Portrait/Landscape treatments are now connected to the file-backed backends. Separate Filter/Beautifier choices, Both actions, capture/review strength and option settings, capture processing order and preferences are implemented. Shared pose geometry has 35 passing tests; Flutter analysis and 13 tests pass locally. Android split APK compilation passes. A new Mac CI fixture comparison covers 16 native pose geometry cases; results are pending.

Live iOS analysis now supplies face landmarks, pose measurements and luminance/open-area signals. Android live pose joints and multi-face group scope now reach shared coaching. Depth preview uses the reference's expanded subject region: iOS material overlay and a bounded Android blurred preview overlay. Voice preference persists independently from current listening state, resumes with the camera and receives native status events. These additions still require physical checks; they are not accepted parity yet.

Android still processing now includes landmark-protected skin processing and guarded eye/lip geometry, native reframe crop dimensions and an image-gradient horizon estimator. Android rendering tolerances, saliency/scenic coverage, horizon calibration and depth edges remain outstanding. The original iOS backend CI compiled and passed the 51 native tests but its new bridge test failed because body-pose Vision cannot initialize on that simulator. Independent per-detector availability now prevents this optional failure from disabling all treatments; rerun is required.

Source audit corrections: the reference keeps treatment settings globally, not per-photo, and its live depth is a rounded subject-region material overlay, not semantic segmentation. Tv/Av priority is behind `DALI_IOS27_EXPOSURE`; the pinned Xcode baseline does not enable it. Manual linked ISO and actual aperture/exposure metadata remain to be ported. Keep these distinctions in acceptance checks instead of advertising unavailable hardware capabilities.

| Phase | Status | Evidence / next work |
| --- | --- | --- |
| P0 | In progress | [Initial UI/defaults audit](cross_platform_ui_inventory.md); physical reference screenshots and exhaustive action inventory still pending |
| P1 | In progress | Three selection controls before guidance; all situation choices; filter menu/settings; montage cards, native descriptions, angle/light reference grid; extracted widgets. Twelve local Flutter tests pass, including landscape/large-text import access. Physical styling and all Effects actions remain pending |
| P2 | In progress | Shared scene rules, three-frame Auto classifier, ambiguous hold, active-guidance freeze, scene resets, Action/Close-up Auto filters; real Swift transition comparison in CI. Full coaching fixtures/calibration pending |
| P3 | In progress | iOS full-body rectangles, saliency and optical horizon; group geometry and motion tracker; explicit availability. Android multi-person/scenic pipeline and richer face/pose analysis pending |
| P4 | In progress | Native iOS filter sequence/coefficients through the typed bridge. Android rendering approximation and full Enhance/Beautify remain pending |
| P5/P6 | Pending | Live depth/beautification and richer exposure/voice/settings parity remain pending |
| P7 | In progress | Previous/next/swipe review; multiple-photo and folder import up to 50; private byte-preserving copies, isolated selection navigation and cleanup; pending-original guard. Rich treatments/analysis and per-photo settings remain pending |
| P8 | In progress | Galaxy S10+ camera, rendering and real import checks pass; full Android/iPhone parity acceptance is outstanding |

The attached Galaxy S10+ disconnected before device validation of this increment. The Samsung SM-T290 passed the updated camera integration flow in 66 seconds, including package browsing, Food selection, controls, timer/style, review/export, and burst. Its first attempt failed at camera readiness after a permission reset; rerun passed with camera permission granted. No physical iPhone validation is available in this Windows workspace.

Installation incident: Flutter's integration runner encountered a lower universal APK version than the previously installed ABI-split APK and automatically uninstalled the tablet app. This cleared private app data/settings; gallery photos are separate. An initial Gradle-property isolation probe also failed before APK-identity validation was added. The final Windows helper builds a separate `com.dalicamera.dali_camera.test` app and verifies its actual APK identity with aapt before invoking Flutter. Normal updates use only `adb install -r`, with no uninstall fallback. Use disposable private test data for integration tests and `adb install -r` for normal updates. The normal UI build is restored after testing.

Earlier P1 normal ARM64 debug APK (superseded by subsequent builds): `apps/dali_camera/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, SHA-256 `57efd5f929d87d598ffcf7f8f3d58b92d3c29849bd37b3f1b37d534cc671e620`. Installed on the tablet with `adb install -r`; build and tests are local evidence, not physical iPhone or CI acceptance. This supersedes the earlier APK for this UI checkpoint only.

Current code checkpoint: `16aac8f`. Local shared analysis/33 tests and Flutter analysis/eight tests pass. The isolated tablet camera flow passes (81 seconds), followed by the extended native bridge suite including the new filter API (19 seconds). The normal APK was rebuilt and updated using `adb install -r`: SHA-256 `15930f49d0272f0902b931c3eec32eec4cc6100f64836bfa282ec097d1ba59e9`, package `com.dalicamera.dali_camera`, version code 2001. These checks do not establish full detector/rendering parity. The new UI, classifier and Vision requests need the [physical Mac/iPhone checkpoint](cross_platform_iphone_checkpoint.md) before calibration can be accepted.

A ninth local Flutter regression check also passes: capture routes the situation-specific Auto filter parameters to the typed bridge, and a failed filter render retains the saved original while manual capture remains available. The Mac/iPhone comparison is requested from the user, who will run it locally.

[CI run 37818899173](https://github.com/glicxu/mobile_camera/actions/runs/37818899173) passed all jobs for production source `16aac8fb710a88f8573f362a8bd676c31432756f`: catalog validation, shared analysis/33 tests, Flutter analysis/eight tests, Android APK build, unsigned iOS device build, 51 native iOS unit tests, iPhone simulator bridge checks, nine native coaching fixtures and 24 native situation-transition fixtures. The ninth Flutter regression test was added and verified locally after this run's source checkpoint. Physical iPhone comparison and Galaxy phone validation remain pending; successful CI does not close the remaining phases.

## Goal and completion rules

### Follow-up import increment

Product decision (October 8, 2026): keep folder import visible in Flutter. The native iOS reference exposes its folder button only in Debug; this Flutter difference is now intentional and should not be reverted as a parity fix. The user identified a future use: posture/landscape packages distributed separately from the app, with instructions attached to their images. The current folder importer opens session-scoped review images; it does not install reference packages or attach coaching instructions.

For a future external-package implementation, define a versioned package manifest linking each image to its title, posture/composition instructions, camera angle, lighting guidance and relevant safety notes. Validate image references and required instructions before adding a package to the reference chooser. Package installation, persistence and management need a separate implementation plan; this decision retains the current feature without treating package loading as implemented.

Multiple-photo and folder selection now use the platform pickers through a typed `PhotoImport` response. Imported files remain separate from captured history. Review navigation wraps within the imported selection; cancellation and provider failure preserve the current selection. Returning to the camera, opening captured history, or replacing an import releases private imported copies and derived files. Source files are copied without JPEG recompression. Folder scanning is bounded to 4,096 entries and 16 nested levels, with up to 50 images imported in filename order. Flutter analysis and all 12 tests pass locally; Android APK compilation passes. Imports are session-scoped; treatment persistence and process-death cleanup/recovery remain pending.

The Galaxy S10+ (SM-G975U, Android 12) reconnected and passed the isolated camera integration flow (33 seconds) and native rendering bridge suite (2 seconds). Real system-picker checks on the normal app passed: a three-image folder, wrap navigation, cancellation retaining the selected third image, two-photo selection, an unreadable file skipped while three valid images opened, and private-copy cleanup on return to camera. SHA-256 hashes of all three imported copies matched the repository source files. Temporary public sample files were removed after testing. iOS physical picker behavior remains pending in the Mac checklist.

The follow-up normal ARM64 APK is `apps/dali_camera/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, SHA-256 `bea9d4b227dc9a4451a92194edd1d43c9337aba57689dd3870f8df9f0085c384`. It includes the scrollable import sheet and its landscape/large-text regression check, added after production source `0371814`. Normal installations use `adb install -r` without deleting user data.

[CI run 37821907275](https://github.com/glicxu/mobile_camera/actions/runs/37821907275) passed all jobs for import source `0371814ee6966459592e916b26d5084fa9523039`: shared/catalog checks, Flutter analysis/11 tests, Android APK build, unsigned iOS build, native iOS unit tests, coaching/situation fixture comparisons and iPhone simulator rendering bridge checks. The scrollable-sheet follow-up passes local analysis, all 12 Flutter tests and Android builds. Its normal APK was installed successfully on both the Galaxy S10+ and SM-T290 using `adb install -r`. System-picker interaction was physically verified on Android, not in the iPhone simulator. The user will run physical iPhone comparisons locally; P0/P3 calibration and P4/P5 visual acceptance still require those results.

Make the Flutter Android and iOS apps match the implemented native iOS product in screen structure, navigation, settings, coaching, capture, effects, and review. Start with the visible camera-screen differences reported during Android testing.

The current Android build is a working partial port. A successful merge, build, or automated test does not establish UI or feature parity. Mark an item complete only when its implementation and acceptance evidence are recorded. A hardware-limited item needs a verified capability check, a truthful user-facing fallback, and an explanation in the coverage inventory. An unimplemented software feature remains pending.

This plan supersedes the remaining-work order and outdated scope exclusions in the [original migration plan](dali_camera_cross_platform_port_plan.md). Use [current coverage](cross_platform_parity.md) and the [main sync inventory](cross_platform_main_sync.md) as starting evidence, not as proof of full parity. New native-main changes must be inventoried separately before updating this frozen reference.

## What is already available

Keep the working preview, capture/original recovery, save/share, basic coaching, catalogs, timer/burst, voice commands, recent originals, watermark, tap focus, zoom, and capability-gated manual shutter/ISO. The shared catalog already contains 76 people references in 11 packages, 24 landscape recipes in four packages, and six Food recipes. Catalog content being present does not mean its browsing UI matches iOS.

Android filters approximate the native render using a color matrix and spatial processing. iOS now uses the native Core Image filter sequence; physical comparison is pending. Current effects appear in review copies. Enhancement, beautification, subject-region depth and rich review are now connected; see the current table for acceptance limits.

## Ordered implementation phases

The current table above records implementation progress. The original checklists below combine implementation with acceptance: an unchecked item remains open where matched physical evidence is still required; it does not override an explicitly tracked software omission.

### Full-parity implementation run (October 8, 2026)

The user requested implementation of all remaining parity features before joint testing. Physical comparison is deferred to that joint test; it is not a reason to stop independent software work. Retain visible folder import by the accepted product decision above.

Typed still-analysis and recipe-rendering commands, generated iOS reference processing engines with drift validation, and Android full-resolution processing are implemented and connected to the UI. Android optical horizon/saliency, guarded feature geometry and native reframe rules are implemented. Cross-engine visual and matched-scene detector calibration remain physical acceptance tasks; see the current coverage table and joint testing record.

Source audit corrects the earlier P5 assumptions: native preview uses a material overlay around a subject region (`OverlayView.swift`, `DigitalDepthOfFocusOverlay`), and saved-photo depth uses a feathered rounded region (`BeautifyEngine.swift`, `DepthBlurEngine`). The baseline does not implement live semantic segmentation or live Filter/Beautify rendering. Match these actual behaviors; semantic segmentation is not an additional parity requirement.

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
- [ ] Add Android equivalents for required multi-person/group signals, pose landmarks, face landmarks/analysis, face and background luminance/backlighting, scenic composition, optical horizon, and subject bounds and saliency geometry (semantic segmentation is not in this baseline).
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

Dependencies: P3 subject-region geometry and P4 effect definitions. The native baseline does not require semantic segmentation.

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

- [ ] Match native slideshow/swipe navigation, multiple-photo and folder import where supported, per-photo selection, global treatment settings, and comparison modes.
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
