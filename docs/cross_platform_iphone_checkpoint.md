# Mac/iPhone checkpoint: situations, selection row and filters

Status: physical comparison required. This checkpoint validates the port foundation; it does not claim completed Beautifier/depth, advanced exposure, or rich review parity.

Use branch `codex/cross-platform-20261007`. The native comparison baseline is `d53a977`. Keep both apps installed and preserve any unsaved originals. Flutter uses a separate bundle ID, `com.dalicamera.daliCamera`.

## Build on your Mac

Use a separate checkout so your existing native app workspace is preserved:

```sh
git clone --branch codex/cross-platform-20261007 https://github.com/glicxu/mobile_camera.git mobile-camera-flutter-checkpoint
cd mobile-camera-flutter-checkpoint
git rev-parse HEAD
flutter --version
xcodebuild -version
cd apps/dali_camera
flutter pub get
flutter build ios --debug --no-codesign
open ios/Runner.xcworkspace
```

The validated toolchain is Flutter 3.44.8 and Xcode 16.4, targeting iOS 17+. In Xcode choose Runner, select your connected iPhone, set your development team, and Run. The unsigned build is a compile check; Xcode supplies device signing. The Alayna native-app profile in [AGENTS.md](../AGENTS.md) applies only to `com.dalifin.camera`, not Flutter.

If using an existing checkpoint checkout, preserve local changes, fetch the branch, and use `git pull --ff-only`. Do not reset your existing native workspace to install this app.

## Checks to report

Use the same iPhone, lens, lighting and scene in Flutter and the native reference. Record model, iOS version, source SHA, and any failing step. Begin with rear camera, then repeat geometry/mirroring checks with front camera.

| Check | Expected / evidence needed |
| --- | --- |
| Selection row | Situation, Effects and contextual Posture/Landscape/Food sit below the viewport. All eight situations can be selected. Close-up hides the reference control, following the native visibility rules. Report remaining layout/navigation differences. |
| Auto | Hold a single-person scene steady, then a group and a clear close-up. Auto requires three consecutive candidate frames, retains an ambiguous scene, and pauses while creative reference guidance is active. Report native versus Flutter classification and transition differences. |
| Group | Frame at least two people, then move one near an edge or obscure a face. Check visible-face, edge and spacing guidance against native. Single-person pose analysis is not accepted as group coverage. |
| Action | Track a moving person with a steady phone, then shake the phone. Check the movement/steadiness guidance. Missing motion samples should show waiting guidance, not a false ready result. |
| Landscape | Use a clear visible horizon and gently rotate the phone. Compare optical-horizon tilt direction with native; distinguish it from camera-roll guidance when no horizon is detected. Check front-camera mirroring. |
| Close-up / Food | Use a clear object/dish, then remove it and move it near the frame edges. Compare saliency-dependent guidance. Camera measurement errors must not stop manual capture. |
| Filters | Import the same photo into each app. Disable native Beautifier; choose matching named presets and the same seven filter settings. Compare Original, styled result and selected export. Flutter iOS now follows native Core Image operation order/coefficients; physical color comparison is still needed. Android remains an approximation. |
| Review / capture | Capture at least three originals. Use previous/next buttons and swipe through recent photos, then save/share the selected copy. Originals remain intact. Per-photo treatment persistence and multi-import are still pending. |
| Lifecycle / speed | Switch lenses, rotate, background/foreground and resume a short live session. Report stale advice, blank preview, slow capture/processing, or heat. Record startup time and a matched ten-minute session if possible. |

No private photos need to be committed to Git. For a visual discrepancy, share a comparison you are comfortable providing, along with the settings and failing step. For a build failure, provide the first compiler error and its file/line plus Flutter/Xcode versions; omit signing secrets.

## Why this checkpoint needs physical input

CI can verify compilation, classifier fixtures and simulator image rendering. It cannot verify the real Vision/camera/motion alignment, on-device performance or whether the new UI and effects match the native experience. Those results are the input for P3 detector calibration and P4 Android visual tolerances in the [remaining plan](cross_platform_remaining_port_plan.md). Software work remains explicitly pending there.
