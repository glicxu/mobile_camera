# Dali Camera Prototype 1: Pose Recommendation Engine Plan

**Status:** Prototype 1 image-review engine successful; live camera coaching still needs field testing and tuning
**Builds on:** Prototype 0 loaded-image review and deterministic coaching engine
**Purpose:** Explore how far deterministic algorithms can go for pre-capture advice that is hard to fix after the photo is taken.

---

## 0. Current Checkpoint

**Last updated:** 2026-08-24 15:22 PDT

Prototype 1 has succeeded as a loaded-image review and tuning prototype. The app can load single images or folders, analyze them, show the selected result variant, inspect metrics, and compare changed images full-screen. This is enough to keep testing deterministic pose/group/beautify ideas against existing photos.

Done:

- loaded-image and folder slideshow review,
- original, reframed, leveled, tilt-test, and beautified variants,
- full-screen zoom inspection and original/current reveal comparison,
- deterministic pose and face landmark measurements on loaded images,
- posture/face issue generation for loaded-image review,
- pose package architecture with Natural, Feminine, Masculine, Professional, and Group packages,
- Group Portrait module with people/face counts, face visibility, edge crowding, and spacing metrics,
- first group portrait advice rules,
- batch analyzer exports pose, face, lighting, and group metrics,
- app installed and launched on the connected iPhone.

Not done:

- threshold tuning against larger image sets,
- true group-photo fixture testing,
- deciding which posture/group rules are stable enough for live camera,
- live-camera field testing with real people,
- promoting selected posture/group advice into live camera guidance,
- reducing known noisy signals such as `arms_flat_against_body`.

Current conclusion:

```text
Prototype 1 image-review engine: done enough to pause and resume later.
Prototype 1 live camera coaching: not done; needs field tests and tuning.
```

---

## 1. Objective

Prototype 1 should test whether Dali can become a useful pose recommendation engine before the shutter is pressed.

Prototype 0 proved that loaded images can demonstrate reframing, leveling, and lighting analysis. Many of those issues can be improved after capture. Prototype 1 should focus on problems that usually require a new photo:

- posture,
- face direction,
- body angle,
- hands and arms,
- occlusion,
- expression readiness,
- small clothing/detail distractions.

The goal is not to identify the person, judge beauty, or classify sex/ethnicity. The goal is to detect visible pose facts, estimate how strong those signals are, and choose short posing tips from a profile-aware advice library.

Implementation order:

1. Run the same deterministic pose engine on loaded/existing images first.
2. Test body and silhouette signals against existing images before using them as advice triggers.
3. Tune pose metrics, thresholds, and wording using the review/debug UI.
4. Promote the same rules into live camera coaching only after loaded-image behavior is understandable and useful.

---

## 1.1 Pose Recommendation Principle

The app should recommend poses, not infer identity.

Use these inputs:

- user-selected posing profile or intent,
- visible body geometry,
- pose and face landmarks,
- framing constraints,
- background and lighting context,
- rough body/silhouette features only when their detection strength is measurable.

Do not label the person as male, female, Asian, or any other identity. If posing differs by style, let the user select a style or goal instead:

```text
Neutral / natural
Feminine
Masculine
Professional
Elegant
Friendly / cute
Fashion
Travel / scenic
Full body
Group portrait
```

The same detected signal can map to different advice by profile:

```text
body_too_square + Feminine: Angle one shoulder away
body_too_square + Masculine: Turn chin slightly, keep shoulders strong
body_too_square + Neutral: Turn slightly
arms_flat_against_body + Feminine: Create space at the waist
arms_flat_against_body + Masculine: Relax arms away from torso
arms_flat_against_body + Neutral: Separate arm from body
```

---

## 1.2 Pose Tip Library And Packages

The pose engine should be structured as a reusable library, not a fixed list of hardcoded prompts.

Core separation:

```text
Vision measurements -> pose/body signals -> pose tip library -> selected packages -> ranked recommendations
```

