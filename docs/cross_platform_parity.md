# Cross-platform implementation progress

Baseline: native iOS `d53a977` (merged from remote main). Updated October 8, 2026.

The native app remains the reference for complete behavior. The new app is under `apps/dali_camera`; service code is in `packages/dali_camera_platform`. This inventory describes implemented code, with validation evidence recorded separately.

| Feature | Flutter / shared implementation | Android service | Flutter iOS service |
| --- | --- | --- | --- |
| Complete-frame preview / rotation / mirroring | Shared geometry and debug overlay | CameraX preview, rotated analysis, capture mirroring | AVFoundation rotated/mirrored outputs and preview |
| Basic live framing | Existing Dart coaching engine | Bundled ML Kit pose extent and face boxes | Vision human and face boxes |
| Camera tilt / stability | Shared rules consume explicit sensor availability | Gravity + linear acceleration; unavailable if absent | CoreMotion device motion |
| People reference catalog | All 76 references, 11 collections, cues, recipients, angles, lighting and settings | Shared assets | Shared assets |
| Landscape reference catalog | All 24 recipes, four packages, cues, angles, light and safety notes | Shared assets | Shared assets |
| Food reference catalog | All six recipes, angle, lighting, safety notes and images | Shared assets | Shared assets |
| Manual creative progression | Angle then two cues, Next/Skip/Natural, urgent framing interruption | Shared logic | Shared logic |
| Capture / original recovery | File-backed handles, busy guards, retry/discard states | Private original + atomic manifest | Private original + atomic manifest |
| Save / copy / share / photo picker | Selected file is exported, original preserved | MediaStore, scoped file sharing, document picker | Photos add-only, activity sheet, PHPicker |
| Review | Original / crop / styled copy, original comparison, fullscreen zoom, recent 25 saved originals | Native JPEG crop and style export | Core Image crop and style export |
| Named filters / watermark | Eight native preset definitions, Auto/Custom/Off, seven parameters, opt-in Dali watermark, separate selected export | Shared color matrix + spatial kernel; large styled copies sampled to at most 3200 px | Same color matrix + Core Image spatial filters |
| Timer / long press | Off/3/5/10s, cancellation on pause/lens/reference change, paced burst (up to 25), hold Timer/Disabled | Sequential original capture/save | Sequential original capture/save |
| Tap focus / zoom / manual M exposure | Active-camera capabilities, persistent tap reticle, clearable Manual preview controls, shutter/ISO, return to full Auto | CameraX metering/zoom; Camera2 MANUAL_SENSOR gate and sensor range clamp | AVFoundation point conversion/zoom/custom exposure and format range clamp |
| Exposure / focus lock | Capability-driven controls | Camera2 exposure compensation and freeze current focus/exposure when available | AVFoundation exposure compensation and lock |
| Voice shutter | Explicit opt-in, standard commands and custom whole-word phrase, countdown/capture-state guard | On-device recognition where available on API 31+ | On-device speech where available for current locale |
| Onboarding / help / accessibility | Welcome, Help, semantic labels, scrollable advice and fixed shutter | TalkBack labels; human acceptance pending | VoiceOver labels; human acceptance pending |
| Diagnostic log | Bounded instruction log, user copies it explicitly | No photos or speech transcripts in log | No photos or speech transcripts in log |
| Advanced measurement parity | Pending calibration and port of derived measurements | Single-person pose extent is not a multi-person detector; no optical horizon or scenic estimator yet | Basic adapter does not yet expose original rich pose/face/saliency/horizon pipeline |
| Full review enhancement parity | Pending | Native crop currently available; original beautify/reframe/level behavior remains to port | Native crop currently available; original beautify/reframe/level behavior remains to port |
| Situation-specific controls | People/Landscape/Food currently available | Other native situations remain to port | Other native situations remain to port |

## Validation and limitations

