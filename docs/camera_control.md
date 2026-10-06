# Dali Camera Control and Assisted Professional Mode

Date: October 6, 2026
Status: First-level placement and basic-control prototype implemented

## Prototype snapshot

The first native iOS test places a compact **Camera** button beside the shutter. This keeps camera control available when composition coaching is turned off and avoids crowding the Situation/Posture/Landscape row.

The initial sheet includes:

- Auto and Assisted modes,
- the active camera and lens name,
- live shutter-duration and ISO readouts,
- capability-bounded exposure compensation,
- combined focus and exposure lock when both are supported,
- one-tap return to Auto,
- an opt-in voice shutter that responds to **“Cheese,”**
- and a short list of controls reported by the active camera.

Voice shutter requests microphone and Speech Recognition access only when the user turns it on. A status row shows when it is listening, and listening pauses automatically during photo review or while the app is in the background. The first prototype uses “Cheese” as the primary command and also accepts “Take photo” and “Take a picture” as compatibility phrases; broader commands and multilingual testing remain future work.

On the simulator, the same sheet explains that physical-camera controls require an iPhone. The prototype reads the active camera's reported limits at runtime; it does not assume a particular exposure range or lock capability.

## Purpose

Dali should use more of the phone camera's available capability while remaining a photography coach rather than becoming a panel of unexplained technical sliders.

The proposed camera-control system has three responsibilities:

1. Discover what the current phone, camera, lens, format, and capture configuration actually support.
2. Explain which setting would improve the current photograph and why.
3. Apply a supported recommendation only after the user selects it or enables an explicitly named automatic-assistance option.

The central rule is:

> Never assume that two phones—or even two cameras on the same phone—have the same controls, ranges, formats, lenses, or image-processing behavior.

All controls and recommendations must be driven by runtime capability discovery.

## Product modes

### Auto

The phone manages focus, exposure, ISO, shutter duration, white balance, lens switching, and image processing. Dali continues to provide composition, posture, horizon, stability, and lighting guidance.

Auto is the default and the safest recovery state.

### Assisted Pro

Dali reads the scene, motion, light, selected photographic situation, active camera, and supported setting ranges. It then recommends a small number of high-value changes.

Each recommendation contains:

- the problem or opportunity,
- the proposed setting,
- a plain-language reason,
- the expected tradeoff,
- an **Apply** action,
- and a **Return to Auto** action.

Examples:

- **Freeze the motion** — Apply 1/500 s; the runner is moving quickly, so a shorter exposure should reduce blur. This may require a higher ISO.
- **Protect the sunset** — Apply −0.7 EV; the brightest sky is close to clipping. The foreground will become darker.
- **Keep the color consistent** — Lock white balance; the scene is stable but Auto White Balance is shifting between frames.
- **Use the wide camera** — Switch to the 1× camera; it gathers more light than the currently selected camera on this phone.

Assisted Pro is the recommended first release because it extends Dali's coaching model without requiring the user to understand every manual control.

### Manual Pro

Manual Pro exposes direct controls only when the active device and capture configuration support them. Unsupported controls are omitted rather than shown disabled without explanation.

Potential controls include:

- physical or virtual camera selection,
- optical switching points and zoom,
- exposure compensation,
- shutter duration,
- ISO,
- focus point and focus lock,
- manual lens position,
- white-balance temperature and tint,
- flash and torch,
- processed, RAW, or Apple ProRAW capture,
- capture quality versus response speed,
- maximum photo dimensions,
- depth and supported mattes,
- and exposure bracketing.

## Device variability requirements

Camera capability varies across:

- phone model and generation,
- operating-system version,
- front versus back camera,
- wide, ultra-wide, telephoto, macro, and other physical cameras,
- virtual multi-camera versus individual physical camera,
- active capture format and resolution,
- still-photo versus video configuration,
- processed, RAW, or ProRAW output,
- frame rate,
- thermal or system-pressure state,
- low-light conditions,
- and combinations of simultaneously enabled features.

A capability may disappear after the user switches camera, format, resolution, or output type. The app must therefore refresh capability state after every configuration change.

The app must not hardcode assumptions such as:

