# Dali Camera Posture Packages

Date: October 6, 2026
Status: **Wedding / Engagement implemented; eleven-package build ready for on-device review**

## Review objective

Review the posture-package structure, package names, pose selection, coaching language, and priorities for future packages. This document distinguishes the current implementation from proposed expansion.

## Implementation status snapshot

The initial people-package milestone and the Graduation, Maternity, Kids, Newborn, Professional, and Wedding packages are complete. No unfinished package is partially exposed in the app.

| Area | Status | Current result |
| --- | --- | --- |
| Package navigation | Implemented | Category-first chooser; each package opens its own photo montage. |
| Implemented packages | Implemented | Male / Masculine, Female / Feminine, Professional / Headshot, Couples, Wedding / Engagement, Friends / Groups, Family, Graduation, Maternity, Kids, and Newborn. |
| Pose assets | Implemented | 76 selectable photo references with stable IDs and project-local image assets. |
| Asset optimization | Implemented | Package references are JPEGs with a 720 px maximum long edge and a 95 KB export target, keeping every image below the 100 KB limit. Run `tools/optimize_package_images.sh` after adding or replacing package artwork. |
| Coaching metadata | Implemented | Two cues, recipient, category, setting, automatic camera angle, and lighting recommendation for every pose. |
| Natural mode | Implemented | Disables posture coaching while leaving ordinary camera coaching available. |
| Separate Angle control | Removed by design | Recommended angle comes from the selected posture and remains visible on its card. |
| Automated validation | Passing | Catalog metadata and package-selection coverage includes Professional and Wedding / Engagement. |
| Physical build | Ready | Previous ten-package build is installed on Alayna’s iPhone; the new eleven-package build is ready to install. |
| Additional packages | Review needed | Select the next package after Wedding / Engagement passes on-device review. |
| Auto package recommendation | Deferred | Product behavior is specified below; implementation has not started. |

### Resume point

Next review point:

1. Review all Kids references for clear, playful, grounded movement.
2. Review every Newborn reference against the caregiver-support and safe-back rules.
3. Confirm that Newborn guidance never encourages sleep on soft, inclined, side, or stomach surfaces.
4. Review all six **Professional / Headshot** references for useful framing and credible workplace styling.
5. Review all six **Wedding / Engagement** references for clear hands, stable footing, and useful occasion coverage.
6. Select the next package only after Wedding / Engagement passes on-device review.
7. Revisit Auto recommendations only after the manual catalog and neutral Solo / Two People / Group vocabulary are approved.

## Current product decision

Dali Camera offers a large, photo-based posture montage. A user selects a reference pose, then receives two short coaching cues while the camera remains available.

The current catalog contains 76 poses:

| Package | Pose count | Purpose |
| --- | ---: | --- |
| Male / Masculine | 9 | Relaxed standing, seated, walking, and turned portrait poses with traditionally masculine styling. |
| Female / Feminine | 13 | Standing, seated, moving, turned, hands, and hair poses with traditionally feminine styling. |
| Professional / Headshot | 6 | Profile photos, résumés, company directories, and environmental workplace portraits. |
| Couples | 6 | Coordinated standing, seated, moving, and close-contact poses for two adults. |
| Wedding / Engagement | 6 | Ring moments, formal portraits, a stable one-knee proposal, first dance, and celebration walk. |
| Friends / Groups | 6 | Coordinated standing, seated, moving, celebratory, and conversational poses for three or more people. |
| Family | 6 | Comfort-first standing, seated, moving, caregiver/child, and multigenerational arrangements. |
| Graduation | 6 | Diploma, cap, gown, seated, walking, turned, and grounded celebration poses. |
| Maternity | 6 | Comfort-first solo portraits plus supportive poses with a husband. |
| Kids | 6 | Short, playful, grounded solo and sibling poses. |
| Newborn | 6 | Caregiver-supported portraits and flat-on-back photos with strict safety language. |

Package labels describe visual styling; they are not eligibility rules. Any user may select any solo package, and the camera does not infer gender.

## Selection and coaching behavior

