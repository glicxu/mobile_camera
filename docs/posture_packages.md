# Dali Camera Posture Packages

Date: October 6, 2026
Status: **Paused after the Family package; ready to resume later**

## Review objective

Review the posture-package structure, package names, pose selection, coaching language, and priorities for future packages. This document distinguishes the current implementation from proposed expansion.

## Implementation status snapshot

The first package milestone is complete and installed on the review iPhone. Further package production is intentionally deferred; no unfinished package is partially exposed in the app.

| Area | Status | Current result |
| --- | --- | --- |
| Package navigation | Implemented | Category-first chooser; each package opens its own photo montage. |
| Implemented packages | Implemented | Male / Masculine, Female / Feminine, Couples, Friends / Groups, and Family. |
| Pose assets | Implemented | 40 selectable photo references with stable IDs and project-local image assets. |
| Coaching metadata | Implemented | Two cues, recipient, category, setting, automatic camera angle, and lighting recommendation for every pose. |
| Natural mode | Implemented | Disables posture coaching while leaving ordinary camera coaching available. |
| Separate Angle control | Removed by design | Recommended angle comes from the selected posture and remains visible on its card. |
| Automated validation | Passing | 29 unit tests, package-specific UI tests, and the complete camera/coaching UI flow. |
| Physical build | Installed | Latest five-package build installed and launched on the review iPhone. |
| Additional packages | Deferred | Graduation, Kids, Maternity, and Professional / Headshot. |
| Auto package recommendation | Deferred | Product behavior is specified below; implementation has not started. |

### Resume point

When package work resumes:

1. Review the five implemented packages on-device and record any image or coaching-language changes.
2. Confirm whether **Graduation** remains the next package.
3. Create its final pose list, reference images, coaching cues, angle, lighting, and accessibility metadata using the same package structure.
4. Add catalog-count, recipient, package-selection, and full-flow regression coverage.
5. Revisit Auto recommendations only after the manual catalog and neutral Solo / Two People / Group vocabulary are approved.

## Current product decision

Dali Camera offers a large, photo-based posture montage. A user selects a reference pose, then receives two short coaching cues while the camera remains available.

The current catalog contains 40 poses:

| Package | Pose count | Purpose |
| --- | ---: | --- |
| Male / Masculine | 9 | Relaxed standing, seated, walking, and turned portrait poses with traditionally masculine styling. |
| Female / Feminine | 13 | Standing, seated, moving, turned, hands, and hair poses with traditionally feminine styling. |
| Couples | 6 | Coordinated standing, seated, moving, and close-contact poses for two adults. |
| Friends / Groups | 6 | Coordinated standing, seated, moving, celebratory, and conversational poses for three or more people. |
| Family | 6 | Comfort-first standing, seated, moving, caregiver/child, and multigenerational arrangements. |

Package labels describe visual styling; they are not eligibility rules. Any user may select any solo package, and the camera does not infer gender.

## Selection and coaching behavior

- **Natural** is the default. It means posture coaching is off, while ordinary framing, lighting, level, and distance coaching may continue.
- The Posture button first opens a quick package chooser. Selecting a package opens a scrollable photo montage containing only that package's poses.
- Selecting a photo closes the montage and starts that pose's coaching sequence.
- Solo instructions are addressed to **Subject**. Couples instructions are addressed to **Couple**; Friends / Groups to **Group**; and Family to **Family**.
- Only one short cue is shown at a time. The user advances with **Next / Done** or skips a cue.
- Swiping the active posture card moves to the previous or next pose within the same package.
- Tapping the active card opens the full reference photo and complete instructions.
- Every posture automatically applies a useful starting camera angle; there is no separate angle selection in the live camera.
- Every posture includes an automatic recommended camera angle and lighting setup. Both appear with the photo; the detail view also explains how to create the recommended light. There is no separate Angle control in the live camera.
- Pose completion is user-confirmed. The app does not claim to recognize that a creative pose has been completed correctly.
- The shutter remains available throughout coaching.

