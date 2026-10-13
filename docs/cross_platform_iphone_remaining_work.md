# Flutter iPhone Port — Remaining Work Checklist

Date: October 12, 2026
Branch: `codex/cross-platform-20261007`
Flutter checkpoint: `3254fd8`
Native iPhone reference: `d53a977`

## Purpose

Track the remaining work required before the Flutter iPhone application can be accepted as the future Dali Camera implementation. Complete and record each item separately. Do not retire the native Swift application until this checklist is complete and a separate replacement decision is approved.

The functional port is substantially implemented. Remaining work is primarily signing, physical iPhone validation, native iOS test coverage, failure recovery, performance, and migration readiness.

## Current verified baseline

- [x] Shared Dart analysis passes.
- [x] All 35 shared-core tests pass.
- [x] Flutter analysis passes.
- [x] All 37 Flutter widget/controller tests pass.
- [x] Unsigned Flutter iOS device build succeeds with Flutter 3.47.2 and Xcode 27.
- [x] Base iPhone-simulator bridge passes native analysis, Portrait/Landscape/Depth rendering, filters, watermark, crop, recovery cleanup, and full-resolution processing.
- [ ] Seeded Photos-library and photo-replacement bridge coverage passes reliably in CI.
- [x] Flutter application is signed, installed, and exercised on the physical iPhone. Side-by-side Profile launch, the native bridge suite, and the end-to-end camera suite pass.

## Completion order

### 1. Signing and physical installation

- [x] Choose the development team and create or select a provisioning profile for `com.dalicamera.daliCamera`. The cross-platform build is labeled `Dali Cam Test` and uses the cyan `TEST` app icon so it remains visually distinct from the native main-line app.
- [x] Confirm that the profile contains the attached iPhone UDID.
- [x] Produce a signed Profile build without changing the native app's signing profile.
- [x] Install the Flutter app alongside the native `com.dalifin.camera` app.
- [x] Confirm that both apps launch independently and that installing either app does not remove the other.
- [x] Record the Flutter version, Xcode version, iPhone model, iOS version, source SHA, bundle ID, and profile expiration.

Acceptance evidence:

- Installed-app listing shows both bundle identifiers.
- Flutter Dali Camera opens to a working live preview.
- No existing native-app photo or recovery state is removed.

### 2. Camera startup, lifecycle, and orientation

- [ ] Compare time from launch to live preview in Flutter and native apps.
- [ ] Test rear and front cameras in portrait.
- [ ] Test both supported landscape orientations.
- [ ] Confirm preview and saved-photo orientation match.
- [ ] Confirm front-camera mirroring matches the preview and native reference.
- [ ] Background and foreground the app repeatedly.
- [ ] Rotate while previewing and while Manual controls are open.
- [ ] Switch cameras repeatedly and confirm stale analysis or controls do not survive.
- [ ] Verify a denied camera permission has a usable Settings recovery path.

Acceptance evidence:

- No blank or frozen preview.
- No stale coaching, depth mask, exposure value, or focus point after session changes.
- Saved photos contain the same visible edges and orientation shown in the preview.

### 3. UI and navigation parity

- [ ] Capture matched screenshots of the native and Flutter camera screens.
- [ ] Compare header order, labels, colors, icons, spacing, and selected states.
- [ ] Compare Situation, Effects, and contextual Posture/Landscape/Food controls.
- [ ] Compare Camera Controls, Manual rail, and one-editor-at-a-time behavior.
- [ ] Compare package overview, reference grid, selected reference, and reference details.
- [ ] Compare photo review, Enhance menu, comparison controls, Edit, and Photo options.
- [ ] Compare the seven-step tutorial and App Settings.
- [ ] Repeat key screens in landscape orientation and maximum Dynamic Type.

Acceptance evidence:

- Every control remains readable and reachable without overflow.
- Intentional Flutter product changes are documented; accidental differences are fixed.
- Side-by-side screenshots are recorded for the checkpoint.

### 4. Coaching, detection, and overlay calibration

