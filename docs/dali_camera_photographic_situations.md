# Dali Camera Photographic Situations

Date: October 5, 2026

Status: Initial implementation in progress

Implementation update: The native iOS implementation includes Auto and all six manual situations, a horizontally scrolling selector, manual override behavior, stable three-frame automatic recommendations, and initial situation-specific coaching cards. Auto recognizes Portrait, Group, Person + Scene, Landscape, Action, and Close-up. Action uses tracked subject movement while the phone is reasonably stable. Close-up uses Vision object-saliency measurements. These two newer classifications are intentionally conservative and remain available as manual overrides.

Situation and Posture share one compact control row in the lower coaching area. Situation starts in Auto and supports manual override. Posture appears for people-based situations, starts at Natural, and immediately begins the selected lower-screen instruction sequence. Camera angle is no longer a separate top-level selection; every posture supplies and displays its recommended angle automatically.

Landscape uses its own **Landscape** button in that row rather than reusing Posture. Its category-first chooser offers Mountains, Lakes & Water, Plains & Fields, and Plants & Gardens, with six photo-based composition recipes per package. Each recipe recommends its angle and light automatically, includes a safety note, and is shown alongside the existing live horizon guidance. Natural disables the selected composition recipe without disabling horizon coaching.

The Posture control first opens a category chooser with five packages: **Male / Masculine**, **Female / Feminine**, **Couples**, **Friends / Groups**, and **Family**. Selecting a package opens only that package's photo montage for quick lookup. The solo packages remain user-selectable for any subject; the camera does not infer gender. Couples provides coordinated two-person poses, Friends / Groups supports three or more people, and Family adds caregiver/child and multigenerational arrangements.

Each posture also carries an **Indoor**, **Outdoor**, or **Indoor & Outdoor** setting tag, a recommended camera angle, and a recommended lighting setup. Setting is descriptive metadata rather than the primary navigation, so a versatile posture is not duplicated in multiple packages. The expanded catalog contains 40 postures—nine masculine, thirteen feminine, six couples, six friends/groups, and six family examples—with room for future occasion packages.

After selecting a posture, the active posture card supports horizontal navigation within that collection: swipe left for the next posture or right for the previous posture. Changing posture restarts its short guidance sequence and updates the compact Posture dropdown.

The posture card always shows the full, practical directions, recommended camera angle, and recommended lighting for the selected posture. An angle explicitly chosen by the user still takes precedence. The larger detail view explains how to create the suggested lighting setup.

Tap the active posture card to open a larger photo-realistic example of that exact posture. The example sheet repeats the practical instructions and shows a camera-angle note only when the posture has a specific recommendation. Swipe the large photo left or right to browse the next or previous posture in the same collection; the active posture selection stays synchronized. Horizontal swiping on the compact card works the same way.

The compact posture card uses a thumbnail of the same photo-realistic example instead of a schematic line figure, making the selected body position recognizable without opening the larger sheet.

## Purpose

Dali Camera should let the user choose the photographic situation before receiving coaching. The selection changes the composition checks, instructions, pose suggestions, and priorities shown while taking the photograph.

The initial list should cover the situations people encounter most often without making the camera interface feel complicated.

## Recommended initial list

| Situation | Intended use | Coaching priorities | Example instructions |
| --- | --- | --- | --- |
| **Portrait** | One main person, usually framed closely | Face angle, eye line, headroom, flattering camera height, body and limb cropping, pose, and light on the face | “Raise the camera slightly.” “Leave a little more space above their head.” |
| **Group** | Two or more people | Make every face visible, balance spacing, keep people away from frame edges, avoid cutting off limbs, and choose a suitable camera distance | “Ask the person on the left to move closer.” “Step back to keep everyone in frame.” |
| **Person + Scene** | A person photographed with a landmark, view, or travel setting | Balance the person and environment, preserve recognizable scenery, align the horizon, control subject size, and choose subject placement | “Move right so the view remains visible.” “Step back to include more of the scene.” |
| **Landscape** | Scenery without a main person | Level horizon, foreground interest, depth, visual balance, leading lines, and sky-to-ground proportion | “Lower the camera to include the foreground.” “Place the horizon above the center.” |
| **Action** | Children, sports, pets, walking, or other movement | Leave space in the direction of motion, maintain subject visibility, anticipate movement, avoid accidental cropping, and encourage stable capture | “Leave more room in front of the subject.” “Track the subject before taking the photo.” |
| **Close-up** | Food, flowers, products, crafts, and small details | Subject isolation, clean background, focus distance, camera alignment, glare, shadow, and edge cropping | “Move slightly farther away to focus.” “Change the angle to reduce glare.” |