## Package 1: Male / Masculine

| ID | Pose | Category | Setting | Recommended angle | Coaching cues |
| --- | --- | --- | --- | --- | --- |
| M1 | Relaxed standing | Standing | Indoor & Outdoor | Eye level | Stand with your feet comfortably apart. Relax your shoulders. |
| M2 | Three-quarter stance | Turned | Indoor & Outdoor | Eye level | Turn your body slightly to your right. Bring your face back toward the camera. |
| M3 | One hand in pocket | Standing | Indoor & Outdoor | Eye level | Rest one hand in your pocket. Let your other arm hang loosely. |
| M4 | Seated forward lean | Seated | Indoor & Outdoor | Eye level | Sit and lean slightly forward. Rest your forearms on your thighs. |
| M5 | Casual walking | Moving | Outdoor | Low angle | Walk slowly across the frame. Look toward the camera for the next shot. |
| M6 | Relaxed arms crossed | Standing | Indoor & Outdoor | Eye level | Cross your arms loosely at mid-torso. Drop your shoulders and keep your hands relaxed. |
| M7 | Casual wall lean | Standing | Indoor & Outdoor | Eye level | Lean one shoulder lightly against the wall. Bend the outside knee and relax your hands. |
| M8 | Seated sideways | Seated | Indoor & Outdoor | Eye level | Sit sideways with both feet visible. Turn your upper body comfortably toward the camera. |
| M9 | Natural look away | Turned | Indoor & Outdoor | From the side | Angle your body slightly away from the camera. Look naturally just past the camera. |

## Package 2: Female / Feminine

| ID | Pose | Category | Setting | Recommended angle | Coaching cues |
| --- | --- | --- | --- | --- | --- |
| F1 | Weight-shift stance | Standing | Indoor & Outdoor | Eye level | Rest your weight on one leg. Soften the other knee. |
| F2 | One foot forward | Standing | Indoor & Outdoor | Low angle | Place one foot slightly in front. Turn your shoulders a little toward the camera. |
| F3 | Hand at waist | Standing | Indoor & Outdoor | Eye level | Rest one hand lightly at your waist. Relax your other arm. |
| F4 | Seated angled pose | Seated | Indoor & Outdoor | Slightly high | Sit with your knees angled slightly to one side. Turn your face toward the camera. |
| F5 | Over-shoulder glance | Turned | Indoor & Outdoor | From the side | Turn your body partly away from the camera. Look back over your shoulder comfortably. |
| F6 | Relaxed arms crossed | Standing | Indoor & Outdoor | Eye level | Cross your arms loosely at mid-torso. Drop your shoulders and keep your hands relaxed. |
| F7 | Casual wall lean | Standing | Indoor & Outdoor | Eye level | Lean one shoulder lightly against the wall. Bend the outside knee and relax your hands. |
| F8 | Walking turn | Moving | Outdoor | Low angle | Take a slow step away from the camera. Turn your face and shoulders gently back toward it. |
| F9 | Seated sideways | Seated | Indoor & Outdoor | Eye level | Sit sideways with both feet visible. Turn your upper body comfortably toward the camera. |
| F10 | Gentle hair sweep | Hands & Hair | Indoor & Outdoor | Eye level | Lift one hand lightly into your hair. Keep your fingers relaxed and your face visible. |
| F11 | Hand near cheek | Hands & Hair | Indoor & Outdoor | Eye level | Bring relaxed fingertips beside your cheek. Keep your eyes and jawline uncovered. |
| F12 | Arm across waist | Hands & Hair | Indoor & Outdoor | Eye level | Rest one forearm softly across your waist. Let your other arm hang freely. |
| F13 | Hands loosely clasped | Hands & Hair | Indoor & Outdoor | Eye level | Clasp your hands loosely below your waist. Move them slightly to one side and relax your shoulders. |

## Package 3: Couples

The Couples package uses neutral language and does not assume gender, relationship type, or which partner takes a particular position.

