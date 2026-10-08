# Native UI parity inventory

Reference: `d53a977`, inspected October 8, 2026. This is the initial P0 audit; it is not a completed screen-by-screen acceptance report. Reference sources are `DaliCamera/ContentView.swift` and `DaliCamera/Models.swift`.

| Native area / source symbol | Flutter state after first P1 changes | Remaining acceptance/work |
| --- | --- | --- |
| Viewport, overlays, coaching selection row | Full-frame preview; selection row now precedes guidance | Matched iPhone screenshots, overlays and visual styling |
| `situationMenu`, `PhotographicSituation` | All eight choices connected | Physical iPhone comparison and Android detector calibration pending |
| `activeSituation`, `SituationClassifier` | Auto uses three stable candidate frames, starts with Person + Scene, holds ambiguous scenes and pauses during creative guidance | Real Swift transition fixtures run in CI; physical calibration pending |
| `effectsMenu` | Filter Auto/Custom/Off quick actions and settings entry | Both Auto/Both Off and independent Beautifier modes await P4; Beautifier visibly unavailable |
| `selectionControlLabel` | Title/icon/chevron and selected value per control | Physical comparison of size, placement, colors and typography; no pixel parity claimed |
| `postureMenu`, `landscapeMenu`, `foodMenu` | Contextual reference title and selected reference/Natural; hidden for Close-up | Physical active-situation and navigation comparison pending |
| `posturePackageCard`, landscape package cards | Montage overview cards, counts, selected indicator, then reference grid | Descriptions exported from native Swift; physical styling comparison pending |
| Reference detail and selection | Existing angle, light, cues and safety; selection feeds guidance | Match native detail/navigation transitions and selection persistence |
| Natural, Next/Skip, recipient/status/direction | Existing manual creative progression preserved | Complete interruption/cooldown parity fixtures |
| `situationGuidance` | Shared Group, Action, Close-up, Food and Landscape rules; explicit unavailable fallbacks | Android multi-person/saliency/horizon signals and full posture pipeline remain pending |
| `controls`, latest photo, camera switch, settings/help | Existing controls retained | Matched layout and all native action/default checks |
| Shutter timer, hold action | Off/3/5/10; Burst/Timer/Disabled | Native persisted defaults and edge-state comparison |
| Voice shutter | Standard/custom commands and actual listening toggle | Persisted desired state versus active listening and interruption semantics |
| `photoFilterDisplayValue`, filter settings | Named presets plus seven parameters and watermark | Native iOS Core Image filter order/coefficients ported; Auto also selects Vivid for Action and Bright for Close-up. Separate stored mode/preset state and Android render parity remain pending |
| Beautifier settings | Not implemented | General Enhance, Portrait/Landscape Polish, native levels/presets and switches |
| Live effect/depth controls | Not implemented | Processing/masking parity and measured device fallback |
| Focus and Exposure / Manual workspace | Auto/manual M, shutter/ISO, tap/zoom/lock/EV where supported | Tv/Av, linked ISO, meter, recommendations; actual capability/SDK checks |
| `reviewSlideshowView`, navigation | Recent originals grid, previous/next/swipe navigation and single-file import | Multi-photo/folder import and per-photo treatment persistence remain pending |
| `reviewComparisonPicker`, review treatments | Original/crop/styled copy and zoom | Native comparison modes, reframe/level/enhance/beautify |
| `reviewAnalysisCard`, metric/debug chips | Bounded instruction log | Rich photo analysis, lighting/pose summaries and diagnostics |
| Review export/recovery controls | Original-safe save/share/retry/discard | Interrupted gallery insertion reconciliation and full derived-copy cleanup |
| Tutor/help, permissions, accessibility | Existing welcome/help and basic semantics | Content alignment, TalkBack/VoiceOver and physical large-text acceptance |

## Defaults found in the reference

- Situation is initially Auto; its classifier recommendation is initially Person + Scene.
- Timer is Off, long press is Burst, voice preference is false, and custom phrase is empty.
- Filter application is Auto; Beautifier application is Off. Flutter currently retains its existing Off filter default until the full settings/state migration is implemented.
- Capture polish strength is 3; Portrait preset is Polished/strength 3, Landscape preset is Vivid/strength 3.
- Portrait brightness/smoothing/blemishes/eyes default on, lips off; landscape sky/color default on.

These findings are required follow-up work, not permission to silently overwrite existing user preferences. Preserve saved choices during migration.

## Evidence for this checkpoint

- Flutter navigation test exercises all three controls, package overview/back navigation, Food reference selection, filter Auto and Custom settings.
- All eight situation choices are enabled. Missing detector measurements produce explicit waiting/fallback guidance rather than false ready states.
- Existing recovery, stale-session, timer, burst, history retention and large-text checks are retained.
- No physical iPhone screenshots or user visual sign-off have been recorded yet.

Follow the [remaining porting plan](cross_platform_remaining_port_plan.md) for dependencies and completion rules.
