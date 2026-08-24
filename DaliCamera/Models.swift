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
    var faceLuminance: Double?
    var backgroundLuminance: Double?
    var cameraRollDegrees: Double
    var cameraStable: Bool
    var timestamp: Date
}

struct PhotoIssue: Identifiable, Equatable {
    let id = UUID()
    let type: String
    let severity: Double
    let confidence: Double
    let recipient: String
    let instruction: String
    let tone: AdviceTone

    var priority: Double {
        severity * confidence
    }
}