- **Natural** is the default. It means posture coaching is off, while ordinary framing, lighting, level, and distance coaching may continue.
- The Posture button first opens a quick package chooser. Selecting a package opens a scrollable photo montage containing only that package's poses.
- Selecting a photo closes the montage and starts that pose's coaching sequence.
- Solo instructions are addressed to **Subject**. Couples, Wedding / Engagement, and husband Maternity instructions are addressed to **Couple**; Friends / Groups to **Group**; Family to **Family**; Kids to **Child / Children**; and Newborn to **Caregiver**.
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
| <img src="../DaliCamera/Assets.xcassets/PoseCoupleCloseStanding.imageset/pose-couple-close-standing.jpg" width="180" alt="Couple demonstrating a close standing pose"> | <img src="../DaliCamera/Assets.xcassets/PoseCoupleArmAroundWaist.imageset/pose-couple-arm-around-waist.jpg" width="180" alt="Couple demonstrating an arm-around-waist pose"> | <img src="../DaliCamera/Assets.xcassets/PoseCoupleBackToBack.imageset/pose-couple-back-to-back.jpg" width="180" alt="Couple demonstrating a back-to-back pose"> |
| Walking hand in hand | Seated together | Forehead to forehead |
| <img src="../DaliCamera/Assets.xcassets/PoseCoupleWalking.imageset/pose-couple-walking.jpg" width="180" alt="Couple walking hand in hand"> | <img src="../DaliCamera/Assets.xcassets/PoseCoupleSeated.imageset/pose-couple-seated.jpg" width="180" alt="Couple seated together"> | <img src="../DaliCamera/Assets.xcassets/PoseCoupleForeheadTouch.imageset/pose-couple-forehead-touch.jpg" width="180" alt="Couple touching foreheads"> |

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
| <img src="../DaliCamera/Assets.xcassets/PoseGroupShoulderRow.imageset/pose-group-shoulder-row.jpg" width="180" alt="Three friends standing shoulder to shoulder"> | <img src="../DaliCamera/Assets.xcassets/PoseGroupStaggered.imageset/pose-group-staggered.jpg" width="180" alt="Three friends in a staggered triangle"> | <img src="../DaliCamera/Assets.xcassets/PoseGroupLinkedWalk.imageset/pose-group-linked-walk.jpg" width="180" alt="Three friends walking with linked arms"> |
| Seated cluster | Celebration | Casual conversation |
| <img src="../DaliCamera/Assets.xcassets/PoseGroupSeatedCluster.imageset/pose-group-seated-cluster.jpg" width="180" alt="Three friends seated together"> | <img src="../DaliCamera/Assets.xcassets/PoseGroupCelebration.imageset/pose-group-celebration.jpg" width="180" alt="Four friends celebrating"> | <img src="../DaliCamera/Assets.xcassets/PoseGroupConversation.imageset/pose-group-conversation.jpg" width="180" alt="Three friends in conversation"> |

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
| <img src="../DaliCamera/Assets.xcassets/PoseFamilyStandingRow.imageset/pose-family-standing-row.jpg" width="180" alt="Family standing in one row"> | <img src="../DaliCamera/Assets.xcassets/PoseFamilySideHug.imageset/pose-family-side-hug.jpg" width="180" alt="Caregiver and child sharing a side hug"> | <img src="../DaliCamera/Assets.xcassets/PoseFamilySeatedCluster.imageset/pose-family-seated-cluster.jpg" width="180" alt="Family seated close together"> |
| Walking hand in hand | Generations together | Shared family laugh |
| <img src="../DaliCamera/Assets.xcassets/PoseFamilyWalking.imageset/pose-family-walking.jpg" width="180" alt="Family walking hand in hand"> | <img src="../DaliCamera/Assets.xcassets/PoseFamilyGenerations.imageset/pose-family-generations.jpg" width="180" alt="Multigenerational family portrait"> | <img src="../DaliCamera/Assets.xcassets/PoseFamilySharedLaugh.imageset/pose-family-shared-laugh.jpg" width="180" alt="Family sharing a natural laugh"> |

## Package 6: Graduation

Graduation is an occasion package for any adult graduate. It avoids school branding and gendered styling so the same guidance works across institutions, gown colors, and personal presentation. The Cap toss pose keeps both feet grounded and uses a small, controlled toss rather than a jump.

