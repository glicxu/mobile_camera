import AVFoundation
import CoreImage
import CoreMotion
import SwiftUI
import Vision

@MainActor
final class CameraModel: NSObject, ObservableObject {
    @Published var advice = Advice(type: "waiting", recipient: "Camera", instruction: "Start camera", tone: .waiting)
    @Published var measurements = Measurements(
        personBox: nil,
        faceBox: nil,
        faceLuminance: nil,
        backgroundLuminance: nil,
        cameraRollDegrees: 0,
        cameraStable: true,
        timestamp: Date()
    )
    @Published var issues: [PhotoIssue] = []
    @Published var permissionDenied = false
    @Published var debugEnabled = false

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoQueue = DispatchQueue(label: "camera.video.queue")
    private let motionManager = CMMotionManager()
    private let coachingEngine = CoachingEngine()
    nonisolated(unsafe) private var lastAnalysis = Date.distantPast
    private var cameraPosition: AVCaptureDevice.Position = .back
    private var currentRollDegrees = 0.0

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    granted ? self?.configureAndStart() : (self?.permissionDenied = true)
                }
            }
        default:
            permissionDenied = true
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
        motionManager.stopDeviceMotionUpdates()
    }

    func switchCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
        configureAndStart()
    }

    private func configureAndStart() {
        startMotion()
        sessionQueue.async { [weak self] in
            guard let self else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.cameraPosition),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else {
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.setSampleBufferDelegate(self, queue: self.videoQueue)

            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
            }

            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }

            self.session.commitConfiguration()

            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.12
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.currentRollDegrees = motion.attitude.roll * 180 / .pi
        }
    }

    private nonisolated func normalizedTopLeftRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
    }

    private nonisolated func estimatePersonFromFace(_ face: DetectionBox) -> DetectionBox {
        let faceRect = face.rect
        let width = min(0.9, faceRect.width * 3.0)
        let height = min(0.95, faceRect.height * 6.2)
        let x = max(0, min(1 - width, faceRect.midX - width / 2))
        let y = max(0, min(1 - height, faceRect.minY - faceRect.height * 0.45))
        return DetectionBox(rect: CGRect(x: x, y: y, width: width, height: height), confidence: face.confidence * 0.72, label: "person_estimated")
    }

    private nonisolated func luminance(in pixelBuffer: CVPixelBuffer, normalizedRect: CGRect?) -> Double? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let rect = normalizedRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)

        let minX = max(0, min(width - 1, Int(rect.minX * CGFloat(width))))
        let maxX = max(minX + 1, min(width, Int(rect.maxX * CGFloat(width))))
        let minY = max(0, min(height - 1, Int(rect.minY * CGFloat(height))))
        let maxY = max(minY + 1, min(height, Int(rect.maxY * CGFloat(height))))

        var total = 0.0
        var count = 0
        let step = max(1, min(width, height) / 80)

        for y in stride(from: minY, to: maxY, by: step) {
            let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in stride(from: minX, to: maxX, by: step) {
                let offset = x * 4
                let b = Double(row[offset])
                let g = Double(row[offset + 1])
                let r = Double(row[offset + 2])
                total += 0.2126 * r + 0.7152 * g + 0.0722 * b
                count += 1
            }
        }

        return count > 0 ? total / Double(count) : nil
    }
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastAnalysis) > 0.22 else { return }
        lastAnalysis = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let humanRequest = VNDetectHumanRectanglesRequest()
        humanRequest.upperBodyOnly = false
        let faceRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])

        do {
            try handler.perform([humanRequest, faceRequest])
        } catch {
            return
        }

        let human = (humanRequest.results ?? [])
            .max { $0.confidence < $1.confidence }
            .map {
                DetectionBox(
                    rect: normalizedTopLeftRect($0.boundingBox),
                    confidence: CGFloat($0.confidence),
                    label: "person"
                )
            }

        let face = (faceRequest.results ?? [])
            .max { $0.confidence < $1.confidence }
            .map {
                DetectionBox(
                    rect: normalizedTopLeftRect($0.boundingBox),
                    confidence: CGFloat($0.confidence),
                    label: "face"
                )
            }

        let person = human ?? face.map { estimatePersonFromFace($0) }
        let faceLuminance = face.flatMap { luminance(in: pixelBuffer, normalizedRect: $0.rect) }
        let backgroundLuminance = luminance(in: pixelBuffer, normalizedRect: nil)

        Task { @MainActor [weak self] in
            guard let self else { return }
            let nextMeasurements = Measurements(
                personBox: person,
                faceBox: face,
                faceLuminance: faceLuminance,
                backgroundLuminance: backgroundLuminance,
                cameraRollDegrees: self.currentRollDegrees,
                cameraStable: abs(self.currentRollDegrees) < 4,
                timestamp: now
            )
            let nextIssues = self.coachingEngine.issues(for: nextMeasurements)
            self.measurements = nextMeasurements
            self.issues = nextIssues
            self.advice = self.coachingEngine.selectAdvice(from: nextIssues, now: now)
        }
    }
}
