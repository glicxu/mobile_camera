# Advanced Camera Controls Review

**Focus and Exposure** is a top-level camera-control group at the same level as Filters and Beautifier. It has one clear decision at the top: **Auto** or **Manual**. Auto leaves focus and exposure under camera control. Manual opens the technical workspace, where the user chooses an exposure program and can then adjust focus, white balance, and other detailed controls. The interface does not present Auto Assistance and Pro Exposure as separate competing modes.

## Control hierarchy

```text
Focus and Exposure
├── Auto
│   ├── Focus: continuous auto
│   └── Exposure: continuous auto
└── Manual
    ├── Exposure program: M, Tv, or Av
    ├── Exposure controls for the selected program
    ├── Focus point and focus distance
    ├── White balance
    └── Technical monitoring when available
```

Filters, Beautifier, shutter behavior, posture guidance, and post-processing do not belong in Focus and Exposure.

## Auto mode

Auto is the normal operating mode. It keeps continuous autofocus, automatic exposure, automatic ISO, and automatic white balance active. Detailed manual controls remain hidden so the user sees a simple status rather than controls that are not currently governing the camera.

Auto may show read-only information:

- current Tv or shutter time;
- current Av or aperture;
- current ISO;
- focus and exposure status; and
- the active camera and lens.

Tapping the preview continues to set the automatic focus and exposure point. Auto Assistance may recommend an adjustment, but it must not silently switch the camera into Manual mode. Any recommendation that requires manual control should explain the change and wait for confirmation.

## Manual mode

Selecting Manual closes Camera Controls and enables a compact **Manual** button in the top bar. Tapping that button calls or hides the right-side tool rail, so the preview remains completely clear when the tools are not needed. The top-bar button can also enter Manual directly from Auto. The rail itself stays small; selecting Focus, Depth, or Exposure opens only that tool's controls, and selecting it again closes them. Manual here means the advanced workspace; the exposure program inside that workspace can be M, Tv Priority, or Av Priority.

The preview card initially shows exposure time as **Auto**. The user can frame and choose a focus point before taking control of Tv. Turning Auto off starts from the currently metered exposure rather than jumping to an arbitrary value.

Leaving Manual returns focus, exposure, ISO, and white balance to their automatic behavior. The app may remember the previous manual values for the next visit, but it must validate them against the active camera before restoring them.

## Exposure programs

### M

M gives the user direct control over shutter time and ISO.

- Tv or shutter time is adjustable.
- ISO is adjustable independently.
- Linked ISO is optional. When enabled, ISO compensates for a Tv change.
- Exposure adjustment changes the linked target rather than applying ordinary automatic exposure compensation.
- Av is shown as a fixed readout unless the active camera can physically change it.
- The exposure meter reports underexposure, balance, or overexposure.

### Tv Priority

Tv Priority keeps the selected shutter time fixed while the camera chooses ISO and any other supported automatic exposure values.

- The user adjusts Tv.
- ISO is shown as Auto with its current value.
- Exposure adjustment allows intentional underexposure or overexposure.
- This mode appears only when the active camera and operating system support it.

Tv Priority is useful for motion control because the user can choose a fast shutter for action or a slower shutter for a stable low-light scene.

### Av Priority

Av Priority keeps the selected aperture fixed while the camera balances the remaining exposure values.

- The user adjusts Av only when the active camera reports an adjustable aperture range.
- Tv and ISO remain automatic.
- Exposure adjustment allows intentional underexposure or overexposure.
- A fixed-aperture phone lens shows its Av as read-only and does not offer Av Priority.

Av Priority must be capability-gated. The app should never imply that a fixed physical aperture can change.

## Manual focus controls

Focus controls appear only in the Manual workspace. They include:

- a movable focus point on the preview;
- a digital depth-of-focus slider that blurs the background around the selected subject;
- a future hardware focus-distance slider from near to far when supported;
- a focus lock;
- a one-tap return to autofocus; and
- a persistent MF or AF Lock indicator while the state affects capture.

The focus-distance slider appears only when the active camera supports manual lens position. Changing the camera or lens requires the focus value to be revalidated because the same numeric lens position may not represent the same subject distance.

The preview shows a persistent focus reticle when the user moves the focus point. Digital depth blur is visible during framing and is also applied to the finalized capture. Subject detection preserves a detected face, person, or salient object around the selected point; when no subject is detected, the app preserves a region around the tap.

## Manual white balance controls

White-balance controls also appear only in the Manual workspace. They include:

- Auto white balance;
- white-balance lock;
- Custom temperature and tint;
- Daylight, Cloudy, Shade, Tungsten, and Fluorescent starting presets; and
- a persistent WB Lock or Custom WB indicator while active.

Custom temperature and tint values must be converted into the active camera's supported gains and clamped to valid limits. Changing the camera or format requires validation before restoring a saved value.

## Technical monitoring

Technical monitoring is subordinate to Manual mode rather than a separate top-level control category.

