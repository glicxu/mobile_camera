import Foundation

final class CoachingEngine {
    private let thresholds = Thresholds()
    private var stableIssueKey: String?
    private var stableSince = Date()
    private var lastAdvice: Advice?
    private var lastAdviceAt = Date.distantPast

    func issues(for measurements: Measurements) -> [PhotoIssue] {
        guard let box = measurements.personBox else {
            return [
                PhotoIssue(
                    type: "subject_missing",
                    severity: 100,
                    confidence: 0.92,
                    recipient: "Photographer",
                    instruction: "Frame the person",
                    tone: .danger
                )
            ]
        }

        let rect = box.rect
        let area = rect.width * rect.height
        var issues: [PhotoIssue] = []

        if area > thresholds.tooCloseArea {
            issues.append(makeIssue("subject_too_close", 82, box.confidence, "Photographer", "Step back", .warning))
        }

        if area < thresholds.tooFarArea {
            issues.append(makeIssue("subject_too_far", 76, box.confidence, "Photographer", "Step closer", .warning))
        }

        if rect.minY > thresholds.tooMuchHeadroom, area > thresholds.tooFarArea {
            issues.append(makeIssue("headroom_too_large", 62, box.confidence, "Photographer", "Raise camera", .warning))
        }

        if rect.minY < thresholds.tooLittleHeadroom {
            issues.append(makeIssue("headroom_too_small", 70, box.confidence, "Photographer", "Lower camera", .warning))
        }

        if rect.maxY > 1 - thresholds.edgePadding, area < thresholds.tooCloseArea {
            issues.append(makeIssue("feet_cropped", 88, box.confidence, "Photographer", "Keep feet in frame", .danger))
        }

        if rect.minX < thresholds.edgePadding {
            issues.append(makeIssue("left_edge_cropped", 72, box.confidence, "Photographer", "Move right", .warning))
        }

        if rect.maxX > 1 - thresholds.edgePadding {
            issues.append(makeIssue("right_edge_cropped", 72, box.confidence, "Photographer", "Move left", .warning))
        }

        if abs(measurements.cameraRollDegrees) > thresholds.rollDegrees {
            let instruction = measurements.cameraRollDegrees > 0 ? "Tilt left" : "Tilt right"
            issues.append(makeIssue("camera_tilted", 64, 0.7, "Photographer", instruction, .warning))
        }

        if let face = measurements.faceLuminance,
           let background = measurements.backgroundLuminance,
           face < thresholds.darkFace,
           background - face > thresholds.backlitDelta {
            issues.append(makeIssue("subject_backlit", 58, 0.7, "Subject", "Face the light", .warning))
        }

        if area > 0.33, rect.height > 0.72 {
            issues.append(makeIssue("scene_excluded", 50, box.confidence, "Photographer", "Include more view", .warning))
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
        _ tone: AdviceTone
    ) -> PhotoIssue {
        PhotoIssue(
            type: type,
            severity: severity,
            confidence: Double(confidence),
            recipient: recipient,
            instruction: instruction,
            tone: tone
        )
    }

    private func makeIssue(
        _ type: String,
        _ severity: Double,
        _ confidence: Double,
        _ recipient: String,
        _ instruction: String,
        _ tone: AdviceTone
    ) -> PhotoIssue {
        PhotoIssue(
            type: type,
            severity: severity,
            confidence: confidence,
            recipient: recipient,
            instruction: instruction,
            tone: tone
        )
    }

    private func commit(_ advice: Advice, now: Date) {
        lastAdvice = advice
        lastAdviceAt = now
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
    let darkFace = 70.0
    let backlitDelta = 55.0
}