| ID | Pose | Category | Setting | Recommended angle | Recommended lighting | Coaching cues |
| --- | --- | --- | --- | --- | --- | --- |
| GR1 | Diploma centered | Standing | Indoor & Outdoor | Eye level | Soft, even front light | Hold the diploma folder with both hands at mid-torso. Stand tall and relax your shoulders. |
| GR2 | Adjust the cap | Hands & Hair | Indoor & Outdoor | Eye level | Soft, even front light | Turn slightly and touch the edge of your cap with relaxed fingertips. Hold the diploma at your side and bring your face back toward the camera. |
| GR3 | Seated with diploma | Seated | Indoor & Outdoor | Slightly high | Soft, even front light | Sit upright with your body angled slightly. Rest the diploma across one thigh and keep both feet comfortably planted. |
| GR4 | Graduation walk | Moving | Outdoor | Low angle | Soft golden-hour light | Hold the diploma at your side and take one slow step. Look toward the camera and let the gown move naturally. |
| GR5 | Over-shoulder graduate | Turned | Indoor & Outdoor | From the side | Soft side light | Turn partly away with the diploma held low at your side. Look back over your shoulder comfortably. |
| GR6 | Cap toss | Moving | Outdoor | Low angle | Soft golden-hour light | Keep both feet grounded and gently toss the cap just above your hand. Follow the cap with your eyes while holding the diploma at your side. |

### Graduation visual reference set

| Diploma centered | Adjust the cap | Seated with diploma |
| --- | --- | --- |
| <img src="../DaliCamera/Assets.xcassets/PoseGraduationDiplomaCentered.imageset/pose-graduation-diploma-centered.jpg" width="180" alt="Graduate holding a diploma folder at mid-torso"> | <img src="../DaliCamera/Assets.xcassets/PoseGraduationAdjustCap.imageset/pose-graduation-adjust-cap.jpg" width="180" alt="Graduate lightly adjusting a mortarboard"> | <img src="../DaliCamera/Assets.xcassets/PoseGraduationSeated.imageset/pose-graduation-seated.jpg" width="180" alt="Graduate seated with a diploma across one thigh"> |
| Graduation walk | Over-shoulder graduate | Cap toss |
| <img src="../DaliCamera/Assets.xcassets/PoseGraduationWalk.imageset/pose-graduation-walk.jpg" width="180" alt="Graduate walking with a rolled diploma"> | <img src="../DaliCamera/Assets.xcassets/PoseGraduationOverShoulder.imageset/pose-graduation-over-shoulder.jpg" width="180" alt="Graduate looking back over one shoulder"> | <img src="../DaliCamera/Assets.xcassets/PoseGraduationCapToss.imageset/pose-graduation-cap-toss.jpg" width="180" alt="Graduate making a small cap toss with both feet grounded"> |

## Package 7: Maternity

Maternity provides three solo references and three references with a husband. Every pose prioritizes stable footing, gentle contact, ordinary sturdy seating, and small movements. The coaching is photographic rather than medical; the expecting parent should skip or adapt any direction that is not comfortable.

| ID | Pose | Category | Setting | Recommended angle | Recommended lighting | Coaching cues |
| --- | --- | --- | --- | --- | --- | --- |
| MT1 | Belly cradle | Standing | Indoor & Outdoor | Eye level | Soft, even front light | Stand with both feet comfortably apart and soften your shoulders. Rest one hand above and one hand below your belly. |
| MT2 | Side profile | Turned | Indoor & Outdoor | From the side | Bright open shade | Turn to the side with both feet flat and your posture comfortable. Cradle your belly lightly and turn your face a little toward the camera. |
| MT3 | Comfortable seated | Seated | Indoor & Outdoor | Slightly high | Soft, even front light | Sit near the front of a sturdy seat with both feet planted. Angle your body slightly and rest your hands comfortably around your belly. |
| MT4 | Embrace with husband | Standing | Indoor & Outdoor | Eye level | Soft, even front light | Have your husband stand just behind and to one side with both of you balanced. Rest your hands gently around the belly and turn your faces toward each other. |
| MT5 | Walk with husband | Moving | Outdoor | Eye level | Soft golden-hour light | Hold hands and take one small, slow step together on level ground. Look toward each other and keep the expecting parent's free hand comfortable. |
| MT6 | Face-to-face with husband | Standing | Indoor & Outdoor | Eye level | Soft side light | Stand face-to-face with both feet planted and shoulders relaxed. Let your husband rest his hands gently on your upper arms and bring your foreheads close if comfortable. |

