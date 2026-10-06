import CoreGraphics
import Foundation

enum PreviewGeometry {
    static func fittedRect(in size: CGSize, aspectRatio: CGFloat) -> CGRect {
        guard size.width > 0, size.height > 0, aspectRatio > 0 else { return .zero }
        let width = min(size.width, size.height * aspectRatio)
        let height = width / aspectRatio
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    static func rollDegrees(gravityX: Double, gravityY: Double, rotation: Double, mirrored: Bool) -> Double {
        guard hypot(gravityX, gravityY) > 0.15 else { return 0 }
        var degrees = atan2(gravityX, -gravityY) * 180 / .pi - (rotation - 90)
        while degrees > 180 { degrees -= 360 }
        while degrees < -180 { degrees += 360 }
        return mirrored ? -degrees : degrees
    }
}

/// Keeps an unsaved original across app launches. Callers choose when it is safe to remove it.
struct PendingCaptureStore {
    let url: URL

    func load() throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func retain(_ data: Data) throws {
        try data.write(to: url, options: .atomic)
    }

    func remove() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

enum AdviceTone {
    case waiting
    case ready
    case warning
    case danger
}

enum GuidedAction: String {
    case subjectPose, cameraHeight, cameraPitch, photographerMove

    var symbol: String {
        switch self {
        case .subjectPose: return "figure.stand"
        case .cameraHeight: return "arrow.up.and.down"
        case .cameraPitch: return "camera.rotate"
        case .photographerMove: return "figure.walk"
        }
    }
}

enum GuidedCompletion {
    case userConfirmed
}

struct GuidedStep: Equatable {
    let instruction: String
    let action: GuidedAction
    var recipientOverride: String? = nil
    // Creative poses and relative camera heights are explicitly confirmed by the user.
    var recipient: String { recipientOverride ?? (action == .subjectPose ? "Subject" : "Photographer") }
    var completion: GuidedCompletion { .userConfirmed }
}

enum PoseCategory: String, CaseIterable, Identifiable {
    case standing, seated, moving, turned, handsHair

    var id: String { rawValue }
    var title: String {
        switch self {
        case .standing: return "Standing"
        case .seated: return "Seated"
        case .moving: return "Moving"
        case .turned: return "Turned / Looking Away"
        case .handsHair: return "Hands & Hair"
        }
    }
    var symbol: String {
        switch self {
        case .standing: return "figure.stand"
        case .seated: return "figure.seated.side"
        case .moving: return "figure.walk"
        case .turned: return "arrow.uturn.right"
        case .handsHair: return "hand.raised"
        }
    }
}

enum PoseSetting: String, Identifiable {
    case indoor, outdoor, both

    var id: String { rawValue }
    var title: String {
        switch self {
        case .indoor: return "Indoor"
        case .outdoor: return "Outdoor"
        case .both: return "Indoor & Outdoor"
        }
    }
    var symbol: String {
        switch self {
        case .indoor: return "house"
        case .outdoor: return "sun.max"
        case .both: return "square.grid.2x2"
        }
    }
}

enum PoseLightingRecommendation: String, CaseIterable, Identifiable {
    case softEven, softSide, openShade, goldenHour, broadEven

    var id: String { rawValue }
    var title: String {
        switch self {
        case .softEven: return "Soft, even front light"
        case .softSide: return "Soft light from 45° to one side"
        case .openShade: return "Bright open shade"
        case .goldenHour: return "Soft golden-hour light"
        case .broadEven: return "Broad, even light across every face"
        }
    }
    var instruction: String {
        switch self {
        case .softEven: return "Face the subject toward a large window or another broad, diffused light source."
        case .softSide: return "Place a window or diffused light about 45 degrees to the side of the subject's face."
        case .openShade: return "Move into open shade while keeping the subjects facing the brighter open sky."
        case .goldenHour: return "Use low, soft sunlight from the side or behind, and keep every face evenly exposed."
        case .broadEven: return "Use a broad light source far enough back to illuminate every face evenly."
        }
    }
    var symbol: String { "sun.max.fill" }
}

enum GuidedPoseCollectionID: String, CaseIterable, Identifiable {
    case masculine, feminine, couples, friendsGroups, family

    var id: String { rawValue }
    var title: String {
        switch self {
        case .masculine: return "Male / Masculine"
        case .feminine: return "Female / Feminine"
        case .couples: return "Couples"
        case .friendsGroups: return "Friends / Groups"
        case .family: return "Family"
        }
    }
}

enum GuidedPose: String, CaseIterable, Identifiable {
    case relaxedStanding = "M1", threeQuarter = "M2", handInPocket = "M3"
    case seatedLean = "M4", walking = "M5"
    case armsCrossedMasculine = "M6", wallLeanMasculine = "M7"
    case seatedSidewaysMasculine = "M8", lookAwayMasculine = "M9"
    case weightShift = "F1", footForward = "F2", handAtWaist = "F3"
    case seatedAngle = "F4", overShoulder = "F5"
    case armsCrossedFeminine = "F6", wallLeanFeminine = "F7"
    case walkingTurnFeminine = "F8", seatedSidewaysFeminine = "F9"
    case hairSweepFeminine = "F10", handNearCheekFeminine = "F11"
    case armAcrossWaistFeminine = "F12", handsClaspedFeminine = "F13"
    case coupleCloseStanding = "CP1", coupleArmAroundWaist = "CP2"
    case coupleBackToBack = "CP3", coupleWalking = "CP4"
    case coupleSeated = "CP5", coupleForeheadTouch = "CP6"
    case groupShoulderRow = "G1", groupStaggered = "G2"
    case groupLinkedWalk = "G3", groupSeatedCluster = "G4"
    case groupCelebration = "G5", groupConversation = "G6"
    case familyStandingRow = "FA1", familySideHug = "FA2"
    case familySeatedCluster = "FA3", familyWalking = "FA4"
    case familyGenerations = "FA5", familySharedLaugh = "FA6"

