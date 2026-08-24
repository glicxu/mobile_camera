import CoreGraphics
import XCTest

final class CoachingEngineTests: XCTestCase {
    func testSubjectMissingProducesHighestPriorityDangerIssue() {
        let issues = CoachingEngine().issues(for: measurements(personBox: nil))

        XCTAssertEqual(issues.first?.type, "subject_missing")
        XCTAssertEqual(issues.first?.recipient, "Photographer")
        XCTAssertEqual(issues.first?.instruction, "Frame the person")
        XCTAssertEqual(issues.first?.tone, .danger)
    }

    func testSubjectTooCloseIncludesReasonData() {
        let box = DetectionBox(
            rect: CGRect(x: 0.08, y: 0.08, width: 0.78, height: 0.82),
            confidence: 0.9,
            label: "person"
        )

        let issues = CoachingEngine().issues(for: measurements(personBox: box, faceBox: nil))
        let tooClose = issues.first { $0.type == "subject_too_close" }

        XCTAssertEqual(tooClose?.instruction, "Step back")
        XCTAssertGreaterThan(tooClose?.reasonData["person_area"] ?? 0, 0.48)
    }

    func testHorizonTiltUsesHorizonConfidence() {
        let box = DetectionBox(
            rect: CGRect(x: 0.3, y: 0.12, width: 0.32, height: 0.62),
            confidence: 0.86,
            label: "person"
        )

        let issues = CoachingEngine().issues(
            for: measurements(
                personBox: box,
                faceBox: DetectionBox(rect: CGRect(x: 0.4, y: 0.18, width: 0.12, height: 0.14), confidence: 0.8, label: "face"),
                horizonAngleDegrees: 5,
                horizonConfidence: 0.76
            )
        )

        let horizonIssue = issues.first { $0.type == "horizon_tilted" }
        XCTAssertEqual(horizonIssue?.instruction, "Tilt left")
        XCTAssertEqual(horizonIssue?.reasonData["horizon_angle_degrees"], 5)
    }

    func testBacklitFaceProducesSubjectLightingAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                faceLuminance: 45,
                backgroundLuminance: 150
            )
        )

        let backlit = issues.first { $0.type == "subject_backlit" }
        XCTAssertEqual(backlit?.recipient, "Subject")
        XCTAssertEqual(backlit?.instruction, "Face the light")
    }

    func testCameraUnstableDelaysReadyAdvice() {
        let engine = CoachingEngine()
        let now = Date()
        let unstableIssues = engine.issues(for: measurements(cameraMotion: 0.7, cameraStable: false))

        let firstAdvice = engine.selectAdvice(from: unstableIssues, now: now)
        let settlingAdvice = engine.selectAdvice(from: [], now: now.addingTimeInterval(0.7))
        let stableAdvice = engine.selectAdvice(from: [], now: now.addingTimeInterval(1.4))

        XCTAssertEqual(firstAdvice.instruction, "Hold steady")
        XCTAssertEqual(settlingAdvice.type, "waiting")
        XCTAssertEqual(stableAdvice.type, "ready")
    }

    func testHandNearFaceProducesSubjectPoseAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                poseAnalysis: PoseAnalysis(
                    confidence: 0.7,
                    visibleKeypointCount: 8,
                    shoulderLineAngleDegrees: 2,
                    shoulderHeightAsymmetry: 0.01,
                    torsoAngleDegrees: 0,
                    wristToFaceDistance: 0.01,
                    armVisibilityScore: 0.9,
                    stanceWidth: 0.2,
                    headToTorsoRatio: 0.28,
                    shouldersHighScore: 0.1,
                    bodySquarenessScore: 0.5,
                    bodyProfileScore: 0.5,
                    armsFlatAgainstBodyScore: 0.1,
                    minWristEdgeDistance: 0.3
                )
            )
        )

        let handIssue = issues.first { $0.type == "hand_near_face" }
        XCTAssertEqual(handIssue?.recipient, "Subject")
        XCTAssertEqual(handIssue?.instruction, "Move hand from face")
    }

    func testHiddenArmProducesSubjectPoseAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                poseAnalysis: PoseAnalysis(
                    confidence: 0.58,
                    visibleKeypointCount: 5,
                    shoulderLineAngleDegrees: nil,
                    shoulderHeightAsymmetry: nil,
                    torsoAngleDegrees: nil,
                    wristToFaceDistance: nil,
                    armVisibilityScore: 0.33,
                    stanceWidth: nil,
                    headToTorsoRatio: nil,
                    shouldersHighScore: nil,
                    bodySquarenessScore: nil,
                    bodyProfileScore: nil,
                    armsFlatAgainstBodyScore: nil,
                    minWristEdgeDistance: nil
                )
            )
        )

        let armIssue = issues.first { $0.type == "arm_hidden" }
        XCTAssertEqual(armIssue?.instruction, "Show both arms")
    }

    func testShouldersHighProducesRelaxShouldersAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                poseAnalysis: PoseAnalysis(
                    confidence: 0.64,
                    visibleKeypointCount: 8,
                    shoulderLineAngleDegrees: 0,
                    shoulderHeightAsymmetry: 0.01,
                    torsoAngleDegrees: 0,
                    wristToFaceDistance: nil,
                    armVisibilityScore: 0.9,
                    stanceWidth: nil,
                    headToTorsoRatio: 0.22,
                    shouldersHighScore: 0.8,
                    bodySquarenessScore: 0.5,
                    bodyProfileScore: 0.5,
                    armsFlatAgainstBodyScore: 0.1,
                    minWristEdgeDistance: 0.3
                )
            )
        )

        XCTAssertEqual(issues.first { $0.type == "shoulders_high" }?.instruction, "Relax shoulders")
    }

    func testFaceYawProducesFaceDirectionAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                faceAnalysis: FaceAnalysis(
                    confidence: 0.82,
                    landmarkPointCount: 28,
                    eyeVisibilityScore: 1,
                    yawEstimate: 0.55,
                    pitchEstimate: 0.3,
                    occlusionScore: 0.05
                )
            )
        )

        XCTAssertEqual(issues.first { $0.type == "face_too_profile" }?.instruction, "Turn face slightly left")
    }

    func testOccludedEyesProduceShowEyesAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                faceAnalysis: FaceAnalysis(
                    confidence: 0.76,
                    landmarkPointCount: 12,
                    eyeVisibilityScore: 0.5,
                    yawEstimate: 0.1,
                    pitchEstimate: 0.3,
                    occlusionScore: 0.54
                )
            )
        )

        XCTAssertEqual(issues.first { $0.type == "eyes_occluded" }?.instruction, "Show your eyes")
    }

    func testPosePackageChangesPoseAdviceVocabulary() {
        let pose = PoseAnalysis(
            confidence: 0.7,
            visibleKeypointCount: 8,
            shoulderLineAngleDegrees: 1,
            shoulderHeightAsymmetry: 0.01,
            torsoAngleDegrees: 0,
            wristToFaceDistance: nil,
            armVisibilityScore: 0.95,
            stanceWidth: 0.18,
            headToTorsoRatio: 0.3,
            shouldersHighScore: 0.1,
            bodySquarenessScore: 0.95,
            bodyProfileScore: 0.05,
            armsFlatAgainstBodyScore: 0.82,
            minWristEdgeDistance: 0.2
        )

        let feminineIssues = CoachingEngine().issues(
            for: measurements(poseAnalysis: pose),
            posePackage: .feminine
        )
        let masculineIssues = CoachingEngine().issues(
            for: measurements(poseAnalysis: pose),
            posePackage: .masculine
        )

        XCTAssertEqual(
            feminineIssues.first { $0.type == "arms_flat_against_body" }?.instruction,
            "Create space at the waist"
        )
        XCTAssertEqual(
            masculineIssues.first { $0.type == "body_too_square" }?.instruction,
            "Turn chin slightly, keep shoulders strong"
        )
    }

    func testGroupPortraitPackageProducesGroupAdvice() {
        let issues = CoachingEngine().issues(
            for: measurements(
                groupAnalysis: GroupAnalysis(
                    peopleCount: 4,
                    faceCount: 2,
                    groupBounds: CGRect(x: 0.02, y: 0.12, width: 0.92, height: 0.7),
                    faceVisibilityRatio: 0.5,
                    edgeCrowdingScore: 0.67,
                    spacingScore: 2.1
                )
            ),
            posePackage: .groupPortrait
        )

        XCTAssertEqual(issues.first { $0.type == "group_faces_missing" }?.instruction, "Make every face visible")
        XCTAssertEqual(issues.first { $0.type == "group_edge_crowded" }?.instruction, "Leave space at the edges")
    }

    private func measurements(
        personBox: DetectionBox? = DetectionBox(
            rect: CGRect(x: 0.32, y: 0.08, width: 0.3, height: 0.62),
            confidence: 0.88,
            label: "person"
        ),
        faceBox: DetectionBox? = DetectionBox(
            rect: CGRect(x: 0.41, y: 0.13, width: 0.1, height: 0.13),
            confidence: 0.82,
            label: "face"
        ),
        horizonAngleDegrees: Double? = nil,
        horizonConfidence: Double = 0,
        faceLuminance: Double? = 120,
        backgroundLuminance: Double? = 130,
        cameraMotion: Double = 0.02,
        cameraStable: Bool = true,
        groupAnalysis: GroupAnalysis? = nil,
        faceAnalysis: FaceAnalysis? = nil,
        poseAnalysis: PoseAnalysis? = nil
    ) -> Measurements {
        Measurements(
            personBox: personBox,
            faceBox: faceBox,
            groupAnalysis: groupAnalysis,
            faceAnalysis: faceAnalysis,
            poseKeypoints: [:],
            poseAnalysis: poseAnalysis,
            faceLuminance: faceLuminance,
            backgroundLuminance: backgroundLuminance,
            horizonAngleDegrees: horizonAngleDegrees,
            horizonY: horizonAngleDegrees == nil ? nil : 0.5,
            horizonConfidence: horizonConfidence,
            cameraRollDegrees: 0,
            cameraMotion: cameraMotion,
            cameraStable: cameraStable,
            skyOrOpenAreaRatio: 0.42,
            timestamp: Date()
        )
    }
}
