# Dali Camera Beautify Plan

**Status:** Loaded-image beautify prototype implemented; capture/save workflow still pending
**Scope:** Post-capture image enhancement, separate from photographer guidance and pose coaching
**Purpose:** Add tasteful portrait polish features that help users appreciate the final photo while keeping the original image available for comparison.

---

## 0. Current Checkpoint

**Last updated:** 2026-08-24 15:22 PDT

The beautify module is implemented for loaded-image review and is separate from photographer guidance. It is ready for visual testing on existing photos, especially to tune the 0-10 strength mapping and decide how strong skin smoothing should feel.

Done:

- separate `BeautifyEngine`,
- `BeautifySettings` and `BeautifyResult`,
- configure-sheet Beautify section,
- persisted beautify strength and effect toggles,
- loaded-image Beautify section with 0-10 slider,
- Beautified review variant,
- face brightness, warmth, clarity, subject emphasis, and face-region smoothing effects started,
- level-10 skin smoothing made intentionally obvious,
- debug chips for applied beautify settings and smoothing values,
- full-screen zoom inspection,
- original/current reveal comparison,
- app installed and launched on the connected iPhone.

Not done:

- batch before/after export over `~/Downloads/test_photos`,
- visual scoring/tuning across multiple portraits,
- save/export/share of beautified images,
- applying beautify to captured photos,
- keeping captured original plus beautified result for pre-save comparison,
- better face/skin segmentation,
- background blur,
- blemish reduction,
- teeth/eye whitening.

Current conclusion:

```text
Loaded-image beautify prototype: done enough to test.
Camera-capture beautify workflow: not done.
```

---

## 1. Principle

Beautify is different from guidance.

Photographer guidance tells the user how to take a better next photo:

```text
Step closer
Tilt left
Face the light
Make every face visible
```

Beautify improves the photo after it is taken:

```text
brighten the face
smooth harsh texture
add warmth
emphasize the subject
soften the background
```

Prototype beautify should be conservative, reversible, and easy to compare against the original.

Avoid identity-changing edits:

- face slimming,
- body reshaping,
- eye enlargement,
- skin color classification,
- sex or ethnicity based beautify,
- irreversible automatic retouching.

---

## 2. Prototype Behavior

Start with loaded images first, matching the Prototype 0 and Prototype 1 testing pattern.

User flow:

```text
Load photo or folder
Select photo
Choose Beautify
Adjust strength 0-10
Swipe compare original vs beautified
Save/export later
```

The original image should always remain accessible.

Default:

```text
Beautify strength: 0
```

Recommended first visible control:

```text
Portrait polish: 0-10
```

---

## 3. First Feature Set

### Portrait Polish 0-10

A single master slider controls several mild adjustments.

```text
0: original
1-3: face brightness + slight warmth
4-6: add gentle skin smoothing + face clarity
7-10: clearly stronger smoothing + subject emphasis
```

The slider should feel like a camera app beautify feature, not a professional editing suite.

Prototype tuning note: level 10 should be visually obvious for skin smoothing so users can immediately understand what the beautify module is doing. Lower levels should remain more natural.

### Face Brightness

Use existing face/person detection and luminance analysis.

Effect:

```text
lift shadows and exposure near the face
protect highlights
blend softly into surrounding image
```

Why first:

- useful for backlit faces,
- connects to existing lighting detection,
- easy to understand visually.

### Skin Smoothing

Apply mild detail reduction around detected face regions.

Effect:

```text
reduce high-frequency texture
preserve major edges
avoid waxy skin
```

Prototype implementation can begin with a soft elliptical face mask. Later versions can use better segmentation.

### Warmth

Apply a small color temperature/tint adjustment.

Effect:

```text
slightly warmer portrait tone
avoid heavy orange cast
```

This should be subtle at all strengths.

### Face Clarity

Apply mild local contrast or sharpening around face details.

Effect:

```text
make eyes and face feel clearer
avoid sharpening skin texture too much
```

This should be paired carefully with smoothing.

### Subject Emphasis

Use a soft vignette or background/edge reduction.

Effect:

```text
keep face/person bright
slightly reduce edge distraction
```

This is easier than full background blur and works even without perfect person segmentation.

---

## 4. Deferred Features

### Background Blur

Good future feature, but mask quality matters.

Prototype option:

```text
blur outside person box with a soft mask
```

Risk:

- rough edges around hair and clothing,
- strange blur when person detection is inaccurate.

### Blemish Reduction

Possible later.

Risk:

- can remove natural detail,
- requires careful local detection.

### Teeth Or Eye Whitening

Defer until landmarks are reliable.

Risk:

- can look artificial,
- can fail badly if mouth/eye landmarks are wrong.

---

## 5. Architecture

Beautify should be its own image-processing module, not part of `CoachingEngine`.

