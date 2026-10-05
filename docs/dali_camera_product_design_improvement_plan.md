# Dali Camera Product and Design Improvement Plan

Date: October 4, 2026

Status: Phone-test candidate. Code changes for capture/review, guidance, preview geometry, onboarding, accessibility, and Dart-core parity are implemented. Automated macOS validation is in progress; physical-device acceptance remains a phone-testing task. See [phone testing](phone_testing.md).

## Implementation progress

The initial implementation adds:

- Retained originals with an atomic local recovery copy for unsaved captures, restored on launch.
- Retry, share, Settings, and explicit discard controls for unsaved originals.
- Guards against repeated capture and overlapping save requests.
- Camera permission refresh when returning to the app and an Open Settings action.
- Direct latest-capture review, selected-variant save/share, and original comparison.
- Photo-first review with diagnostics, folder import, and tilt simulation behind the debug setting.
- Protection against stale analysis replacing the current review result.
- Recovery-store tests covering relaunch-style recovery, removal, and write failure.

Readiness work now includes a full-frame preview shared with the overlay, consistent capture rotation/mirroring, upright Vision input, display-relative gravity roll, a fixed shutter area with scrollable advice, shorter onboarding, accessible control labels, large-text/simulator UI checks, and the shared Xcode scheme.

The Dart core includes matching guidance sessions, preview geometry, and adapter-based photo recovery/export logic. All 20 Dart tests pass and analysis is clean. Native XCTest and simulator UI coverage are run by the Phone readiness macOS workflow, including an unsigned physical-iPhone build. Simulator screenshots and test results are exported for review.

Remaining acceptance work is on-device: camera/Photos permission recovery, real sensor alignment, lighting quality, VoiceOver interaction, and comfortable use of the pose suggestions. Follow [the iPhone checklist](phone_testing.md). Creative pose steps deliberately remain manually confirmed; automatic pose verification is not a claim of this build. The Dart package is shared core logic, not a completed Flutter/Android camera application.

## Goal

Make Dali a dependable camera that helps someone take a better photo of a friend, inspect the result, and save or share it without assistance.

This plan follows a source-based review of the native iOS app. The browser fallback and Dart core provided supporting context. Rendered layouts, camera behavior, and accessibility still need validation on an iPhone.

Preserve the prominent shutter, short coaching instructions, stable advice timing, and beautification being off by default.

## Priorities and sequence

| Phase | Priority | Outcome |
| --- | --- | --- |
| 1. Make capture dependable | High | A failed save does not lose the captured moment; permission recovery works. |
| 2. Complete the photo workflow | High | Users can capture, review, enhance, save, and share a photo. |
| 3. Simplify coaching and navigation | Medium | The default interface emphasizes the photograph and one clear instruction. |
| 4. Validate visual accuracy and accessibility | High for alignment; medium for remaining polish | Guidance matches the visible preview and essential controls remain usable. |
| 5. Add posture and camera-position suggestions | Medium; after the first milestone and preview alignment | Ten selectable posture suggestions and five camera positions provide clear, optional creative direction. |

Complete phases 1 and 2 as the first milestone. Investigate preview coordinate alignment early and resolve it before relying on coaching in user testing. Apply accessibility checks throughout implementation, then perform the full device pass in phase 4.

## Phase 1: Make capture dependable

### Changes

- Retain the captured original independently of Photos save status, until it is saved or explicitly discarded.
- Provide **Retry save** and **Share** when saving fails or Photos access is denied.
- Distinguish capturing, saving, saved, and failed states with concise feedback.
- Handle repeated shutter taps safely while a capture is in flight.
- Add **Open Settings** to the camera permission screen.
- Recheck permission when the app becomes active, clear the denied state after access is granted, and restart the camera when appropriate.

### Acceptance criteria

- Denying Photos access or encountering a save error leaves the captured photo available for recovery.
- Retrying a save does not require taking another photo.
- Granting camera access in Settings restores the camera without restarting the app.
- Status messages accurately reflect whether a photo has been saved.
- Capture remains available regardless of whether coaching considers the composition ready.

### Implementation starting points

- `DaliCamera/CameraModel.swift`: capture delegate, photo persistence, authorization, session lifecycle.
- `DaliCamera/ContentView.swift`: permission screen, shutter, capture status and recovery actions.

## Phase 2: Complete the photo workflow

### Changes