- [ ] Test Auto classification with a single person, group, landscape, action, close-up object, and food.
- [ ] Confirm Auto requires stable evidence and does not rapidly switch situations.
- [ ] Compare posture instructions, recipients, Next/Natural progression, camera angle, and lighting.
- [ ] Confirm urgent framing advice pauses posture progression.
- [ ] Test groups with multiple visible faces, edge placement, spacing, and partial occlusion.
- [ ] Test action guidance with subject movement, camera movement, and missing motion data.
- [ ] Compare optical-horizon direction with device-roll guidance.
- [ ] Test salient-object guidance for Close-up and Food.
- [ ] Compare overlay alignment near all four preview edges.
- [ ] Repeat representative scenes with front and rear cameras, rotation, low light, varied skin tones, and partial bodies.

Acceptance evidence:

- Overlays align with visible subjects after preview geometry conversion.
- Missing or unavailable measurements show waiting/fallback guidance rather than false readiness.
- Native and Flutter guidance differences are either corrected or explicitly accepted with tolerances.

### 5. Focus, exposure, zoom, and Manual controls

- [ ] Verify tap focus changes the real camera focus point.
- [ ] Verify focus-only tapping does not unexpectedly reset manual exposure.
- [ ] Verify exposure metering when supported.
- [x] Adjust EV in automatic exposure and reset it to exactly `0 EV`.
- [x] Test focus/exposure lock and unlock.
- [ ] Test the complete supported zoom range on each lens.
- [ ] Enter Manual and confirm exposure starts in Auto.
- [x] Disable exposure Auto and adjust shutter duration and ISO.
- [ ] Verify Linked ISO behavior and relative exposure changes.
- [ ] Confirm aperture is informational on fixed-aperture hardware.
- [ ] Use Exposure Auto and confirm focus is preserved.
- [ ] Use full Auto and confirm focus, exposure, ISO, white balance, and EV reset.
- [ ] Repeat after camera switching, rotation, and background/foreground transitions.

Acceptance evidence:

- Displayed values agree with sensor/capture metadata within expected rounding.
- Unsupported controls are hidden or explicitly unavailable.
- Stale commands from a previous camera configuration are rejected.

Tv/Av priority is not part of this acceptance baseline. It is disabled in the frozen native reference build.

### 6. Capture, timer, burst, and processing

- [ ] Capture with Filters and Beautifier both Off.
- [ ] Capture with Both Auto.
- [ ] Exercise separate Filter and Beautifier Auto/Custom/Off combinations.
- [x] Confirm the shutter gives immediate visual feedback.
- [x] Confirm the captured original appears during processing and the final result replaces it.
- [ ] Test 3-, 5-, and 10-second timers and cancellation.
- [ ] Confirm camera switching or backgrounding cancels a countdown.
- [ ] Test long-press Burst, release, maximum count, and interruption.
- [ ] Confirm capture is blocked while an unsaved recovery original requires action.
- [x] Confirm only one finalized image is automatically saved per ordinary capture.

Acceptance evidence:

- No duplicate captures from one tap or voice command.
- The immutable private original survives processing failure.
- Retry uses the frozen capture recipe rather than subsequently changed settings.

### 7. Filters, beautifier, depth, and visual output

- [ ] Import the same source photo into native and Flutter apps.
- [ ] Compare all named filters at matching settings.
- [ ] Compare all seven filter parameters.
- [ ] Compare General Enhance at levels 1, 3, and 5.
- [ ] Compare Portrait Polish at levels 1, 3, and 5, including each option.
- [ ] Compare Landscape Polish at levels 1, 3, and 5, including sky and color options.
- [ ] Test photos with and without faces, sky, and sufficient lighting.
- [ ] Compare live subject-region depth preview and saved feathered blur.
- [ ] Switch cameras while depth is active and check for stale masks.
- [ ] Verify watermark placement, transparency, scale, and preservation of underlying pixels.
- [ ] Test maximum-resolution photos and record memory/processing behavior.

Acceptance evidence:

- Off preserves the original appearance.
- Processing never overwrites the source file.
- Output dimensions and orientation are preserved unless the selected edit intentionally changes them.
- Visual differences have documented tolerances or are corrected.

### 8. Photos library, import, and replacement