| ID | Pose | Category | Setting | Recommended angle | Coaching cues |
| --- | --- | --- | --- | --- | --- |
| CP1 | Close standing | Standing | Indoor & Outdoor | Eye level | Stand close with your shoulders lightly touching. Turn both faces toward the camera and relax your outside arms. |
| CP2 | Arm around waist | Standing | Indoor & Outdoor | Eye level | Stand slightly staggered with one partner just behind the other. Place one arm gently around the front partner's waist. |
| CP3 | Back to back | Standing | Indoor & Outdoor | Eye level | Stand back to back with light contact at your shoulders. Angle outward slightly and turn both faces toward the camera. |
| CP4 | Walking hand in hand | Moving | Outdoor | Low angle | Hold hands and take a slow step together. Look at each other while keeping your joined hands visible. |
| CP5 | Seated together | Seated | Indoor & Outdoor | Slightly high | Sit close with your shoulders touching and bodies angled inward. Keep both sets of hands relaxed and visible. |
| CP6 | Forehead to forehead | Standing | Indoor & Outdoor | Eye level | Turn toward each other and step comfortably close. Touch foreheads lightly and rest your hands on each other's upper arms. |

### Couples visual reference set

| Close standing | Arm around waist | Back to back |
| --- | --- | --- |
| <img src="../DaliCamera/Assets.xcassets/PoseCoupleCloseStanding.imageset/pose-couple-close-standing.png" width="180" alt="Couple demonstrating a close standing pose"> | <img src="../DaliCamera/Assets.xcassets/PoseCoupleArmAroundWaist.imageset/pose-couple-arm-around-waist.png" width="180" alt="Couple demonstrating an arm-around-waist pose"> | <img src="../DaliCamera/Assets.xcassets/PoseCoupleBackToBack.imageset/pose-couple-back-to-back.png" width="180" alt="Couple demonstrating a back-to-back pose"> |
| Walking hand in hand | Seated together | Forehead to forehead |
| <img src="../DaliCamera/Assets.xcassets/PoseCoupleWalking.imageset/pose-couple-walking.png" width="180" alt="Couple walking hand in hand"> | <img src="../DaliCamera/Assets.xcassets/PoseCoupleSeated.imageset/pose-couple-seated.png" width="180" alt="Couple seated together"> | <img src="../DaliCamera/Assets.xcassets/PoseCoupleForeheadTouch.imageset/pose-couple-forehead-touch.png" width="180" alt="Couple touching foreheads"> |

## Package 4: Friends / Groups

| ID | Pose | Category | Setting | Recommended angle | Recommended lighting | Coaching cues |
| --- | --- | --- | --- | --- | --- | --- |
| G1 | Shoulder-to-shoulder row | Standing | Indoor & Outdoor | Eye level | Broad, even light | Stand shoulder to shoulder in one relaxed row. Close the gaps slightly and keep every face visible. |
| G2 | Staggered triangle | Standing | Indoor & Outdoor | Slightly high | Broad, even light | Place one person slightly forward and the others just behind on each side. Angle everyone gently inward and keep all faces visible. |
| G3 | Linked-arm walk | Moving | Outdoor | Low angle | Bright open shade | Link arms loosely and take a slow step together. Look toward one another while keeping every face visible. |
| G4 | Seated cluster | Seated | Indoor & Outdoor | Slightly high | Broad, even light | Sit close with the center person slightly forward. Angle the outside people inward and keep every set of hands visible. |
| G5 | Celebration | Standing | Indoor & Outdoor | Slightly high | Broad, even light | Stand close and raise your hands at different heights. Keep every face visible and hold the pose for the next shot. |
| G6 | Casual conversation | Turned | Indoor & Outdoor | Eye level | Broad, even light | Stand in a loose semicircle facing one another. Keep gestures small so every face stays visible. |

### Friends / Groups visual reference set