- Make the latest-photo thumbnail open that capture directly.
- Keep access to the photo library as a separate action inside review.
- Provide a photo-first review screen with **Back to camera**, **Compare**, **Save a copy**, and **Share**.
- Clearly distinguish the original, reframed, leveled, and polished variants.
- Save or share the selected variant and preserve the original.
- Explain that portrait polish applies during review; do not imply that a live camera setting has already changed the saved original.
- Display export progress, success, and recoverable failure feedback.

### Acceptance criteria

- Users can inspect the latest capture without searching for it in the library.
- Users can compare an enhancement against the original and export the version they selected.
- Exported appearance and orientation match the selected preview.
- Enhancement never overwrites the original.
- Returning to the camera is a clear, direct action.

### Implementation starting points

- `DaliCamera/ContentView.swift`: thumbnail action, review navigation, variant selection, comparison and export controls.
- `DaliCamera/CameraModel.swift`: retained capture and variant export.
- `DaliCamera/BeautifyEngine.swift`: existing enhancement output.

## Phase 3: Simplify coaching and navigation

### Changes

- Move metrics, pose points, folder imports, and simulated tilt controls into an explicit testing mode.
- Hide detection boxes by default while retaining them for diagnostics.
- Keep one active instruction visible without covering the subject unnecessarily.
- Use distinct graphics for photographer movement, phone rotation, and subject direction.
- Identify who should act in each coaching instruction.
- Replace the seven-part first-run tutorial with a short, dismissible introduction; retain detailed explanations in help.
- Use plain user-facing language for settings such as pose selection.

### Acceptance criteria

- The default review screen prioritizes the photograph, comparison, and save/share actions.
- Technical metrics and simulation controls appear only in testing mode.
- Users can distinguish “move left,” “tilt left,” and “ask the subject to turn left.”
- Users can reach the camera quickly on first launch and reopen help later.

### Implementation starting points

- `DaliCamera/ContentView.swift`: review analysis panel, settings, tutorial and testing controls.
- `DaliCamera/OverlayView.swift`: detection boxes and direction graphics.
- `DaliCamera/Models.swift`: structured action semantics if needed to replace graphics inferred from instruction text.

## Phase 4: Validate visual accuracy and accessibility

### Changes

- Use a shared mapping between camera analysis coordinates and the visible preview, accounting for aspect-fill crop, rotation, safe areas, and mirroring.
- Confirm coaching evaluates the framing the user actually sees.
- Adapt review layout for small screens, landscape orientation, and larger text.
- Add explicit accessibility labels and appropriate state descriptions to icon controls.
- Verify VoiceOver focus order, variant selection, comparison alternatives, and status feedback.

### Acceptance criteria

- Detection overlays align with the subject on front and rear cameras in supported orientations.
- Framing advice corresponds to the visible preview boundaries.
- Essential controls remain visible and usable on a small supported iPhone and at larger text sizes.
- VoiceOver users can capture, open review, select a version, and save or share it.

### Implementation starting points

- `DaliCamera/CameraPreview.swift`: preview geometry and orientation.
- `DaliCamera/OverlayView.swift`: coordinate conversion and overlay layout.
- `DaliCamera/CameraModel.swift`: analysis coordinate handling.
- `DaliCamera/ContentView.swift`: adaptive layout and accessibility.

## Phase 5: Add posture and camera-position suggestions

Status: Native and Dart-core implementations are present. Automated validation and the physical-phone acceptance pass are tracked in [phone testing](phone_testing.md).

### Implemented increment

- **Poses & angles** in the live People Coach opens the 10-pose and five-position chooser. Both collections are available to everyone, with no gender inference.
- Each pose includes a schematic reference and two subject cues. Camera-position steps run before pose steps when both are selected; the side position offers an explicit right-side alternative.
- The existing coaching scheduler displays one cue at a time. Urgent subject visibility, distance, and cropping issues can interrupt the sequence without advancing it.
- **Done / Next** and **Skip this step** advance explicitly. **Natural** exits guidance; choosing a new sequence resets progress. Taking a photo does not depend on completing the sequence.
- This increment uses `userConfirmed` completion for every creative step. It does not claim automatic pose verification or camera-height estimation. Generic camera tilt, lighting, and styling corrections are deferred while a creative sequence is selected; switching to Natural restores the ordinary rule set.
- Guided symbols distinguish subject posing, camera height, camera pitch, and photographer movement without parsing direction words. Text defines subject-relative and photographer-relative directions, independent of selfie mirroring.
- Added XCTest coverage for catalog counts, recipients, manual progression, Natural mode, missing-subject interruption/resumption, conflicting face-direction advice, direction alternatives, and sequence replacement.

