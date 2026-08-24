import CoreGraphics
import Foundation

@MainActor
final class SessionLogger {
    let sessionID = UUID().uuidString

    private let encoder = JSONEncoder()
    private var lastAdviceType: String?
    private var lastInstructionStartedAt: Date?
    private var eventIndex = 0
    private lazy var logURL: URL? = makeLogURL()

    init() {
        encoder.dateEncodingStrategy = .iso8601
    }

    func recordAdvice(_ advice: Advice, measurements: Measurements, issues: [PhotoIssue]) {
        guard advice.type != lastAdviceType else { return }

        let now = measurements.timestamp
        let previousDuration = lastInstructionStartedAt.map { now.timeIntervalSince($0) }
        lastAdviceType = advice.type
        lastInstructionStartedAt = now

        append(
            SessionLogEvent(
                sessionID: sessionID,
                index: nextIndex(),
                timestamp: now,
                event: "advice_changed",
                selectedInstruction: advice.instruction,
                selectedAdviceType: advice.type,
                selectedRecipient: advice.recipient,
                previousInstructionDurationSeconds: previousDuration,
                readinessScore: readinessScore(for: issues),
                measurementConfidences: confidenceSummary(for: measurements),
                detectedIssues: issues.map(SessionLogIssue.init),
                captureStatus: nil
            )
        )
    }

    func recordCapture(status: String, measurements: Measurements, issues: [PhotoIssue], advice: Advice) {
        append(
            SessionLogEvent(
                sessionID: sessionID,
                index: nextIndex(),
                timestamp: Date(),
                event: "capture",
                selectedInstruction: advice.instruction,
                selectedAdviceType: advice.type,
                selectedRecipient: advice.recipient,
                previousInstructionDurationSeconds: lastInstructionStartedAt.map { Date().timeIntervalSince($0) },
                readinessScore: readinessScore(for: issues),
                measurementConfidences: confidenceSummary(for: measurements),
                detectedIssues: issues.map(SessionLogIssue.init),
                captureStatus: status
            )
        )
    }

    func exportURL() -> URL? {
        guard let logURL else { return nil }

        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        return logURL
    }

    private func nextIndex() -> Int {
        eventIndex += 1
        return eventIndex
    }

    private func append(_ event: SessionLogEvent) {
        guard let logURL, let data = try? encoder.encode(event) else { return }

        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        guard let line = String(data: data, encoding: .utf8)?.appending("\n"),
              let lineData = line.data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: logURL) else {
            return
        }

        handle.seekToEndOfFile()
        handle.write(lineData)
        try? handle.close()
    }

    private func makeLogURL() -> URL? {
        guard let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let logsURL = supportURL.appendingPathComponent("DaliCameraLogs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsURL, withIntermediateDirectories: true)
        return logsURL.appendingPathComponent("\(sessionID).jsonl")
    }

    private func readinessScore(for issues: [PhotoIssue]) -> Double {
        let topPriority = issues.map(\.priority).max() ?? 0
        return max(0, min(100, 100 - topPriority))
    }

    private func confidenceSummary(for measurements: Measurements) -> [String: Double] {
        [
            "person": measurements.personBox.map { Double($0.confidence) } ?? 0,
            "face": measurements.faceBox.map { Double($0.confidence) } ?? 0,
            "pose_keypoints": Double(measurements.poseKeypoints.count),
            "horizon": measurements.horizonConfidence,
            "camera_stable": measurements.cameraStable ? 1 : 0
        ]
    }
}

private struct SessionLogEvent: Encodable {
    let sessionID: String
    let index: Int
    let timestamp: Date
    let event: String
    let selectedInstruction: String
    let selectedAdviceType: String
    let selectedRecipient: String
    let previousInstructionDurationSeconds: Double?
    let readinessScore: Double
    let measurementConfidences: [String: Double]
    let detectedIssues: [SessionLogIssue]
    let captureStatus: String?
}

private struct SessionLogIssue: Encodable {
    let type: String
    let severity: Double
    let confidence: Double
    let priority: Double
    let recipient: String
    let instruction: String
    let successCondition: String
    let cooldownMilliseconds: Int
    let reasonData: [String: Double]

    init(issue: PhotoIssue) {
        type = issue.type
        severity = issue.severity
        confidence = issue.confidence
        priority = issue.priority
        recipient = issue.recipient
        instruction = issue.instruction
        successCondition = issue.successCondition
        cooldownMilliseconds = issue.cooldownMilliseconds
        reasonData = issue.reasonData
    }
}
