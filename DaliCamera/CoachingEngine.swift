import Foundation

final class CoachingEngine {
    private let thresholds = Thresholds()
    private let poseTipLibrary = PoseTipLibrary()
    private var stableIssueKey: String?
    private var stableSince = Date()
    private var lastAdvice: Advice?
    private var lastAdviceAt = Date.distantPast

    func issues(
        for measurements: Measurements,
        includePosture: Bool = true,
        posePackage: PosePackageID = .neutral
    ) -> [PhotoIssue] {
        guard let box = measurements.personBox else {
            return [
                PhotoIssue(
                    type: "subject_missing",
                    severity: 100,
                    confidence: 0.92,
                    priority: 92,
                    recipient: "Photographer",
                    instruction: "Frame the person",
                    successCondition: "person_box confidence above 0.45",
                    cooldownMilliseconds: Int(thresholds.repeatCooldownSeconds * 1000),
                    reasonData: [:],
                    tone: .danger
                )
            ]
        }

        let rect = box.rect
        let area = rect.width * rect.height
        var issues: [PhotoIssue] = []

        if measurements.faceBox == nil, area > thresholds.tooFarArea {
            issues.append(makeIssue(
                "face_missing",
                84,
                max(0.52, Double(box.confidence) * 0.82),
                "Subject",
                "Face the camera",
                .warning,
                reasonData: ["person_area": Double(area)]
            ))
        }

        if area > thresholds.tooCloseArea {
            issues.append(makeIssue("subject_too_close", 82, box.confidence, "Photographer", "Step back", .warning, reasonData: ["person_area": Double(area)]))
        }

        if area < thresholds.tooFarArea {
            issues.append(makeIssue("subject_too_far", 76, box.confidence, "Photographer", "Step closer", .warning, reasonData: ["person_area": Double(area)]))
        }

        if rect.minY > thresholds.tooMuchHeadroom, area > thresholds.tooFarArea {
            issues.append(makeIssue("headroom_too_large", 62, box.confidence, "Photographer", "Raise camera", .warning, reasonData: ["headroom": Double(rect.minY)]))
        }

        if rect.minY < thresholds.tooLittleHeadroom {
            issues.append(makeIssue("headroom_too_small", 70, box.confidence, "Photographer", "Lower camera", .warning, reasonData: ["headroom": Double(rect.minY)]))
        }

        if rect.maxY > 1 - thresholds.edgePadding, area < thresholds.tooCloseArea {
            issues.append(makeIssue("feet_cropped", 88, box.confidence, "Photographer", "Keep feet in frame", .danger, reasonData: ["bottom_edge": Double(1 - rect.maxY)]))
        }

        if rect.minX < thresholds.edgePadding {
            issues.append(makeIssue("limb_cropped", 72, box.confidence, "Photographer", "Move right", .warning, reasonData: ["left_edge": Double(rect.minX)]))
        }

        if rect.maxX > 1 - thresholds.edgePadding {
            issues.append(makeIssue("limb_cropped", 72, box.confidence, "Photographer", "Move left", .warning, reasonData: ["right_edge": Double(1 - rect.maxX)]))
        }

        if abs(measurements.cameraRollDegrees) > thresholds.rollDegrees {
            let instruction = measurements.cameraRollDegrees > 0 ? "Tilt left" : "Tilt right"
            issues.append(makeIssue("camera_tilted", 64, 0.7, "Photographer", instruction, .warning, reasonData: ["roll_degrees": measurements.cameraRollDegrees]))
        }

        if let horizonAngle = measurements.horizonAngleDegrees,
           measurements.horizonConfidence > 0.55,
           abs(horizonAngle) > thresholds.horizonDegrees {
            let instruction = horizonAngle > 0 ? "Tilt left" : "Tilt right"
            issues.append(makeIssue(
                "horizon_tilted",
                68,
                measurements.horizonConfidence,
                "Photographer",
                instruction,
                .warning,
                reasonData: ["horizon_angle_degrees": horizonAngle]
            ))
        }

        if let face = measurements.faceLuminance,
           let background = measurements.backgroundLuminance,
           face < thresholds.darkFace,
           background - face > thresholds.backlitDelta {
            issues.append(makeIssue("subject_backlit", 58, 0.7, "Subject", "Face the light", .warning, reasonData: ["face_luminance": face, "background_luminance": background]))
        }

        if let face = measurements.faceLuminance,
           face < thresholds.darkFace,
           measurements.backgroundLuminance.map({ $0 - face <= thresholds.backlitDelta }) ?? true {
            issues.append(makeIssue("face_underexposed", 54, 0.62, "Photographer", "Find brighter light", .warning, reasonData: ["face_luminance": face]))
        }

        if includePosture,
           posePackage == .groupPortrait,
           let group = measurements.groupAnalysis {
            issues.append(contentsOf: groupPortraitIssues(for: group, posePackage: posePackage))
        }

        if includePosture,
           let pose = measurements.poseAnalysis,
           pose.confidence > thresholds.poseMinimumConfidence {
            issues.append(contentsOf: postureIssues(for: pose, face: measurements.faceBox, person: box, posePackage: posePackage))
        }

        if includePosture,
           let faceAnalysis = measurements.faceAnalysis,
           faceAnalysis.confidence > thresholds.faceMinimumConfidence {
            issues.append(contentsOf: facePostureIssues(for: faceAnalysis, posePackage: posePackage))
        }

        if area > 0.33, rect.height > 0.72, measurements.skyOrOpenAreaRatio < 0.28 {
            issues.append(makeIssue("scene_excluded", 50, box.confidence, "Photographer", "Include more view", .warning, reasonData: ["person_area": Double(area), "open_area_ratio": measurements.skyOrOpenAreaRatio]))
        }

        if !measurements.cameraStable {
            issues.append(makeIssue("camera_unstable", 46, 0.8, "Photographer", "Hold steady", .waiting, reasonData: ["camera_motion": measurements.cameraMotion]))
        }

        return issues.sorted {
            if $0.priority == $1.priority {
                return $0.severity > $1.severity
            }
            return $0.priority > $1.priority
        }
    }