- every phone has 0.5×, 1×, and 3× cameras,
- a displayed zoom label always corresponds to a physical lens,
- every back camera supports manual focus,
- every Pro-branded phone supports the same ProRAW configuration,
- all cameras share the same ISO or exposure-duration range,
- lens position corresponds to a reliable distance in meters,
- depth is available for every format,
- or the front camera behaves like the back camera.

## Capability profile

Dali should build a fresh `CameraCapabilityProfile` from the active capture session rather than from a device-name table.

### Phone and session fields

| Field | Purpose |
| --- | --- |
| Stable device identifier | Distinguish available capture devices during the session. |
| Camera position | Front, back, or unspecified. |
| Camera type | Wide, ultra-wide, telephoto, virtual multi-camera, and other reported types. |
| Constituent cameras | Identify the physical cameras inside a virtual device. |
| Switching zoom factors | Show where a virtual camera may change constituent camera. |
| Active format | Record resolution, pixel format, color space, and frame-rate constraints. |
| System-pressure state | Reduce expensive features when the phone reports pressure. |

### Exposure fields

- Supported exposure modes.
- Minimum and maximum exposure compensation.
- Current exposure compensation and target offset.
- Minimum and maximum ISO for the active format.
- Minimum and maximum exposure duration for the active format.
- Current ISO, exposure duration, and aperture value.
- Support for exposure point or exposure region of interest.
- Support for custom exposure.

The aperture value is useful metadata, but phone camera apertures are generally fixed and should not be presented as an adjustable control unless the capture device explicitly reports otherwise.

### Focus fields

- Supported focus modes.
- Support for focus point or focus region of interest.
- Support for focus lock.
- Support for custom lens position.
- Current normalized lens position.
- Minimum-focus-distance or macro-related information when available.

Manual lens position is a normalized device value, not a dependable subject distance. Dali should label it **Near ↔ Far**, not meters or feet.

### White-balance fields

- Supported white-balance modes.
- Support for locking custom gains or temperature and tint.
- Minimum and maximum supported device gains.
- Current temperature, tint, and gains where available.

### Lens, zoom, and lighting fields

- Minimum and maximum zoom for the active device and format.
- Virtual-camera switching factors.
- Available constituent cameras.
- Flash availability and supported flash modes.
- Torch availability and supported torch levels.
- Stabilization and low-light support reported by the current configuration.

### Photo-output fields

- Supported processed codecs and file types.
- Supported RAW pixel formats and file types.
- Apple ProRAW support in the current session.
- Supported maximum photo dimensions.
- Quality-prioritization range.
- Responsive capture, zero-shutter-lag, and fast-capture support.
- Depth-data, portrait-effects matte, semantic matte, and calibration-data support.
- Bracketing and lens-stabilization-during-bracketing support.
- Content-aware distortion correction and virtual-device fusion support.

## Control availability states

Every setting should have an explicit runtime state:

| State | UI behavior |
| --- | --- |
| Supported and available | Show the control normally. |
| Supported but incompatible with the current configuration | Hide it from the primary panel; explain the required configuration in details. |
| Temporarily restricted | Preserve the user's intent, show the reason, and return to a safe setting. |
| Unsupported on this camera | Omit it. |
| Unknown or failed discovery | Remain in Auto and do not guess. |

When changing one setting invalidates another, Dali must explain the change before applying it. For example: “Switching to RAW will turn off this processed-photo option.”

## Recommended user experience

### Entry point

Add a **Camera** or **Pro** control near the existing coaching controls. The situation-specific button continues to select creative guidance; Camera controls capture behavior.

The control displays the current state:

- Auto
- Assisted
- Manual
- RAW
- ProRAW
- or a short active preset such as Motion or Sunset.

### Assisted recommendation card

Show no more than one primary camera-setting recommendation at a time. The card should contain:

1. A goal such as **Freeze movement**.
2. A setting such as **1/500 s · Auto ISO**.
3. One sentence explaining the evidence.
4. One sentence explaining the tradeoff.
5. **Apply** and **Keep Auto** actions.

Camera-setting guidance must not compete with urgent framing or safety guidance. Recommended priority is:

1. Safety or capture failure.
2. Severe blur or highlight loss.
3. Focus failure.
4. Composition and posture.
5. Creative camera-setting opportunity.

### Manual panel

Use a compact summary row and one expanded control at a time. Avoid showing every slider simultaneously.

Suggested summary:

`1× · 1/250 · ISO 80 · AWB · AF · HEIF`

Tapping a value opens its control and explanation. Every manual control provides:

- Auto,
- the supported range,
- the current value,
- a reset action,
- and an explanation of its visible effect.

## Recommendation inputs

Dali can combine existing measurements with new camera metadata:

| Evidence | Possible recommendation |
| --- | --- |
| Subject motion | Shorter exposure duration or Action preset. |
| Phone motion | Stabilize phone, shorten exposure, or use timer. |
| Highlight clipping | Lower exposure compensation or bracket. |
| Deep shadows with a stable scene | Stabilize and allow a longer exposure. |
| Face versus background luminance | Adjust exposure point or compensation. |
| Low light on a weaker lens | Recommend the camera with better light-gathering behavior when known from live measurements. |
| Stable color with shifting white balance | Lock white balance. |
| Close subject and focus difficulty | Change camera, enable supported macro behavior, or increase distance. |
| Landscape with large brightness range | Protect highlights, stabilize, or offer a bracket. |
| Intended editing workflow | Offer RAW or ProRAW when supported. |

Recommendations should use live measurements from the current camera rather than a permanent claim that one lens is always better.

## Initial Assisted Pro rules

### Motion

- If subject motion is high and light permits, recommend a shorter exposure.
- Prefer automatic ISO initially so the phone can compensate within its supported range.
- Warn when the predicted ISO increase may cause visible noise.

### Low light

- First recommend stability, a timer, or support.
- Prefer the currently available camera that demonstrates better live exposure behavior; do not infer solely from its displayed zoom name.
- Offer a longer exposure only when phone and subject motion are low.
- Do not recommend a long exposure for moving people merely because the scene is dark.

### Bright sky or sunset

- Use highlight measurements to recommend modest negative exposure compensation.
- Explain that foreground shadows will deepen.
- Offer bracketing only when supported and the phone is stable.

### Portrait

- Meter near the face when supported.
- Recommend exposure compensation only when face luminance is materially different from the background.
- Keep focus and exposure controls separate so the user can lock one without necessarily locking the other.

### Consistent series

- Recommend exposure lock and white-balance lock when the scene is stable and the user is making several related photographs.
- Clearly show every locked control to prevent accidental inconsistent captures later.

## Software overlays

Some professional aids can be computed from the live preview even when the camera does not expose a matching hardware control:

- luminance histogram,
- RGB histogram,
- highlight and shadow clipping warnings,
- zebra patterns,
- focus peaking based on local contrast,
- horizon level,
- motion and stability indication,
- and depth or edge visualization when appropriate data is available.

These aids must be labeled as estimates from the preview stream. The preview can differ from the final processed or RAW photograph.

## Capture formats

### Processed photo

Use the phone's computational pipeline and an efficient format such as HEIF or JPEG when supported. This remains the default for most users.

### Standard RAW

Standard RAW provides minimally processed sensor data and greater editing latitude, but produces much larger files and may not include the computational-photography result users expect.

### Apple ProRAW

When the current device and session report support, ProRAW can combine RAW editing flexibility with parts of Apple's computational pipeline. Support must be checked after the photo output is connected to the configured capture session.

When saving RAW plus processed output, the app must track both resources, clearly report save failures, and never discard either version before successful persistence or explicit user action.

## Safety and trust rules

- Never silently enter Manual mode.
- Never silently capture RAW or ProRAW because of file-size and workflow consequences.
- Never apply a recommendation outside the active camera's reported range.
- Clamp values only as a last defensive measure; normally present valid values before Apply.
- Cancel stale recommendations after camera or format changes.
- Return to Auto after a device-configuration failure.
- Keep the shutter available unless capture is genuinely unsafe or unavailable.
- Show persistent indicators for exposure, focus, or white-balance locks.
- Record which settings Dali recommended, which the user applied, and which were active at capture.

