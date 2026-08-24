# Dali Camera

## Product And Technology Design

**Working tagline:** A professional photographer beside you.

**Status:** V1 product and technical design
**Initial platform:** Mobile, iOS and Android
**Initial mode:** One person + scenic environment
**Core technical direction:** Real-time computer vision plus deterministic coaching rules, without an LLM in the live camera loop

---

## 1. Product Vision

Dali Camera helps ordinary people take better photographs while the photograph is being composed.

Most AI photography products focus on improving an image after capture:

```text
Take a photo -> AI improves the photo
```

Dali Camera focuses on improving the act of taking the photo:

```text
See the scene -> measure it -> coach the photographer -> take a better photo
```

The goal is not to replace the photographer or generate a better-looking synthetic image. The goal is to give the person holding the camera the judgment of a good photographer at the moment it matters.

V1 should feel like a calm side coach:

- Move slightly left.
- Step back.
- Lower the camera.
- Tilt slightly right.
- Keep their feet in frame.
- Turn them toward the light.
- Great. Take it.

The product succeeds when a normal person can hand their phone to a friend and get a noticeably better photo.

---

## 2. V1 Product Definition

### V1 Goal

Help one person take a noticeably better photograph of another person in a scenic environment.

Examples:

- hiking viewpoints,
- beaches,
- mountains,
- lakes,
- parks,
- monuments,
- city overlooks,
- travel photos,
- outdoor family snapshots.

This initial use case is valuable because the photographer must balance two important subjects:

1. the person,
2. the place.

A normal portrait mode may optimize the person while losing the scenery. A landscape-focused framing may preserve the view while making the person tiny or awkward. Dali Camera V1 should help the user find a better balance between both.

### V1 Promise

Dali Camera V1 should catch common, fixable mistakes before the shutter is pressed.

It should help with:

- person placement,
- subject size,
- headroom,
- foot and limb cropping,
- camera tilt,
- horizon alignment,
- face exposure,
- backlighting,
- basic camera height,
- basic scenic preservation,
- simple subject direction,
- shot readiness.

V1 does not need deep artistic understanding. It needs to reliably detect obvious photographic problems and give one useful instruction at a time.

---

## 3. Product Principles

### Help Before Capture

Dali Camera should help the photographer take a better real photograph, not rely on repairing a bad photograph later.

### One Instruction At A Time

A scene may contain several problems. The user should not see several instructions at once.

The coaching controller should select the most valuable current action and wait for the user to respond before offering another.

### Keep The Camera View Primary

The live camera preview is the main interface. Advice should appear near the edges of the screen whenever possible and should not obscure the subject or scenic content.

### Use Plain Photographer Language

Advice should be short, directional, and immediately actionable.

Good:

- Move left.
- Step back.
- Lower camera.
- Tilt right.
- Turn toward the light.
- Great shot.

Avoid:

- Improve the composition.
- Consider reframing based on the rule of thirds.
- Subject-background relationship is suboptimal.
- Lighting conditions are not ideal.

### Do Not Nag

The app should feel calm. Recommendations should be stable, sparse, and useful. A user should feel helped, not corrected every second.

### Do Not Block Capture

The user remains in control. Dali Camera may recommend waiting or adjusting, but it should not prevent the user from taking a photo.

---

## 4. V1 Non-Goals

V1 should not attempt to be:

- a Photoshop replacement,
- a generative image app,
- a full professional camera app,
- a social network,
- a cloud photo library,
- a general visual assistant,
- a style-learning photography tutor,
- a multi-person group posing system.

V1 should also avoid:

- complex aesthetic judging,
- automatic capture by default,
- cloud-only AI dependency,
- long explanations,
- many simultaneous overlays,
- advanced semantic reasoning about what makes a scene beautiful.

Every feature should be evaluated against one question:

> Does this help the user take a better photo before pressing the shutter?

---

## 5. V1 Advice Experience

### Core Loop

```text
Observe camera frame
  -> measure scene
  -> detect possible problems
  -> score and prioritize problems
  -> wait for stability
  -> show one instruction
  -> observe user response
  -> confirm improvement
  -> show next instruction or ready state
```

### Advice Placement

Advice should appear at the edge of the camera view and point in the direction of the action when possible.