    func selectAdvice(from issues: [PhotoIssue], now: Date = Date()) -> Advice {
        let topIssue = issues.first { $0.confidence > 0.45 }
        let key = topIssue?.type ?? "ready"

        if stableIssueKey != key {
            stableIssueKey = key
            stableSince = now
        }

        let stableFor = now.timeIntervalSince(stableSince)
        let oldEnough = now.timeIntervalSince(lastAdviceAt) > thresholds.minimumAdviceSeconds
        let repeatedTooSoon = lastAdvice?.type == key && now.timeIntervalSince(lastAdviceAt) < thresholds.repeatCooldownSeconds

        if stableFor < (topIssue == nil ? thresholds.readyStableSeconds : thresholds.issueStableSeconds) {
            return lastAdvice ?? Advice(type: "waiting", recipient: "Camera", instruction: "Hold steady", tone: .waiting)
        }

        guard let topIssue else {
            let ready = Advice(type: "ready", recipient: "Camera", instruction: "Great shot", tone: .ready)
            if oldEnough || lastAdvice?.type != "ready" {
                commit(ready, now: now)
            }
            return ready
        }

        if repeatedTooSoon, let lastAdvice {
            return lastAdvice
        }

        if !oldEnough, let lastAdvice {
            return lastAdvice
        }

        let advice = Advice(
            type: topIssue.type,
            recipient: topIssue.recipient,
            instruction: topIssue.instruction,
            tone: topIssue.tone
        )
        commit(advice, now: now)
        return advice
    }

    private func makeIssue(
        _ type: String,
        _ severity: Double,
        _ confidence: CGFloat,
        _ recipient: String,
        _ instruction: String,
        _ tone: AdviceTone,
        reasonData: [String: Double] = [:]
    ) -> PhotoIssue {
        makeIssue(type, severity, Double(confidence), recipient, instruction, tone, reasonData: reasonData)
    }