Recommended shape:

```text
Still image
-> Vision measurements
-> BeautifySettings
-> BeautifyEngine
-> Beautified image
-> compare UI
```

Guidance path stays separate:

```text
Measurements
-> CoachingEngine
-> advice/issues
```

Shared inputs:

- face box,
- person box,
- face luminance,
- background luminance,
- image size.

Separate outputs:

- beautified image,
- beautify debug metrics,
- applied settings.

Suggested models:

```text
BeautifySettings
- strength: Int 0...10
- faceBrightnessEnabled: Bool
- skinSmoothingEnabled: Bool
- warmthEnabled: Bool
- clarityEnabled: Bool
- subjectEmphasisEnabled: Bool

BeautifyResult
- image
- settings
- faceDetected
- personDetected
- debugValues
```

### App-Level Configuration

The app should have one configuration surface instead of adding every new module control to the capture screen.

Recommended ownership:

```text
AppSettings
- shootingMode
- selectedPosePackage
- beautifySettings
- debugEnabled

CameraModel
- captures images
- produces shared measurements
- owns review images/results

CoachingEngine
- consumes measurements and selected guidance package
- returns advice/issues

BeautifyEngine
- consumes original image, measurements, and beautify settings
- returns beautified image/result
```

The capture screen should stay focused:

```text
top: title, configure, help, switch camera
center: camera preview and optional guidance
bottom: photo library, capture, reserved secondary action
```

The configure sheet should own settings that would otherwise clutter the camera:

```text
shooting mode
pose package
beautify strength
beautify advanced controls
debug overlay
future favorite packages
```

This makes future modules additive. A new module should add settings to `AppSettings`, a processing engine if needed, and a configure-sheet section. It should not require redesigning the capture controls.

---

## 6. UI Plan

Loaded-image review should have a Beautify view or tab.

Controls:

```text
Original / Beautified compare
Portrait polish slider 0-10
Reset
```

Optional advanced controls later:

```text
Face brightness
Smooth skin
Warmth
Clarity
Subject emphasis
```

Display rules:

- show the beautified image as a full image,
- allow easy swipe/reveal comparison with original, started,
- allow full-screen zoom inspection for original, reframed, leveled, beautified, and tilt-test variants, done,
- do not cover the image with debug overlays,
- put debug values in the analysis panel only.

### Configure Button

Use a single configure button on the photo-taking screen.

Initial contents:

```text
Camera
- shooting mode

Guidance
- pose package
- debug overlay
```

Future beautify contents:

```text
Beautify
- portrait polish 0-10
- optional advanced controls
```

Do not show the beautify slider on the capture screen. Once implemented, the selected strength can be applied after capture and shown in review.

---

## 7. Testing Plan

Test with loaded images first.

Image sets:

- dark face / bright background,
- normal outdoor portrait,
- indoor low light portrait,
- close face portrait,
- full body portrait,
- group portrait,
- no face detected.

For each image, record:

```text
file
face_detected
person_detected
strength
face_luminance_before
face_luminance_after
visible_smoothing_artifacts
color_shift_quality
subject_emphasis_quality
human_rating
notes
```

Acceptance criteria:

- strength 0 matches original,
- strength 1-3 is subtle and safe,
- strength 4-6 is visibly useful,
- strength 7-10 remains acceptable but can be clearly stronger,
- no crash when no face is detected,
- original comparison is always available.

---

## 8. Milestones

### Milestone 1: Beautify Plan And Model

- create separate beautify plan, done,
- define `BeautifySettings`, done,
- define `BeautifyResult`, done,
- keep beautify independent from `CoachingEngine`, done,
- add a configure-sheet architecture so module settings do not clutter capture controls, started,
- persist beautify settings across app launches, done.

### Milestone 2: Loaded-Image Prototype

- add beautify slider to loaded-image review, done,
- generate beautified image from current review image, done,
- support original vs beautified comparison, done,
- add full-screen zoom inspection for changed images, done,
- add debug values to analysis panel, done.

### Milestone 3: First Effects

- implement face brightness, started,
- implement mild warmth, started,
- implement soft subject emphasis, started,
- implement gentle face smoothing if the face mask is reliable enough, started.

### Milestone 4: Batch Evaluation

- run beautify over `~/Downloads/test_photos`,
- save before/after samples or metrics,
- identify strengths that look acceptable,
- tune default slider mapping.

### Milestone 5: Camera Integration

- apply selected beautify strength after capture,
- keep captured original internally available,
- allow user to compare before saving/sharing.

---

## 9. Definition Of Success

Beautify succeeds when a user can load a portrait, move a `0-10` slider, and quickly see a tasteful improvement without losing trust in the original photo.

The first useful target is:

```text
face is brighter
portrait is warmer
subject stands out more
skin texture is gently softened
original remains available for comparison
```