| Shoulder-to-shoulder | Staggered triangle | Linked-arm walk |
| --- | --- | --- |
| <img src="../DaliCamera/Assets.xcassets/PoseGroupShoulderRow.imageset/pose-group-shoulder-row.png" width="180" alt="Three friends standing shoulder to shoulder"> | <img src="../DaliCamera/Assets.xcassets/PoseGroupStaggered.imageset/pose-group-staggered.png" width="180" alt="Three friends in a staggered triangle"> | <img src="../DaliCamera/Assets.xcassets/PoseGroupLinkedWalk.imageset/pose-group-linked-walk.png" width="180" alt="Three friends walking with linked arms"> |
| Seated cluster | Celebration | Casual conversation |
| <img src="../DaliCamera/Assets.xcassets/PoseGroupSeatedCluster.imageset/pose-group-seated-cluster.png" width="180" alt="Three friends seated together"> | <img src="../DaliCamera/Assets.xcassets/PoseGroupCelebration.imageset/pose-group-celebration.png" width="180" alt="Four friends celebrating"> | <img src="../DaliCamera/Assets.xcassets/PoseGroupConversation.imageset/pose-group-conversation.png" width="180" alt="Three friends in conversation"> |

## Package 5: Family

The Family package uses caregiver and family-member language without assuming a particular family structure. Every close-contact instruction should be treated as optional and comfort-first.

| ID | Pose | Category | Setting | Recommended angle | Recommended lighting | Coaching cues |
| --- | --- | --- | --- | --- | --- | --- |
| FA1 | Family standing row | Standing | Indoor & Outdoor | Eye level | Broad, even light | Stand in one relaxed row with shorter family members near the center. Close the gaps gently and keep every face visible. |
| FA2 | Caregiver side hug | Standing | Indoor & Outdoor | Eye level | Soft, even front light | Stand side by side and bring your faces comfortably closer in height. Add a gentle side hug and turn both faces toward the camera. |
| FA3 | Family seated cluster | Seated | Indoor & Outdoor | Slightly high | Broad, even light | Sit close with younger family members slightly forward. Angle everyone inward and keep hands and faces visible. |
| FA4 | Walking hand in hand | Moving | Outdoor | Low angle | Bright open shade | Hold hands with the youngest family member in the center. Take one slow step together and look toward one another. |
| FA5 | Generations together | Seated | Indoor & Outdoor | Slightly high | Broad, even light | Seat one family member near the center and arrange the others close behind and beside them. Angle everyone inward and keep every face unobstructed. |
| FA6 | Shared family laugh | Turned | Indoor & Outdoor | Eye level | Broad, even light | Stand in a loose cluster and turn gently toward one another. Share a small laugh while keeping every face visible. |

### Family visual reference set

| Standing row | Caregiver side hug | Seated cluster |
| --- | --- | --- |
| <img src="../DaliCamera/Assets.xcassets/PoseFamilyStandingRow.imageset/pose-family-standing-row.png" width="180" alt="Family standing in one row"> | <img src="../DaliCamera/Assets.xcassets/PoseFamilySideHug.imageset/pose-family-side-hug.png" width="180" alt="Caregiver and child sharing a side hug"> | <img src="../DaliCamera/Assets.xcassets/PoseFamilySeatedCluster.imageset/pose-family-seated-cluster.png" width="180" alt="Family seated close together"> |
| Walking hand in hand | Generations together | Shared family laugh |
| <img src="../DaliCamera/Assets.xcassets/PoseFamilyWalking.imageset/pose-family-walking.png" width="180" alt="Family walking hand in hand"> | <img src="../DaliCamera/Assets.xcassets/PoseFamilyGenerations.imageset/pose-family-generations.png" width="180" alt="Multigenerational family portrait"> | <img src="../DaliCamera/Assets.xcassets/PoseFamilySharedLaugh.imageset/pose-family-shared-laugh.png" width="180" alt="Family sharing a natural laugh"> |

## Content and safety principles