    private func makeIssue(
        _ type: String,
        _ severity: Double,
        _ confidence: Double,
        _ recipient: String,
        _ instruction: String,
        _ tone: AdviceTone,
        reasonData: [String: Double] = [:]
    ) -> PhotoIssue {
        PhotoIssue(
            type: type,
            severity: severity,
            confidence: confidence,
            priority: severity * confidence,
            recipient: recipient,
            instruction: instruction,
            successCondition: "\(type) clears for \(thresholds.issueStableSeconds)s",
            cooldownMilliseconds: Int(thresholds.repeatCooldownSeconds * 1000),
            reasonData: reasonData,
            tone: tone
        )
    }

    private func commit(_ advice: Advice, now: Date) {
        lastAdvice = advice
        lastAdviceAt = now
    }

    private func postureIssues(for pose: PoseAnalysis, face: DetectionBox?, person: DetectionBox, posePackage: PosePackageID) -> [PhotoIssue] {
        var issues: [PhotoIssue] = []

        if let wristToFaceDistance = pose.wristToFaceDistance,
           wristToFaceDistance < thresholds.handNearFaceDistance {
            issues.append(makePoseIssue(
                "hand_near_face",
                80,
                min(0.92, pose.confidence + 0.12),
                "Subject",
                "Move hand from face",
                .warning,
                posePackage: posePackage,
                reasonData: ["wrist_to_face_distance": wristToFaceDistance]
            ))
        }

        if pose.visibleKeypointCount >= 4,
           pose.armVisibilityScore < thresholds.armVisibility {
            issues.append(makePoseIssue(
                "arm_hidden",
                66,
                max(0.48, pose.confidence),
                "Subject",
                "Show both arms",
                .warning,
                posePackage: posePackage,
                reasonData: ["arm_visibility_score": pose.armVisibilityScore]
            ))
        }

        if let squareness = pose.bodySquarenessScore,
           squareness > thresholds.bodySquareness,
           person.rect.width > 0.16 {
            issues.append(makePoseIssue(
                "body_too_square",
                44,
                pose.confidence,
                "Subject",
                "Turn slightly left",
                .waiting,
                posePackage: posePackage,
                reasonData: ["body_squareness_score": squareness]
            ))
        }

        if let profile = pose.bodyProfileScore,
           profile > thresholds.bodyProfile,
           person.rect.width > 0.08 {
            issues.append(makePoseIssue(
                "body_too_profile",
                42,
                pose.confidence,
                "Subject",
                "Angle body toward camera",
                .waiting,
                posePackage: posePackage,
                reasonData: ["body_profile_score": profile]
            ))
        }

        if let armsFlat = pose.armsFlatAgainstBodyScore,
           armsFlat > thresholds.armsFlatAgainstBody,
           pose.armVisibilityScore > 0.65 {
            issues.append(makePoseIssue(
                "arms_flat_against_body",
                48,
                pose.confidence,
                "Subject",
                "Separate arm from body",
                .waiting,
                posePackage: posePackage,
                reasonData: ["arms_flat_against_body_score": armsFlat]
            ))
        }

        if let wristEdge = pose.minWristEdgeDistance,
           wristEdge < thresholds.handCutOffEdgeDistance {
            issues.append(makePoseIssue(
                "hand_cut_off",
                60,
                pose.confidence,
                "Photographer",
                "Keep hands in frame",
                .warning,
                posePackage: posePackage,
                reasonData: ["wrist_edge_distance": wristEdge]
            ))
        }

        if let shouldersHigh = pose.shouldersHighScore,
           shouldersHigh > thresholds.shouldersHigh {
            issues.append(makePoseIssue(
                "shoulders_high",
                52,
                pose.confidence,
                "Subject",
                "Relax shoulders",
                .waiting,
                posePackage: posePackage,
                reasonData: ["shoulders_high_score": shouldersHigh]
            ))
        }

        return issues
    }