```text
+--------------------------------------+
|                                      |
|  <- Move slightly left               |
|                                      |
|                                      |
|            LIVE CAMERA               |
|                                      |
|                                      |
|                       Lower camera v |
|                                      |
|             GREAT SHOT               |
+--------------------------------------+
```

### Advice Types

V1 should use a controlled advice vocabulary rather than free-form generated text.

#### Photographer Movement

- Move left.
- Move right.
- Step back.
- Step closer.
- Lower camera.
- Raise camera.

#### Camera Handling

- Tilt left.
- Tilt right.
- Hold steady.
- Switch to portrait.
- Switch to landscape.

#### Framing

- Keep their feet in frame.
- Give them more headroom.
- Put them slightly left.
- Put them slightly right.
- Include more of the view.
- Leave more space above them.

#### Lighting

- Turn them toward the light.
- Move them out of shadow.
- Try a slightly different angle.

#### Subject Direction

- Ask them to turn slightly left.
- Ask them to turn slightly right.
- Ask them to face the light.
- Ask them to step slightly forward.

#### Readiness

- Hold there.
- Great shot.
- Ready.
- Take it.

### Advice Priority

V1 should fix obvious failures before offering taste-level improvements.

Priority order:

1. Subject missing, face missing, or body severely cropped.
2. Feet, head, or limbs accidentally cut off.
3. Severe camera tilt or horizon tilt.
4. Subject too close or too far.
5. Poor headroom or awkward subject placement.
6. Face in deep shadow or strong backlight.
7. Scenic background mostly excluded or blocked.
8. Basic pose or subject direction.
9. Fine composition improvements.
10. Ready state.

---

## 6. Algorithmic V1 Feasibility

Most V1 coaching can be done without an LLM.

V1 should use machine learning models for perception, but deterministic algorithms for judgment and advice selection.

The distinction:

- ML vision models answer: What is visible in the frame?
- Deterministic rules answer: Is this framing problem worth correcting?
- The coaching controller answers: What should we tell the user right now?

No LLM is required to detect the main V1 issues.

### V1 Detection Capabilities

| Capability | Non-LLM approach |
| --- | --- |
| Detect one person | Person detector or segmentation model |
| Detect face | Face detector |
| Body position | Person bounding box, pose keypoints, body mask |
| Subject size | Person box area relative to frame area |
| Headroom | Distance from face/head top to frame top |
| Feet cropped | Ankle/foot keypoints, body mask touching lower frame |
| Limb cropped | Pose keypoints or mask touching frame edges |
| Face exposure | Brightness over face region |
| Backlighting | Face brightness compared with background brightness |
| Horizon tilt | Horizon detection, line detection, segmentation, IMU roll |
| Camera roll | Device motion sensors plus visual line analysis |
| Subject placement | Subject center compared with target composition zones |
| Too much sky | Sky segmentation ratio |
| Scenic preservation | Non-person visible area, sky/water/mountain/building segmentation |
| Hold steady | Gyroscope, accelerometer, optical flow |
| Ready state | Weighted score over framing, tilt, exposure, stability |

### Harder Without Higher-Level AI

Some features are possible later but should not define V1:

- identifying the most beautiful part of a scene,
- understanding that light rays are the visual center,
- knowing that a waterfall should be preserved,
- detecting subtle distracting background objects,
- evaluating sophisticated pose quality,
- adapting to a user's personal photographic style.

These can be introduced later through on-device semantic models, cloud vision models, or LLM-assisted scene strategy. They are not required for the first useful product.

---

## 7. Technical Architecture

V1 should use a hybrid real-time architecture:

```text
Camera frame
  -> sensor state
  -> vision measurement layer
  -> deterministic photography engine
  -> coaching controller
  -> advice renderer
```

### Layer 1: Camera And Sensor Input

Inputs:

- live camera frames,
- camera orientation,
- focal length or zoom level,
- gyroscope,
- accelerometer,
- exposure metadata when available.

The sensor layer helps distinguish actual composition problems from hand movement and device roll.

### Layer 2: Vision Measurement

This layer answers:

> What does the camera currently see?

V1 measurements:

- person bounding box,
- face bounding box,
- face landmarks if available,
- body pose keypoints,
- body segmentation mask,
- estimated head, torso, legs, and feet positions,
- frame brightness,
- face brightness,
- background brightness,
- sky or open-area segmentation,
- horizon or dominant horizontal line,
- image motion and camera stability.