- Use invitational, non-judgmental language. Poses are creative options, not corrections to a person's body.
- Avoid judging body shape, attractiveness, weight, age, gender expression, or physical ability.
- Do not infer a package from the camera image. Selection is always explicit.
- Use gender-neutral partner language in Couples.
- Describe gentle contact and comfort explicitly for close-contact poses.
- Never require contact, a difficult balance position, or use of an unsafe surface.
- Keep hands, faces, and joints visible where doing so improves the photograph, without presenting that choice as mandatory.
- Treat left and right in pose cues as the subject's left and right. Photographer movement uses the photographer's viewpoint.

## Package architecture for future growth

The package name should answer **who or what kind of session is being photographed**. Category and setting should remain filters or metadata rather than becoming duplicate packages.

Recommended hierarchy:

1. **Natural** — no posture coaching.
2. **People packages** — Masculine, Feminine, Couples, Family, Friends / Groups, Kids, Maternity, and Graduation.
3. **Session or mood filters** — Casual, Formal, Editorial, Playful, Romantic, Seated, Moving, Indoor, and Outdoor.

This avoids creating separate packages such as “Outdoor Masculine” and “Indoor Masculine,” which would duplicate the same poses. A pose may appear in more than one filtered view while retaining one catalog identity.

## Future extension: Auto category recommendation

Auto should eventually recommend the most relevant posture category and surface it as the first card in the package chooser. The user remains in control and may accept the recommendation, select another package, or choose Natural.

### Proposed experience

1. The user opens Posture and sees an **Auto suggestion** card above the package list.
2. The card shows the suggested category, a short reason, and several preview poses—for example, **“Two people · standing outdoors.”**
3. Tapping the card opens a filtered pose montage rather than immediately starting a pose.
4. The user selects the desired pose from that montage.
5. If confidence is low, the card says **“Choose a category”** and does not make a recommendation.
6. Manual package and pose selections remain stable until the user returns to Auto.

### Signals Auto may use

| Signal | Possible category effect |
| --- | --- |
| Number of visible people | Solo, two-person, or group suggestions |
| Standing, seated, or moving | Filters the montage to the most relevant pose category |
| Indoor or outdoor scene | Prioritizes poses with a compatible setting tag |
| Full body, waist-up, or close portrait framing | Prioritizes poses that fit the visible framing |
| Available wall or seating context | May prioritize wall-lean or seated poses when confidence is high |
| Current photographic situation | Portrait, Group, Person + Scene, and Action may rank packages differently |

### Required boundaries

- Do not infer **Male / Masculine** or **Female / Feminine** from a person's appearance. Auto may recommend a neutral solo collection or ask the user to choose a preferred style.
- Do not infer that two people are a romantic couple. Present a neutral **Two people** recommendation until the user explicitly chooses Couples, Friends / Groups, or Family.
- Do not infer age, relationship, gender identity, physical ability, or desired level of contact.
- Explain the visible reason for the recommendation instead of presenting it as certain.
- Keep Natural and the complete package list available directly below the recommendation.
- Never automatically activate a pose or begin close-contact coaching without a user selection.

### Recommended enabling catalog changes

Auto will work best after the catalog includes neutral top-level choices:

- **Solo Essentials** for one person, with style filters chosen manually.
- **Two People** with Couples, Friends, and Family as user-selected refinements.
- **Groups** for three or more people.

This structure lets Auto make useful visual recommendations without making sensitive assumptions. The existing Masculine, Feminine, and Couples packages can remain available as explicit style or relationship choices.

### Suggested display card

> **Auto suggestion**
>
> Two people · standing outdoors
> View 5 matching poses

The card should update only after the recommendation is stable across several camera frames. It should not rapidly change while the user is browsing or after a manual choice.

### Implementation phases