    var id: String { rawValue }
    var package: GuidedPoseCollectionID {
        if rawValue.hasPrefix("CP") { return .couples }
        if rawValue.hasPrefix("FA") { return .family }
        if rawValue.hasPrefix("G") { return .friendsGroups }
        return rawValue.hasPrefix("M") ? .masculine : .feminine
    }
    var title: String {
        switch self {
        case .relaxedStanding: return "Relaxed standing"
        case .threeQuarter: return "Three-quarter stance"
        case .handInPocket: return "One hand in pocket"
        case .seatedLean: return "Seated forward lean"
        case .walking: return "Casual walking"
        case .armsCrossedMasculine, .armsCrossedFeminine: return "Relaxed arms crossed"
        case .wallLeanMasculine, .wallLeanFeminine: return "Casual wall lean"
        case .seatedSidewaysMasculine, .seatedSidewaysFeminine: return "Seated sideways"
        case .lookAwayMasculine: return "Natural look away"
        case .weightShift: return "Weight-shift stance"
        case .footForward: return "One foot forward"
        case .handAtWaist: return "Hand at waist"
        case .seatedAngle: return "Seated angled pose"
        case .overShoulder: return "Over-shoulder glance"
        case .walkingTurnFeminine: return "Walking turn"
        case .hairSweepFeminine: return "Gentle hair sweep"
        case .handNearCheekFeminine: return "Hand near cheek"
        case .armAcrossWaistFeminine: return "Arm across waist"
        case .handsClaspedFeminine: return "Hands loosely clasped"
        case .coupleCloseStanding: return "Close standing"
        case .coupleArmAroundWaist: return "Arm around waist"
        case .coupleBackToBack: return "Back to back"
        case .coupleWalking: return "Walking hand in hand"
        case .coupleSeated: return "Seated together"
        case .coupleForeheadTouch: return "Forehead to forehead"
        case .groupShoulderRow: return "Shoulder-to-shoulder row"
        case .groupStaggered: return "Staggered triangle"
        case .groupLinkedWalk: return "Linked-arm walk"
        case .groupSeatedCluster: return "Seated cluster"
        case .groupCelebration: return "Celebration"
        case .groupConversation: return "Casual conversation"
        case .familyStandingRow: return "Family standing row"
        case .familySideHug: return "Caregiver side hug"
        case .familySeatedCluster: return "Family seated cluster"
        case .familyWalking: return "Walking hand in hand"
        case .familyGenerations: return "Generations together"
        case .familySharedLaugh: return "Shared family laugh"
        }
    }

    var symbol: String {
        switch self {
        case .relaxedStanding: return "figure.stand"
        case .threeQuarter: return "person.crop.rectangle"
        case .handInPocket: return "hand.raised"
        case .seatedLean: return "figure.seated.side"
        case .walking: return "figure.walk"
        case .armsCrossedMasculine, .armsCrossedFeminine: return "figure.arms.open"
        case .wallLeanMasculine, .wallLeanFeminine: return "rectangle.portrait.and.arrow.right"
        case .seatedSidewaysMasculine, .seatedSidewaysFeminine: return "figure.seated.side"
        case .lookAwayMasculine: return "eyes"
        case .weightShift: return "figure.stand"
        case .footForward: return "shoeprints.fill"
        case .handAtWaist: return "figure.stand"
        case .seatedAngle: return "figure.seated.side"
        case .overShoulder: return "arrow.uturn.backward.circle"
        case .walkingTurnFeminine: return "figure.walk"
        case .hairSweepFeminine, .handNearCheekFeminine: return "hand.raised"
        case .armAcrossWaistFeminine: return "figure.stand"
        case .handsClaspedFeminine: return "hands.clap"
        case .coupleCloseStanding, .coupleArmAroundWaist, .coupleForeheadTouch: return "figure.2"
        case .coupleBackToBack: return "figure.2"
        case .coupleWalking: return "figure.walk"
        case .coupleSeated: return "figure.seated.side"
        case .groupShoulderRow, .groupStaggered, .groupCelebration, .groupConversation: return "person.3"
        case .groupLinkedWalk: return "figure.walk"
        case .groupSeatedCluster: return "figure.seated.side"
        case .familyStandingRow, .familySideHug, .familyGenerations, .familySharedLaugh: return "figure.and.child.holdinghands"
        case .familyWalking: return "figure.walk"
        case .familySeatedCluster: return "figure.seated.side"
        }
    }