The detection layer should stay shared and deterministic. New posing knowledge should usually be added as data/configuration, not by rewriting the Vision measurement code.

### Pose Tip

Each tip should be a small, testable unit:

```text
id
title
instruction
recipient
profile_tags
style_tags
shot_tags
required_signals
trigger_thresholds
confidence_rules
priority
cooldown_ms
success_condition
reason_template
examples
```

Example:

```text
id: create_waist_space
instruction: Create space at the waist
profile_tags: feminine, fashion, full_body
required_signals: arm_body_gap_left, arm_body_gap_right, torso_visibility_score
success_condition: arm-body gap increases or arms_flat_score falls
```

### Pose Package

A package is a curated set of tips for a goal or taste:

```text
Natural portrait
Feminine portrait
Masculine portrait
Professional headshot
Elegant full body
Cute / friendly
Fashion editorial
Travel scenic
Couple posing
Group portrait
User favorites
```

Packages can:

- include or exclude tips,
- change wording,
- change thresholds,
- change priorities,
- prefer subject-facing advice or photographer-facing advice,
- define examples for the tutor/onboarding screen.

### User-Selectable Sets

Users should eventually be able to select one or more favorite packages.

Prototype behavior:

```text
selected_package = Neutral / natural
optional_secondary_package = none
```

Future behavior:

```text
selected packages:
- Elegant full body
- Travel scenic
- My favorites
```

Recommendation ranking should only consider tips from selected packages, plus a small set of universal safety/composition tips such as face visibility, hand cropping, severe backlight, and camera tilt.

Favorite sets should be stored as user preferences and should not require retraining the detection layer.

---

## 2. Product Principle

Prototype 1 advice should feel like a helpful photographer, not a critic.

Good advice:

- is specific,
- is physically actionable,
- can be completed in one movement,
- avoids negative wording,
- explains only one thing at a time,
- improves the next photo more than post-capture editing could.

Avoid advice that sounds subjective or judgmental:

- "You look awkward",
- "This is unflattering",
- "Pose better",
- "Smile naturally",
- "Look confident".

Prefer direct prompts:

- "Relax shoulders",
- "Turn slightly left",
- "Move hand from face",
- "Stand taller",
- "Look at the camera".

---

## 3. Prototype 1 Scope

### Must Test

- pose keypoint quality on live camera and loaded images,
- shoulder posture,
- body angle,
- face direction,
- hand near face,
- hidden or missing arms,
- feet and ankle visibility,
- head and chin position if face landmarks are reliable, started,
- one posture instruction at a time,
- loaded-image pose debug mode for tuning.

### Should Test If Time Allows

- eye openness,
- smile/readiness proxy,
- sunglasses or face obstruction,
- hair covering face, started through generic face/eye occlusion,
- bag strap or object across torso,
- group spacing for two or more people, started.

### Should Defer

- full aesthetic scoring,
- fashion/style recommendations,
- complex posing sequences,
- body shape judgments,
- cultural pose preference modeling,
- LLM-generated pose critique,
- automatic body reshaping or face editing.

---

## 4. Measurement Layer

Prototype 1 should extend the existing `Measurements` model or add a companion pose analysis model.

Required raw inputs:

```text
person_box
face_box
pose_keypoints
face_landmarks
left_shoulder
right_shoulder
left_elbow
right_elbow
left_wrist
right_wrist
left_hip
right_hip
left_knee
right_knee
left_ankle
right_ankle
```

Current implementation uses Vision face landmark observations for loaded images and live measurements, but posture/face-direction rules are only included in loaded-image advice while thresholds are being tuned.

Group portrait analysis has been added as a separate package-specific module on top of the shared measurement layer. It uses the same loaded-image and live detection pass, then records group counts and layout metrics without changing the core person/pose/face rules.

Derived metrics:

```text
pose_confidence
visible_keypoint_count
shoulder_line_angle
shoulder_height_asymmetry
shoulder_to_ear_distance
torso_angle
face_yaw_estimate
face_pitch_estimate
wrist_to_face_distance
elbow_to_torso_distance
arm_visibility_score
leg_visibility_score
stance_width
head_to_torso_ratio
```