- [ ] Fix or stabilize the seeded Photos-library bridge job in CI.
- [ ] Add iOS automated coverage for Replace original; the current integration replacement assertions are Android-only.
- [x] Test full Photos access.
- [ ] Test limited Photos access and changing the allowed selection.
- [ ] Test denied access, Settings recovery, and retry without restarting.
- [ ] Test iCloud-backed image retrieval.
- [ ] Browse the complete library newest-first with lazy loading.
- [ ] Test the separate 20-photo picker.
- [ ] Test folder import, empty folders, unreadable files, and documented traversal limits.
- [ ] Confirm imported/library originals remain unchanged.
- [x] Test Save as new photo.
- [ ] Test Replace original using Photos content editing.
- [ ] Reopen the replaced asset and confirm its current version is loaded.
- [ ] Cancel selection and replacement flows and verify current edits remain available.

Acceptance evidence:

- The correct photo is loaded, processed, saved, or replaced after navigation.
- Private-copy cleanup never deletes a Photos asset.
- Replace preserves the asset identity; Save as creates exactly one new asset.

### 9. Recovery and injected failures

Use only disposable test photos and device data for this section.

- [ ] Force-quit during capture processing.
- [ ] Force-quit during Photos saving.
- [ ] Relaunch and verify the pending original can be retried or discarded.
- [ ] Simulate or create a disk-full condition and verify visible failure.
- [ ] Test processing failure, Photos denial, unavailable iCloud asset, and invalid replacement target.
- [ ] Rapidly navigate photos while treatments are processing.
- [ ] Rapidly press the shutter while capture/save guards are active.
- [ ] Verify private orphan cleanup while retaining active history and pending recovery.
- [ ] Decide whether to improve or accept the documented iOS Photos-commit duplicate-retry window.

Acceptance evidence:

- No original is silently lost.
- A failed operation never exports or replaces the wrong photo.
- Recovery and cleanup never delete unrelated gallery content.

### 10. Voice shutter and audio lifecycle

- [ ] Test every built-in voice command.
- [ ] Test a custom phrase as complete words and reject substring matches.
- [ ] Confirm one phrase triggers only one capture or countdown.
- [ ] Deny and later grant microphone and speech permissions.
- [ ] Background and foreground while voice shutter is enabled.
- [ ] Test interruption by calls, Siri, music, and other audio sessions where practical.
- [ ] Confirm desired voice preference is retained separately from actual listening availability.

Acceptance evidence:

- Voice errors never prevent manual capture.
- Listening state and status messages reflect actual availability.
- The audio session is released when camera/voice operation stops.

### 11. Accessibility

- [ ] Walk the complete camera flow with VoiceOver.
- [ ] Verify logical focus order and labels for the camera header, selection controls, advice, shutter, and review.
- [ ] Verify sliders and adjustable controls announce values and changes.
- [ ] Verify comparison and fullscreen photo controls remain understandable without sight.
- [ ] Repeat key screens with maximum Dynamic Type.
- [ ] Confirm reduced-motion mode removes unnecessary flashing or pulsing.
- [ ] Confirm color is not the only indication of coaching state.

Acceptance evidence:

- All primary operations can be completed with VoiceOver.
- No essential control is clipped, unreachable, or represented only by color.

### 12. Performance and thermal acceptance

- [ ] Record launch-to-preview and launch-to-shutter-ready times.
- [ ] Record shutter-feedback latency.
- [ ] Record capture-to-final-image and Photos-save durations with effects Off and at maximum processing.
- [ ] Measure preview and analysis responsiveness.
- [ ] Run matched ten-minute native and Flutter sessions.
- [ ] Record process memory, device temperature, and visible throttling.
- [ ] Repeat with front/rear cameras, maximum-resolution photos, filters, Portrait Polish, Landscape Polish, and depth.
- [ ] Establish explicit acceptable limits and lower-tier-device fallback behavior.

Acceptance evidence:

- No unbounded memory growth or thermal failure.
- The preview and shutter remain responsive within the agreed limits.
- Unsupported maximum-resolution operations fail visibly while retaining the original.

### 13. Native iOS automated-test coverage

- [ ] Replace the placeholder `RunnerTests.testExample` with meaningful iOS plugin tests.
- [ ] Test Photos identity mapping and private-copy cleanup.
- [ ] Test save, replace, cancellation, and failure results.
- [ ] Test recovery-manifest reconciliation.
- [ ] Test stale camera configuration rejection.
- [ ] Test EV reset and Auto restoration.
- [ ] Test orientation and mirroring conversions.
- [ ] Test voice-service state transitions where they can be isolated.
- [ ] Make the simulator bridge job reliably complete and publish diagnostics on failure.

