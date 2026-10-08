# Native UI parity inventory

Reference: native iOS `d53a977`, audited October 8, 2026. This records implementation coverage, not physical visual sign-off. Source behavior is in `DaliCamera/ContentView.swift`, `Models.swift`, `CameraModel.swift` and the native processing engines. Both Flutter backends are connected unless a limitation is stated.

| Reference area | Implemented behavior | Acceptance / platform limits |
| --- | --- | --- |
| Header / App Settings / tutorial | Dali Cam, Manual, coaching light, gear and camera switch in native order; teal active states; landscape sidebar; About/version, native placeholder sections and seven-step tutorial | Earlier inventory omitted this header behavior; corrected after user comparison. Camera controls beside shutter; Help/import accessible through App Settings. Physical styling/accessibility acceptance pending |
| Camera viewport / overlays | Complete oriented preview, normalized geometry, guidance/status and capture controls | Front/rear edge alignment, rotation and physical styling comparison |
| Situation menu / classifier | Eight choices; Auto starts Person + Scene, uses three stable candidates, holds ambiguity and freezes during creative guidance | Native transition fixtures pass; matched Android scene calibration pending |
| Effects menu | Independent Filter/Beautifier Auto, Custom, Off; Both Auto/Both Off; selected values and settings | Saved custom filter survives Off/Auto; capture applies from immutable original |
| Posture / Landscape / Food menu | Context follows active situation; Close-up hides reference menu; selected reference/Natural labels | Joint menu/navigation comparison |
| Packages / reference details | Montage overview, native descriptions/counts, reference grids, angles, lighting, cues and safety; selection feeds guidance | All shared catalog content exported; physical typography/spacing comparison |
| Natural / Next / Skip / coaching | Manual progression, issue priority/cooldown/interruption, recipient/direction/status | 9 baseline and 150 rich native coaching cases; creative pose completion remains manual |
| Detection | Face landmarks, pose geometry, luminance, scenic saliency/horizon, motion and explicit availability | Android multi-face groups + single-body pose; color-contrast saliency and gradient horizon differ from Vision; 16 native pose fixtures |
| Camera controls | Timer Off/3/5/10; hold Burst/Timer/Disabled; voice preference/custom phrase; actual listening status | On-device recognition may be unavailable. Desired state survives pause independently from actual listening |
| Filter settings | Named presets and seven parameters, Auto per situation, watermark; mode/preset/raw values persisted | iOS native Core Image sequence; Android corresponding spatial/color operations require visual tolerance acceptance |
| Beautifier settings | General Enhance, Portrait Polish, Landscape Polish; native levels, presets, option switches and separate capture/review settings | Landmark-aware guarded eyes/lips, skin/blemishes and sky/color; strength-zero avoids cosmetics |
| Depth | Reference rounded subject-region live overlay and feathered saved blur; subject/focus fallback | Baseline has no semantic segmentation or live Filter/Beautifier rendering. Android bounded preview blur needs physical edge/performance checks |
| Focus / exposure / Manual | Auto/M, shutter/ISO, linked ISO, EV, lock, tap metering, zoom, actual aperture and supported metering | Hardware-gated. Android live exposure-offset unavailable; Tv/Av belongs to disabled native iOS 27 compile gate, outside Xcode 16.4 baseline |
| Recent / review navigation | 25 saved originals, previous/next/swipe/wrap, source-isolated derived selections | Global treatment settings follow reference; no per-photo treatment persistence requirement |
| Import | Up to 20 selected photos or 50 folder images; private byte-preserving copies, cancellation and bounded traversal | Folder import intentionally visible by product decision; session review only, not package installation |
| Comparison / fullscreen | Before/After/Split, draggable split, pan/zoom; new source starts Before, processed selection shows After | Before exports original; After/Split export selected version |
| Review treatments | Original, optional legacy tighter crop/filter, native Reframe/Level/Enhance/Portrait/Landscape, strengths and options | Missing measurements disable geometric treatments; originals retained on failure |
| Analysis / diagnostics | Pose, face/group, lighting, composition, availability and debug measurements; coaching package choice | Physical confidence/calibration comparison |
| Save / share / recovery | Save original first, explicit Save copy, selected exports, retry/discard, pending recovery and private cleanup | Android share uses cache copy; iOS retains busy state until share sheet finishes. iOS add-only Photos commit crash window can duplicate retry |
| Help / welcome / accessibility | Current workflow help, semantic control labels, wrapping comparison choices and large-text/landscape navigation | Widget checks pass; TalkBack/VoiceOver, permission/audio interruptions and matched physical screenshots pending |

## Defaults and persistence

Situation Auto; timer Off; hold Burst; voice false; custom phrase empty; filter Auto on fresh install; Beautifier Off. Existing saved choices are preserved. Capture polish strength 3, Portrait Polished and Landscape Vivid. Portrait brightness/smoothing/blemishes/eyes on and lips off; landscape sky/color on. Review settings follow separate native defaults. Mode switches retain the saved custom filter preset and parameter values.

## Validation

The pipeline compares native Swift coaching, situation transitions and pose geometry, builds Android and unsigned iOS, runs shared/widget checks, preserves native iOS unit validation and tests the Flutter native file bridge on an iPhone simulator. Android camera and file-processing checks use a separate test app so normal app settings are retained. See [joint testing](cross_platform_joint_testing.md) for current device evidence and physical acceptance tasks. No physical iPhone sign-off has been recorded.
