# Cross-platform sync with remote main

Source: `origin/main` commit `d53a977`, ?Expand camera controls, effects, and guided capture?. Destination: `codex/cross-platform-20261007`. Local `main` is unchanged.

## Implemented in this sync

- Merge all native iOS changes, new engine sources, six Food images, watermark, tests and documents. Preserve the smaller SwiftUI modifier groups required by the existing Xcode build. Keep the thread-safe watermark context compatible with older SDK Swift 6 annotations and use the SDK-compatible Bluetooth HFP option spelling. Compile the new iOS 27 priority-exposure API only with the iOS 27 SDK; older SDK builds omit those unavailable capabilities while retaining manual M.
- Export six Food recipes and eight named filter definitions directly from Swift, with CI checking metadata and all 106 reference images plus the watermark.
- Add Food selection, angle/cue progression, reference details, light and safety notes to Flutter. Food guidance does not require a person in frame.
- Show coaching status and directional icons in Flutter.
- Add shutter timer Off/3/5/10s, visible countdown and cancellation, and long press Burst/Timer/Disabled. Burst is a paced sequence capped at 25 originals, saving each before another capture. Release, app pause, camera changes or failed original save stop the sequence. Tap/voice captures now stay in the live camera; the latest-photo button opens review.
- Add standard voice commands and a custom whole-word phrase to both on-device speech backends; empty custom phrases never trigger capture. Language/permission availability still varies by device.
- Add recent-photo review of up to 25 saved private originals, persisted across app launches. Retain pending originals independently. Prune only owned saved private files after committing the history; preserve gallery files.
- Add named filters Auto/Custom/Off, seven adjustable parameters and an opt-in Dali watermark. Prepare a separate styled review copy after capture or from review; Save selected exports it. The original remains unchanged. Auto chooses Natural for people, Blue Sky for Landscape and Fresh for Food.
- Add capability-gated tap focus, zoom and manual M shutter/ISO on both backends. Auto enters the Manual workspace with metered values and remains automatic until Auto exposure is disabled. Manual controls can be hidden over the preview. Camera/lens changes reset unsupported state. Return to Auto restores autofocus, automatic exposure/ISO/white balance and zero EV.

## Deliberate platform differences and remaining parity work

The preceding cross-platform milestone had not ported the full detector/enhancement pipeline. This sync preserves those new native improvements and extends Flutter's working features without presenting unimplemented controls:

- Flutter named filters reuse native parameter values but render a shared color matrix with platform-specific spatial softness/detail. They do not reproduce Core Image temperature, vibrance, shadow recovery or noise reduction exactly. Effects appear in the review copy; the camera preview remains natural. Android styled derivatives sample large source images to a maximum 3200 px long edge to bound memory; originals and their gallery exports retain full resolution.
- Landmark-aware face brightness, skin/blemish processing, eye/lip geometry and person/saliency-based live depth blur remain in the native app. They require the richer detector/rendering port already tracked in the cross-platform plan. Flutter does not expose a pretend Beautifier or Depth control.
- Flutter exposes M only when manual sensor exposure is available. Tv/Av priority, linked ISO, exposure meter/recommendations and physical aperture controls remain native-only; fixed-aperture hardware must not be represented as adjustable. Hardware focus distance, custom white balance and monitoring remain future work in the native plan as well.
- Multi-photo/folder import and swipe review remain native-only. Flutter provides its existing single-photo picker and selectable recent-photo grid.
- Physical iPhone camera, speech, manual exposure and visual filter comparison still require testing on the user's Mac/iPhone. CI simulator rendering does not validate sensor behavior.

## Validation

- Local shared-core analysis and 27 tests: pass.
- Local Flutter analysis and six controller/widget tests: pass, including timer cancellation, duplicate-trigger prevention, burst release/save failure and 25-photo retention.
- Android debug build: pass.
- Extended native bridge tests check style and watermark rendering, original-byte preservation, invalid parameters, private-only cleanup and pending-original protection.
- Extended phone integration checks Food selection, timer capture, styled-copy export, focus/zoom, and sensor-reported manual shutter/ISO when supported.
- Samsung SM-G975U (Android 12) and SM-T290 (Android 11): Food/reference selection, timer/style export, capture/crop/save, both lenses, stale-control rejection, tap focus, zoom, sensor-reported shutter/ISO, actual shutter hold/release and recent-history opening pass. Both report manual exposure and 1?8? zoom. This is a short regression check, not a new ten-minute soak or thermal benchmark.
- Both Android native bridge suites pass, including visible styled pixels, bottom-right watermark signal, an unchanged top-left region, owned-copy cleanup and protection of pending originals. The initial stricter mean-difference threshold underestimated the sparse signature; the corrected threshold still rejects an absent watermark.
- Normal Android app restored on both devices after the test runner removed its test installation.
- ARM64 debug APK: `apps/dali_camera/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, 110.6 MiB, SHA-256 `21a4b2b5f1df6e3f1463aa694633121deaa46fc7a0c3e2815f446e0d80459786`. Universal and other ABI development APKs also built.
- [CI run 37802721231](https://github.com/glicxu/mobile_camera/actions/runs/37802721231) passed every job for source `8e6997f3cd8d49dd079b7ac9a7ec111014cd9a57`: 27 shared tests, six Flutter tests, analysis, catalog/assets, Android APK, unsigned Flutter iOS device build, nine real Swift/Dart fixtures, 51 native iOS tests and the extended Flutter bridge test on iPhone simulator.

## Phone test additions

1. Choose Food ? Food photography ? Hero plate. Open its reference and verify light/safety details; follow the angle and two cues.
2. Set a 3-second timer. Tap shutter, cancel, then take another timer photo. Switch camera or background the app during countdown and confirm it cancels.
3. Hold shutter for a short burst; release and check recent photos. If Photos permission is denied, the first failed original must remain available for retry and block another capture.
4. Choose Fresh and enable the watermark. Capture, open latest photo, compare Original, and Save selected. Check the original gallery photo remains unchanged and the styled copy has the signature at bottom right.
5. Tap different preview positions, adjust zoom, and enter Manual on a supported camera. Disable Auto exposure, change shutter/ISO, hide/reopen the tools, and Return to Auto. Repeat after a lens/rotation/background transition.
6. Enable on-device voice with an available language and a custom phrase. Check normal commands and the custom phrase trigger one photo/countdown; unrelated words and substring matches should not.
