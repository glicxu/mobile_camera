# Dali Camera photo review and capture UX improvement plan

Date: October 21, 2026

Status: Photo review implemented and tested on Android; iPhone and extended acceptance pending. Capture layout implemented; Android UI validation completed, hands-on scene testing and iPhone validation pending.

Scope: Photo review and capture layout in the Flutter app on iPhone and Android

Tapping the last-photo thumbnail should immediately open a lightweight viewer of that photo. The user should be able to inspect, browse, share, favorite, or delete it without entering an editing workflow. Filters, Beautifier, and Enhance become available after the user chooses Edit.

This round prioritizes passive review, fast opening, a larger image, and familiar action buttons. A compact thumbnail strip follows as a secondary enhancement.

## Photo review implementation status

- Implemented: passive viewing without automatic photo analysis or effect rendering; saved capture appearance retained separately from recovery originals.
- Implemented: full-width image area, compact review actions, explicit Edit entry, save/discard handling, in-place pinch/double-tap zoom, and non-wrapping navigation.
- Implemented: newest-photo-first loading, paged metadata, display-sized previews, full-resolution loading on demand, bounded preview copies, and stale-load cancellation.
- Implemented: native iOS and Android metadata, favorite, and deletion operations, plus an optional thumbnail strip available in Photo options. Android library favorites require Android 11 or later; older versions show the action as unavailable.
- Automated validation: 50 Flutter tests passed, Flutter analysis passed, Android debug APK built, and whitespace checks passed. Tests cover passive entry, paged loading, navigation boundaries, stale preview/full-image results after leaving, edge-to-edge layout, zoom versus swipe, saved capture identity, editing, and recovery.
- Samsung SM-G975U on Android 12: installed with a data-preserving update. Verified full-width 3:4 rendering with all four corners visible, portrait/landscape controls, metadata dimensions, favorite toggle, optional thumbnail strip, double-tap zoom and panning, opening/cancelling the share sheet, and confirmed deletion through Android trash. Only the generated test image was favorited and deleted; no existing photos were modified.
- Pending: iPhone compilation/device acceptance, cloud-photo and limited-access checks on real devices, physical pinch testing, older Android permission flows, and extended memory/performance measurement. No before/after timing claim is made.
- iPhone validation: the configured Mac at `mac` is unreachable over SSH (connection timeout). No iPhone installation or signing changes have been attempted.

## Baseline comparison before this round

Apple documents reviewing recent photos directly from Camera. Samsung Gallery exposes Favorite, Edit, Info, Share, and Delete while viewing a photo. Button placement and thumbnail presentation vary by device and OS version; Dali should adopt the familiar actions and clear separation between viewing and editing.

The iPhone thumbnail strip and Samsung single-photo presentation discussed in the UX review are visual references. Neither establishes how those apps load or cache images internally.

| Area | Previous Flutter behavior | Implemented direction |
| --- | --- | --- |
| Review entry | Editing tools start closed, but opening a photo runs still-image analysis. | Show the saved photo immediately; run analysis only when an editing feature needs it. |
| Library access | Enumerates library metadata before opening the first photo. Images load individually, with up to three private copies retained. | Open the latest photo first, then fetch older metadata in pages. |
| Image layout | Review adds 8 logical pixels of padding on each side. Other rows reduce image space. | Remove side padding and maximize the photo area between compact control bars. |
| Main actions | Bottom bar emphasizes Enhance and conditionally Save. | Expose Share, Favorite, Edit, Info, and Delete. |
| Navigation | Swipe and arrow navigation wrap around the collection. | Swipe through photos and stop at collection boundaries. |
| Zoom | Tapping opens a separate fullscreen viewer. | Support pinch and double-tap zoom directly in review. |
| Thumbnails | No review filmstrip. | Add a compact, optionally collapsible strip after the primary improvements. |