- The exposure meter appears for M, Tv Priority, and Av Priority.
- A luminance histogram may be enabled for all three programs.
- Highlight clipping warnings or zebras may be enabled when exposure is being adjusted.
- Focus peaking appears when focus distance is controlled manually.

Histogram, zebras, and focus peaking are preview guidance only. They must not be recorded in the saved photo. If monitoring reduces preview responsiveness, the app should lower its update frequency before affecting shutter response.

## Proposed interface

When Focus and Exposure is expanded, the first row is a segmented control:

`Auto | Manual`

Auto shows a compact status card with live Tv, Av, ISO, focus, and white-balance state. Selecting Manual dismisses the sheet; the top-bar Manual button then calls the right-side tool rail when it is wanted. The preview remains unobstructed until the rail and a tool are selected:

1. Focus opens the tap-focus instruction and persistent focus point.
2. Depth opens digital background blur: `Off | 1 | 2 | 3 | 4 | 5`.
3. Exposure opens program, exposure-time, ISO, and Av controls supported by the active lens.
4. Auto provides a one-tap return to automatic focus and exposure.

The Exposure editor also provides a centered **Under / Over exposure** control from -2 EV to +2 EV, subject to the active camera's supported range. Dragging it changes the live camera preview immediately; there is no Apply step. In automatic and priority exposure it changes the camera's exposure bias. With fixed manual Tv and ISO, it changes ISO from the metered baseline so the requested exposure is visible before capture. A **Reset to 0** button restores the balanced target.

Tv and Av appear only when supported. If only M is supported, the program selector is unnecessary. White balance, hardware focus distance, and optional monitoring can be added to this same preview workspace without returning them to Camera Controls.

## Transition rules

| Transition | Required behavior |
| --- | --- |
| Auto to Manual | Open the preview workspace, preserve automatic exposure initially, and read current Tv, Av, ISO, focus, and white balance as safe starting values. |
| Manual to Auto | Restore continuous autofocus, continuous auto exposure, automatic ISO, automatic white balance, and zero exposure adjustment. |
| M to Tv | Keep Tv, change ISO to Auto, and clear Linked ISO. |
| M to Av | Use the current supported Av, then change Tv and ISO to Auto. |
| Tv or Av to M | Use the current metered Tv and ISO as the starting manual values. |
| Camera or lens change | Refresh capabilities, clamp valid values, and reset unsupported settings. |
| App returns from background | Revalidate the active camera and all manual values before applying them. |

## Capability and safety rules

- A control appears only when the active camera reports support.
- Auto and Manual must be mutually exclusive and visually obvious.
- Manual exposure programs must not silently change after selection.
- A fixed aperture is read-only and cannot expose an Av Priority choice.
- Focus distance is hidden when manual lens position is unavailable.
- White-balance values are clamped to the active device's supported gains.
- Preview overlays never appear in the saved photo.
- Reset restores the complete automatic state, not only exposure.
- Capture remains available when an optional meter or overlay cannot run.

## Current implementation changes

The existing code provides much of the exposure behavior. The current interface reorganization is complete:

- Auto Assistance and Pro Exposure switches have been replaced by the Auto and Manual selector.
- Selecting Manual now dismisses Camera Controls and shows the controls over the live preview.
- Tap-to-focus selects a persistent manual focus point without changing manual exposure.
- Digital depth of focus provides a live background-blur preview and matching capture processing.
- Exposure time defaults to Auto; its Tv control appears only after Auto is turned off.
- The M, Tv, and Av program selector appears in the Manual preview workspace when supported.
- Keep current Tv, Av, ISO, exposure adjustment, Linked ISO, and exposure-meter behavior.
- Move focus lock and exposure lock into the appropriate Auto or Manual behavior instead of displaying them as unrelated controls.
- Add focus point, focus distance, and white-balance controls under Manual.
- Hide the detailed capability checklist from normal use; retain it for diagnostics if needed.

## Implementation order

1. **Implemented:** Replace Auto Assistance and Pro Exposure with the Auto and Manual selector.
2. **Implemented:** Move M, Tv, and Av programs under Manual without changing their exposure engine behavior.
3. **Partially implemented:** Manual focus point, autofocus return, and focus-state indicator are live; hardware focus distance remains future work.
4. **Implemented:** Digital depth of focus with live preview and finalized-capture blur.
5. Implement white-balance lock, temperature, tint, and starting presets.
6. Add histogram, zebras, and focus peaking as optional Manual monitoring.
7. Add broader device tests for mode transitions and capability changes.

## Decisions for review

- [ ] Use Focus and Exposure as a top-level group alongside Filters and Beautifier.
- [ ] Use only Auto and Manual as its modes, with Auto as the default.
- [ ] Treat M, Tv Priority, and Av Priority as exposure programs inside Manual.
- [ ] Hide detailed focus and white-balance controls while Auto is selected.
- [ ] Keep preview tap focus and exposure available in Auto.
- [ ] Show focus point and focus distance inside Manual.
- [ ] Show white-balance controls inside Manual.
- [ ] Hide Av Priority when the physical aperture is fixed.
- [ ] Keep histogram, zebras, and focus peaking subordinate to Manual.