    var cues: [String] {
        switch self {
        case .relaxedStanding: return ["Stand with your feet comfortably apart.", "Relax your shoulders."]
        case .threeQuarter: return ["Turn your body slightly to your right.", "Bring your face back toward the camera."]
        case .handInPocket: return ["Rest one hand in your pocket.", "Let your other arm hang loosely."]
        case .seatedLean: return ["Sit and lean slightly forward.", "Rest your forearms on your thighs."]
        case .walking: return ["Walk slowly across the frame.", "Look toward the camera for the next shot."]
        case .armsCrossedMasculine, .armsCrossedFeminine: return ["Cross your arms loosely at mid-torso.", "Drop your shoulders and keep your hands relaxed."]
        case .wallLeanMasculine, .wallLeanFeminine: return ["Lean one shoulder lightly against the wall.", "Bend the outside knee and relax your hands."]
        case .seatedSidewaysMasculine, .seatedSidewaysFeminine: return ["Sit sideways with both feet visible.", "Turn your upper body comfortably toward the camera."]
        case .lookAwayMasculine: return ["Angle your body slightly away from the camera.", "Look naturally just past the camera."]
        case .weightShift: return ["Rest your weight on one leg.", "Soften the other knee."]
        case .footForward: return ["Place one foot slightly in front.", "Turn your shoulders a little toward the camera."]
        case .handAtWaist: return ["Rest one hand lightly at your waist.", "Relax your other arm."]
        case .seatedAngle: return ["Sit with your knees angled slightly to one side.", "Turn your face toward the camera."]
        case .overShoulder: return ["Turn your body partly away from the camera.", "Look back over your shoulder comfortably."]
        case .walkingTurnFeminine: return ["Take a slow step away from the camera.", "Turn your face and shoulders gently back toward it."]
        case .hairSweepFeminine: return ["Lift one hand lightly into your hair.", "Keep your fingers relaxed and your face visible."]
        case .handNearCheekFeminine: return ["Bring relaxed fingertips beside your cheek.", "Keep your eyes and jawline uncovered."]
        case .armAcrossWaistFeminine: return ["Rest one forearm softly across your waist.", "Let your other arm hang freely."]
        case .handsClaspedFeminine: return ["Clasp your hands loosely below your waist.", "Move them slightly to one side and relax your shoulders."]
        case .coupleCloseStanding: return ["Stand close with your shoulders lightly touching.", "Turn both faces toward the camera and relax your outside arms."]
        case .coupleArmAroundWaist: return ["Stand slightly staggered with one partner just behind the other.", "Place one arm gently around the front partner's waist."]
        case .coupleBackToBack: return ["Stand back to back with light contact at your shoulders.", "Angle outward slightly and turn both faces toward the camera."]
        case .coupleWalking: return ["Hold hands and take a slow step together.", "Look at each other while keeping your joined hands visible."]
        case .coupleSeated: return ["Sit close with your shoulders touching and bodies angled inward.", "Keep both sets of hands relaxed and visible."]
        case .coupleForeheadTouch: return ["Turn toward each other and step comfortably close.", "Touch foreheads lightly and rest your hands on each other's upper arms."]
        case .groupShoulderRow: return ["Stand shoulder to shoulder in one relaxed row.", "Close the gaps slightly and keep every face visible."]
        case .groupStaggered: return ["Place one person slightly forward and the others just behind on each side.", "Angle everyone gently inward and keep all faces visible."]
        case .groupLinkedWalk: return ["Link arms loosely and take a slow step together.", "Look toward one another while keeping every face visible."]
        case .groupSeatedCluster: return ["Sit close with the center person slightly forward.", "Angle the outside people inward and keep every set of hands visible."]
        case .groupCelebration: return ["Stand close and raise your hands at different heights.", "Keep every face visible and hold the pose for the next shot."]
        case .groupConversation: return ["Stand in a loose semicircle facing one another.", "Keep gestures small so every face stays visible."]
        case .familyStandingRow: return ["Stand in one relaxed row with shorter family members near the center.", "Close the gaps gently and keep every face visible."]
        case .familySideHug: return ["Stand side by side and bring your faces comfortably closer in height.", "Add a gentle side hug and turn both faces toward the camera."]
        case .familySeatedCluster: return ["Sit close with younger family members slightly forward.", "Angle everyone inward and keep hands and faces visible."]
        case .familyWalking: return ["Hold hands with the youngest family member in the center.", "Take one slow step together and look toward one another."]
        case .familyGenerations: return ["Seat one family member near the center and arrange the others close behind and beside them.", "Angle everyone inward and keep every face unobstructed."]
        case .familySharedLaugh: return ["Stand in a loose cluster and turn gently toward one another.", "Share a small laugh while keeping every face visible."]
        }
    }

    var category: PoseCategory {
        switch self {
        case .relaxedStanding, .handInPocket, .weightShift, .footForward, .handAtWaist,
             .armsCrossedMasculine, .wallLeanMasculine, .armsCrossedFeminine, .wallLeanFeminine,
             .coupleCloseStanding, .coupleArmAroundWaist, .coupleBackToBack, .coupleForeheadTouch,
             .groupShoulderRow, .groupStaggered, .groupCelebration,
             .familyStandingRow, .familySideHug:
            return .standing
        case .seatedLean, .seatedAngle, .seatedSidewaysMasculine, .seatedSidewaysFeminine, .coupleSeated,
             .groupSeatedCluster, .familySeatedCluster, .familyGenerations:
            return .seated
        case .walking, .walkingTurnFeminine, .coupleWalking, .groupLinkedWalk, .familyWalking:
            return .moving
        case .threeQuarter, .overShoulder, .lookAwayMasculine, .groupConversation, .familySharedLaugh:
            return .turned
        case .hairSweepFeminine, .handNearCheekFeminine, .armAcrossWaistFeminine, .handsClaspedFeminine:
            return .handsHair
        }
    }

    var setting: PoseSetting {
        switch self {
        case .walking, .walkingTurnFeminine, .coupleWalking, .groupLinkedWalk, .familyWalking: return .outdoor
        default: return .both
        }
    }

    /// Every posture asset includes a useful starting viewpoint. The user can still override it.
    var recommendedCameraAngle: CameraAngleChoice {
        switch self {
        case .walking, .walkingTurnFeminine, .footForward, .coupleWalking, .groupLinkedWalk, .familyWalking: return .low
        case .seatedAngle, .coupleSeated, .groupStaggered, .groupSeatedCluster, .groupCelebration,
             .familySeatedCluster, .familyGenerations: return .slightlyHigh
        case .overShoulder, .lookAwayMasculine: return .side
        case .relaxedStanding, .threeQuarter, .handInPocket, .seatedLean,
             .seatedSidewaysMasculine, .weightShift, .handAtWaist,
             .armsCrossedMasculine, .wallLeanMasculine, .armsCrossedFeminine, .wallLeanFeminine,
             .hairSweepFeminine, .handNearCheekFeminine, .armAcrossWaistFeminine, .handsClaspedFeminine,
             .seatedSidewaysFeminine, .coupleCloseStanding, .coupleArmAroundWaist, .coupleBackToBack,
             .coupleForeheadTouch, .groupShoulderRow, .groupConversation,
             .familyStandingRow, .familySideHug, .familySharedLaugh:
            return .eyeLevel
        }
    }