## Naming decisions

### Person + Scene

Use **Person + Scene** instead of **People + Landscape**. It is shorter, works for city and indoor locations as well as natural landscapes, and communicates that both the person and the setting matter.

### Group

Use **Group** instead of **Group Photo** in the selector to keep labels compact. Supporting text can explain that this mode is for two or more people.

### Action

Action should cover moving people, children, sports, and pets initially. Separate modes can be considered later if testing shows that users expect specialized coaching for them.

### Close-up

Close-up provides a useful general category without adding separate Food, Product, Flower, and Macro modes. True macro photography may require device-specific lens behavior, so the interface should promise close-up coaching rather than guaranteed macro capability.

## Conditions that should not be separate situations

Some characteristics affect every kind of photograph and should be detected automatically rather than requiring another user selection.

| Condition | Recommended behavior |
| --- | --- |
| **Low light / night** | Adapt the instructions for the selected situation: hold steady, find better light, avoid strong backlighting, or use the appropriate camera capability. |
| **Backlighting** | Adjust face or subject-lighting advice within Portrait, Group, Person + Scene, Action, or Close-up. |
| **Phone orientation** | Adapt framing guidance automatically for portrait or landscape phone orientation. |
| **Front camera / selfie** | Adapt direction language and mirroring automatically. Consider a dedicated Selfie situation only if the general Portrait guidance is not sufficient. |

## Possible future situations

These are useful, but adding them now could make the first selection experience crowded:

- **Selfie** — arm-length distance, front-camera eye line, face placement, and background awareness.
- **Pet** — eye-level camera position, animal attention, and unpredictable movement.
- **Food** — overhead and three-quarter angles, plate alignment, shadows, and color.
- **Architecture** — vertical alignment, symmetry, perspective, and edge control.
- **Event** — candid people, mixed lighting, groups, and fast changes.
- **Document** — rectangular alignment, glare, readable detail, and complete edge capture. This may be better as a utility rather than an artistic coaching mode.

Add a dedicated situation only when it needs meaningfully different coaching and users can recognize when to select it.

## Selection interface

A standard segmented control is too crowded for six situations on a phone. Use a compact dropdown for Situation alongside Angle and, when people are involved, Posture:

`Situation: Auto ▾ · Angle: Eye level ▾ · Posture: Natural ▾`

Recommended behavior:

- Keep the coaching on/off control in the top bar.
- Show the situation selector in the lower coaching area only when coaching is on.
- Keep the selected situation, angle, and posture visible in one row without opening another page.
- Change the instruction content in place when the selection changes.
- Start in **Auto**, which recommends a situation from the live camera view.
- Let the user override the recommendation at any time.
- Keep a manual selection until the user chooses Auto again; do not silently replace it.
- Remember the most recently selected situation during the current session.
- Use both symbols and text; do not rely on symbols alone.
- Keep the shutter available regardless of the selected situation or coaching state.

## Automatic situation selection

Automatic selection can be best effort. It does not need to be perfect because the user can immediately choose a different situation.

### Initial observable signals

| Signal from the camera view | Likely situation |
| --- | --- |
| One prominent face or body occupying much of the frame | Portrait |
| Two or more visible faces or bodies | Group |
| One or more people occupying a smaller portion of a scene with a visible background | Person + Scene |
| No prominent person, with a horizon or broad distant scene | Landscape |
| Sustained subject movement between frames | Action |
| One nearby object occupying much of the frame, especially without a face | Close-up |

The most ambiguous distinction will be **Portrait** versus **Person + Scene**. The first implementation can use the detected person's size relative to the frame and the amount of visible background. The user override is the final authority.