### Maternity visual reference set

| Belly cradle | Side profile | Comfortable seated |
| --- | --- | --- |
| <img src="../DaliCamera/Assets.xcassets/PoseMaternityBellyCradle.imageset/pose-maternity-belly-cradle.jpg" width="180" alt="Expecting parent standing with hands gently cradling the belly"> | <img src="../DaliCamera/Assets.xcassets/PoseMaternitySideProfile.imageset/pose-maternity-side-profile.jpg" width="180" alt="Expecting parent in a stable side-profile pose"> | <img src="../DaliCamera/Assets.xcassets/PoseMaternitySeatedSupport.imageset/pose-maternity-seated-support.jpg" width="180" alt="Expecting parent seated upright with both feet planted"> |
| Embrace with husband | Walk with husband | Face-to-face with husband |
| <img src="../DaliCamera/Assets.xcassets/PoseMaternityHusbandEmbrace.imageset/pose-maternity-husband-embrace.jpg" width="180" alt="Expecting mother and husband sharing a gentle standing embrace"> | <img src="../DaliCamera/Assets.xcassets/PoseMaternityHusbandWalk.imageset/pose-maternity-husband-walk.jpg" width="180" alt="Expecting mother walking slowly hand in hand with her husband"> | <img src="../DaliCamera/Assets.xcassets/PoseMaternityHusbandFaceToFace.imageset/pose-maternity-husband-face-to-face.jpg" width="180" alt="Expecting mother and husband standing face-to-face"> |

## Package 8: Kids

Kids uses brief, playful directions that a child can understand quickly. Every pose keeps feet on level ground or uses a sturdy seat; there is no jumping, climbing, hanging, or difficult balance.

| ID | Pose | Category | Setting | Recommended angle | Recommended lighting | Coaching cues |
| --- | --- | --- | --- | --- | --- | --- |
| K1 | Big smile | Standing | Indoor & Outdoor | Eye level | Soft, even front light | Stand with both feet comfortably apart and place your hands loosely behind your back. Look toward the camera and share a smile that feels natural. |
| K2 | Comfortable seated | Seated | Indoor & Outdoor | Eye level | Soft, even front light | Sit near the front of a sturdy seat with both feet flat. Rest your hands loosely together and turn your face toward the camera. |
| K3 | Slow walk | Moving | Outdoor | Eye level | Bright open shade | Take one small, slow step toward the camera on clear, level ground. Let your arms swing naturally and look toward the camera. |
| K4 | Peek around | Turned | Outdoor | From the side | Bright open shade | Keep both feet on the ground and peek around the side without climbing. Touch the surface lightly and keep your whole face visible. |
| K5 | Superhero stance | Standing | Indoor & Outdoor | Low angle | Soft, even front light | Plant both feet comfortably wide and place your hands on your hips. Keep both feet grounded, lift your chin slightly, and give a proud smile. |
| K6 | Sibling side hug | Standing | Indoor & Outdoor | Eye level | Broad, even light | Stand side by side with both sets of feet steady. Add a gentle side hug if comfortable and keep both faces visible. |

### Kids visual reference set

| Big smile | Comfortable seated | Slow walk |
| --- | --- | --- |
| <img src="../DaliCamera/Assets.xcassets/PoseKidsBigSmile.imageset/pose-kids-big-smile.jpg" width="180" alt="Child standing with hands behind the back and a natural smile"> | <img src="../DaliCamera/Assets.xcassets/PoseKidsComfortableSeated.imageset/pose-kids-comfortable-seated.jpg" width="180" alt="Child seated safely with both feet flat"> | <img src="../DaliCamera/Assets.xcassets/PoseKidsSlowWalk.imageset/pose-kids-slow-walk.jpg" width="180" alt="Child taking a small slow step on a level path"> |
| Peek around | Superhero stance | Sibling side hug |
| <img src="../DaliCamera/Assets.xcassets/PoseKidsPeekAround.imageset/pose-kids-peek-around.jpg" width="180" alt="Child peeking around a tree without climbing"> | <img src="../DaliCamera/Assets.xcassets/PoseKidsSuperhero.imageset/pose-kids-superhero.jpg" width="180" alt="Child standing with grounded feet and hands on hips"> | <img src="../DaliCamera/Assets.xcassets/PoseKidsSiblingSideHug.imageset/pose-kids-sibling-side-hug.jpg" width="180" alt="Two siblings sharing a gentle side hug"> |