    var recommendedLighting: PoseLightingRecommendation {
        switch self {
        case .walking, .walkingTurnFeminine, .coupleWalking, .groupLinkedWalk, .familyWalking:
            return .openShade
        case .overShoulder, .lookAwayMasculine, .hairSweepFeminine, .handNearCheekFeminine:
            return .softSide
        case .coupleCloseStanding, .coupleArmAroundWaist, .coupleBackToBack, .coupleSeated, .coupleForeheadTouch:
            return .softEven
        case .groupShoulderRow, .groupStaggered, .groupSeatedCluster, .groupCelebration, .groupConversation,
             .familyStandingRow, .familySeatedCluster, .familyGenerations, .familySharedLaugh:
            return .broadEven
        case .relaxedStanding, .threeQuarter, .handInPocket, .weightShift, .handAtWaist,
             .seatedLean, .footForward, .seatedAngle, .armsCrossedMasculine, .wallLeanMasculine,
             .seatedSidewaysMasculine, .armsCrossedFeminine, .wallLeanFeminine, .seatedSidewaysFeminine,
             .armAcrossWaistFeminine, .handsClaspedFeminine, .familySideHug:
            return .softEven
        }
    }

    var instruction: String { cues.joined(separator: " ") }

    var exampleAssetName: String {
        switch self {
        case .relaxedStanding: return "PoseRelaxedStanding"
        case .threeQuarter: return "PoseThreeQuarter"
        case .handInPocket: return "PoseHandInPocket"
        case .seatedLean: return "PoseSeatedLean"
        case .walking: return "PoseWalking"
        case .armsCrossedMasculine: return "PoseArmsCrossedMasculine"
        case .wallLeanMasculine: return "PoseWallLeanMasculine"
        case .seatedSidewaysMasculine: return "PoseSeatedSidewaysMasculine"
        case .lookAwayMasculine: return "PoseLookAwayMasculine"
        case .weightShift: return "PoseWeightShift"
        case .footForward: return "PoseFootForward"
        case .handAtWaist: return "PoseHandAtWaist"
        case .seatedAngle: return "PoseSeatedAngle"
        case .overShoulder: return "PoseOverShoulder"
        case .armsCrossedFeminine: return "PoseArmsCrossedFeminine"
        case .wallLeanFeminine: return "PoseWallLeanFeminine"
        case .walkingTurnFeminine: return "PoseWalkingTurnFeminine"
        case .seatedSidewaysFeminine: return "PoseSeatedSidewaysFeminine"
        case .hairSweepFeminine: return "PoseHairSweepFeminine"
        case .handNearCheekFeminine: return "PoseHandNearCheekFeminine"
        case .armAcrossWaistFeminine: return "PoseArmAcrossWaistFeminine"
        case .handsClaspedFeminine: return "PoseHandsClaspedFeminine"
        case .coupleCloseStanding: return "PoseCoupleCloseStanding"
        case .coupleArmAroundWaist: return "PoseCoupleArmAroundWaist"
        case .coupleBackToBack: return "PoseCoupleBackToBack"
        case .coupleWalking: return "PoseCoupleWalking"
        case .coupleSeated: return "PoseCoupleSeated"
        case .coupleForeheadTouch: return "PoseCoupleForeheadTouch"
        case .groupShoulderRow: return "PoseGroupShoulderRow"
        case .groupStaggered: return "PoseGroupStaggered"
        case .groupLinkedWalk: return "PoseGroupLinkedWalk"
        case .groupSeatedCluster: return "PoseGroupSeatedCluster"
        case .groupCelebration: return "PoseGroupCelebration"
        case .groupConversation: return "PoseGroupConversation"
        case .familyStandingRow: return "PoseFamilyStandingRow"
        case .familySideHug: return "PoseFamilySideHug"
        case .familySeatedCluster: return "PoseFamilySeatedCluster"
        case .familyWalking: return "PoseFamilyWalking"
        case .familyGenerations: return "PoseFamilyGenerations"
        case .familySharedLaugh: return "PoseFamilySharedLaugh"
        }
    }

    var steps: [GuidedStep] {
        cues.map {
            GuidedStep(
                instruction: $0,
                action: .subjectPose,
                recipientOverride: package == .couples ? "Couple" : (package == .friendsGroups ? "Group" : (package == .family ? "Family" : nil))
            )
        }
    }

    var conflicts: Set<String> {
        var result: Set<String> = ["body_too_square", "body_too_profile", "arms_flat_against_body", "arm_hidden"]
        if self == .overShoulder || self == .lookAwayMasculine {
            result.formUnion(["face_missing", "face_too_profile", "face_turned_away"])
        }
        if category == .moving { result.insert("camera_unstable") }
        if category == .seated { result.insert("feet_cropped") }
        return result
    }
}

enum GuidedCameraPosition: String, CaseIterable, Identifiable {
    case eyeLevel = "C1", chestLevel = "C2", waistLevel = "C3", elevated = "C4", side = "C5"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .eyeLevel: return "Eye level"
        case .chestLevel: return "Chest level"
        case .waistLevel: return "Waist level, farther back"
        case .elevated: return "Slightly above eye level"
        case .side: return "To the side, at eye level"
        }
    }
    func steps(moveRight: Bool) -> [GuidedStep] {
        switch self {
        case .eyeLevel:
            return [GuidedStep(instruction: "Hold the camera at their eye level.", action: .cameraHeight)]
        case .chestLevel:
            return [GuidedStep(instruction: "Lower the camera to their chest level.", action: .cameraHeight)]
        case .waistLevel:
            return [GuidedStep(instruction: "Lower the camera to their waist level.", action: .cameraHeight),
                    GuidedStep(instruction: "Step back until their feet fit.", action: .photographerMove)]
        case .elevated:
            return [GuidedStep(instruction: "Raise the camera just above their eye level.", action: .cameraHeight),
                    GuidedStep(instruction: "Angle the camera down slightly.", action: .cameraPitch)]
        case .side:
            return [GuidedStep(instruction: "Hold the camera at their eye level.", action: .cameraHeight),
                    GuidedStep(instruction: moveRight ? "Move a little to your right around the subject." : "Move a little to your left around the subject.", action: .photographerMove)]
        }
    }
}

struct Advice: Equatable {
    let type: String
    let recipient: String
    let instruction: String
    let tone: AdviceTone

    var directionSymbol: String? {
        switch type {
        case "camera_tilted", "horizon_tilted": return "arrow.triangle.2.circlepath.camera"
        case "headroom_too_large", "headroom_too_small": return "arrow.up.and.down"
        case "limb_cropped": return "figure.walk"
        case "subject_too_close", "subject_too_far", "scene_excluded", "feet_cropped": return "arrow.up.left.and.arrow.down.right"
        default: return recipient == "Subject" ? "figure.stand" : nil
        }
    }
}

