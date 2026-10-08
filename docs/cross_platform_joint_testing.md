# Joint phone testing ? parity candidate

Branch: `codex/cross-platform-20261007`. Native reference: `d53a977`. Baseline features are connected; visual and hardware acceptance will happen together. Keep the native iOS app installed for comparison. Folder import remains intentionally available for session photos; future reference packages will need image instructions.

## Build and device evidence

Use `git rev-parse HEAD` to record the tested source. Android integration checks use isolated package `com.dalicamera.dali_camera.test`. The normal app is `com.dalicamera.dali_camera`; normal updates use `adb install -r` and never uninstall as a fallback. APK: `apps/dali_camera/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`.

- Flutter 3.44.8 / Dart 3.12.2; Mac CI Xcode 16.4, iOS 17+.
- Galaxy S10+ SM-G975U / Android 12: camera/control/export flow and native rendering/recovery checks pass at the implementation checkpoint. Final spatial treatment rerun pending.
- Samsung SM-T290 / Android 11: 120-second analysis soak delivered 98 fresh one-second samples. Navigation/bridge rerun pending after removing a test assumption about Auto's active scene.
- Shared core: 35 tests; Flutter: 18 tests and analysis pass. Swift comparisons: 9 baseline coaching, 24 scene transitions, 150 rich coaching and 16 pose geometry cases pass. Final CI/device evidence will be appended after the last run.
- Physical iPhone and second Android vendor remain untested. Debug checks do not establish release speed, thermal behavior or exact rendering equality.

## Test together in this order

1. **Camera and menus.** Open rear camera. Confirm Situation, Effects and the contextual Posture/Landscape/Food control below the viewport. Browse a package, choose a reference, use Next/Skip/Natural, change situations and return. Check Close-up visibility, rotation, front-camera mirroring and large text.
2. **Capture and recovery.** Capture three photos, use timer and hold-burst, review and swipe between them. Confirm gallery originals and recent history. Return to camera, background/resume and switch lenses. A failed original save must offer retry/discard and block overwriting it.
3. **Effects and custom settings.** Try Both Off, Both Auto and separate modes. Select a named filter, change its parameters, switch Off/Auto/Custom and restart: custom values must survive. Compare matching native iOS presets using the same imported source. Try General Enhance, Portrait and Landscape at strengths 0, 3 and 5 and toggle their options.
4. **Review and exports.** Open a new photo in Before; choose a treatment and inspect After/Split/fullscreen zoom. Before saves/shares the original; After/Split saves/shares the selected copy. Cancel sharing, navigate, save another copy and confirm exported photo identity. Originals must remain unchanged.
5. **Analysis and coaching.** Compare one person, two people, partial faces, low light, backlight, moving person, food and landscape. Try a visible tilted horizon for Level and a misplaced subject for Reframe. Missing measurements must show waiting/unavailable behavior. Record incorrect advice with the scene and settings.
6. **Depth and controls.** Enable depth levels 1/3/5 around a person and a tapped focus point. Check preview/saved edges, rapid lens changes and rotation. Try tap metering, zoom, lock, EV and supported manual shutter/ISO with linked ISO. Aperture is informational on fixed-aperture cameras; unsupported controls remain unavailable.
7. **Voice and permissions.** Enable standard/custom voice on a supported device; background/resume, speak twice, disable it and restart. Check actual listening status. Deny/re-enable camera, Photos and microphone/speech permissions and verify recovery. Try TalkBack/VoiceOver navigation.
8. **Imports and endurance.** Select several photos (max 20), open a folder (max 50), cancel a replacement, try an unreadable file and return to camera. Imports are session-only and must not replace a pending original. Run a matched ten-minute session and report capture/processing delays, heat or stale overlays.

On your Mac follow [iPhone installation](cross_platform_iphone_checkpoint.md). Compare both iOS apps on the same lens, source photo, settings and lighting. Report device/OS, source SHA, checklist step, expected versus actual behavior and a screenshot you are comfortable sharing. No private test photo needs to enter Git.

## Explicit acceptance limits

Android's multi-face groups, single-body pose, color-contrast saliency, gradient horizon and spatial/color rendering differ from Vision/Core Image. We still need to agree on visual and detector tolerances using matched scenes. Depth matches the native rounded subject-region design, not semantic segmentation. On-device speech availability depends on the phone. Android live exposure-offset metering is unavailable; native Tv/Av is behind the disabled iOS 27 compile gate. An iOS add-only Photos commit crash can duplicate an original on retry; cleanup only affects private files, never gallery content.