This layer should run locally and frequently enough to support real-time feedback.

Target frequencies:

- camera preview: 30-60 FPS,
- lightweight tracking: 15-30 FPS,
- heavier pose or segmentation: 5-15 FPS,
- coaching decision update: 1-5 FPS.

Exact numbers should be determined through profiling on target devices.

### Layer 3: Deterministic Photography Engine

This layer converts measurements into scored photographic issues.

Examples:

```text
subject_center_x = 0.52
subject_height_ratio = 0.68
face_center_y = 0.31
headroom_ratio = 0.08
horizon_y = 0.47
horizon_angle = 4.2 degrees
face_luminance = 0.31
background_luminance = 0.67
camera_motion = low
```

The engine evaluates rules such as:

```text
if horizon_angle > 3 degrees:
    issue = camera_tilt_right
```

```text
if body_mask_touches_bottom and feet_keypoints_missing:
    issue = feet_cropped
```

```text
if face_luminance < background_luminance - threshold:
    issue = face_backlit
```

```text
if person_area_ratio > max_target_ratio:
    issue = subject_too_close
```

Each issue receives:

- issue type,
- confidence,
- severity,
- suggested instruction,
- intended recipient,
- cooldown period,
- success condition.

### Layer 4: Coaching Controller

This is the most important product layer.

It decides:

> What should Dali say right now?

Responsibilities:

- prioritize issues,
- suppress low-value advice,
- avoid oscillation,
- wait for measurement stability,
- avoid repeating the same instruction too often,
- give the user time to respond,
- detect whether an instruction helped,
- transition to ready state when quality is high enough.

The controller should behave more like a calm coach than a live debug console.

### Layer 5: Advice Renderer

This layer presents the selected instruction.

V1 rendering options:

- short text,
- directional arrow,
- subtle edge placement,
- readiness indicator,
- optional haptic confirmation.

The renderer should avoid covering faces, bodies, and important scene areas when possible.

---

## 8. Rule Examples

### Feet Cropped

Measurement:

- body mask touches bottom edge,
- ankle or foot keypoints are missing or outside frame,
- person box height suggests full-body composition was intended.

Advice:

- Photographer: Step back.
- Photographer: Lower camera slightly.

Success:

- feet or lower body visible,
- body mask no longer touches bottom edge,
- subject remains large enough.

### Too Much Headroom

Measurement:

- face/head top is far from upper frame,
- subject is vertically low,
- lower body is visible enough.

Advice:

- Raise camera slightly.
- Move them higher in the frame.

Success:

- headroom enters target range.

### Horizon Tilt

Measurement:

- horizon or dominant horizontal line angle exceeds threshold,
- IMU roll confirms device is tilted,
- condition persists for a short duration.

Advice:

- Tilt left.
- Tilt right.

Success:

- horizon angle returns within tolerance.

### Face In Shadow

Measurement:

- face luminance below target,
- face is much darker than background,
- exposure compensation alone may not solve the issue.

Advice:

- Turn them toward the light.
- Try a slightly different angle.

Success:

- face luminance improves relative to background.

### Subject Too Small

Measurement:

- person box area below target range,
- full environment dominates frame,
- face too small for a person + landscape photo.

Advice:

- Step closer.
- Ask them to step closer.

Success:

- subject area enters target range while preserving background.

### Subject Too Large

Measurement:

- person box area above target range,
- body or head close to frame edges,
- scenery mostly excluded.

Advice:

- Step back.
- Include more of the view.

Success:

- subject area enters target range,
- scenic area increases.

---

## 9. Scoring And Readiness

Dali Camera can maintain an internal shot readiness score. The score does not need to be shown to the user.

Example:

```text
Framing              88
Subject placement    84
Horizon              96
Lighting             78
Cropping             94
Scene preservation   86
Stability            91
-----------------------
Shot readiness       88
```

Readiness should consider:

- no severe cropping,
- face visible,
- subject size acceptable,
- tilt acceptable,
- exposure acceptable,
- camera stable,
- no high-priority unresolved issue.

User-facing states:

- Keep adjusting.
- Hold there.
- Ready.
- Great shot.

The readiness score should drive the coaching controller, not become a visible technical dashboard.

---

## 10. Stability And Hysteresis

