# Cross-platform implementation progress

Baseline: native iOS `da72a5d`. Updated October 7, 2026.

The native app remains the reference for complete behavior. The new app is under `apps/dali_camera`; service code is in `packages/dali_camera_platform`. This inventory describes implemented code, with validation evidence recorded separately.

| Feature | Flutter / shared implementation | Android service | Flutter iOS service |
| --- | --- | --- | --- |
| Complete-frame preview / rotation / mirroring | Shared geometry and debug overlay | CameraX preview, rotated analysis, capture mirroring | AVFoundation rotated/mirrored outputs and preview |
| Basic live framing | Existing Dart coaching engine | Bundled ML Kit pose extent and face boxes | Vision human and face boxes |
| Camera tilt / stability | Shared rules consume explicit sensor availability | Gravity sensor; unavailable if absent | CoreMotion device motion |
| People reference catalog | All 76 references, 11 collections, cues, recipients, angles, lighting and settings | Shared assets | Shared assets |
| Landscape reference catalog | All 24 recipes, four packages, cues, angles, light and safety notes | Shared assets | Shared assets |
| Manual creative progression | Angle then two cues, Next/Skip/Natural, urgent framing interruption | Shared logic | Shared logic |
| Capture / original recovery | File-backed handles, busy guards, retry/discard states | Private original + atomic manifest | Private original + atomic manifest |
| Save / copy / share / photo picker | Selected file is exported, original preserved | MediaStore, scoped file sharing, document picker | Photos add-only, activity sheet, PHPicker |
| Review | Original / tighter crop, original comparison, fullscreen zoom | Native JPEG crop export | Core Image crop export |
| Exposure / focus lock | Capability-driven controls | Camera2 exposure compensation and freeze current focus/exposure when available | AVFoundation exposure compensation and lock |
| Voice shutter | Explicit opt-in, capture-state guard | On-device recognition where available on API 31+ | On-device speech where available for current locale |
| Onboarding / help / accessibility | Welcome, Help, semantic labels, scrollable advice and fixed shutter | TalkBack labels; human acceptance pending | VoiceOver labels; human acceptance pending |
| Diagnostic log | Bounded instruction log, user copies it explicitly | No photos or speech transcripts in log | No photos or speech transcripts in log |
| Advanced measurement parity | Pending calibration and port of derived measurements | Single-person pose extent is not a multi-person detector; no optical horizon or scenic estimator yet | Basic adapter does not yet expose original rich pose/face/saliency/horizon pipeline |
| Full review enhancement parity | Pending | Native crop currently available; original beautify/reframe/level behavior remains to port | Native crop currently available; original beautify/reframe/level behavior remains to port |
| Situation-specific controls | People/Landscape currently available | Other native situations remain to port | Other native situations remain to port |

## Validation and limitations

Local shared-core analysis and 24 tests pass. Flutter controller/layout tests cover failed save and restoration, stale-session rejection, and large-text control access. Physical Samsung SM-G975U / Android 12 tests passed preview startup, selection of a pose, Natural reset, rear/front switching, capture/save, and crop-copy export on an earlier candidate. Tests are rerun as the adapters change.

The first CI candidate compiled Android and unsigned Flutter iOS successfully. Its catalog check failed because the original source checksum depended on Windows line endings; the exporter now normalizes source text and verifies original and exported asset checksums separately. Final evidence will be added after the current candidate is validated.

The catalogs are authored in Swift during coexistence. `tools/export_shared_catalog.py` exports the manifest, Dart data and Flutter images; `--check` detects metadata or asset drift. One baseline source reference exceeded the documented 100 KB limit; only the Flutter derivative is optimized, preserving the original native asset. Export requires Pillow; CI checks do not depend on platform JPEG encoder byte equivalence.

`NativeFrame` validates compact packet schema v1 and maps measurements into the existing `FrameAnalysis` contract. A successful empty detection, an unavailable detector and an unsupported sensor are distinct. Missing scenic information does not trigger a false scene-excluded correction. The old ten-pose Dart enum is retained for compatibility; the new app uses the complete shared catalog.

Android save retries use stable names to reconcile an owned gallery insertion. iOS Photos insertion has a crash window before the app can acknowledge completion; after an interrupted save, check Photos before retrying to avoid a duplicate. A saved original is not removed from private storage while the current review still needs it. Full storage-retention policy and crash-window hardening remain part of later parity work.

Real lighting, comfortable guidance, TalkBack/VoiceOver interaction, pixel alignment near image edges, sustained thermal behavior and the iPhone comparison require physical-device acceptance. Build success does not establish those results.