## Package 9: Newborn

Newborn is intentionally conservative. Flat-surface poses keep the baby on their back on a firm, flat, non-inclined crib or bassinet mattress with a fitted sheet only. Held poses require a seated, awake caregiver and continuous head-and-neck support. The camera stays outside the sleep space, and the baby's face and airway remain unobstructed. These rules follow current [CDC safe-sleep guidance](https://www.cdc.gov/reproductive-health/features/babies-sleep.html) and the [American Academy of Pediatrics parent guidance](https://www.healthychildren.org/English/ages-stages/baby/sleep/Pages/A-Parents-Guide-to-Safe-Sleep.aspx).

| ID | Pose | Category | Setting | Recommended angle | Recommended lighting | Coaching cues |
| --- | --- | --- | --- | --- | --- | --- |
| NB1 | Safe back pose | Lying Safely | Indoor | Overhead | Soft, even front light | Place the baby on their back in an empty safety-approved bassinet with a fitted sheet only. Keep the face uncovered and photograph from outside the bassinet. |
| NB2 | Caregiver nearby | Lying Safely | Indoor | Overhead | Soft, even front light | Keep the baby on their back on a firm, flat crib mattress with a caregiver within reach. Let the baby move naturally without repositioning the head or limbs. |
| NB3 | Seated cradle | Seated | Indoor | Eye level | Soft, even front light | Sit securely and cradle the baby with continuous head, neck, and body support. Keep the face and nose clear while you look gently toward the baby. |
| NB4 | Shoulder support | Seated | Indoor | Eye level | Soft, even front light | Sit securely and support the upright baby's head and neck with one hand and body with the other. Keep the baby's face turned outward enough that the nose and mouth stay clear. |
| NB5 | Parents seated together | Seated | Indoor | Eye level | Broad, even light | Sit together while one parent cradles the baby with full head and neck support. Have the other parent lean in gently while keeping every face visible. |
| NB6 | Hands and feet detail | Lying Safely | Indoor | Overhead | Soft side light | Keep the baby on their back on a firm, flat crib mattress with a caregiver within reach. Frame the hands and covered feet without holding or bending the baby's limbs. |

### Newborn visual reference set

| Safe back pose | Caregiver nearby | Seated cradle |
| --- | --- | --- |
| <img src="../DaliCamera/Assets.xcassets/PoseNewbornSafeBack.imageset/pose-newborn-safe-back.jpg" width="180" alt="Newborn safely on their back in an empty bassinet"> | <img src="../DaliCamera/Assets.xcassets/PoseNewbornCaregiverNearby.imageset/pose-newborn-caregiver-nearby.jpg" width="180" alt="Newborn on a firm flat crib mattress with caregiver hands nearby"> | <img src="../DaliCamera/Assets.xcassets/PoseNewbornSeatedCradle.imageset/pose-newborn-seated-cradle.jpg" width="180" alt="Seated parent cradling a newborn with head and neck support"> |
| Shoulder support | Parents seated together | Hands and feet detail |
| <img src="../DaliCamera/Assets.xcassets/PoseNewbornShoulderSupport.imageset/pose-newborn-shoulder-support.jpg" width="180" alt="Seated father supporting newborn upright at the shoulder"> | <img src="../DaliCamera/Assets.xcassets/PoseNewbornParentsSeated.imageset/pose-newborn-parents-seated.jpg" width="180" alt="Two seated parents with a fully supported newborn"> | <img src="../DaliCamera/Assets.xcassets/PoseNewbornHandsFeetDetail.imageset/pose-newborn-hands-feet-detail.jpg" width="180" alt="Newborn safely on the back for a hands and feet detail"> |

## Package 10: Professional / Headshot

Professional / Headshot provides neutral, gender-independent guidance for profile photos, résumés, company directories, formal portraits, and workplace context. Clothing and occupation are not inferred; the package focuses on an open expression, relaxed shoulders, visible hands when included, and clean framing.