    private func facePostureIssues(for face: FaceAnalysis, posePackage: PosePackageID) -> [PhotoIssue] {
        var issues: [PhotoIssue] = []

        if face.occlusionScore > thresholds.faceOcclusion {
            issues.append(makePoseIssue(
                "face_occluded",
                78,
                face.confidence,
                "Subject",
                "Clear the face",
                .warning,
                posePackage: posePackage,
                reasonData: ["face_occlusion_score": face.occlusionScore]
            ))
        }

        if face.eyeVisibilityScore < thresholds.eyeVisibility {
            issues.append(makePoseIssue(
                "eyes_occluded",
                74,
                face.confidence,
                "Subject",
                "Show your eyes",
                .warning,
                posePackage: posePackage,
                reasonData: ["eye_visibility_score": face.eyeVisibilityScore]
            ))
        }

        if let yaw = face.yawEstimate,
           abs(yaw) > thresholds.faceProfileYaw {
            let instruction = yaw > 0 ? "Turn face slightly left" : "Turn face slightly right"
            issues.append(makePoseIssue(
                "face_too_profile",
                70,
                face.confidence,
                "Subject",
                instruction,
                .warning,
                posePackage: posePackage,
                reasonData: ["face_yaw_estimate": yaw]
            ))
        } else if let yaw = face.yawEstimate,
                  abs(yaw) > thresholds.faceTurnedYaw {
            let instruction = yaw > 0 ? "Turn face slightly left" : "Turn face slightly right"
            issues.append(makePoseIssue(
                "face_turned_away",
                58,
                face.confidence,
                "Subject",
                instruction,
                .warning,
                posePackage: posePackage,
                reasonData: ["face_yaw_estimate": yaw]
            ))
        }

        if let pitch = face.pitchEstimate,
           pitch < thresholds.chinHighPitch {
            issues.append(makePoseIssue(
                "chin_too_high",
                42,
                face.confidence,
                "Subject",
                "Lower chin slightly",
                .waiting,
                posePackage: posePackage,
                reasonData: ["face_pitch_estimate": pitch]
            ))
        }

        if let pitch = face.pitchEstimate,
           pitch > thresholds.chinLowPitch {
            issues.append(makePoseIssue(
                "chin_too_low",
                42,
                face.confidence,
                "Subject",
                "Lift chin slightly",
                .waiting,
                posePackage: posePackage,
                reasonData: ["face_pitch_estimate": pitch]
            ))
        }

        return issues
    }

    private func groupPortraitIssues(for group: GroupAnalysis, posePackage: PosePackageID) -> [PhotoIssue] {
        var issues: [PhotoIssue] = []

        if group.faceVisibilityRatio < 0.8 {
            issues.append(makePoseIssue(
                "group_faces_missing",
                86,
                0.74,
                "Photographer",
                "Make every face visible",
                .warning,
                posePackage: posePackage,
                reasonData: [
                    "people_count": Double(group.peopleCount),
                    "face_count": Double(group.faceCount),
                    "face_visibility_ratio": group.faceVisibilityRatio
                ]
            ))
        }

        if group.edgeCrowdingScore > 0.45 {
            issues.append(makePoseIssue(
                "group_edge_crowded",
                72,
                0.68,
                "Photographer",
                "Leave space at the edges",
                .warning,
                posePackage: posePackage,
                reasonData: ["edge_crowding_score": group.edgeCrowdingScore]
            ))
        }

        if let spacing = group.spacingScore,
           spacing > 1.75 {
            issues.append(makePoseIssue(
                "group_spacing_wide",
                64,
                0.62,
                "Photographer",
                "Bring everyone closer together",
                .waiting,
                posePackage: posePackage,
                reasonData: ["spacing_score": spacing]
            ))
        }

        return issues
    }

    private func makePoseIssue(
        _ type: String,
        _ severity: Double,
        _ confidence: Double,
        _ recipient: String,
        _ instruction: String,
        _ tone: AdviceTone,
        posePackage: PosePackageID,
        reasonData: [String: Double] = [:]
    ) -> PhotoIssue {
        let base = makeIssue(type, severity, confidence, recipient, instruction, tone, reasonData: reasonData)
        guard let tip = poseTipLibrary.tip(for: type, package: posePackage) else {
            return base
        }

        return PhotoIssue(
            type: base.type,
            severity: max(0, base.severity + tip.priorityAdjustment),
            confidence: base.confidence,
            priority: max(0, base.severity + tip.priorityAdjustment) * base.confidence,
            recipient: tip.recipient,
            instruction: tip.instruction,
            successCondition: tip.successCondition,
            cooldownMilliseconds: base.cooldownMilliseconds,
            reasonData: base.reasonData.merging(["pose_package": Double(posePackageIndex(posePackage))]) { current, _ in current },
            tone: base.tone
        )
    }

