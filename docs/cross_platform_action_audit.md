# Comprehensive native-to-Flutter action audit

Reference: native iOS `d53a977`, including reachable `ContentView.swift` actions and their camera/processing services. Audited October 8, 2026. This is the current implementation contract for [the porting plan](cross_platform_remaining_port_plan.md); older aggregate coverage and historical checkpoints do not override it.

Status: software corrections and validation in progress. An implemented action is not physical visual acceptance. No iPhone visual sign-off is recorded. Follow every destination and state transition below when comparing apps, rather than checking only whether a similarly named button exists.

## Camera and Manual destinations (P0/P1/P6)

| Native source/action | Flutter destination and behavior | Verification |
| --- | --- | --- |
| `topBar`: Manual | `CameraHeader` enters Auto-exposure Manual workspace and toggles its rail; `ManualPreviewControls` sits at the right of the viewport | Widget rail alignment/exclusive editors; device check |
| `manualPreviewToolRail`: Focus | Opens only the focus editor; preview tap selects a persistent focus point without changing AE in Manual | Typed AF-only command; widget focus-only/reset checks |
| Depth | Opens only depth editor; 0-5 live region blur and subject/focus fallback; Auto disables depth | Native backend + widget effective-depth checks |
| Exposure | Opens only exposure editor; Auto on entry; turning Auto off initializes measured Tv/ISO | Actual camera snapshot and hardware capability gates |
| Shutter duration and ISO | Logarithmic sliders use active sensor ranges; ISO changes update relative EV; native fixed aperture is informational | Android real sensor checks; iPhone physical check pending |
| Exposure adjustment, Reset | Under/over adjustment changes the manual ISO; Reset restores base exposure product | Controller checks; real-camera command checks |
| Exposure Auto | Resets exposure and EV while preserving manually selected focus | Typed `resetFocus=false`; regression check |
| Full Auto | Resets focus, exposure, indicator and effective depth; hides the rail | Typed `resetFocus=true`; regression/device check |
| Coaching light | Toggles coaching and contextual selection/guidance, leaving shutter available | Header widget/device tests |
| Gear | Opens App Settings; current package version, tutorial, About and native placeholder sections | Version/header/tutorial tests |
| Camera switch | Reconfigures actual lens, invalidates previous commands/measurements, refreshes capabilities | Camera and stale-configuration integration checks |
| `advancedCameraControlsSection` | Collapsed Focus and Exposure; Auto/Manual, actual camera/lens/Tv/Av/ISO; Manual dismisses controls sheet | Widget/source audit; sensor snapshots |
| Bottom camera controls | Opens scrollable sheet with pinned title/Done and Shutter/Filters/Beautifier/Focus and Exposure disclosures | Large-text and device tests |

The reference's `proExposureControls`, `exposureMeter`, `assistedRecommendationCard`, lock and metering-picker helpers are not called by the reachable Focus and Exposure section. Their mere presence is not another visible baseline screen. Tv/Av priority is additionally behind `DALI_IOS27_EXPOSURE`, disabled in the Xcode 16.4 build. Existing Flutter capability commands remain available to its tests, but unsupported UI must not advertise these as working hardware.

## Capture and viewport (P1/P3/P5/P6)

| Native action/state | Flutter implementation | Verification / limit |
| --- | --- | --- |
| Shutter tap | White ring shutter, timer count; captures and saves an immutable original before processing | Capture/export/failure tests |
| Countdown | Center large count, Cancel; sequence cannot survive pause or modal controls | Cancellation/duplicate capture tests |
| Long press Burst/Timer/Disabled | Release/cancel stops burst; visible burst count; pending original blocks next capture | Device and controller tests |
| Voice standard/custom phrase | Desired preference distinct from actual listening; custom phrase, permission status, lifecycle resume and deduplication | Controller/native checks; physical speech/audio acceptance pending |
| Auto preview tap | AF+AE point with transient focus/exposure indicator | Two-second indicator; hardware gate |
| Manual preview tap | AF-only persistent indicator and subject-depth focus point | Typed bridge distinguishes both paths |
| Viewfinder | Complete oriented image; overlay geometry shares native preview coordinates | Independent Preview/ImageAnalysis geometry checks |
| Person coaching overlay | Native person-context grid, status lights, directional circles and prompt; pulse respects reduced motion | Source audit and widget/device checks; visual acceptance pending |
| Debug overlay | Face/person rectangles, pose landmarks and optical horizon from available signals | Shared schema/geometry checks |
| Signature | Free native signature visible in preview and applied to processed captures | Asset + native rendering path; no invented free toggle |
| Live effects | Only the reference's region-based depth path is live; Filters/Beautifier finalize captures | No baseline semantic segmentation or live cosmetics |