Real-time measurements fluctuate. Dali Camera should not react to every frame.

An issue should generally be shown only when:

```text
severity exceeds threshold
and confidence exceeds threshold
and issue persists for N milliseconds
and no higher-priority issue exists
and the previous instruction is not still in cooldown
```

After giving advice, the controller should wait before changing its mind.

Example:

```text
instruction_shown = "Step back"
minimum_display_time = 1500 ms
response_window = 3000 ms
success_condition = subject_area_ratio enters target range
```

This prevents bad behavior such as:

- Move left.
- Move right.
- Move left.
- Tilt down.
- Step back.

The product should feel stable even when the raw measurements are noisy.

---

## 11. Privacy And Offline Design

V1 should be offline-first.

Core coaching should work without sending camera frames to a server.

Reasons:

- hiking and travel often happen with poor connectivity,
- camera frames are sensitive,
- latency matters,
- cloud processing adds cost,
- user trust is essential.

V1 privacy principles:

- analyze frames on device when practical,
- do not retain frames unnecessarily,
- do not transmit images by default,
- clearly disclose any optional cloud processing,
- make essential coaching useful offline.

Cloud AI may be useful later for advanced scene understanding, but it should not be required for the core V1 experience.

---

## 12. Performance And Battery

Continuous camera analysis can drain battery and heat the device.

Battery efficiency is a product requirement, especially for hiking and travel.

V1 strategies:

- run expensive models at lower frequency,
- track between detections rather than redetecting every frame,
- pause expensive analysis while waiting for user response,
- reduce analysis when the camera is stable,
- use device motion to avoid analyzing blurry transitional frames,
- prefer hardware-accelerated on-device ML,
- adapt model frequency based on battery and thermal state.

The app should remain comfortable to use for real outdoor photo sessions.

---

## 13. Suggested V1 Milestones

### Milestone 1: Measurement Prototype

Goal:

- show live camera preview,
- detect one person,
- detect face,
- estimate body box and keypoints,
- show debug overlays for measurements.

Success:

- measurements are stable enough to support deterministic rules.

### Milestone 2: Rule Engine Prototype

Goal:

- implement rules for tilt, cropping, headroom, subject size, and face exposure,
- output structured issues,
- show internal scoring.

Success:

- the system correctly identifies obvious problems in test scenes.

### Milestone 3: Coaching Controller

Goal:

- choose one instruction at a time,
- add hysteresis and cooldowns,
- detect success after an instruction,
- avoid oscillation.

Success:

- advice feels calm and followable during real camera use.

### Milestone 4: User-Facing Advice UI

Goal:

- place advice near camera edges,
- use arrows and short text,
- add ready state,
- avoid covering the subject.

Success:

- users understand what to do without reading instructions.

### Milestone 5: Field Test

Goal:

- compare normal camera photos against Dali-coached photos in real scenic locations.

Success:

- users follow advice,
- Dali photos are preferred,
- time-to-capture remains acceptable,
- users do not feel nagged.

---

## 14. Measuring Success

The primary success metric is not whether the system sounds intelligent.

It is:

> Did the user get a better photograph?

Testing should compare:

- A: normal camera photo,
- B: Dali-coached photo.

Independent reviewers or users should compare the results.

Metrics:

- overall preference,
- which photo the user would keep or share,
- subject presentation,
- scenic preservation,
- composition quality,
- lighting quality,
- percentage of suggestions followed,
- number of suggestions before capture,
- time from camera open to capture,
- recommendation reversals,
- percentage of sessions reaching ready state,
- percentage of users who disable coaching,
- repeat usage.

The most important qualitative question:

> Did Dali make the photographer feel more capable?

---

## 15. Later Extensions

After V1 works, Dali can add higher-level intelligence.

Possible later capabilities:

- identify the scenic feature that matters most,
- preserve waterfalls, mountains, sunsets, reflections, or landmarks,
- support couples and groups,
- support portrait-only mode,
- support scenic-only mode,
- detect better capture moments,
- suggest richer posing,
- learn user style preferences,
- optionally use cloud AI for scene strategy.

These should come after the core coaching experience proves useful.

---

## 16. Guiding Principle

Do not use AI to replace the photographer.

Use AI to help people see like photographers.

For V1, that means a practical, offline-first, algorithmic coach that catches common mistakes and gives one calm instruction at a time.
