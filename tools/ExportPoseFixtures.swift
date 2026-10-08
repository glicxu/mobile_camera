import Foundation
import CoreGraphics

@main
struct PoseFixtureExporter {
    static func main() throws {
        let base: [String: CGPoint] = [
            "nose": CGPoint(x: 0.5, y: 0.18), "leftShoulder": CGPoint(x: 0.35, y: 0.3), "rightShoulder": CGPoint(x: 0.65, y: 0.3),
            "leftElbow": CGPoint(x: 0.30, y: 0.46), "rightElbow": CGPoint(x: 0.70, y: 0.46),
            "leftWrist": CGPoint(x: 0.30, y: 0.62), "rightWrist": CGPoint(x: 0.70, y: 0.62),
            "leftHip": CGPoint(x: 0.4, y: 0.6), "rightHip": CGPoint(x: 0.6, y: 0.6),
            "leftAnkle": CGPoint(x: 0.38, y: 0.92), "rightAnkle": CGPoint(x: 0.62, y: 0.92)
        ]
        let person = DetectionBox(rect: CGRect(x: 0.25, y: 0.1, width: 0.5, height: 0.85), confidence: 0.9, label: "person")
        let face = DetectionBox(rect: CGRect(x: 0.43, y: 0.12, width: 0.14, height: 0.14), confidence: 0.9, label: "face")
        var fixtures: [[String: Any]] = []
        for index in 0..<16 {
            var points = base
            if index == 1 { points["leftShoulder"] = CGPoint(x: 0.35, y: 0.24) }
            if index == 2 { points["leftWrist"] = CGPoint(x: 0.47, y: 0.18) }
            if index == 3 { points["rightWrist"] = CGPoint(x: 0.99, y: 0.6) }
            if index == 4 { points.removeValue(forKey: "rightHip") }
            if index == 5 { points = [:] }
            if index == 6 { points = ["nose": CGPoint(x: 0.5, y: 0.1)] }
            if index == 7 { points["leftElbow"] = CGPoint(x: 0.45, y: 0.4); points["rightElbow"] = CGPoint(x: 0.55, y: 0.4) }
            if index == 8 { points["leftShoulder"] = CGPoint(x: 0.48, y: 0.3); points["rightShoulder"] = CGPoint(x: 0.52, y: 0.3) }
            if index == 9 { points["leftHip"] = CGPoint(x: 0.6, y: 0.6); points["rightHip"] = CGPoint(x: 0.8, y: 0.6) }
            if index == 10 { points.removeValue(forKey: "leftWrist"); points.removeValue(forKey: "rightWrist") }
            if index == 11 { points["leftAnkle"] = CGPoint(x: 0.1, y: 0.92); points["rightAnkle"] = CGPoint(x: 0.9, y: 0.92) }
            let confidence: CGFloat = index == 12 ? 0.1 : 0.8
            let detection = points.reduce(into: [String: DetectionPoint]()) { output, entry in
                output[index == 13 ? "VNHumanBodyPoseObservationJointName.\(entry.key)" : entry.key] = DetectionPoint(point: entry.value, confidence: confidence)
            }
            let analysis = ReferencePoseGeometry().poseAnalysis(from: detection, person: index == 14 ? nil : person, face: index == 15 ? nil : face)
            var expected: [String: Any] = [:]
            if let analysis {
                for child in Mirror(reflecting: analysis).children {
                    let value = Mirror(reflecting: child.value)
                    expected[child.label!] = value.displayStyle == .optional ? (value.children.first?.value ?? NSNull()) : child.value
                }
            }
            fixtures.append(["name": "pose-\(index)", "points": detection.mapValues { ["x": $0.point.x, "y": $0.point.y, "confidence": $0.confidence] },
                "hasPerson": index != 14, "hasFace": index != 15, "expected": analysis == nil ? NSNull() : expected])
        }
        try JSONSerialization.data(withJSONObject: fixtures, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
    }
}