## Situation, effects and references (P1/P2/P4)

| Native action | Flutter destination / transition | Verification |
| --- | --- | --- |
| Situation dropdown | Eight choices; Auto resolves after stable candidates, holds ambiguity, freezes during creative guidance | 24 native transition cases |
| Effects dropdown | Independent Filter/Beautifier Auto/Custom/Off plus Both Auto/Both Off and settings entry | Capture recipes/custom retention checks |
| Filters disclosure | Named preset dropdown; seven individual sliders collapsed; changing a preset copies its values into Custom | Preset/default catalog + mode retention tests |
| Beautifier disclosure | Type dropdown; Enhance level 1-5; Portrait/Landscape preset dropdown and collapsed individual settings | Settings source audit; native defaults/presets |
| Portrait options | Brighten/even skin, smooth skin, reduce blemishes, enlarge eyes, plump lips | Presets and guarded landmark-aware backend |
| Landscape options | Blue sky/cloud detail, rich landscape color | Separate saved capture settings |
| Contextual reference control | Posture/Landscape/Food; Close-up hides reference choice; Natural removes creative reference | Widget and device flows |
| Package card | Native description/count and montage; opens reference grid | Shared exported catalog |
| Reference thumbnail | Selects immediately and dismisses chooser; no extra confirmation step | Widget/device selection tests |
| Reference information | Separate example sheet with image, angle/light instructions, cues/safety and Done | Food safety device assertion; catalog export |
| Pose example Prev/Next/swipe | Wraps within that package and updates active pose/example | `ReferenceDetails`, `adjacentReference` |
| Active pose swipe | Native 86x96 example, category/setting, complete instruction and angle/light; drag 44 points or accessible previous/next action chooses an adjacent pose | Widget deliberate slow-swipe and hierarchy checks |
| Creative Next/Natural | Native step bar exists only for a selected posture; Natural returns to scene guidance. Next advances manually; urgent framing can interrupt without completing a pose automatically | Widget hierarchy + 150 native coaching fixtures and nine baseline fixtures |
| Live advice panel | Selected posture replaces the scene card; selected Food/Landscape retains its recipe card plus scene advice. Recipe selection has no posture step bar | Native reachable `liveAdvicePanel`; widget checks |
| Composition instructions | Landscape/Food recipes and angles come from native catalog, not a new independent angle picker | Export drift validation |

## Review, library, imports and storage (P4/P7)

| Native source/action | Flutter destination / behavior | Verification / limit |
| --- | --- | --- |
| Camera thumbnail: `openSystemPhotoLibrary` | Requests accessible Photos library; newest-first metadata; loads only opened images | Lazy loading/wrap/access/failure regression tests; platform integration |
| Library authorization | Authorized/limited supported; denied/empty falls back to captured history or import; Settings available | Android API-specific permissions; iOS read/write authorization |
| Library loading | Private byte-preserving copy of chosen asset; bounded three-copy cache; iCloud/network errors retain previous selection | No eager full-library decoding or gallery deletion |
| Review header Photos picker | Separate system multiple-photo selection, maximum 20 | Picker bridge; separate from full-library thumbnail action |
| Folder import | Up to 50 images, filename order; bounded traversal and private copies | Intentionally visible by user decision, beyond native Debug-only button |
| Camera return | Ends imported/library session, releases owned copies/variants, resumes camera | Navigation/cleanup regression tests |
| Prev/Next/image swipe | Wraps imported selection/library; guards busy/pending original; a 60-point drag navigates even when slow | Library/source-isolation and deliberate slow-swipe tests |
| Before/After/Split | Above image, source starts Before and successful treatment selects After | Comparison/export tests |
| Image label and fullscreen | Original/processed label, treatment subtitle, explicit fullscreen plus tap; pan/zoom/split | Review widgets; physical visual check |
| Treatment selector | Native three treatment choices and level 0-5; automatic debounced update, Reset 0 | Latest-edit coalescing and original protection tests |
| Treatment settings | Global review settings, separate from capture settings; no per-photo persistence invention | Stored settings and immutable original |
| Original/Reframe/Level | Source-associated native transforms; missing geometry disables unsupported correction | Horizon/reframe bridge fixtures |
| Detailed analysis | Debug-only face/group/pose, lighting, composition, issues and availability; optional pose package | Shared analysis schema and native fixtures |
| Save copy/Share | Before exports original; After/Split exports selected variant; explicit copy action | Wrong-source/failure safeguards and native bridge checks |
| Pending original | Retry/Discard; cannot capture/import/library-navigate over it; recover after interruption | Controller/native recovery tests |
| Recent history | 25 saved private originals plus pending original; owned derived cleanup | Retention and reconciliation tests |
| Photos commit crash | iOS add-only save can commit before pending manifest is acknowledged | Documented duplicate-retry window; retained original, no gallery deletion |

