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
    // Creative poses and relative camera heights are explicitly confirmed by the user.
    var recipient: String { action == .subjectPose ? "Subject" : "Photographer" }
    var completion: GuidedCompletion { .userConfirmed }
}

enum GuidedPose: String, CaseIterable, Identifiable {
    case relaxedStanding = "M1", threeQuarter = "M2", handInPocket = "M3"
    case seatedLean = "M4", walking = "M5"
    case weightShift = "F1", footForward = "F2", handAtWaist = "F3"
    case seatedAngle = "F4", overShoulder = "F5"

    var id: String { rawValue }
    var package: PosePackageID { rawValue.hasPrefix("M") ? .masculine : .feminine }
    var title: String {
        switch self {
        case .relaxedStanding: return "Relaxed standing"
        case .threeQuarter: return "Three-quarter stance"
        case .handInPocket: return "One hand in pocket"
        case .seatedLean: return "Seated forward lean"
        case .walking: return "Casual walking"
        case .weightShift: return "Weight-shift stance"
        case .footForward: return "One foot forward"
        case .handAtWaist: return "Hand at waist"
        case .seatedAngle: return "Seated angled pose"
        case .overShoulder: return "Over-shoulder glance"
        }
    }

    var cues: [String] {
        switch self {
        case .relaxedStanding: return ["Stand with your feet comfortably apart.", "Relax your shoulders."]
        case .threeQuarter: return ["Turn your body slightly to your right.", "Bring your face back toward the camera."]
        case .handInPocket: return ["Rest one hand in your pocket.", "Let your other arm hang loosely."]
        case .seatedLean: return ["Sit and lean slightly forward.", "Rest your forearms on your thighs."]
        case .walking: return ["Walk slowly across the frame.", "Look toward the camera for the next shot."]
        case .weightShift: return ["Rest your weight on one leg.", "Soften the other knee."]
        case .footForward: return ["Place one foot slightly in front.", "Turn your shoulders a little toward the camera."]
        case .handAtWaist: return ["Rest one hand lightly at your waist.", "Relax your other arm."]
        case .seatedAngle: return ["Sit with your knees angled slightly to one side.", "Turn your face toward the camera."]
        case .overShoulder: return ["Turn your body partly away from the camera.", "Look back over your shoulder comfortably."]
        }
    }

    var steps: [GuidedStep] { cues.map { GuidedStep(instruction: $0, action: .subjectPose) } }

    var conflicts: Set<String> {
        var result: Set<String> = ["body_too_square", "body_too_profile", "arms_flat_against_body", "arm_hidden"]
        if self == .overShoulder {
            result.formUnion(["face_missing", "face_too_profile", "face_turned_away"])
        }
        if self == .walking { result.insert("camera_unstable") }
        if self == .seatedLean || self == .seatedAngle { result.insert("feet_cropped") }
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