Validation: Swift syntax and whitespace checks pass. Dart tests cover all 50 pose/position combinations for sequence behavior, along with interruptions, resets, geometry, and photo recovery. Native unit/UI tests and the physical-iPhone build run on a macOS GitHub Actions runner. The real camera, accessibility, and pose-comfort checks remain part of the phone acceptance pass.

Scope: **10 posture suggestions total: five male/masculine examples and five female/feminine examples**, plus **five camera positions**. These are selectable style collections, available to any subject. Keep Natural as the default and let the user choose a collection; do not infer gender from camera input.

### Posture suggestion catalog

Each entry is a pose the user can choose, not a defect the app should automatically diagnose. Show only the next short cue, addressed to the subject. Left and right in subject instructions refer to the subject's own left and right.

| ID | Collection | Posture | Initial subject cue | Follow-up cue, shown separately | Validation approach |
| --- | --- | --- | --- | --- | --- |
| M1 | Male / Masculine | Relaxed standing | "Stand with your feet comfortably apart." | "Relax your shoulders." | Check ankle spacing and shoulder visibility when available; comfort remains user-confirmed. |
| M2 | Male / Masculine | Three-quarter stance | "Turn your body slightly to your right." | "Bring your face back toward the camera." | Use shoulder/torso orientation and face yaw as approximate signals; do not claim an exact body angle. |
| M3 | Male / Masculine | One hand in pocket | "Rest one hand in your pocket." | "Let your other arm hang loosely." | Offer as a guided pose; pocket placement and relaxed hands require user confirmation. |
| M4 | Male / Masculine | Seated forward lean | "Sit and lean slightly forward." | "Rest your forearms on your thighs." | Use visible torso, elbow, and wrist landmarks as supporting signals; seat availability is user-confirmed. |
| M5 | Male / Masculine | Casual walking | "Walk slowly across the frame." | "Look toward the camera for the next shot." | Make this a user-selected motion pose; test that ordinary hold-steady coaching does not continuously contradict it. |
| F1 | Female / Feminine | Weight-shift stance | "Rest your weight on one leg." | "Soften the other knee." | Hip, knee, and ankle positions can suggest the stance; actual weight distribution cannot be confirmed from a single image. |
| F2 | Female / Feminine | One foot forward | "Place one foot slightly in front." | "Turn your shoulders a little toward the camera." | Use visible leg separation and torso landmarks; depth ordering remains approximate. |
| F3 | Female / Feminine | Hand at waist | "Rest one hand lightly at your waist." | "Relax your other arm." | Use wrist-to-hip proximity and elbow visibility; avoid judging body shape or hand pressure. |
| F4 | Female / Feminine | Seated angled pose | "Sit with your knees angled slightly to one side." | "Turn your face toward the camera." | Use knee visibility and face yaw when confident; seating and comfort are user-confirmed. |
| F5 | Female / Feminine | Over-shoulder glance | "Turn your body partly away from the camera." | "Look back over your shoulder comfortably." | Check face visibility and relative torso orientation; suppress generic profile corrections that conflict with the selected pose. |

### Camera-position catalog

Camera-position cues are addressed to the photographer. Left and right refer to the photographer's view of the scene. Treat these as optional composition choices, not universal corrections. Heights are relative to the subject, including seated subjects.

| ID | Position | Photographer cue | Intended use | Follow-up and validation |
| --- | --- | --- | --- | --- |
| C1 | Eye level, straight on | "Hold the camera at their eye level." | A starting position for head-and-shoulders portraits. | Keep the phone level and eyes visible. Relative physical height requires user confirmation; face placement alone does not prove it. |
| C2 | Chest level, straight on | "Lower the camera to their chest level." | A starting position for waist-up portraits. | Recheck headroom and hand cropping. Show one framing correction only after the position cue. |
| C3 | Waist level, farther back | "Lower the camera to their waist level." | A starting position for full-body portraits with scenery. | Then offer "Step back until their feet fit." Validate visible feet and frame margins without assuming camera distance is known. |
| C4 | Slightly above eye level | "Raise the camera just above their eye level." | An optional viewpoint for closer portraits. | Then offer "Angle the camera down slightly." Distinguish downward pitch from sideways roll; preserve face and headroom. |
| C5 | Slightly to the side, at eye level | "Move a little to your left around the subject." | An optional three-quarter viewpoint with a changed background. | Keep the same subject framed and offer a mirrored right-side alternative. The user chooses the side; do not invent a preferred background direction. |