Sources: [Apple Camera photo review](https://support.apple.com/guide/iphone/view-share-and-print-photos-iph3d314a6f/ios) and [Samsung Gallery actions](https://www.samsung.com/us/support/answer/ANS10002535/).

## Default review experience

1. The user taps the last-photo thumbnail on the camera screen.
2. The viewer opens on the photo represented by that thumbnail. Use the available preview immediately and replace it with a sharper display-sized image when ready.
3. The saved appearance remains unchanged, including effects already applied during capture. Do not silently substitute a private unprocessed original or apply the current camera settings again.
4. The user can zoom, browse adjacent photos, or use the review actions.
5. Back to Camera returns promptly to capture. Viewing an unchanged photo never requires Save or Discard.
6. Edit explicitly enters the editing experience. Filters, Beautifier, Enhance, crop, and comparison controls belong there.

Opening review must not trigger filter rendering, beautifier processing, face or pose analysis, or generation of edit variants. Merely hiding the editor is insufficient; defer its processing and resource initialization as well.

## Layout and controls

| Screen region | Contents |
| --- | --- |
| Top bar | Back to Camera, photo date/time, More |
| Main area | Photo centered on a dark background, using the full available width |
| Optional strip | Small nearby thumbnails with the selected photo highlighted |
| Bottom bar | Share, Favorite, Edit, Info, Delete |

Keep top and bottom controls clear of the image and within device safe areas. Avoid a large title, persistent navigation arrows, or routine status messages that shrink the photo. Show loading and error feedback only when needed.

Remove horizontal padding around the photo. Preserve aspect ratio and show the full image without stretching or automatic cropping. Typical camera photos should meet the left and right edges when they fit vertically. Unusually tall images may require side space to remain fully visible between the control bars; preserving the photograph takes priority over forcing width.

Reflow controls for landscape orientation and large text. Give icon buttons accessible labels and platform-appropriate touch targets. Pinch and double-tap zoom operate within review; when zoomed, dragging pans the image instead of changing photos.

## Action behavior

- **Back to Camera:** Available during image loading. Cancel or ignore pending review work when leaving.
- **Share:** Share the displayed saved photo. An edited result can be shared from the editing workflow without silently sharing a different version.
- **Favorite:** Reflect and update the library asset's favorite state where supported. Any app-only favorite behavior must be explicitly identified.
- **Edit:** Open the tool choices without automatically applying an effect. Load each tool's processing resources when required.
- **Info:** Show photo date, dimensions, and available metadata in a dismissible panel.
- **Delete:** Confirm the action and use the platform library deletion flow. Clearly distinguish deleting a library photo from discarding an unsaved capture. After deletion, show an adjacent photo or an empty state with Back to Camera.
- **More:** Hold secondary actions such as opening the library or importing photos.

Save and Cancel belong to editing. Preserve the saved photo and its original recovery data until the user commits changes. Leaving an edit with changes offers a clear save or discard choice. Existing failed-save recovery remains available through Retry save and explicit discard; normal review must not lose an unsaved capture.

## Loading and navigation

- Resolve the asset represented by the camera thumbnail first. Do not wait for a complete library enumeration.
- Request a display-sized image for ordinary review. Request higher resolution as needed for zoom, editing, or export.
- Fetch older photo metadata incrementally. Decode only the current image and a small, bounded set of neighboring images.
- Keep cache and private-copy storage bounded. Release resources when they are no longer needed.
- Cancel or ignore stale requests after swiping or leaving review. A late result must never replace the newly selected photo.
- Keep Back to Camera responsive during cloud downloads, image decoding, and errors. Offer retry for an unavailable image without blocking navigation.
- Browse in a consistent chronological order. Stop at the newest and oldest accessible photos instead of wrapping unexpectedly.
- Respect limited library access and provide a useful empty state when no accessible photos remain.

The thumbnail enhancement should load only small thumbnails near the current selection, fetching additional thumbnails as the strip scrolls. It must not delay the main image or cause full-resolution loading of the library. Keep the strip compact and collapsible so the photograph retains priority.

## Implementation priorities

| Priority | Work | Completion outcome |
| --- | --- | --- |
| P0 | Separate viewing from editing and defer analysis/effects | Opening review performs no editing work. |
| P0 | Open the thumbnail's photo immediately and page library metadata | First display does not depend on scanning the library. |
| P0 | Remove photo side padding and simplify control bars | The photograph uses the available space between controls. |
| P0 | Add the familiar review actions | Users can manage a photo without entering Enhance. |
| P1 | Integrate zoom and improve navigation/loading cancellation | Browsing, inspecting, and returning to Camera stay responsive. |
| P2 | Add the compact thumbnail strip | Users can jump among nearby photos without expensive bulk loading. |

## Implementation starting points

- [Review layout and entry](../apps/dali_camera/lib/main.dart): `review()`, `openPhotoLibrary()`, and `openFullScreen()`.
- [Review state and loading](../apps/dali_camera/lib/camera_controller.dart): `openPhotoLibrary()`, `_openLibraryIndex()`, `openLatest()`, `openHistory()`, and `_analyzeStill()`.
- [Image display and zoom](../apps/dali_camera/lib/review_comparison.dart): separate ordinary viewing from editing comparison while reusing display and zoom behavior where appropriate.
- [Platform API](../packages/dali_camera_platform/pigeons/camera_api.dart): assess additions for paged metadata, display-sized previews, favorites, metadata, and deletion.
- Native iOS and Android adapters: implement the platform operations while preserving asset identity, permissions, and saved appearance.

## Acceptance criteria

Checked items have automated or Samsung evidence. They do not imply iPhone acceptance. The remaining device cases are listed above.

- [x] Tapping the last-photo thumbnail opens that same photo with its saved appearance.
- [x] Opening review invokes no analysis, filter rendering, beautifier processing, or edit-variant generation.
- [ ] The viewer displays an available preview before library enumeration or a high-resolution download completes.
- [ ] Library metadata is paged; decoded images and private copies remain bounded during extended browsing.
- [x] A typical camera photo reaches both side edges when its aspect ratio fits the available height. No photo is stretched or automatically cropped.
- [x] Top and bottom controls remain usable in portrait, landscape, and large-text layouts.
- [ ] Share, Favorite, Edit, Info, and Delete act on the currently displayed asset.
- [x] Editing begins only after Edit, and Save/Cancel appear only as appropriate for editing or failed-save recovery.
- [ ] Pinch and double-tap zoom work in review; panning a zoomed photo does not accidentally navigate.
- [x] Navigation stops at collection boundaries, and stale image loads never replace the selected photo.
- [ ] Back to Camera remains available during cloud loading and failures.
- [ ] Deletion is confirmed; empty, limited-access, and unavailable-photo states remain navigable.
- [x] Unsaved captures retain Retry save and explicit discard recovery.
- [x] The optional thumbnail strip loads small nearby thumbnails and does not delay the main photo.

Validate on physical iPhone and Android devices with local and cloud-backed photos, a large library, limited permissions, portrait and landscape images, tall images, and failed saves. Record time to first visible image and memory behavior before and after implementation; this plan does not claim measured performance gains yet.

## Remaining testing and observed issue

1. Bring the configured Mac online, compile the Flutter iOS target, and test on the intended iPhone. Follow the Flutter signing instructions; the dedicated Alayna profile in AGENTS.md is for the separate native bundle.
2. Check cloud-only images, denied/limited access, physical pinch gestures, and larger libraries over an extended session. Measure first visible image time and memory before making performance claims.
3. During the first Samsung launch, the ML Kit acceleration benchmark child process crashed with a JNI `NoSuchFieldError`, triggering Samsung's cache suggestion. The main camera and photo viewer subsequently operated, and no cache or app data was cleared. This startup observation remains a separate follow-up; it was not established as a regression from this UX change.

## Next round: stable capture layout and on-demand guidance

Added: October 21, 2026

Status: Implemented locally. Android UI validation and automated checks completed. Hands-on scene testing and iPhone validation remain pending.

Implementation progress:

- Replaced separate portrait/landscape layouts with one handset-anchored layout. A native display-orientation query distinguishes both landscape directions; control icons rotate independently of their positions.
- Guidance starts closed. Guide opens a compact overlay, with examples and details available on request. Overlay visibility does not reserve layout space or change photo effects.
- Retained compact Filters and Beautifier shortcuts and the existing Controls/Manual entry points. Updated the tutorial for the new guidance flow.
- Added regression coverage for physical shutter anchors, unchanged viewport bounds, effect settings, camera restart avoidance, overlay versus focus taps, and a 320-by-568 logical-pixel screen with 200% text scaling.

The capture screen should retain familiar control locations when the phone rotates. Guidance should appear only when requested, as an overlay inside the viewport, without taking permanent space away from the scene. The review implementation and acceptance results above do not establish completion of this capture work.

### Comparison and current baseline

The current `live()` layout in `main.dart` splits the available area below the header approximately 5:4 between preview and controls when coaching is enabled in portrait. With coaching disabled, the controls use a fixed 190 logical pixels. Landscape switches to a separate side panel using up to 44% of the screen width, capped at 360 logical pixels, with additional outer padding. These layout changes explain the substantial shift in preview size and control placement.

Apple documents expandable camera controls, while Samsung describes quick controls and smaller mode pop-ups that preserve preview visibility. Exact arrangements vary by device and software version. Stable positions relative to the handset are the proposed Dali interaction target, rather than a claim that every stock camera uses identical behavior.

| Area | Regular-camera reference or design goal | Proposed Dali change |
| --- | --- | --- |
| Rotation | Familiar controls relative to the handset | Anchor shutter, last-photo thumbnail, and camera switch to the same physical locations; rotate icons and labels for readability. |
| Viewport | The scene remains the main focus | Replace the large guidance area and wide landscape sidebar with compact essential controls. |
| Guidance | Small indicators and assistance revealed when needed | Show a dismissible overlay inside the existing viewport, without resizing it. |
| Secondary controls | Expandable controls keep the default screen simple | Place filters, beauty, and manual adjustments behind compact buttons. |
| Framing | Operating controls preserves predictable composition | Opening guidance or settings must not change preview size, crop, or zoom. |

References: [Apple camera basics and controls](https://support.apple.com/en-gb/guide/iphone/iph263472f78/26/ios/26) and [Samsung camera interface changes](https://doc.samsungmobile.com/SM-S901B/021674220226/ben-bd.html).

### Prioritized recommendations

| Priority | Improvement | Expected behavior |
| --- | --- | --- |
| P0 | Stabilize controls during rotation | Keep the shutter at the same physical end of the handset in both landscape directions. Preserve the selected lens, zoom, focus, and settings; rotate labels and icons without rebuilding the screen into a different arrangement. |
| P0 | Restore viewport space | Use the full available width in portrait with compact top and bottom controls. Preserve the selected capture aspect ratio; do not stretch or silently crop the scene to fill the display. |
| P0 | Make guidance an on-demand overlay | Start with guidance closed. A clearly labeled Guide button opens a translucent card over the viewport; tapping it again or using Close dismisses it. Opening and closing must leave the preview bounds unchanged. |
| P1 | Simplify guidance content | Show one actionable instruction, such as "Move slightly left," with a directional cue. Expand pose examples and detailed explanations only when requested. Keep the central subject and shutter clear. |
| P1 | Consolidate secondary controls | Reveal filters, beauty, and manual controls through compact entry points without permanently reserving a large panel. |
| P0 | Keep guidance independent of photo effects | Opening or closing guidance must not change filters, beauty settings, or the resulting photo. Never include guidance graphics in saved images. |
| P0 | Validate on physical devices | Check both landscape directions, guidance visibility, focus, zoom, capture, and saved-image orientation on Android and iPhone. |

### Proposed capture experience

1. Camera opens with a large viewport, essential controls, and guidance closed.
2. Rotating the handset preserves the controls' physical anchors and current camera settings. Icons and labels orient for readability.
3. Tapping Guide displays a compact instruction overlay without moving or resizing the scene.
4. The user can expand a pose example or explanation when needed, then close it to restore an unobstructed view.
5. Focus and zoom remain available outside the overlay. Interacting with the overlay must not accidentally focus or zoom the scene beneath it.
6. Capture remains immediately accessible. The saved image reflects the chosen capture settings and orientation, without any guidance graphics.

### Capture implementation starting points

- [Capture layout](../apps/dali_camera/lib/main.dart): `live()`, portrait/landscape layout branches, header, shutter controls, and guidance entry point.
- [Guidance cards](../apps/dali_camera/lib/live_guidance.dart): adapt `LiveGuidancePanel` and its scene/reference content for compact, dismissible presentation.
- [Viewport guidance](../apps/dali_camera/lib/coaching_overlay.dart): coordinate existing cues with the requested guidance visibility and avoid duplicate instructions.
- [Camera state](../apps/dali_camera/lib/camera_controller.dart): keep overlay visibility separate from effect settings and preserve capture state through rotation.
- Native preview and orientation handling: verify alignment of the displayed scene, focus coordinates, and saved-image orientation in both landscape directions.

### Capture acceptance criteria

Checked items have widget-test or Samsung UI evidence. They do not imply iPhone acceptance or a visible-scene capture check.

- [ ] Shutter, last-photo thumbnail, and camera switch retain their physical anchors in portrait and both landscape directions.
- [ ] Rotation preserves selected lens, zoom, focus, and capture settings without a disruptive preview restart.
- [x] The default screen has no persistent guidance panel consuming viewport space.
- [x] Guide opens and closes an overlay without changing preview bounds, crop, aspect ratio, or zoom.
- [ ] The preview uses available space while preserving the selected capture framing without stretching or silent cropping.
- [x] Guidance shows one primary instruction; examples and detailed explanations expand only on request.
- [x] Essential controls remain accessible with guidance open in the tested Samsung layout and small-screen widget tests with 200% text scaling. iPhone safe-area acceptance remains pending.
- [x] Overlay interactions do not trigger focus underneath; unobstructed preview areas retain tap-to-focus. Physical pinch validation remains pending.
- [ ] Opening or closing guidance leaves filter and beauty settings unchanged, and saved photos contain no guidance graphics.
- [ ] Android and iPhone device checks confirm correct preview, focus coordinates, and saved-image orientation in portrait and both landscape directions.

### Capture validation and next hands-on checks

- Automated validation: all 52 Flutter tests passed; Flutter analysis and whitespace checks passed. Android debug builds succeeded; iOS compilation has not been run in this round.
- Samsung SM-G975U, Android 12: installed through a data-preserving update. Checked portrait and both forced landscape directions, upright control labels, the shutter staying at the same handset end, and opening/closing the guidance overlay. Restored the device's original rotation settings (automatic rotation off, portrait).
- The current live view was dark during remote testing. This verifies layout, not subject framing, focus accuracy, or saved-image orientation. No existing photos were changed during these capture-layout checks.
- Widget regression tests cover the shutter's transformed position in both landscape directions, unchanged preview bounds when guidance toggles, no camera restart on rotation, unchanged filter/beauty/zoom settings, and overlay taps not reaching focus metering. Existing capture and review tests remain part of the validation suite.
- Moved the preview watermark above the zoom controls to prevent their overlap. This changes only the preview decoration, not the saved watermark rendering.
- Next: point the Samsung at a visible scene and physically rotate it both ways. Check that framing and focus stay aligned, pinch zoom works, the Guide overlay feels unobtrusive, and a saved photo has the intended orientation. Repeat on iPhone after restoring Mac access.