| ID | Pose | Category | Setting | Recommended angle | Recommended lighting | Coaching cues |
| --- | --- | --- | --- | --- | --- | --- |
| PR1 | Classic headshot | Standing | Indoor | Eye level | Soft, even front light | Turn your shoulders slightly away from the camera. Bring your face back toward the lens and relax your jaw. |
| PR2 | Three-quarter professional | Turned | Indoor | Eye level | Soft side light | Turn your body about one-third away from the camera. Bring your face back toward the lens and keep both shoulders relaxed. |
| PR3 | Seated forward | Seated | Indoor | Slightly high | Soft, even front light | Sit near the front of the chair and lean forward slightly. Rest your forearms lightly on your thighs and keep your hands relaxed. |
| PR4 | Relaxed arms crossed | Standing | Indoor | Eye level | Soft, even front light | Cross your arms loosely at mid-torso. Lower your shoulders and keep your fingers visible and relaxed. |
| PR5 | Open standing | Standing | Indoor | Eye level | Soft, even front light | Stand tall with your feet comfortably apart. Let both arms rest naturally and keep your shoulders open. |
| PR6 | Workplace portrait | Turned | Indoor | Eye level | Soft side light | Turn your body slightly toward the workspace. Rest one hand lightly on a nearby surface and bring your face back toward the camera. |

### Professional / Headshot visual reference set

| Classic headshot | Three-quarter professional | Seated forward |
| --- | --- | --- |
| <img src="../DaliCamera/Assets.xcassets/PoseProfessionalClassicHeadshot.imageset/pose-professional-classic-headshot.jpg" width="180" alt="Professional classic head-and-shoulders portrait"> | <img src="../DaliCamera/Assets.xcassets/PoseProfessionalThreeQuarter.imageset/pose-professional-three-quarter.jpg" width="180" alt="Professional in a three-quarter pose"> | <img src="../DaliCamera/Assets.xcassets/PoseProfessionalSeatedForward.imageset/pose-professional-seated-forward.jpg" width="180" alt="Professional seated with a slight forward lean"> |
| Relaxed arms crossed | Open standing | Workplace portrait |
| <img src="../DaliCamera/Assets.xcassets/PoseProfessionalArmsCrossed.imageset/pose-professional-arms-crossed.jpg" width="180" alt="Professional with arms crossed loosely"> | <img src="../DaliCamera/Assets.xcassets/PoseProfessionalOpenStanding.imageset/pose-professional-open-standing.jpg" width="180" alt="Professional in an open full-body standing pose"> | <img src="../DaliCamera/Assets.xcassets/PoseProfessionalEnvironmental.imageset/pose-professional-environmental.jpg" width="180" alt="Professional standing in a workplace environment"> |

## Package 11: Wedding / Engagement

Wedding / Engagement adds occasion-specific moments without replacing the general Couples package. It uses partner-neutral language, keeps contact optional and tasteful, and avoids jumping or unstable positions. The proposal reference uses a controlled one-knee pose on a flat, clear surface.

| ID | Pose | Category | Setting | Recommended angle | Recommended lighting | Coaching cues |
| --- | --- | --- | --- | --- | --- | --- |
| WE1 | Formal side by side | Standing | Indoor & Outdoor | Eye level | Bright open shade | Stand side by side with your shoulders lightly touching. Join your inside hands at waist height and turn both faces toward the camera. |
| WE2 | Ring reveal | Hands & Details | Indoor | Eye level | Soft, even front light | Angle toward each other and bring the ring hand naturally to mid-torso. Keep the ring hand relaxed and both faces visible. |
| WE3 | One-knee proposal | Kneeling | Outdoor | From the side | Soft golden-hour light | On a flat, clear surface, lower onto one knee with your front foot planted. Hold the open ring box at mid-torso and turn both faces enough for the camera to see. |
| WE4 | Exchange rings | Hands & Details | Indoor & Outdoor | Eye level | Soft, even front light | Face each other and center your hands comfortably between you. Slide the ring on gently while keeping both faces visible. |
| WE5 | First dance | Standing | Indoor | Eye level | Soft side light | Stand in a comfortable dance hold with both feet grounded. Keep your joined hands visible and angle both faces slightly toward the camera. |
| WE6 | Celebration walk | Moving | Outdoor | Low angle | Soft golden-hour light | Hold hands and take one slow step together. Look toward each other and carry any bouquet low at the outside hip. |