### Stability and confidence

The app should not switch situations every time the camera moves slightly:

- Evaluate multiple consecutive frames instead of making a decision from one frame.
- Require a candidate to remain likely for a short interval before changing the recommendation.
- Use separate thresholds for entering and leaving a situation to avoid rapid back-and-forth changes.
- Keep the current recommendation when no alternative has sufficient confidence.
- Prefer the user's most recent manual choice when automatic confidence is low.
- Pause automatic changes while a pose sequence is active or the shutter is being pressed.

Show the result as a suggestion, such as **Auto: Group**, so the user understands that it was inferred. Do not present the classification as certain.

### Override behavior

1. The camera opens in Auto and displays the current recommendation.
2. The user may tap any situation to override it.
3. The manual selection remains locked even if the camera view changes.
4. The user taps Auto to resume live recommendations.
5. Turning coaching off hides the selector but should preserve its Auto or manual state when coaching is turned back on.

Situation analysis should run on-device using the visual signals already needed for coaching. It should not delay the preview or prevent the user from taking a photograph.

## Situation-specific coaching

Each situation should begin with a small, curated list of coaching rules. This gives the first version predictable behavior and lets the team test whether each instruction is understandable before making the system more dynamic.

### First version

For each situation:

- Define the important checks in priority order.
- Provide short instructions for each detectable problem.
- Specify whether the photographer, subject, or group should act.
- Define when the instruction is considered resolved.
- Include a fallback creative suggestion when no clear problem is detected.
- Suppress rules that conflict with the selected situation.

The app should show only the highest-priority useful instruction. The shutter must remain available even when an instruction has not been resolved.

### Later expansion

The coaching catalog can grow in two complementary ways:

1. **Add reviewed coaching rules.** Expand the curated list when testing identifies a common, actionable photographic problem.
2. **Use more live camera evidence.** Add stronger scene, motion, lighting, subject, and composition measurements so the app chooses the most relevant item from the catalog.

The live camera should select and prioritize coaching; it should not generate unrestricted instructions in the initial implementation. A constrained catalog makes the language consistent, testable, and less likely to contradict what is visible.

Each new rule should record:

- the situations where it applies,
- the required camera observations and confidence,
- its priority relative to safety and basic framing problems,
- the minimum display time and cooldown,
- conflicting rules that it suppresses,
- and how the team will validate that the instruction helped.

## Coaching design principles

- Give one short, actionable instruction at a time.
- Say who should act: photographer, subject, or group.
- Prioritize safety and basic capture problems before artistic refinements.
- Avoid instructions that conflict with the selected situation. For example, Action should not repeatedly ask a moving subject to hold still.
- Do not claim that a creative choice is objectively wrong. Present composition and pose guidance as suggestions.
- Prefer automatic detection for lighting, orientation, horizon, and camera direction.

## Questions for review

1. Is **Person + Scene** clear enough, or would **Travel Photo** be easier for the intended audience?
2. Should **Action** be in the first release, or should it follow after the four static situations are reliable?
3. Is **Close-up** broad enough for both food and objects, or should **Food** be a separate high-priority situation?
4. Does Portrait need a visible **Selfie** variation when the front camera is selected?
5. Should automatic selection return after each capture, or remain in the user's current Auto/manual state for the full camera session?
6. When Auto has low confidence, should it keep the last recommendation or fall back to Person + Scene?
7. Which three situation-specific instructions should be implemented first for each situation?

## Proposed first-release decision

Start user testing with Auto plus all six recommended situations:

1. Auto
2. Portrait
3. Group
4. Person + Scene
5. Landscape
6. Action
7. Close-up

Auto should make a stable best-effort recommendation, while a manual override remains selected until the user returns to Auto. Begin with a reviewed coaching catalog for every situation, then use additional camera observations to select more relevant guidance and expand the catalog over time.

Treat low light, orientation, and front-camera use as automatic adaptations. During testing, measure whether users understand the labels, can find the desired situation quickly, trust or correct the automatic recommendation, and receive instructions that are clearly different and useful for each selection.