struct DetectionBox: Equatable {
    var rect: CGRect
    var confidence: CGFloat
    var label: String
}

struct Measurements {
    var personBox: DetectionBox?
    var faceBox: DetectionBox?
    var groupAnalysis: GroupAnalysis?
    var faceAnalysis: FaceAnalysis?
    var poseKeypoints: [String: DetectionPoint]
    var poseAnalysis: PoseAnalysis?
    var faceLuminance: Double?
    var backgroundLuminance: Double?
    var horizonAngleDegrees: Double?
    var horizonY: CGFloat?
    var horizonConfidence: Double
    var cameraRollDegrees: Double
    var cameraMotion: Double
    var cameraStable: Bool
    var skyOrOpenAreaRatio: Double
    var timestamp: Date
    var salientObjectBox: DetectionBox? = nil
    var subjectMotion: Double = 0
}

enum PhotographicSituation: String, CaseIterable, Identifiable {
    case auto
    case portrait
    case group
    case personScene
    case landscape
    case action
    case closeUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .portrait: return "Portrait"
        case .group: return "Group"
        case .personScene: return "Person + Scene"
        case .landscape: return "Landscape"
        case .action: return "Action"
        case .closeUp: return "Close-up"
        }
    }

    var symbol: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .portrait: return "person.crop.rectangle"
        case .group: return "person.3"
        case .personScene: return "person.and.background.dotted"
        case .landscape: return "mountain.2"
        case .action: return "figure.run"
        case .closeUp: return "viewfinder"
        }
    }

    var showsPersonOverlay: Bool {
        switch self {
        case .portrait, .group, .personScene, .action: return true
        case .auto, .landscape, .closeUp: return false
        }
    }

    var supportsPoseGuidance: Bool {
        self == .portrait || self == .personScene
    }

    var angleChoices: [CameraAngleChoice] {
        switch self {
        case .auto: return []
        case .portrait: return [.eyeLevel, .slightlyHigh, .side]
        case .group: return [.eyeLevel, .slightlyHigh, .low]
        case .personScene: return [.eyeLevel, .low, .side]
        case .landscape: return [.low, .eyeLevel, .slightlyHigh]
        case .action: return [.low, .eyeLevel, .side]
        case .closeUp: return [.overhead, .fortyFive, .side]
        }
    }
}

enum CameraAngleChoice: String, CaseIterable, Identifiable {
    case eyeLevel
    case slightlyHigh
    case low
    case overhead
    case fortyFive
    case side

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eyeLevel: return "Eye level"
        case .slightlyHigh: return "Slightly high"
        case .low: return "Low angle"
        case .overhead: return "Overhead"
        case .fortyFive: return "45-degree angle"
        case .side: return "From the side"
        }
    }

    var instruction: String {
        switch self {
        case .eyeLevel: return "Hold the camera level with the main subject."
        case .slightlyHigh: return "Raise the camera slightly and angle it down gently."
        case .low: return "Lower the camera and angle it upward gently."
        case .overhead: return "Hold the camera directly above and parallel to the subject."
        case .fortyFive: return "Photograph from slightly above and off to one side."
        case .side: return "Move to one side while keeping the subject clearly framed."
        }
    }

    var symbol: String {
        switch self {
        case .eyeLevel: return "camera"
        case .slightlyHigh: return "arrow.up.right"
        case .low: return "arrow.down.left"
        case .overhead: return "arrow.down"
        case .fortyFive: return "arrow.down.right"
        case .side: return "arrow.left.and.right"
        }
    }

    var guidedPosition: GuidedCameraPosition? {
        switch self {
        case .eyeLevel: return .eyeLevel
        case .slightlyHigh: return .elevated
        case .low: return .waistLevel
        case .side, .fortyFive: return .side
        case .overhead: return nil
        }
    }
}

enum CameraControlMode: String, CaseIterable, Identifiable {
    case auto
    case assisted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .assisted: return "Assisted"
        }
    }
}

struct CameraControlCapabilities: Equatable, Sendable {
    var isAvailable: Bool
    var cameraName: String
    var lensName: String
    var supportsExposureBias: Bool
    var minimumExposureBias: Double
    var maximumExposureBias: Double
    var currentExposureBias: Double
    var supportsFocusLock: Bool
    var supportsExposureLock: Bool
    var isFocusExposureLocked: Bool
    var currentISO: Double?
    var currentExposureDurationSeconds: Double?

    static let unavailable = CameraControlCapabilities(
        isAvailable: false,
        cameraName: "Camera unavailable",
        lensName: "Unknown lens",
        supportsExposureBias: false,
        minimumExposureBias: 0,
        maximumExposureBias: 0,
        currentExposureBias: 0,
        supportsFocusLock: false,
        supportsExposureLock: false,
        isFocusExposureLocked: false,
        currentISO: nil,
        currentExposureDurationSeconds: nil
    )

    func clampedExposureBias(_ value: Double) -> Double {
        min(maximumExposureBias, max(minimumExposureBias, value))
    }
}

enum LandscapeCompositionPackageID: String, CaseIterable, Identifiable {
    case mountains
    case lakes
    case plains
    case plants

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mountains: return "Mountains"
        case .lakes: return "Lakes & Water"
        case .plains: return "Plains & Fields"
        case .plants: return "Plants & Gardens"
        }
    }

    var description: String {
        switch self {
        case .mountains: return "Peaks, ridges, valleys, and foreground depth"
        case .lakes: return "Reflections, shorelines, rocks, reeds, and water texture"
        case .plains: return "Open sky, paths, repeating rows, and layered fields"
        case .plants: return "Garden paths, foliage layers, patterns, and details"
        }
    }

    var symbol: String {
        switch self {
        case .mountains: return "mountain.2.fill"
        case .lakes: return "water.waves"
        case .plains: return "sun.horizon.fill"
        case .plants: return "leaf.fill"
        }
    }
}