Candidate body/silhouette strength signals:

```text
shoulder_to_hip_width_ratio
torso_visibility_score
waist_clearance_score
arm_body_gap_left
arm_body_gap_right
silhouette_readability_score
stance_symmetry
weight_shift_proxy
body_line_angle
upper_body_openness
people_count
face_count
group_bounds
face_visibility_ratio
edge_crowding_score
group_spacing_score
```

These are composition features, not identity features. They should appear in debug and reports before they affect coaching.

Coordinate rule:

```text
x: 0.0 left -> 1.0 right
y: 0.0 top  -> 1.0 bottom
```

Acceptance criteria:

- each metric reports confidence,
- missing keypoints do not crash the analysis,
- rules can explain which metric triggered advice,
- loaded-image and live-camera analysis use the same metric definitions.
- body/silhouette signals are tested on existing image folders before becoming visible advice.

---

## 5. Deterministic Advice Areas

### Posture

Issue types:

```text
shoulders_high
shoulders_uneven
torso_slouched
body_too_square
body_too_profile
```

Advice vocabulary:

```text
Relax shoulders
Stand taller
Turn slightly left
Turn slightly right
Angle body toward camera
```

Possible signals:

- shoulders high relative to face or neck,
- head too close to shoulder line,
- torso compressed vertically,
- shoulder line too flat and square to camera,
- shoulder/hip relationship too profile for the intended portrait.

### Hands And Arms

Issue types:

```text
hand_near_face
arm_hidden
arms_flat_against_body
hand_cut_off
```

Advice vocabulary:

```text
Move hand from face
Show both arms
Separate arm from body
Keep hands in frame
```

Possible signals:

- wrist overlaps or nearly touches face box,
- one arm keypoint chain is missing while body is visible,
- elbow/wrist keypoints are too close to torso centerline,
- wrist is near or beyond image edge.

### Face Direction

Issue types:

```text
face_turned_away
face_too_profile
chin_too_high
chin_too_low
```

Advice vocabulary:

```text
Look at the camera
Turn face slightly left
Turn face slightly right
Lower chin slightly
Lift chin slightly
```

Possible signals:

- face box missing while person box is strong,
- eye/nose/mouth landmarks asymmetric, started,
- face box aspect and landmark positions suggest profile,
- landmark geometry suggests face pitch, started.

### Occlusion

Issue types:

```text
face_occluded
eyes_occluded
hair_on_face
object_in_front
```

Advice vocabulary:

```text
Clear the face
Move hair from face
Move object aside
Show your eyes
```

Possible signals:

- low-confidence face landmarks inside a detected face, started,
- eyes missing while face box is present, started,
- hand or wrist overlaps face,
- object/person box overlap blocks face region.

### Readiness

Issue types:

```text
pose_unstable
eyes_not_ready
subject_not_facing
```

Advice vocabulary:

```text
Hold that pose
Look here
Ready
Take it
```

Possible signals:

- pose keypoints moving rapidly across recent frames,
- face/eye landmarks unstable,
- subject gaze or face direction not aligned,
- all major issues clear for a stable duration.

### Group Portrait

Issue types:

```text
group_faces_missing
group_edge_crowded
group_spacing_wide
```

Advice vocabulary:

```text
Make every face visible
Leave space at the edges
Bring everyone closer together
Face the camera
Look here
Hold that pose
```

Possible signals:

- multiple person boxes or multiple face boxes are detected,
- detected face count is low relative to detected people count,
- the combined group bounds sit too close to an image edge,
- horizontal spacing between people is wide relative to average person width.

Current prototype rule:

```text
shared measurements -> group analysis -> Group package -> group portrait issues
```

This is the first test of the module architecture. Future modules should follow the same shape: add measurement fields only when needed, keep module rules isolated, and expose the module through a selected package.

---

## 6. Rule Engine Shape