    private func posePackageIndex(_ package: PosePackageID) -> Int {
        PosePackageID.allCases.firstIndex(of: package) ?? 0
    }
}

private struct PoseTipLibrary {
    private let packages: [PosePackageID: PosePackage]

    init() {
        packages = Dictionary(uniqueKeysWithValues: PosePackageID.allCases.map { package in
            (package, PosePackage(id: package, title: package.title, tipOverrides: Self.tips(for: package)))
        })
    }

    func tip(for issueType: String, package: PosePackageID) -> PoseTip? {
        packages[package]?.tipOverrides[issueType]
    }

    private static func tips(for package: PosePackageID) -> [String: PoseTip] {
        switch package {
        case .neutral:
            return packageTips([
                tip("hand_near_face", "Subject", "Move hand from face"),
                tip("arm_hidden", "Subject", "Show both arms"),
                tip("body_too_square", "Subject", "Turn slightly"),
                tip("body_too_profile", "Subject", "Angle body toward camera"),
                tip("arms_flat_against_body", "Subject", "Separate arm from body"),
                tip("hand_cut_off", "Photographer", "Keep hands in frame"),
                tip("shoulders_high", "Subject", "Relax shoulders"),
                tip("face_occluded", "Subject", "Clear the face"),
                tip("eyes_occluded", "Subject", "Show your eyes"),
                tip("face_too_profile", "Subject", "Turn face slightly"),
                tip("face_turned_away", "Subject", "Look toward camera"),
                tip("chin_too_high", "Subject", "Lower chin slightly"),
                tip("chin_too_low", "Subject", "Lift chin slightly")
            ])
        case .feminine:
            return packageTips([
                tip("hand_near_face", "Subject", "Move hand lightly away from face"),
                tip("arm_hidden", "Subject", "Show both arms softly"),
                tip("body_too_square", "Subject", "Angle one shoulder away"),
                tip("body_too_profile", "Subject", "Turn torso slightly toward camera"),
                tip("arms_flat_against_body", "Subject", "Create space at the waist"),
                tip("hand_cut_off", "Photographer", "Keep hands in frame"),
                tip("shoulders_high", "Subject", "Drop shoulders softly"),
                tip("face_occluded", "Subject", "Clear the face"),
                tip("eyes_occluded", "Subject", "Show your eyes"),
                tip("face_too_profile", "Subject", "Turn face softly toward camera"),
                tip("face_turned_away", "Subject", "Bring face back toward camera"),
                tip("chin_too_high", "Subject", "Lower chin slightly"),
                tip("chin_too_low", "Subject", "Lift chin slightly")
            ])
        case .masculine:
            return packageTips([
                tip("hand_near_face", "Subject", "Move hand away from face"),
                tip("arm_hidden", "Subject", "Bring both arms into view"),
                tip("body_too_square", "Subject", "Turn chin slightly, keep shoulders strong"),
                tip("body_too_profile", "Subject", "Open shoulders toward camera"),
                tip("arms_flat_against_body", "Subject", "Relax arms away from torso"),
                tip("hand_cut_off", "Photographer", "Keep hands in frame"),
                tip("shoulders_high", "Subject", "Set shoulders down"),
                tip("face_occluded", "Subject", "Clear the face"),
                tip("eyes_occluded", "Subject", "Show your eyes"),
                tip("face_too_profile", "Subject", "Turn face toward camera"),
                tip("face_turned_away", "Subject", "Look toward camera"),
                tip("chin_too_high", "Subject", "Lower chin slightly"),
                tip("chin_too_low", "Subject", "Lift chin slightly")
            ])
        case .professional:
            return packageTips([
                tip("hand_near_face", "Subject", "Move hand away from face"),
                tip("arm_hidden", "Subject", "Keep both arms visible"),
                tip("body_too_square", "Subject", "Angle shoulders slightly"),
                tip("body_too_profile", "Subject", "Turn shoulders toward camera"),
                tip("arms_flat_against_body", "Subject", "Leave space beside the torso"),
                tip("hand_cut_off", "Photographer", "Keep hands in frame"),
                tip("shoulders_high", "Subject", "Relax shoulders"),
                tip("face_occluded", "Subject", "Clear the face"),
                tip("eyes_occluded", "Subject", "Show your eyes"),
                tip("face_too_profile", "Subject", "Turn face toward camera"),
                tip("face_turned_away", "Subject", "Look toward camera"),
                tip("chin_too_high", "Subject", "Lower chin slightly"),
                tip("chin_too_low", "Subject", "Lift chin slightly")
            ])
        case .groupPortrait:
            return packageTips([
                tip("group_faces_missing", "Photographer", "Make every face visible"),
                tip("group_edge_crowded", "Photographer", "Leave space at the edges"),
                tip("group_spacing_wide", "Photographer", "Bring everyone closer together"),
                tip("hand_near_face", "Subject", "Move hands away from faces"),
                tip("arm_hidden", "Photographer", "Make sure everyone is visible"),
                tip("body_too_square", "Photographer", "Angle the group slightly"),
                tip("body_too_profile", "Subject", "Face the camera"),
                tip("arms_flat_against_body", "Subject", "Relax arms naturally"),
                tip("hand_cut_off", "Photographer", "Keep all hands in frame"),
                tip("shoulders_high", "Subject", "Relax shoulders"),
                tip("face_occluded", "Photographer", "Clear blocked faces"),
                tip("eyes_occluded", "Photographer", "Make sure eyes are visible"),
                tip("face_too_profile", "Subject", "Turn faces toward camera"),
                tip("face_turned_away", "Subject", "Look toward camera"),
                tip("chin_too_high", "Subject", "Lower chin slightly"),
                tip("chin_too_low", "Subject", "Lift chin slightly")
            ])
        }
    }