enum LandscapeLightRecommendation: String, CaseIterable, Identifiable {
    case sunriseSunset
    case mistySideLight
    case blueHour
    case sunset
    case goldenHour
    case softOvercast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sunriseSunset: return "Sunrise or sunset"
        case .mistySideLight: return "Sunrise, sunset, or mist"
        case .blueHour: return "Sunrise or blue hour"
        case .sunset: return "Sunset"
        case .goldenHour: return "Golden hour"
        case .softOvercast: return "Soft overcast"
        }
    }

    var instruction: String {
        switch self {
        case .sunriseSunset: return "Use low side light to reveal shape, depth, and natural texture."
        case .mistySideLight: return "Look for side light or mist that separates each ridge."
        case .blueHour: return "Stabilize the phone and preserve the cool color in sky and water."
        case .sunset: return "Expose for the bright sky while retaining visible foreground detail."
        case .goldenHour: return "Use warm side light to add depth without losing highlight detail."
        case .softOvercast: return "Use even cloud light to preserve natural color and fine detail."
        }
    }

    var symbol: String {
        switch self {
        case .sunriseSunset, .mistySideLight, .sunset, .goldenHour: return "sun.horizon.fill"
        case .blueHour: return "moon.haze.fill"
        case .softOvercast: return "cloud.fill"
        }
    }
}

enum LandscapeCompositionRecipe: String, CaseIterable, Identifiable {
    case mountainTrail = "MT1"
    case layeredRidges = "MT2"
    case peakOpenSky = "MT3"
    case valleyAbove = "MT4"
    case personScale = "MT5"
    case mountainDetail = "MT6"
    case lakeReflection = "LK1"
    case lakeForegroundRocks = "LK2"
    case lakeCurvingShoreline = "LK3"
    case lakeMinimal = "LK4"
    case lakeReeds = "LK5"
    case lakeWaterTexture = "LK6"
    case plainPath = "PL1"
    case plainOpenSky = "PL2"
    case plainRepeatingRows = "PL3"
    case plainSingleTree = "PL4"
    case plainForegroundTexture = "PL5"
    case plainLayeredColors = "PL6"
    case plantGardenPath = "PG1"
    case plantPortrait = "PG2"
    case plantBacklitLeaves = "PG3"
    case plantPattern = "PG4"
    case plantLayeredFoliage = "PG5"
    case plantDetail = "PG6"

    var id: String { rawValue }

    var package: LandscapeCompositionPackageID {
        switch self {
        case .mountainTrail, .layeredRidges, .peakOpenSky, .valleyAbove, .personScale, .mountainDetail:
            return .mountains
        case .lakeReflection, .lakeForegroundRocks, .lakeCurvingShoreline, .lakeMinimal, .lakeReeds, .lakeWaterTexture:
            return .lakes
        case .plainPath, .plainOpenSky, .plainRepeatingRows, .plainSingleTree, .plainForegroundTexture, .plainLayeredColors:
            return .plains
        case .plantGardenPath, .plantPortrait, .plantBacklitLeaves, .plantPattern, .plantLayeredFoliage, .plantDetail:
            return .plants
        }
    }

    var title: String {
        switch self {
        case .mountainTrail: return "Foreground trail to peak"
        case .layeredRidges: return "Layered ridgelines"
        case .peakOpenSky: return "Peak with open sky"
        case .valleyAbove: return "Valley from above"
        case .personScale: return "Person for scale"
        case .mountainDetail: return "Mountain detail"
        case .lakeReflection: return "Centered reflection"
        case .lakeForegroundRocks: return "Foreground rocks"
        case .lakeCurvingShoreline: return "Curving shoreline"
        case .lakeMinimal: return "Minimal water and sky"
        case .lakeReeds: return "Reeds at the water's edge"
        case .lakeWaterTexture: return "Moving water texture"
        case .plainPath: return "Path through the field"
        case .plainOpenSky: return "Large open sky"
        case .plainRepeatingRows: return "Repeating rows"
        case .plainSingleTree: return "Single tree"
        case .plainForegroundTexture: return "Grass or flowers in front"
        case .plainLayeredColors: return "Layered field colors"
        case .plantGardenPath: return "Garden path"
        case .plantPortrait: return "Single plant portrait"
        case .plantBacklitLeaves: return "Backlit leaves"
        case .plantPattern: return "Repeating pattern"
        case .plantLayeredFoliage: return "Layered foliage"
        case .plantDetail: return "Flower or leaf detail"
        }
    }

    var cues: [String] {
        switch self {
        case .mountainTrail:
            return ["Lower the camera near the trail.", "Use the trail to lead toward the peak."]
        case .layeredRidges:
            return ["Frame several overlapping ridges.", "Keep the brightest ridge away from the center."]
        case .peakOpenSky:
            return ["Place the peak below the center.", "Leave clean sky around its outline."]
        case .valleyAbove:
            return ["Include the valley foreground.", "Keep the horizon level and away from the center."]
        case .personScale:
            return ["Place the person away from the peak.", "Step back until the landscape remains dominant."]
        case .mountainDetail:
            return ["Isolate one ridge, texture, or patch of light.", "Remove distracting edges."]
        case .lakeReflection:
            return ["Center the shoreline horizontally.", "Keep the reflected peak or trees fully visible."]
        case .lakeForegroundRocks:
            return ["Lower the camera near stable dry rocks.", "Use them to lead into the water."]
        case .lakeCurvingShoreline:
            return ["Follow the shoreline through the frame.", "Keep its far end visible."]
        case .lakeMinimal:
            return ["Simplify the frame to water, horizon, and sky.", "Remove shoreline clutter."]
        case .lakeReeds:
            return ["Place the reeds along one edge.", "Keep open water visible beyond them."]
        case .lakeWaterTexture:
            return ["Fill the frame with ripples or flow.", "Avoid bright reflections at the edges."]
        case .plainPath:
            return ["Place the path near a lower corner.", "Let it lead toward the distance."]
        case .plainOpenSky:
            return ["Place the horizon low.", "Keep the strongest cloud or color away from dead center."]
        case .plainRepeatingRows:
            return ["Align the rows into the distance.", "Keep their convergence point visible."]
        case .plainSingleTree:
            return ["Isolate the tree against open space.", "Leave breathing room around its canopy."]
        case .plainForegroundTexture:
            return ["Focus on the nearest grass or flowers.", "Keep enough distant field to show depth."]
        case .plainLayeredColors:
            return ["Stack color bands across the frame.", "Keep their boundaries clean and level."]
        case .plantGardenPath:
            return ["Use the path as a leading line.", "Keep its destination visible."]
        case .plantPortrait:
            return ["Move to the plant's height.", "Choose a clean background behind it."]
        case .plantBacklitLeaves:
            return ["Place the light behind the leaves.", "Shift sideways until the edges glow without losing detail."]
        case .plantPattern:
            return ["Fill the frame with the pattern.", "Keep rows and edges aligned."]
        case .plantLayeredFoliage:
            return ["Separate foreground, middle, and background plants.", "Avoid merging the main leaf shapes."]
        case .plantDetail:
            return ["Move close enough to simplify the frame.", "Keep the key petal or leaf edge sharp."]
        }
    }