1. **Metadata filtering:** Use existing person count, situation, movement, setting, and pose-category metadata to produce a ranked list.
2. **Stable recommendation:** Require consistent evidence across multiple frames and retain the previous recommendation when confidence is low.
3. **Auto suggestion card:** Show the recommendation and reason at the top of the package chooser.
4. **Filtered montage:** Open a cross-package set of matching poses after the user taps the card.
5. **User feedback:** Record only local preference signals such as accepted, changed, or dismissed recommendations to improve ranking without inferring identity.

## Deferred package roadmap

These packages are approved directions but are not implemented. Production is paused after Family.

| Priority | Proposed package | Initial scope | Why it adds value |
| --- | --- | ---: | --- |
| 1 | Graduation | 5–6 poses | Clear occasion-based need: diploma, cap, gown, walking, and celebration. |
| 2 | Kids | 5–6 poses | Requires short, playful, motion-friendly prompts rather than adult portrait instructions. |
| 3 | Maternity | 5–6 poses | Benefits from specialized, comfort-first guidance and partner variations. |
| 4 | Professional / Headshot | 5–6 poses | Supports profile photos, resumes, teams, and formal portraits. |

Suggested next increment: **Graduation**, adding the first occasion-based posture package.

Landscape composition is tracked separately from people posture packages. See [Landscape Composition Packages](landscape_packages.md) for the proposed Mountains, Lakes & Water, Plains & Fields, Plants & Gardens, angle, sunrise, and sunset system.

## Questions for review

1. Should the two solo packages remain **Male / Masculine** and **Female / Feminine**, or should the top level use style-based names such as **Structured / Relaxed** and **Soft / Expressive**?
2. Should shared poses such as arms crossed, wall lean, and seated sideways appear once in a universal **Essentials** package instead of appearing in both solo packages?
3. Is **Couples** the right label, or would **Partners** be more inclusive while remaining immediately understandable?
4. Is the current Couples set balanced, or should it include a no-contact pose before close-contact poses?
5. Should package cards show the number of poses and a one-line description before opening the montage?
6. Should users be able to mark favorite poses or hide poses they do not want to see?
7. Should categories such as Standing, Seated, Moving, and Hands & Hair become visible filters in the montage?
8. Should Indoor / Outdoor tags be visible on every card, or only inside the detailed pose view?
9. Which package should be developed next: Graduation, Kids, Maternity, or Professional / Headshot?
10. Should Couples coaching support more than two people, or should all three-or-more-person guidance live exclusively in Friends / Groups and Family?
11. Should Auto appear only inside the posture chooser, or should its recommended category also appear on the compact Posture control in the live camera?
12. Should Auto recommendations reset after every capture or remain stable for the complete photo session?

## Decisions when package work resumes

- Keep the five current packages while they are tested on-device.
- Keep the category-first package chooser with a short description, pose count, and three-image preview for every package.
- Add one no-contact Couples pose, such as **Walk side by side** or **Facing outward**, if testing shows that the current set feels too intimate.
- Design **Graduation** next using the reusable package structure.
- Design the Auto suggestion card and its neutral **Solo / Two People / Group** recommendation vocabulary before implementing automatic package selection.
- Test style-based solo package names with users before renaming the current labels.
- Add favorites only after users have enough poses to make repeat selection burdensome.

## Review checklist

- [ ] Package names are clear and inclusive.
- [ ] Every reference image clearly demonstrates its named pose.
- [ ] Every cue is short, comfortable, and unambiguous.
- [ ] Couples poses cover both connected and low-contact preferences.
- [ ] Recommended camera angles improve the pose rather than adding unnecessary steps.
- [ ] Natural behavior is understood as “posture coaching off.”
- [ ] Auto recommendations are useful without inferring gender or relationships.
- [ ] The next package and its scope are approved.

## Implementation references

- Pose catalog and metadata: `DaliCamera/Models.swift`
- Montage and active posture experience: `DaliCamera/ContentView.swift`
- Reference photography: `DaliCamera/Assets.xcassets`
- Unit coverage: `DaliCameraTests/CoachingEngineTests.swift`
- UI coverage: `DaliCameraUITests/PhoneReadinessUITests.swift`
