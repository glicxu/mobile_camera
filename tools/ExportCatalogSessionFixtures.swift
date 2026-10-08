import Foundation

/// Export the actual selected-posture sequence used by the native camera screen.
@main
struct ExportCatalogSessionFixtures {
    static func main() throws {
        let fixtures: [[String: Any]] = GuidedPose.allCases.map { pose in
            let session = GuidedSession(pose: pose, position: pose.recommendedCameraAngle.guidedPosition)
            return [
                "id": pose.id,
                "position": session.position?.rawValue ?? "none",
                "steps": session.steps.map { step in
                    ["instruction": step.instruction, "recipient": step.recipient, "action": step.action.rawValue]
                }
            ]
        }
        try JSONSerialization.data(withJSONObject: fixtures, options: [.sortedKeys])
            .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