Prototype 1 should reuse the existing issue format:

```text
type
severity
confidence
priority
recipient
instruction
success_condition
cooldown_ms
reason_data
tone
```

Priority should favor issues that cannot be repaired later:

1. face not visible or occluded,
2. hands covering face,
3. posture/body angle,
4. missing arms/hands/feet,
5. expression/readiness,
6. general framing and lighting from Prototype 0.

The engine should continue to show only one instruction at a time.

### Profile-Aware Recommendation Layer

Add a layer between detection and final advice:

```text
measurements -> pose_signals -> pose_tip_library -> selected_packages -> candidate_tips -> priority -> selected_advice
```

Each candidate tip should include:

```text
tip_id
signal_type
signal_strength
confidence
package
profile_tags
instruction
reason_data
safe_to_show
```

Rules:

- identity labels are not inputs,
- user-selected package/profile can change wording and priority,
- body/silhouette signals start as debug-only,
- a signal graduates to advice only after image-folder tests show it is useful and not too noisy.

---

## 7. Prototype UI

### Loaded-Image Pose Debug Mode

Add a review mode that shows:

- original photo,
- skeleton overlay, started,
- face landmarks if available,
- pose metric values, started,
- detected posture chips, started,
- selected instruction, started.
- visual analysis page with image overlay and side/bottom diagnostic panel, started.

This should be the first tuning surface because it makes deterministic rules easier to inspect.

### Live Camera Mode

Show the same advice card pattern already used in Prototype 0:

```text
Subject: Look at the camera
Subject: Relax shoulders
Subject: Move hand from face
Photographer: Keep hands in frame
Camera: Great shot
```

Keep debug overlays behind a toggle.

---

## 8. Test Plan

### Loaded Image Fixtures

Create or collect image sets for:

- relaxed shoulders vs raised shoulders,
- body square vs slightly angled,
- hand near face vs clear face,
- arms visible vs one arm hidden,
- chin high vs neutral,
- chin low vs neutral,
- face forward vs turned away,
- feet visible vs cropped,
- stable pose vs motion blur.
- visible waist/torso shape vs hidden body line,
- arms separated from torso vs pressed against torso,
- shoulder-to-hip relationship clear vs ambiguous,
- stance balanced vs weight shifted,
- upper body open vs closed.
- small group with all faces visible vs hidden faces,
- group near image edge vs comfortable edge spacing,
- group spread apart vs tighter spacing.

For each fixture, record:

```text
expected_issue
expected_instruction
metric_values
pass/fail
notes
```

### Body Signal Strength Report

Run a batch analysis over existing folders, starting with:

```text
~/Downloads/test_photos
```

For each image, record:

```text
file
pose_keypoint_count
pose_confidence
person_box_area
shoulder_to_hip_width_ratio
torso_visibility_score
waist_clearance_score
left_arm_body_gap
right_arm_body_gap
silhouette_readability_score
stance_symmetry
weight_shift_proxy
body_line_angle
upper_body_openness
triggered_pose_tips
group_people_count
group_face_count
group_face_visibility_ratio
group_edge_crowding_score
group_spacing_score
human_notes
```

For each signal, evaluate:

```text
coverage: how often the required landmarks exist
stability: whether duplicate/similar images produce similar values
separation: whether good and bad examples differ clearly
noise: whether the signal fires on too many normal photos
usefulness: whether the resulting advice would improve the next shot
```

Initial known finding from the current image set:

- `arms_flat_against_body` fires on 5/5 images, so it is likely too eager and should stay experimental until the arm/body gap signal is improved.
- group metrics are now exported in the batch report and JSON, but they need group-photo fixtures before thresholds can be trusted.

### Live Field Tests

Test one subject outdoors and indoors:

- standing portrait,
- scenic full-body photo,
- waist-up portrait,
- walking pose,
- seated pose,
- backlit subject,
- subject holding phone/bag/drink.

Acceptance criteria:

- advice appears only when confidence is adequate,
- advice clears when the subject follows it,
- no rapid switching between posture prompts,
- prompts feel respectful and understandable,
- the final photo is visibly better than an unguided baseline.

---

## 9. Risks

- Pose keypoints may be unreliable with loose clothing, seated subjects, or partial bodies.
- Face landmarks may fail on small or backlit faces.
- Some posture advice can feel personal if phrased poorly.
- Deterministic thresholds may vary by body type, camera angle, and cultural posing preference.
- Live performance may degrade if too many Vision requests run on every frame.

Mitigations:

- start with loaded-image debug mode,
- require confidence thresholds,
- prefer neutral wording,
- log metric values for every shown instruction,
- throttle pose analysis in live mode,
- keep posture advice optional during early tests.

---

## 10. Milestones

### Milestone 1: Pose Metrics Debug Surface

- show pose skeleton on loaded images with connected lines, started,
- compute derived pose metrics, started,
- show raw pose and face metric values and confidence, started,
- log detected pose issues, started.
- add in-app visual analysis viewer for loaded images, started.
- support slideshow/folder review for faster image-set testing, started.
- move debug text into the analysis panel instead of covering the original photo, started.

### Milestone 1.5: Body Signal Strength Testing

- add body/silhouette signal calculations as debug-only metrics,
- update batch analyzer to export body signal values,
- update desktop/in-app analysis views to show those values,
- run against existing image folders,
- mark each signal as strong, weak, noisy, or blocked,
- keep weak/noisy signals out of visible coaching.

### Milestone 2: First Pose Recommendation Rules

- implement `hand_near_face`, started,
- implement `arm_hidden`, started,
- implement `body_too_square`, started,
- implement `shoulders_high`, started,
- add unit tests with synthetic measurements, started.
- add selected posing profile,
- map current pose issues to profile-aware advice vocabulary.

### Milestone 2.5: Pose Tip Library

- define a `PoseTip` data model, started,
- define a `PosePackage` data model, started,
- move current pose advice wording into built-in package overrides, started,
- add package selection to image review mode, started,
- show active package in the analysis panel, started,
- add a user favorites package placeholder,
- make future tips additive without changing the measurement layer.

### Milestone 2.6: Group Portrait Module

- add `GroupAnalysis` to shared measurements, done,
- count multiple people and faces in loaded-image analysis, done,
- count multiple people and faces in live measurement pass, done,
- add the Group package to the package selector, done,
- add group metrics to the in-app analysis panel, done,
- export group metrics in the batch markdown and JSON reports, done,
- implement first group rules for face visibility, edge spacing, and group spacing, done,
- tune thresholds using real group-photo fixtures.

### Milestone 3: Face Direction Rules

- add face landmark extraction, started,
- estimate face yaw/pitch, started,
- implement `face_turned_away`, started,
- implement `chin_too_high` and `chin_too_low` as experimental loaded-image rules.

### Milestone 3.5: Additional Hard-To-Fix Rules

- implement `face_occluded`, started,
- implement `eyes_occluded`, started,
- implement `arms_flat_against_body`, started,
- implement `hand_cut_off`, started,
- implement `body_too_profile`, started.

### Milestone 4: Live Coaching Integration

- run pose measurement in live camera mode, started,
- keep pose rules out of live camera advice until loaded-image tuning is reliable, started,
- merge pose issues with Prototype 0 issues,
- tune priority and cooldown,
- verify no instruction flicker.

### Milestone 5: Field Test

- test with real subjects,
- compare unguided vs Dali-guided photos,
- review logs,
- adjust thresholds and vocabulary.

---

## 11. Definition Of Success

Prototype 1 succeeds if deterministic rules can reliably provide at least three useful hard-to-fix pre-capture prompts:

```text
Look at the camera
Move hand from face
Relax shoulders
Turn slightly left/right
Show both arms
```

The advice should be understandable, respectful, and visibly improve the next photo.

Pose recommendation becomes strong enough for live camera only when at least three pose/silhouette signals show acceptable coverage, stability, and usefulness on existing images.