Acceptance evidence:

- iOS-native behavior is not protected only by Dart mocks or Android integration tests.
- CI runs the relevant bridge assertions instead of merely compiling the iOS app.

### 14. Toolchain, release, and migration decision

- [ ] Select and document the supported Flutter and Xcode versions.
- [ ] Either retain Flutter 3.44.8 or update `pubspec.lock` and CI for Flutter 3.47.x after validation.
- [ ] Produce signed Debug, Profile, and Release builds.
- [ ] Decide the production bundle identifier.
- [ ] Decide whether and how the Flutter app replaces the existing native application.
- [ ] Plan migration for preferences, recovery state, and private history if the bundle identifier changes.
- [ ] Review App Store privacy declarations and required privacy manifests.
- [ ] Verify app icon, launch screen, version/build numbering, archive, and export.
- [ ] Update iPhone installation and rollback instructions.
- [ ] Keep the native application installable until Flutter retirement approval is explicit.

Acceptance evidence:

- A reproducible signed release archive is produced.
- Upgrade/coexistence behavior and user-data consequences are documented and approved.
- A rollback path to the native app remains available during transition.

### 15. Documentation closeout

- [ ] Update documents that still describe iOS as wholly deferred now that the base simulator bridge passes.
- [ ] Update stale Flutter test totals.
- [ ] Remove or correct stale Share-flow checklist items; Share was removed from the current camera product scope.
- [ ] Record every accepted limitation and physical-device result.
- [ ] Add links to screenshots, logs, source SHA, device/OS matrix, and CI runs.
- [ ] Mark this checklist complete only after each open item is closed or explicitly accepted.

## Final acceptance gate

The Flutter iPhone port is accepted only when all of the following are true:

- [x] Signed Flutter and native reference apps run side by side on the same physical iPhone.
- [ ] No unresolved original-loss, wrong-photo export, permission-recovery, or preview-alignment defect remains.
- [ ] Every reachable native baseline behavior is implemented, intentionally superseded, or documented as hardware-limited.
- [ ] Physical camera, Photos, voice, accessibility, lifecycle, and performance checks pass.
- [ ] CI includes reliable iOS-native and bridge validation.
- [ ] Production bundle ID, migration, release, and rollback decisions are approved.
- [ ] Native Dali Camera retirement is approved separately.

## Progress log

Add one entry after each completed checklist item:

| Date | Source SHA | Device / OS | Checklist item | Result | Evidence / notes |
| --- | --- | --- | --- | --- | --- |
| 2026-10-12 | `3254fd8` | iPhone simulator / local Xcode 27 | Baseline build and bridge | Pass | 35 core tests, 37 Flutter tests, unsigned iOS device build, and base simulator bridge passed. Seeded Photos/replacement and physical iPhone checks remain open. |
| 2026-10-12 | `3254fd8` + working tree | iPhone 13 Pro / iOS 18.0.1 | Signing and side-by-side Profile install | Pass | Flutter 3.47.2, Xcode 27.0, bundle `com.dalicamera.daliCamera`, wildcard development profile expiring 2027-10-13. `Dali Cam Test` and native `com.dalifin.camera` are both installed. |
| 2026-10-12 | `3254fd8` + working tree | iPhone 13 Pro / iOS 18.0.1 | Profile native bridge suite | Pass | Recovery startup, portrait/landscape/original rendering, filter, watermark, crop, cleanup, and full-resolution treatment passed in Profile mode. |
| 2026-10-12 | `3254fd8` + working tree | iPhone 13 Pro / iOS 18.0.1 | Profile end-to-end camera suite, initial attempts | Fail, resolved | Initial permission resets blocked startup. The first complete run then exposed stale EV snapshots because AVFoundation applies exposure bias asynchronously. The bridge now returns from Apple's completion callback. |
| 2026-10-12 | `3254fd8` + working tree | iPhone 13 Pro / iOS 18.0.1 | Profile end-to-end camera suite | Pass | Attached to the installed Profile app to preserve Camera permission. The 41-second suite passed camera startup, controls, EV adjustment/reset, focus/exposure lock, manual shutter/ISO, timer capture, styled Photos output, review comparison, Landscape Polish selection, crop, Save as, library navigation, camera switching/stale-command rejection, and burst release. Normal `lib/main.dart` Profile build was restored and launched afterward. |