Validated application source: `422c212687e021737c30c8bb0153402b900672cc`, branch `codex/cross-platform-20261007`. [CI run 37741441492](https://github.com/glicxu/mobile_camera/actions/runs/37741441492) passed every job: 24 shared-core tests and analysis, three Flutter tests and analysis, catalog/asset validation, Android APK build, unsigned Flutter iOS device build, 32 native iOS unit tests, iPhone simulator bridge tests, and nine real Swift/Dart coaching fixtures. The retained reference app needed its large SwiftUI modifier expression split into smaller groups to compile reliably with Xcode 16.4; modifier order and behavior remain intact.

| Device | Verified scope | Remaining acceptance |
| --- | --- | --- |
| Samsung SM-G975U, Android 12 / API 31 | Preview dimensions, reference selection/Natural, both lenses, supported exposure/lock/Auto, stale-control rejection, capture/original save and crop-copy export; ten-minute live session | Physical edge alignment, lighting/comfort, TalkBack, thermal behavior, permission changes and actual process-death recovery |
| Samsung SM-T290, Android 11 / API 30 | Same short camera/control/export flow; rendering and recovery bridge tests | Ten-minute session and human acceptance; this is a second device tier from the same vendor |
| iPhone 16 Pro simulator, iOS 18.5 | Native JPEG rendering preserves original bytes, crop dimensions/aspect, retained-original recovery and discard; reference unit tests | Camera/sensors, voice, Photos permissions and physical iPhone comparison |

The Android bridge test also restores an AtomicFile backup left by an interrupted manifest replacement. The tablet's first test launch lost its debug connection; native bridge and full camera tests passed on retry. The phone's 600-second session observed 570 fresh one-second analysis samples and no test failures. Memory sampling during the session showed roughly 466–488 MiB total PSS and a stable native heap; this is a debug-build check, not a release FPS/thermal benchmark. Both Android devices have the normal app installed after testing.

The local ARM64 debug APK is `apps/dali_camera/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk` (about 110 MiB). SHA-256: `563298db4ebd136603168428ffe31486c6752c9fa29072872585cf10d3bbfb80`. A universal development APK is also available locally and as the CI artifact. Neither is a store release.

The catalogs are authored in Swift during coexistence. `tools/export_shared_catalog.py` exports the manifest, Dart data and Flutter images; `--check` detects metadata or asset drift. One baseline source reference exceeded the documented 100 KB limit; only the Flutter derivative is optimized, preserving the original native asset. Export requires Pillow; CI checks do not depend on platform JPEG encoder byte equivalence.

`NativeFrame` validates compact packet schema v1 and maps measurements into the existing `FrameAnalysis` contract. A successful empty detection, an unavailable detector and an unsupported sensor are distinct. Missing scenic information does not trigger a false scene-excluded correction. The old ten-pose Dart enum is retained for compatibility; the new app uses the complete shared catalog.

Android save retries use stable names to reconcile an owned gallery insertion. iOS Photos insertion has a crash window before the app can acknowledge completion; after an interrupted save, check Photos before retrying to avoid a duplicate. A saved original is not removed from private storage while the current review still needs it. Recent history now retains up to 25 saved private originals plus any unsaved recovery copy; pruning removes only owned private files after persisting the retained list. Gallery copies are preserved. Crash-window hardening and a complete derived-copy cleanup policy remain part of later parity work.

Real lighting, comfortable guidance, TalkBack/VoiceOver interaction, pixel alignment near image edges, sustained thermal behavior and the iPhone comparison require physical-device acceptance. Build success does not establish those results. Follow [Android testing](android_testing.md) and [Flutter iPhone comparison](flutter_iphone_testing.md). M4 acceptance requires the user's physical iPhone/Mac access before proceeding to M5 calibration and full enhancement parity.


## Remote main sync: d53a977

The native iOS update is merged in full; the SwiftUI modifier decomposition is retained. See [main sync inventory](cross_platform_main_sync.md) for the Flutter port and its outstanding parity items. Older validation above applies to the preceding implementation; new tests are recorded in that inventory. A merged native feature is not automatically a Flutter feature.
