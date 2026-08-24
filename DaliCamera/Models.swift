import CoreGraphics
import Foundation

enum AdviceTone {
    case waiting
    case ready
    case warning
    case danger
}

struct Advice: Equatable {
    let type: String
    let recipient: String
    let instruction: String
    let tone: AdviceTone
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