    var instruction: String { cues.joined(separator: " ") }

    var recommendedCameraAngle: CameraAngleChoice {
        switch self {
        case .mountainTrail, .lakeForegroundRocks, .lakeReeds, .plainPath,
             .plainForegroundTexture, .plantGardenPath, .plantBacklitLeaves:
            return .low
        case .layeredRidges, .peakOpenSky, .personScale, .lakeReflection,
             .lakeMinimal, .plainOpenSky, .plainSingleTree, .plantPortrait,
             .plantLayeredFoliage:
            return .eyeLevel
        case .valleyAbove, .lakeCurvingShoreline, .lakeWaterTexture,
             .plainRepeatingRows, .plainLayeredColors:
            return .slightlyHigh
        case .mountainDetail: return .side
        case .plantPattern: return .overhead
        case .plantDetail: return .fortyFive
        }
    }

    var recommendedLight: LandscapeLightRecommendation {
        switch self {
        case .mountainTrail: return .sunriseSunset
        case .layeredRidges: return .mistySideLight
        case .peakOpenSky: return .blueHour
        case .valleyAbove: return .sunset
        case .personScale: return .goldenHour
        case .mountainDetail: return .softOvercast
        case .lakeReflection, .lakeForegroundRocks, .lakeReeds,
             .plainPath, .plainSingleTree, .plantBacklitLeaves:
            return .sunriseSunset
        case .lakeCurvingShoreline, .plainRepeatingRows, .plainForegroundTexture:
            return .goldenHour
        case .lakeMinimal: return .blueHour
        case .plainOpenSky: return .sunset
        case .lakeWaterTexture, .plainLayeredColors, .plantGardenPath,
             .plantPortrait, .plantPattern, .plantLayeredFoliage, .plantDetail:
            return .softOvercast
        }
    }

    var safetyNote: String {
        switch self {
        case .mountainTrail:
            return "Stay on a stable marked trail; do not step into vegetation for a lower angle."
        case .layeredRidges:
            return "Use an established overlook and remain behind every barrier."
        case .peakOpenSky:
            return "Change the framing from a safe position instead of climbing for a clearer outline."
        case .valleyAbove:
            return "Never approach a cliff edge; use a protected overlook for the elevated view."
        case .personScale:
            return "Keep the person on a broad safe trail and away from drop-offs."
        case .mountainDetail:
            return "Zoom or reframe from stable ground rather than approaching loose rock."
        case .lakeReflection:
            return "Stay on a stable dry shoreline and never enter the water for symmetry."
        case .lakeForegroundRocks:
            return "Use dry stable rocks from shore; do not climb wet rocks or enter the water."
        case .lakeCurvingShoreline:
            return "Use an established path or overlook and avoid unstable banks."
        case .lakeMinimal:
            return "Compose from a safe public shoreline and remain back from soft or eroded edges."
        case .lakeReeds:
            return "Stay on the boardwalk or dry bank; do not enter reeds or wetlands."
        case .lakeWaterTexture:
            return "Angle downward from stable ground without leaning over a bank or railing."
        case .plainPath:
            return "Remain on the established path and respect field boundaries."
        case .plainOpenSky:
            return "Use a designated pullout or public path, never an active roadway."
        case .plainRepeatingRows:
            return "Photograph from an authorized edge and do not enter or damage crops."
        case .plainSingleTree:
            return "Stay on public ground and do not cross fences to improve the angle."
        case .plainForegroundTexture:
            return "Keep to the path so grass, flowers, and habitat remain undisturbed."
        case .plainLayeredColors:
            return "Use a protected overlook and remain behind barriers and fences."
        case .plantGardenPath:
            return "Stay on the maintained garden path and keep access clear for others."
        case .plantPortrait:
            return "Do not touch, bend, or move the plant to clean the background."
        case .plantBacklitLeaves:
            return "Shift only along the maintained path; do not step into planting beds."
        case .plantPattern:
            return "Use the path edge for the overhead view and never step into the bed."
        case .plantLayeredFoliage:
            return "Compose from the path without pushing through or rearranging foliage."
        case .plantDetail:
            return "Move the phone, not the plant; avoid touching petals, stems, or leaves."
        }
    }

    var exampleAssetName: String {
        switch self {
        case .mountainTrail: return "LandscapeMountainTrail"
        case .layeredRidges: return "LandscapeMountainRidges"
        case .peakOpenSky: return "LandscapeMountainPeakSky"
        case .valleyAbove: return "LandscapeMountainValley"
        case .personScale: return "LandscapeMountainScale"
        case .mountainDetail: return "LandscapeMountainDetail"
        case .lakeReflection: return "LandscapeLakeReflection"
        case .lakeForegroundRocks: return "LandscapeLakeRocks"
        case .lakeCurvingShoreline: return "LandscapeLakeShoreline"
        case .lakeMinimal: return "LandscapeLakeMinimal"
        case .lakeReeds: return "LandscapeLakeReeds"
        case .lakeWaterTexture: return "LandscapeLakeRipples"
        case .plainPath: return "LandscapePlainPath"
        case .plainOpenSky: return "LandscapePlainSky"
        case .plainRepeatingRows: return "LandscapePlainRows"
        case .plainSingleTree: return "LandscapePlainTree"
        case .plainForegroundTexture: return "LandscapePlainForeground"
        case .plainLayeredColors: return "LandscapePlainLayers"
        case .plantGardenPath: return "LandscapePlantGardenPath"
        case .plantPortrait: return "LandscapePlantPortrait"
        case .plantBacklitLeaves: return "LandscapePlantBacklit"
        case .plantPattern: return "LandscapePlantPattern"
        case .plantLayeredFoliage: return "LandscapePlantFoliage"
        case .plantDetail: return "LandscapePlantDetail"
        }
    }
}

