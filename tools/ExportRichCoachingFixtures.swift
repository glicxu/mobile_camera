import Foundation
import CoreGraphics

@main
struct RichCoachingExporter {
    static func main() throws {
        func values(_ value: Any) -> [String: Any] {
            var result: [String: Any] = [:]
            for child in Mirror(reflecting: value).children {
                guard let name = child.label else { continue }
                let mirror = Mirror(reflecting: child.value)
                result[name] = mirror.displayStyle == .optional ? mirror.children.first?.value ?? NSNull() : child.value
            }
            return result
        }
        var fixtures: [[String: Any]] = []
        for package in PosePackageID.allCases {
            for value in [0.0, 0.02, 0.055, 0.1, 0.3, 0.5, 0.65, 0.8, 0.95, 1.0] {
                for yaw in [-0.9, 0.0, 0.9] {
                    let pose = PoseAnalysis(confidence: 0.9, visibleKeypointCount: 11, shoulderLineAngleDegrees: value * 30, shoulderHeightAsymmetry: value,
                        torsoAngleDegrees: value * 30, wristToFaceDistance: value, armVisibilityScore: value, stanceWidth: value, headToTorsoRatio: value,
                        shouldersHighScore: value, bodySquarenessScore: value, bodyProfileScore: value, armsFlatAgainstBodyScore: value, minWristEdgeDistance: value)
                    let face = FaceAnalysis(confidence: 0.9, landmarkPointCount: 40, eyeVisibilityScore: value, yawEstimate: yaw, pitchEstimate: yaw, occlusionScore: value)
                    let group = GroupAnalysis(peopleCount: 3, faceCount: 2, groupBounds: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), faceVisibilityRatio: value, edgeCrowdingScore: value, spacingScore: value)
                    let measures = Measurements(personBox: DetectionBox(rect: CGRect(x: 0.25, y: 0.1, width: 0.5, height: 0.8), confidence: 0.9, label: "person"),
                        faceBox: DetectionBox(rect: CGRect(x: 0.4, y: 0.15, width: 0.2, height: 0.15), confidence: 0.9, label: "face"), groupAnalysis: group,
                        faceAnalysis: face, poseKeypoints: [:], poseAnalysis: pose, faceLuminance: value * 255, backgroundLuminance: 200,
                        horizonAngleDegrees: yaw * 12, horizonY: 0.5, horizonConfidence: 0.9, cameraRollDegrees: yaw * 8,
                        cameraMotion: 0, cameraStable: true, skyOrOpenAreaRatio: value, timestamp: Date(timeIntervalSince1970: 100))
                    var groupJSON = values(group); groupJSON["groupBounds"] = ["x": 0.1, "y": 0.1, "width": 0.8, "height": 0.8]
                    let issues = CoachingEngine().issues(for: measures, posePackage: package)
                    fixtures.append(["name": "\(package.rawValue)-\(value)-\(yaw)", "package": package.rawValue, "pose": values(pose), "face": values(face), "group": groupJSON,
                        "luminance": value * 255, "horizon": yaw * 12, "roll": yaw * 8, "openArea": value,
                        "issues": issues.map { ["type": $0.type, "recipient": $0.recipient, "instruction": $0.instruction, "priority": $0.priority, "severity": $0.severity, "confidence": $0.confidence] }])
                }
            }
        }
        try JSONSerialization.data(withJSONObject: fixtures, options: [.sortedKeys]).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