## Proposed data model

```swift
struct CameraCapabilityProfile {
    let deviceID: String
    let position: CameraPosition
    let cameraType: CameraType
    let lenses: [CameraLensCapability]
    let exposure: ExposureCapability
    let focus: FocusCapability
    let whiteBalance: WhiteBalanceCapability
    let lighting: LightingCapability
    let photoOutput: PhotoOutputCapability
    let activeConfigurationID: String
}

struct CameraRecommendation {
    let goal: CameraRecommendationGoal
    let evidence: [CameraEvidence]
    let proposedChanges: [CameraSettingChange]
    let explanation: String
    let tradeoff: String
    let configurationID: String
}
```

The `configurationID` prevents the app from applying a recommendation calculated for a camera or format that is no longer active.

## Implementation phases

### Phase 1: Capability foundation

1. **Partially implemented:** The active camera now produces a runtime profile for exposure compensation, focus/exposure lock, shutter, ISO, device name, and lens name. Full multi-camera discovery remains.
2. **Partially implemented:** Display the active profile in the Camera sheet. Persistent diagnostic logging remains.
3. **Partially implemented:** Refresh the profile after camera configuration and control changes. Format and output changes still need coverage.
4. **Started:** Unit coverage verifies that values are clamped to the active camera's injected range. Broader phone fixtures remain.
5. **Implemented for initial testing:** The Camera sheet acts as the physical-phone capability screen.

### Phase 2: Assisted Pro MVP

1. Add Auto, Assisted, and Manual state management.
2. Add lens selection from discovered devices or constituents.
3. Add exposure compensation with supported limits.
4. Add tap focus and tap exposure, plus visible lock states.
5. Display live shutter duration, ISO, focus mode, and white-balance mode.
6. Implement Motion, Low Light, Bright Sky, Portrait, and Consistent Series recommendations.
7. Add Apply, Keep Auto, and Return to Auto actions.

### Phase 3: Manual controls and overlays

1. Add supported shutter-duration and ISO controls.
2. Add manual focus and white-balance controls.
3. Add histogram, clipping warnings, zebras, and focus peaking.
4. Add named presets whose values are resolved against the active capability profile.

### Phase 4: Professional capture formats

1. Add processed format selection and maximum supported photo dimensions.
2. Add RAW and ProRAW when reported by the active session.
3. Add safe multi-resource persistence for RAW plus processed captures.
4. Add exposure bracketing and optional depth or matte delivery where compatible.
5. Validate memory, thermal, storage, latency, and recovery behavior on several physical phones.

## Testing matrix

At minimum, test:

- a phone with one back camera,
- a phone with multiple back cameras,
- a phone with and without RAW support,
- a phone with and without ProRAW support,
- front and back cameras,
- camera and format changes while recommendations are visible,
- minimum and maximum values for every manual range,
- low-light and high-motion combinations,
- storage failure during multi-resource capture,
- thermal or system-pressure restrictions,
- and accessibility with VoiceOver and large text.

Tests should assert behavior from injected capability profiles rather than relying on the test runner's phone model.

## Success criteria

- No unsupported control is presented as usable.
- Every recommendation is valid for the active camera configuration.
- A recommendation becomes invalid immediately after its source configuration changes.
- Users can return all controls to Auto with one action.
- Assisted recommendations explain both benefit and tradeoff.
- The captured file records the settings that were actually resolved and used.
- The app behaves usefully on a basic single-camera phone and expands progressively on more capable phones.

## Apple platform references

- [AVCaptureDevice](https://developer.apple.com/documentation/avfoundation/avcapturedevice)
- [Exposure controls](https://developer.apple.com/documentation/avfoundation/capture-device-exposure)
- [White-balance controls](https://developer.apple.com/documentation/avfoundation/capture-device-white-balance)
- [AVCapturePhotoSettings](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings)
- [RAW and Apple ProRAW capture](https://developer.apple.com/documentation/avfoundation/capturing-photos-in-raw-and-apple-proraw-formats)
- [Bracketed photo capture](https://developer.apple.com/documentation/avfoundation/avcapturephotobracketsettings)