struct SituationClassifier {
    private(set) var recommendation: PhotographicSituation = .personScene
    private var candidate: PhotographicSituation?
    private var candidateFrameCount = 0
    private let requiredStableFrames: Int

    init(requiredStableFrames: Int = 3) {
        self.requiredStableFrames = max(1, requiredStableFrames)
    }

    mutating func update(with measurements: Measurements) -> PhotographicSituation {
        guard let next = Self.candidate(for: measurements) else {
            candidate = nil
            candidateFrameCount = 0
            return recommendation
        }

        guard next != recommendation else {
            candidate = nil
            candidateFrameCount = 0
            return recommendation
        }

        if candidate == next {
            candidateFrameCount += 1
        } else {
            candidate = next
            candidateFrameCount = 1
        }

        if candidateFrameCount >= requiredStableFrames {
            recommendation = next
            candidate = nil
            candidateFrameCount = 0
        }
        return recommendation
    }

    static func candidate(for measurements: Measurements) -> PhotographicSituation? {
        if let group = measurements.groupAnalysis,
           max(group.peopleCount, group.faceCount) >= 2 {
            return .group
        }

        if let person = measurements.personBox {
            if measurements.subjectMotion >= 0.16 {
                return .action
            }
            let personArea = person.rect.width * person.rect.height
            let faceArea = measurements.faceBox.map { $0.rect.width * $0.rect.height } ?? 0
            if personArea >= 0.2 || faceArea >= 0.035 {
                return .portrait
            }
            return .personScene
        }

        if measurements.horizonConfidence >= 0.45 {
            return .landscape
        }

        if let object = measurements.salientObjectBox {
            let area = object.rect.width * object.rect.height
            if object.confidence >= 0.35, area >= 0.18 {
                return .closeUp
            }
        }

        if measurements.skyOrOpenAreaRatio >= 0.5 {
            return .landscape
        }

        // Keep the last stable recommendation when the current frame is ambiguous.
        return nil
    }
}

struct GroupAnalysis: Equatable {
    var peopleCount: Int
    var faceCount: Int
    var groupBounds: CGRect?
    var faceVisibilityRatio: Double
    var edgeCrowdingScore: Double
    var spacingScore: Double?
}

struct DetectionPoint: Equatable {
    var point: CGPoint
    var confidence: CGFloat
}

struct FaceAnalysis: Equatable {
    var confidence: Double
    var landmarkPointCount: Int
    var eyeVisibilityScore: Double
    var yawEstimate: Double?
    var pitchEstimate: Double?
    var occlusionScore: Double
}

struct PoseAnalysis: Equatable {
    var confidence: Double
    var visibleKeypointCount: Int
    var shoulderLineAngleDegrees: Double?
    var shoulderHeightAsymmetry: Double?
    var torsoAngleDegrees: Double?
    var wristToFaceDistance: Double?
    var armVisibilityScore: Double
    var stanceWidth: Double?
    var headToTorsoRatio: Double?
    var shouldersHighScore: Double?
    var bodySquarenessScore: Double?
    var bodyProfileScore: Double?
    var armsFlatAgainstBodyScore: Double?
    var minWristEdgeDistance: Double?
}

enum PosePackageID: String, CaseIterable, Identifiable {
    case neutral
    case feminine
    case masculine
    case professional
    case groupPortrait

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .neutral:
            return "Natural"
        case .feminine:
            return "Feminine"
        case .masculine:
            return "Masculine"
        case .professional:
            return "Professional"
        case .groupPortrait:
            return "Group"
        }
    }
}

struct PosePackage: Equatable {
    let id: PosePackageID
    let title: String
    let tipOverrides: [String: PoseTip]
}

struct PoseTip: Equatable {
    let issueType: String
    let recipient: String
    let instruction: String
    let successCondition: String
    let priorityAdjustment: Double
}

struct ReframeSuggestion: Equatable {
    var cropRect: CGRect
    var targetAspectRatio: CGFloat
    var instruction: String
    var confidence: Double
    var reason: String
}

struct BeautifySettings: Equatable {
    var strength: Int = 0
    var faceBrightnessEnabled: Bool = true
    var skinSmoothingEnabled: Bool = true
    var warmthEnabled: Bool = true
    var clarityEnabled: Bool = true
    var subjectEmphasisEnabled: Bool = true

    var normalizedStrength: Double {
        Double(max(0, min(10, strength))) / 10
    }
}

struct BeautifyResult: Equatable {
    var settings: BeautifySettings
    var faceDetected: Bool
    var personDetected: Bool
    var debugValues: [String: Double]
}

enum VoiceShutterCommand {
    static func matches(_ transcript: String) -> Bool {
        let words = transcript
            .lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }

        if words.last == "cheese" { return true }
        guard let takeIndex = words.lastIndex(of: "take") else { return false }
        let command = Array(words[takeIndex...])
        return command.starts(with: ["take", "photo"])
            || command.starts(with: ["take", "a", "photo"])
            || command.starts(with: ["take", "picture"])
            || command.starts(with: ["take", "a", "picture"])
    }
}

struct PhotoIssue: Identifiable, Equatable {
    let type: String
    let severity: Double
    let confidence: Double
    let priority: Double
    let recipient: String
    let instruction: String
    let successCondition: String
    let cooldownMilliseconds: Int
    let reasonData: [String: Double]
    let tone: AdviceTone

    var id: String {
        type
    }
}