Library browsing does not install posture/landscape packages. External packages with per-image instructions remain a separate future feature, as agreed with the user.

## Platform services and acceptance (P2-P5/P8)

Shared Swift/Dart comparisons cover nine baseline coaching cases, 150 rich coaching cases, 24 scene transitions and 16 pose geometry cases. Both native services provide face/pose/luminance, subject bounds, optical horizon and explicit availability. Android groups use multiple faces with single-body pose; saliency uses color contrast and horizon uses gradients, rather than claiming Vision-identical detectors. iOS and Android use the reference processing order and guarded face/landscape operations; full-resolution native processing keeps large images outside the typed bridge. Android and Core Image output need agreed visual tolerances using matched inputs.

Seven tutorial pages now have distinct native-inspired illustrations and current workflow text. Controls expose semantics; large-text portrait/landscape and narrow Manual editors are automated. TalkBack/VoiceOver reading order, matched iPhone visuals, speech/audio interruption, ten-minute thermal/performance sessions and cross-vendor coverage remain physical acceptance tasks in [joint testing](cross_platform_joint_testing.md).

The build record and source SHA must accompany validation. A passed build or an action marked implemented must never be reported as accepted visual parity. Final iPhone comparison is performed locally on the user's Mac; no SSH/signing information is required to finish independent software work.

Simulator library validation uses a single public catalog fixture and a disposable erased simulator. Photos authorization is configured with Apple's [simctl privacy workflow](https://developer.apple.com/videos/play/wwdc2020/10647/), and fixture insertion uses [simctl addmedia](https://devstreaming-cdn.apple.com/videos/wwdc/2019/418o9bbtoe880sauh/418/418_getting_the_most_out_of_simulator.pdf). The bridge checks exact provider bytes, failed missing-asset lookup, private-copy deletion and retention of the original Photos asset. These checks are pending in the current CI run and do not establish physical picker/limited-access acceptance.

## Android detector and memory decision (P3/P4)

The port retains its pinned bundled face model `com.google.mlkit:face-detection:16.1.7` and single-person pose model `com.google.mlkit:pose-detection:18.0.0-beta5`; this run adds no detector dependency. Bundling avoids a first-use model download. Google's [face detector guide](https://developers.google.com/ml-kit/vision/face-detection/android) estimates a 6.9 MB bundled size increase and explains why contour analysis is limited to the most prominent face. The [pose detector guide](https://developers.google.com/ml-kit/vision/pose-detection/android) and [coverage description](https://developers.google.com/ml-kit/vision/pose-detection) document 33 landmarks, single-person coverage and beta status; advertised benchmark rates are not measurements on our phones. SDK use is governed by [ML Kit Terms and Privacy](https://developers.google.com/ml-kit/terms), distinct from the documentation sample-code license.

Live analysis uses keep-latest camera frames with session IDs and throttling; still analysis uses a bounded image, separate multi-face detection and one prominent contour/pose. No detector network download is needed by this configuration. Depth/scenic fallback stays available when face/pose analysis fails. Matched low-light/group/partial-body calibration and thermal measurements remain physical acceptance, not reasons to silently label a single-body pose detector as multi-person coverage.

Full-resolution Android processing estimates 12 bytes per output pixel against 65% of the runtime heap budget before decoding. Photos beyond the budget fail visibly and retain the original. The analysis copy is bounded to 1400 pixels, while supported output preserves native dimensions. This guard is a conservative estimate, not a device-independent memory guarantee; recorded Galaxy debug PSS was 466-488 MiB in the earlier ten-minute run. Current high-resolution fixture validation and matched iPhone performance remain tracked separately.
