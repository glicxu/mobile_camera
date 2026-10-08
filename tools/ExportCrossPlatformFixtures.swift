import Foundation
import CoreGraphics

/// Run on macOS with Models.swift and CoachingEngine.swift. Fixtures are
/// computed by the real Swift rule engine, never inferred from Dart output.
@main
struct FixtureExporter {
    static func main() throws {
        let cases: [(String, CGRect?, CGRect?, Double, Bool)] = [
            ("missing", nil, nil, 0, true),
            ("normal", CGRect(x: 0.3, y: 0.12, width: 0.4, height: 0.72), CGRect(x: 0.42, y: 0.16, width: 0.12, height: 0.12), 0, true),
            ("too_close", CGRect(x: 0.1, y: 0.05, width: 0.8, height: 0.95), nil, 0, true),
            ("too_far", CGRect(x: 0.46, y: 0.4, width: 0.08, height: 0.2), nil, 0, true),
            ("left_edge", CGRect(x: 0, y: 0.12, width: 0.4, height: 0.72), CGRect(x: 0.1, y: 0.16, width: 0.12, height: 0.12), 0, true),
            ("right_edge", CGRect(x: 0.6, y: 0.12, width: 0.4, height: 0.72), CGRect(x: 0.7, y: 0.16, width: 0.12, height: 0.12), 0, true),
            ("feet", CGRect(x: 0.3, y: 0.25, width: 0.4, height: 0.75), CGRect(x: 0.4, y: 0.3, width: 0.12, height: 0.12), 0, true),
            ("tilted", CGRect(x: 0.3, y: 0.12, width: 0.4, height: 0.72), CGRect(x: 0.42, y: 0.16, width: 0.12, height: 0.12), 8, true),
            ("unstable", CGRect(x: 0.3, y: 0.12, width: 0.4, height: 0.72), CGRect(x: 0.42, y: 0.16, width: 0.12, height: 0.12), 0, false)
        ]
        func box(_ rect: CGRect?) -> [String: Double]? {
            rect.map { ["x": Double($0.minX), "y": Double($0.minY), "width": Double($0.width), "height": Double($0.height)] }
        }
        let epoch = Date(timeIntervalSince1970: 100)
        let fixtures: [[String: Any]] = cases.map { name, person, face, roll, stable in
            let measurements = Measurements(personBox: person.map { DetectionBox(rect: $0, confidence: 0.9, label: "person") },
                faceBox: face.map { DetectionBox(rect: $0, confidence: 0.9, label: "face") }, groupAnalysis: nil,
                faceAnalysis: nil, poseKeypoints: [:], poseAnalysis: nil, faceLuminance: nil,
                backgroundLuminance: nil, horizonAngleDegrees: nil, horizonY: nil, horizonConfidence: 0,
                cameraRollDegrees: roll, cameraMotion: stable ? 0 : 0.2, cameraStable: stable, skyOrOpenAreaRatio: 1, timestamp: epoch)
            let engine = CoachingEngine()
            let issues = engine.issues(for: measurements, includePosture: false)
            _ = engine.selectAdvice(from: issues, now: epoch)
            let advice = engine.selectAdvice(from: issues, now: epoch.addingTimeInterval(4))
            return ["name": name, "person": box(person) as Any? ?? NSNull(), "face": box(face) as Any? ?? NSNull(),
                "roll": roll, "stable": stable, "issues": issues.map { $0.type },
                "advice": ["type": advice.type, "recipient": advice.recipient, "instruction": advice.instruction]]
        }
        let data = try JSONSerialization.data(withJSONObject: fixtures, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
    }
}
