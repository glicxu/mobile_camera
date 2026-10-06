# Dali Camera V1 Implementation And Testing Plan

**Status:** Prototype 0 implemented; V1 measurement/rule expansion in progress
**Companion doc:** `docs/dali_camera.md`
**Purpose:** Define how to build and test the V1 algorithmic coaching functionality.

**Posture extension:** [Phase 5: posture and camera-position suggestions](dali_camera_product_design_improvement_plan.md#phase-5-add-posture-and-camera-position-suggestions) now defines 40 posture suggestions (nine male/masculine, thirteen female/feminine, six couples, six friends/groups, and six family examples), five camera positions, implementation tasks, and acceptance criteria. The native implementation presents a category-first package chooser, tags each pose's suitable setting, recommends camera angle and lighting for every pose, and provides manually confirmed sequences. The full-frame preview alignment implementation and Dart-core parity are included. See [phone testing](phone_testing.md) for build instructions, automated validation, and the physical-device acceptance checklist.

**Landscape packages:** The Landscape situation now exposes a separate Landscape control and category-first chooser. Mountains, Lakes & Water, Plains & Fields, and Plants & Gardens provide 24 photo-based composition recipes with two cues, automatic camera-angle and light recommendations, and safety guidance. Live horizon coaching remains visible with the selected recipe. See [Landscape composition packages](landscape_packages.md) for status and deferred filter, guided-step, and Auto work.

**Camera control extension:** [Camera Control and Assisted Professional Mode](camera_control.md) defines runtime capability discovery, Auto/Assisted/Manual behavior, device-specific fallbacks, recommendation rules, professional capture formats, and a staged implementation plan. The design intentionally avoids assuming that phones or cameras share the same lenses, ranges, or output capabilities.

---

## 1. Objective

Build a V1 prototype that proves Dali Camera can give useful real-time photography advice without an LLM in the live camera loop.

The prototype should answer four questions:

1. Can the app reliably measure the scene in real time?
2. Can deterministic rules identify common photo problems?
3. Can the coaching controller choose one useful instruction at a time?
4. Do coached users take better photos than they would with the normal camera?

V1 should focus on one photographer taking a photo of one subject in a scenic outdoor environment.

---

## 2. V1 Functional Scope

### Must Test

The first implementation should test these capabilities:

- person detection,
- face detection,
- body position in frame,
- subject size,
- headroom,
- foot and limb cropping,
- camera tilt,
- horizon tilt,
- face exposure,
- backlighting,
- basic scenic preservation,
- camera stability,
- one-instruction coaching,
- shot readiness.

### Should Defer

These should not block V1 testing:

- group photos,
- couples,
- complex posing,
- automatic capture,
- user style learning,
- semantic scene understanding,
- LLM-generated advice,
- cloud analysis,
- post-capture editing.

---

## 3. Implementation Milestones

### Milestone 1: Camera Preview And Debug Overlay

Goal:

- show live camera preview,
- read device orientation and motion,
- render debug overlays on top of the preview.

Debug overlay should show:

- frame bounds,
- detected person box,
- detected face box,
- pose keypoints when available,
- horizon line when available,
- roll angle,
- exposure measurements,
- current detected issues.

Acceptance criteria:

- preview is smooth enough for handheld use,
- debug overlay aligns with camera content,
- motion/orientation values update live,
- app can run for several minutes without overheating noticeably.

### Milestone 2: Vision Measurement Layer

Goal:

- produce stable normalized measurements from camera frames.

Required measurements:

```text
person_box
face_box
pose_keypoints
body_mask or body_bounds
face_luminance
background_luminance
horizon_angle
horizon_y
camera_roll
camera_motion
sky_or_open_area_ratio
```

All coordinates should be normalized to the visible preview frame:

```text
x: 0.0 left -> 1.0 right
y: 0.0 top  -> 1.0 bottom
```

Acceptance criteria:

- person and face measurements remain stable during small hand movements,
- missing measurements are represented explicitly,
- confidence is tracked for every measurement,
- downstream rules can run even when some measurements are unavailable.

### Milestone 3: Deterministic Rule Engine

Goal:

- convert measurements into structured photographic issues.

Each issue should include:

```text
type
severity
confidence
priority
recipient
instruction
success_condition
cooldown_ms
```

Initial issue types:

- `subject_missing`,
- `face_missing`,
- `subject_too_close`,
- `subject_too_far`,
- `headroom_too_large`,
- `headroom_too_small`,
- `feet_cropped`,
- `limb_cropped`,
- `camera_tilted`,
- `horizon_tilted`,
- `face_underexposed`,
- `subject_backlit`,
- `scene_excluded`,
- `camera_unstable`.

Acceptance criteria:

- obvious test cases trigger the expected issue,
- low-confidence measurements do not produce confident advice,
- issues include numeric reason data for debugging,
- rules are unit-testable without a camera.

### Milestone 4: Coaching Controller

Goal:

- choose one stable, high-value instruction at a time.

Controller behavior:

- prioritize severe problems first,
- wait for an issue to persist before showing advice,
- keep advice visible for a minimum duration,
- avoid switching rapidly between instructions,
- detect whether the user improved the issue,
- transition to ready state when no high-priority issues remain.

Acceptance criteria:

- no rapid oscillation between opposite instructions,
- no more than one active instruction is shown,
- repeated advice is rate-limited,
- successful user movement clears or changes the instruction,
- ready state appears when the scene is acceptable and stable.

### Milestone 5: User-Facing Advice UI

Goal:

- replace debug output with clear camera coaching UI.

Advice UI should support:

- short text,
- directional indicator,
- photographer vs. subject recipient,
- ready state,
- subtle haptic feedback where useful.

Acceptance criteria:

- advice is readable outdoors,
- advice does not cover the face or main subject,
- instructions are understandable without onboarding,
- UI remains usable in portrait and landscape orientation.

### Milestone 6: Field Test Build

Goal:

- test the app in real scenic locations with real users.

The build should include:

- normal capture,
- Dali-coached capture,
- optional debug recording,
- timestamped instruction log,
- final measurement summary,
- basic session metadata.

Acceptance criteria:

- testers can complete a photo session without developer assistance,
- logs make it possible to understand what advice was shown and why,
- captured photos can be compared against normal camera photos.

---

## 4. Rule Test Plan

### Subject Missing

Test scenes:

- no person in frame,
- person partially entering frame,
- person fully visible.

Expected:

- no ready state when subject is missing,
- guidance should ask photographer to frame the person,
- issue should clear when person is visible with adequate confidence.

### Face Missing

Test scenes:

- subject facing camera,
- subject turned away,
- face blocked by hat/hair/shadow,
- subject too far for face detector.

Expected:

- app should not assume face quality when face is not detected,
- advice may ask subject to face camera or photographer to step closer,
- severity should depend on intended photo type.

### Subject Too Close

Test scenes:

- face-only crop,
- upper-body crop,
- full-body scenic photo,
- body touching multiple frame edges.

Expected:

- app suggests stepping back or including more of the view,
- issue clears when subject size enters target range.

### Subject Too Far

Test scenes:

- subject tiny in landscape,
- subject moderately small but acceptable,
- subject at target size.

Expected:

- app suggests stepping closer or asking subject to step closer,
- app does not overcorrect when scenery should remain important.

### Headroom

Test scenes:

- too much sky above head,
- head nearly touching top edge,
- good headroom.

Expected:

- app suggests adjusting camera height or framing,
- issue ignores temporary pose/keypoint jitter.

### Feet And Limb Cropping

Test scenes:

- feet intentionally cropped in half-body portrait,
- feet accidentally clipped in full-body scenic shot,
- hand or elbow cut off near edge,
- full body visible.

Expected:

- app distinguishes acceptable half-body framing from accidental full-body cropping when possible,
- app suggests stepping back or lowering camera,
- issue clears when body no longer touches problematic edge.

### Tilt And Horizon

Test scenes:

- level horizon,
- horizon tilted left,
- horizon tilted right,
- no visible horizon but device roll available,
- buildings or railings with strong horizontal lines.

Expected:

- app suggests tilt correction only when confidence is high,
- visual horizon and IMU roll should be reconciled,
- app avoids tilt advice when scene has no reliable reference.

### Exposure And Backlighting

Test scenes:

- face evenly lit,
- face in shadow with bright background,
- strong sunset backlight,
- low-light scene,
- subject facing light.

Expected:

- app detects when face is much darker than background,
- advice prefers repositioning or turning toward light,
- app avoids impossible advice when overall scene is dark.

### Scenic Preservation

Test scenes:

- person blocking most of view,
- too much empty sky,
- scenery excluded by tight crop,
- balanced person plus background.

Expected:

- app suggests stepping back or including more of the view,
- rule uses simple area and segmentation heuristics,
- app does not need to know the semantic importance of the scenery.

### Camera Stability

Test scenes:

- steady handheld,
- walking while framing,
- shaking phone,
- stable after adjustment.

Expected:

- app delays ready state while unstable,
- app may show Hold steady,
- other advice should not flicker during movement.

---

## 5. Test Data Strategy

### Synthetic And Fixture Tests

Use still images and recorded clips to test rules repeatedly.

Fixture categories:

- good scenic portrait,
- cropped feet,
- too much headroom,
- tilted horizon,
- backlit face,
- subject too small,
- subject too large,
- no person,
- person off-center,
- scenery mostly excluded.

Each fixture should include expected issue labels.

### Live Indoor Tests

Use indoor testing for rapid iteration:

- face detection,
- body framing,
- headroom,
- cropping,
- exposure contrast,
- instruction stability.

Indoor tests should not be used as the final proof of scenic-photo quality.

### Outdoor Field Tests

Use real outdoor locations:

- park,
- hill/viewpoint,
- beach or lake,
- street viewpoint,
- monument or landmark.

For each session, capture:

- normal camera photo,
- Dali-coached photo,
- instruction timeline,
- final readiness score,
- tester feedback.

---

## 6. Product Test Protocol

Each test session should use the same basic flow:

1. Photographer takes a normal photo without Dali coaching.
2. Photographer takes a Dali-coached photo of the same subject and scene.
3. Photographer rates whether the coaching was helpful or annoying.
4. Subject rates whether the direction felt natural.
5. Independent reviewers compare the normal and coached photos.

Important test questions:

- Which photo would the user keep?
- Which photo better shows the person?
- Which photo better preserves the place?
- Did the advice feel easy to follow?
- Did the app give too much advice?
- Did the app ever feel wrong or unstable?
- How long did the coached capture take?

---

## 7. Metrics

### Product Quality Metrics

- coached photo preference rate,
- user keep/share preference,
- average time to capture,
- average number of instructions per capture,
- percentage of instructions followed,
- percentage of sessions reaching ready state,
- percentage of sessions abandoned,
- percentage of users who disable coaching.

### Technical Metrics

- person detection confidence,
- face detection confidence,
- pose/keypoint stability,
- horizon confidence,
- rule precision per issue type,
- rule recall per issue type,
- instruction reversal rate,
- instruction dwell time,
- ready-state false positive rate,
- ready-state false negative rate,
- frame processing latency,
- model frequency,
- battery drain,
- thermal state.

### UX Metrics

- advice comprehension,
- perceived helpfulness,
- perceived annoyance,
- trust in advice,
- subject comfort,
- photographer confidence.

---

## 8. Logging Requirements

For test builds, log enough information to debug decisions without saving unnecessary image data.

Recommended session log:

```text
session_id
timestamp
device_model
orientation
measurement_confidences
detected_issues
selected_instruction
instruction_start_time
instruction_end_time
success_or_timeout
readiness_score
capture_time
```

Image or video retention should be optional and explicit.

Privacy default:

- no uploaded frames,
- no retained camera frames unless test mode is enabled,
- clear labeling for any debug recording.

---

## 9. Acceptance Criteria For V1 Prototype

The V1 prototype is successful enough to continue if:

- it can run live on a phone,
- it detects the main framing and lighting problems reliably enough for field testing,
- advice remains stable during normal handheld movement,
- users understand the advice without explanation,
- most sessions produce no more than three instructions before ready state,
- coached photos are preferred over normal photos in a meaningful percentage of tests,
- battery and heat are acceptable for short outdoor sessions.

Suggested initial target:

```text
Coached photo preferred:          > 60%
Advice followed:                  > 70%
Instruction reversal rate:        < 10%
Median instructions per capture:  <= 3
Median coached capture time:      <= 30 seconds
Ready-state false positives:      low enough to preserve user trust
```

These are starting targets, not final product benchmarks.

---

## 10. Implementation Order

Recommended order:

1. Build camera preview and debug overlay.
2. Add person and face detection.
3. Add normalized measurement model.
4. Add deterministic rules for subject size, cropping, headroom, and tilt.
5. Add simple issue scoring.
6. Add coaching controller with hysteresis.
7. Add user-facing advice UI.
8. Add readiness state.
9. Add exposure and backlighting rules.
10. Add scenic preservation heuristics.
11. Add logging for field tests.
12. Run indoor fixture tests.
13. Run outdoor field tests.
14. Tune thresholds and priority order.

This order proves the core interaction before spending time on advanced scene understanding.

---

## 11. Current Prototype Status

Implemented in the iOS prototype:

- live AVFoundation camera preview,
- still photo capture to Photos,
- front/back camera switching,
- Vision person rectangle detection,
- Vision face rectangle detection,
- Vision body pose keypoint extraction for debug display,
- Vision horizon-angle measurement when available,
- normalized preview-space boxes and keypoints,
- sampled face/background luminance,
- sampled sky/open-area ratio for scenic-preservation heuristics,
- CoreMotion roll and rotation-rate motion measurement,
- deterministic rules for the initial V1 issue set,
- focused `CoachingEngine` unit tests for initial V1 rules,
- one-instruction coaching controller with stability delay and repeat cooldown,
- timestamped JSON Lines session logging for advice changes and captures,
- debug-panel log sharing for field-test review,
- AVFoundation session configuration isolated from SwiftUI state to keep Swift 6 builds clean,
- saved-photo review mode using `PhotosPicker` to run the coaching algorithm on existing images,
- suggested-reframe crop overlay for still-photo coaching fixtures,
- swipe comparison between the original photo and a generated reframed crop,
- saved-photo tilt testing with a generated leveled comparison image,
- manual saved-photo tilt fixture buttons for deterministic `Tilt left` / `Tilt right` UX tests,
- debug overlays for boxes, keypoints, horizon line, issue labels, and measurement values.

Current heuristic limitations:

- `body_mask` is not implemented yet; person bounds come from Vision rectangles and face fallback.
- `horizon_y` is a placeholder midpoint until the horizon observation is projected more precisely.
- `sky_or_open_area_ratio` is a lightweight top-third brightness/blue heuristic, not semantic scene understanding.
- `cameraStable` currently uses motion magnitude, while tilt advice separately uses roll.
- log review workflow still needs reviewer tooling outside the app.

Recommended next implementation step:

1. Use saved-photo review mode to build a small fixture set of good/cropped/backlit/tilted/scenic photos.
2. Compare suggested reframe overlays against human-preferred crops.
3. Compare leveled images against tilted originals to tune horizon thresholds.
4. Tune thresholds from those fixtures and real iPhone footage.
5. Add a more precise `horizon_y` projection or hide the horizon line until projection is trustworthy.
6. Add reviewer tooling to summarize exported JSONL logs.

---

## 12. Open Technical Choices

The implementation should still choose:

- mobile framework,
- camera library,
- on-device person detection model,
- pose estimation model,
- segmentation model,
- horizon detection approach,
- storage format for test logs,
- field-test review workflow.

Important selection criteria:

- real-time performance,
- on-device support,
- model size,
- battery impact,
- iOS and Android availability,
- ease of debugging,
- licensing.

---

## 13. First Prototype Definition

The first useful prototype can be smaller than full V1.

Prototype 0 should do only this:

- detect a single person,
- detect face box,
- estimate subject size and headroom,
- detect obvious foot cropping,
- detect camera roll,
- show one instruction at a time,
- show Ready when no obvious issue remains.

Prototype 0 advice vocabulary:

- Step back.
- Step closer.
- Raise camera.
- Lower camera.
- Tilt left.
- Tilt right.
- Keep their feet in frame.
- Hold steady.
- Ready.

If Prototype 0 feels helpful, the product has a real foundation.