### Wedding / Engagement visual reference set

| Formal side by side | Ring reveal | One-knee proposal |
| --- | --- | --- |
| <img src="../DaliCamera/Assets.xcassets/PoseWeddingFormalSideBySide.imageset/pose-wedding-formal-side-by-side.jpg" width="180" alt="Wedding couple standing formally side by side"> | <img src="../DaliCamera/Assets.xcassets/PoseWeddingRingReveal.imageset/pose-wedding-ring-reveal.jpg" width="180" alt="Engaged couple showing a ring naturally at mid-torso"> | <img src="../DaliCamera/Assets.xcassets/PoseWeddingProposalReaction.imageset/pose-wedding-proposal-reaction.jpg" width="180" alt="Groom making a stable one-knee proposal to a bride-to-be"> |
| Exchange rings | First dance | Celebration walk |
| <img src="../DaliCamera/Assets.xcassets/PoseWeddingRingExchange.imageset/pose-wedding-ring-exchange.jpg" width="180" alt="Wedding couple exchanging rings with hands visible"> | <img src="../DaliCamera/Assets.xcassets/PoseWeddingFirstDance.imageset/pose-wedding-first-dance.jpg" width="180" alt="Wedding couple in a grounded first-dance pose"> | <img src="../DaliCamera/Assets.xcassets/PoseWeddingCelebrationWalk.imageset/pose-wedding-celebration-walk.jpg" width="180" alt="Wedding couple walking slowly hand in hand"> |

## Content and safety principles

- Use invitational, non-judgmental language. Poses are creative options, not corrections to a person's body.
- Avoid judging body shape, attractiveness, weight, age, gender expression, or physical ability.
- Do not infer a package from the camera image. Selection is always explicit.
- Use gender-neutral partner language in Couples.
- Describe gentle contact and comfort explicitly for close-contact poses.
- Never require contact, a difficult balance position, or use of an unsafe surface.
- For Kids, never coach jumping, climbing, hanging, or balance tricks.
- For Newborn, address all instructions to an awake caregiver; never coach a baby to hold a position.
- For Newborn flat-surface photos, use only a firm, flat, non-inclined safety-approved crib or bassinet surface with a fitted sheet, place the baby on their back, and keep the sleep space empty.
- For Newborn held photos, keep the caregiver seated with continuous head-and-neck support and the baby's face and airway visible.
- Keep hands, faces, and joints visible where doing so improves the photograph, without presenting that choice as mandatory.
- Treat left and right in pose cues as the subject's left and right. Photographer movement uses the photographer's viewpoint.

## Package architecture for future growth

The package name should answer **who or what kind of session is being photographed**. Category and setting should remain filters or metadata rather than becoming duplicate packages.

Recommended hierarchy:

1. **Natural** — no posture coaching.
2. **People packages** — Masculine, Feminine, Professional / Headshot, Couples, Wedding / Engagement, Family, Friends / Groups, Kids, Newborn, Maternity, and Graduation.
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

## Future package roadmap

Kids, Newborn, Professional / Headshot, and Wedding / Engagement are complete. The next package should be selected after the current eleven packages are reviewed on-device; no additional direction is approved yet.

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
9. After Wedding / Engagement review, which audience or occasion has the largest remaining gap?
10. Should Couples coaching support more than two people, or should all three-or-more-person guidance live exclusively in Friends / Groups and Family?
11. Should Auto appear only inside the posture chooser, or should its recommended category also appear on the compact Posture control in the live camera?
12. Should Auto recommendations reset after every capture or remain stable for the complete photo session?

## Decisions when package work resumes

- Keep the eleven current packages while they are tested on-device.
- Keep the category-first package chooser with a short description, pose count, and three-image preview for every package.
- Add one no-contact Couples pose, such as **Walk side by side** or **Facing outward**, if testing shows that the current set feels too intimate.
- Review **Kids**, **Newborn**, **Professional / Headshot**, and **Wedding / Engagement** on-device before selecting another package.
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