### Product behavior and implementation tasks

- Add a small pose chooser with a title, simple reference illustration, and an optional camera-position choice. Keep both off until selected; users can skip, switch, or return to Natural.
- Reuse the existing masculine and feminine package identifiers, but represent individual pose choices with stable IDs. Add explicit camera-position IDs rather than identifying actions by matching instruction text.
- Model each suggestion with recipient, initial cue, follow-up cue, applicable framing, required measurements, conflicts, and completion method (`measured` or `userConfirmed`).
- Deliver posture and camera-position cues through the existing single-instruction scheduler. Resolve urgent framing or visibility problems before optional creative suggestions.
- Do not show a follow-up until the current step is confirmed or a supported measurement remains stable. When the required landmark is missing or confidence is low, allow manual confirmation or skipping without claiming completion.
- Prevent conflicting corrections: selected over-shoulder poses should not trigger repeated demands to face fully forward; walking poses should not be treated as failed static poses.
- Keep shutter capture available throughout. Do not force users to complete a pose sequence to take a photo.
- Validate the 10 poses and five positions independently first; do not assume all 50 combinations produce useful guidance.

### Acceptance criteria

- The catalog contains exactly 10 distinct posture suggestions and five distinct camera positions, with all options reachable through the UI.
- Both posture collections can be chosen by any user, and no collection is assigned by inferred gender.
- Each cue identifies whether the subject or photographer should act; front-camera mirroring does not reverse its intended meaning.
- Only one cue appears at a time. Follow-ups, skip, switching poses, and returning to Natural work without contradictory or stale instructions.
- Unsupported measurements never produce a false success indication. Camera height, pocket placement, comfort, and similar unobservable details use user confirmation.
- Test cases cover missing landmarks, low confidence, cropped legs, seated subjects, walking, profile poses, and mirrored previews.
- Device testing confirms that the suggestions are understandable and usable with different body proportions, clothing, and mobility preferences. Users can skip any pose without penalty.

### Implementation starting points

- `DaliCamera/Models.swift`: pose IDs, camera-position IDs, recipients, prerequisites, and completion methods.
- `DaliCamera/CoachingEngine.swift`: sequencing, confidence handling, priorities, and conflicting-rule suppression.
- `DaliCamera/ContentView.swift`: catalog selection, reference previews, next/skip controls, and return to Natural.
- `DaliCamera/OverlayView.swift`: distinct subject, photographer-movement, camera-height, and rotation graphics.
- `DaliCameraTests/CoachingEngineTests.swift`: catalog coverage, step progression, conflicts, missing measurements, and capture-independent guidance.
- `packages/dali_camera_core`: mirror the approved catalog and rule semantics when the cross-platform port reaches this feature.

## State and data design

Organize the experience around three explicit states: **camera**, **capture awaiting save**, and **photo review**. Track capture and export progress separately where needed.

- Store the captured original independently of save success.
- Track the selected review variant explicitly and use it for export.
- Keep recovery actions attached to the photo that failed to save.
- Keep testing controls behind one consistent setting.
- Avoid introducing additional coaching or enhancement features before the first milestone is complete.

## Validation plan

| Area | Checks |
| --- | --- |
| Capture reliability | Denied Photos access, failed saves, retry, repeated shutter taps, and background/foreground transitions. |
| Permission recovery | Deny camera access, open Settings, grant access, and return to the app. |
| Output correctness | Export original and enhanced versions; compare appearance and orientation with the selected preview. |
| Preview alignment | Front and rear cameras, portrait and landscape, subjects near each visible frame edge. |
| Layout and accessibility | Small-screen portrait, landscape, larger text, and VoiceOver navigation through the complete workflow. |
| Product usability | Ask a first-time user to photograph a friend, inspect the result, and save an enhancement without assistance. |

Use focused automated checks for capture state transitions, retry behavior, selected-variant export, and coordinate transformations where practical. Use real-device checks for camera behavior, rendered layout, and accessibility.

During usability sessions, record whether users complete each step without help, where they hesitate, whether they understand who should follow an instruction, and whether they can identify which version was saved. Use those observations to prioritize the next iteration.

## First milestone

Deliver phases 1 and 2: a dependable capture-to-review-to-save/share workflow. Resolve any preview alignment issue that would invalidate coaching before testing the product promise with users.

The milestone is complete when permission and save failures are recoverable, the latest capture opens directly, and users can export the selected result while preserving the original.
