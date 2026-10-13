import Foundation
import CoreGraphics

/// Uses the actual frozen native classifier, including its transition history.
@main
struct SituationFixtureExporter {
    static func main() throws {
        let small = CGRect(x: 0.4, y: 0.4, width: 0.1, height: 0.2)
        let large = CGRect(x: 0.2, y: 0.1, width: 0.5, height: 0.7)
        let sequence: [(String, CGRect?, Int, Double, Double, CGRect?, Double)] = [
            ("portrait_1", large, 0, 0, 0, nil, 0),
            ("ambiguous_breaks_candidate", nil, 0, 0, 0, nil, 0),
            ("portrait_1_again", large, 0, 0, 0, nil, 0),
            ("portrait_2", large, 0, 0, 0, nil, 0),
            ("portrait_3", large, 0, 0, 0, nil, 0),
            ("group_beats_action_1", large, 2, 0.3, 0, nil, 0),
            ("group_beats_action_2", large, 2, 0.3, 0, nil, 0),
            ("group_beats_action_3", large, 2, 0.3, 0, nil, 0),
            ("action_1", large, 0, 0.16, 0, nil, 0),
            ("action_2", large, 0, 0.16, 0, nil, 0),
            ("action_3", large, 0, 0.16, 0, nil, 0),
            ("person_scene_1", small, 0, 0, 0, nil, 0),
            ("person_scene_2", small, 0, 0, 0, nil, 0),
            ("person_scene_3", small, 0, 0, 0, nil, 0),
            ("horizon_beats_object_1", nil, 0, 0, 0.45, large, 0),
            ("horizon_beats_object_2", nil, 0, 0, 0.45, large, 0),
            ("horizon_beats_object_3", nil, 0, 0, 0.45, large, 0),
            ("close_up_1", nil, 0, 0, 0, large, 0),
            ("close_up_2", nil, 0, 0, 0, large, 0),
            ("close_up_3", nil, 0, 0, 0, large, 0),
            ("open_area_1", nil, 0, 0, 0, nil, 0.5),
            ("open_area_2", nil, 0, 0, 0, nil, 0.5),
            ("open_area_3", nil, 0, 0, 0, nil, 0.5),
            ("ambiguous_holds", nil, 0, 0, 0, nil, 0)
        ]
        func jsonBox(_ rect: CGRect?) -> Any {
            guard let rect else { return NSNull() }
            return ["x": Double(rect.minX), "y": Double(rect.minY), "width": Double(rect.width), "height": Double(rect.height)]
        }
        var classifier = SituationClassifier()
        let rows: [[String: Any]] = sequence.map { name, person, count, speed, horizon, object, openArea in
            let measures = Measurements(
                personBox: person.map { DetectionBox(rect: $0, confidence: 0.9, label: "person") }, faceBox: nil,
                groupAnalysis: count == 0 ? nil : GroupAnalysis(peopleCount: count, faceCount: count, groupBounds: nil, faceVisibilityRatio: 1, edgeCrowdingScore: 0, spacingScore: nil),
                faceAnalysis: nil, poseKeypoints: [:], poseAnalysis: nil, faceLuminance: nil, backgroundLuminance: nil,
                horizonAngleDegrees: nil, horizonY: nil, horizonConfidence: horizon, cameraRollDegrees: 0, cameraMotion: 0,
                cameraStable: true, skyOrOpenAreaRatio: openArea, timestamp: Date(timeIntervalSince1970: 100),
                salientObjectBox: object.map { DetectionBox(rect: $0, confidence: 0.9, label: "object") }, subjectMotion: speed
            )
            let recommendation = classifier.update(with: measures)
            return ["name": name, "person": jsonBox(person), "faceCount": count, "subjectMotion": speed,
                    "horizonConfidence": horizon, "object": jsonBox(object), "openAreaRatio": openArea,
                    "candidate": SituationClassifier.candidate(for: measures)?.rawValue as Any? ?? NSNull(),
                    "recommendation": recommendation.rawValue]
        }
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
    }
}