    private static func packageTips(_ tips: [(String, PoseTip)]) -> [String: PoseTip] {
        Dictionary(uniqueKeysWithValues: tips)
    }

    private static func tip(
        _ issueType: String,
        _ recipient: String,
        _ instruction: String,
        priorityAdjustment: Double = 0
    ) -> (String, PoseTip) {
        (
            issueType,
            PoseTip(
                issueType: issueType,
                recipient: recipient,
                instruction: instruction,
                successCondition: "\(issueType) clears for pose package",
                priorityAdjustment: priorityAdjustment
            )
        )
    }
}

private struct Thresholds {
    let issueStableSeconds = 0.65
    let readyStableSeconds = 0.45
    let minimumAdviceSeconds = 1.5
    let repeatCooldownSeconds = 2.8
    let tooCloseArea: CGFloat = 0.48
    let tooFarArea: CGFloat = 0.055
    let tooMuchHeadroom: CGFloat = 0.16
    let tooLittleHeadroom: CGFloat = 0.025
    let edgePadding: CGFloat = 0.025
    let rollDegrees = 4.0
    let horizonDegrees = 3.0
    let darkFace = 70.0
    let backlitDelta = 55.0
    let poseMinimumConfidence = 0.24
    let faceMinimumConfidence = 0.45
    let handNearFaceDistance = 0.04
    let handCutOffEdgeDistance = 0.025
    let armVisibility = 0.55
    let bodySquareness = 0.82
    let bodyProfile = 0.58
    let armsFlatAgainstBody = 0.62
    let shouldersHigh = 0.62
    let faceTurnedYaw = 0.28
    let faceProfileYaw = 0.48
    let chinHighPitch = 0.16
    let chinLowPitch = 0.46
    let eyeVisibility = 0.75
    let faceOcclusion = 0.38
}
