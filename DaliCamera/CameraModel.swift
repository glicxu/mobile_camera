@preconcurrency import AVFoundation
import CoreImage
import CoreMotion
import Photos
import SwiftUI
import UIKit
import Vision

@MainActor
final class CameraModel: NSObject, ObservableObject {
    @Published var advice = Advice(type: "waiting", recipient: "Camera", instruction: "Start camera", tone: .waiting)
    @Published var measurements = Measurements(
        personBox: nil,
        faceBox: nil,
        groupAnalysis: nil,
        faceAnalysis: nil,
        poseKeypoints: [:],
        poseAnalysis: nil,
        faceLuminance: nil,
        backgroundLuminance: nil,
        horizonAngleDegrees: nil,
        horizonY: nil,
        horizonConfidence: 0,
        cameraRollDegrees: 0,
        cameraMotion: 0,
        cameraStable: true,
        skyOrOpenAreaRatio: 0,
        timestamp: Date()
    )
    @Published var issues: [PhotoIssue] = []
    @Published var permissionDenied = false
    @Published private(set) var previewAspectRatio: CGFloat = 3.0 / 4.0
    @Published private(set) var isFrontCamera = false
    @Published private(set) var cameraReady = false
    private var videoRotation: CGFloat = 90
    nonisolated(unsafe) private var configuredCameraPosition: AVCaptureDevice.Position?

    func updatePreviewRotation(_ angle: CGFloat) {
        guard videoRotation != angle else { return }
        videoRotation = angle
        coachingEngine.reset()
        let session = session
        sessionQueue.async {
            for output in session.outputs {
                if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            }
        }
    }
    @Published var debugEnabled = false
    @Published var captureStatus: String?
    @Published var reviewImage: UIImage?
    @Published var reframedImage: UIImage?
    @Published var tiltedImage: UIImage?
    @Published var leveledImage: UIImage?
    @Published var beautifiedImage: UIImage?
    @Published var reframeSuggestion: ReframeSuggestion?
    @Published var beautifySettings = BeautifySettings()
    @Published var beautifyResult: BeautifyResult?
    @Published var selectedPosePackage: PosePackageID = .neutral
    @Published var latestPhotoThumbnail: UIImage?
    @Published private(set) var isCapturing = false
    @Published private(set) var isSaving = false
    @Published private(set) var hasUnsavedCapture = false
    @Published private(set) var exportStatus: String?
    @Published private(set) var isAnalyzingPhoto = false
    @Published private(set) var guidedSession = GuidedSession(pose: nil, position: nil)

    func beginGuidance(pose: GuidedPose?, position: GuidedCameraPosition?, moveRight: Bool = false) {
        guidedSession = GuidedSession(pose: pose, position: position, moveRight: moveRight)
        coachingEngine.reset()
        advice = Advice(type: "waiting", recipient: "Camera", instruction: "Checking framing…", tone: .waiting)
    }

    func advanceGuidance() {
        guard advice.type == guidedSession.advice?.type, guidedSession.currentStep != nil else { return }
        guidedSession.advance()
        coachingEngine.reset()
        advice = guidedSession.advice ?? advice
    }

    var guidedAction: GuidedAction? {
        advice.type == guidedSession.advice?.type ? guidedSession.currentStep?.action : nil
    }
    private var latestCaptureData: Data?
    private var pendingCaptureData: Data?
    private var pendingExportData: Data?
    private var analysisID = UUID()

    private static var captureStore: PendingCaptureStore {
        PendingCaptureStore(url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PendingCapture.photo"))
    }

    override init() {
        super.init()
        if let data = try? Self.captureStore.load() {
            latestCaptureData = data
            pendingCaptureData = data
            latestPhotoThumbnail = UIImage(data: data)
            hasUnsavedCapture = true
            exportStatus = "Unsaved photo recovered. Save or share it before taking another."
        }
    }

    func openLatestCapture() {
        guard let latestCaptureData else { return }
        analyzeStillPhoto(data: latestCaptureData)
    }

    func retryCaptureSave() {
        guard let pendingCaptureData else { return }
        savePhotoData(pendingCaptureData, isCapture: true)
    }

    func discardUnsavedCapture() {
        guard !isSaving else { return }
        do {
            try Self.captureStore.remove()
            pendingCaptureData = nil
            latestCaptureData = nil
            latestPhotoThumbnail = nil
            hasUnsavedCapture = false
            exportStatus = nil
            clearStillPhoto()
        } catch {
            exportStatus = "Could not discard photo. Please try again."
        }
    }

    func saveCopy(_ image: UIImage) {
        guard !isSaving else { return }
        guard let data = image.jpegData(compressionQuality: 0.95) else {
            exportStatus = "Could not prepare photo for saving."
            return
        }
        pendingExportData = data
        savePhotoData(data, isCapture: false)
    }

    func retryExport() {
        guard let pendingExportData else { return }
        savePhotoData(pendingExportData, isCapture: false)
    }

    var canRetryExport: Bool { pendingExportData != nil && !isSaving }

    private func savePhotoData(_ data: Data, isCapture: Bool) {
        guard !isSaving else { return }
        isSaving = true
        exportStatus = isCapture ? "Saving original…" : "Saving copy…"
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor [weak self] in
                    self?.isSaving = false
                    self?.exportStatus = "Photos access is needed. Enable it in Settings, then retry, or share the photo."
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            } completionHandler: { success, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isSaving = false
                    if success {
                        if isCapture {
                            self.pendingCaptureData = nil
                            self.hasUnsavedCapture = false
                            try? Self.captureStore.remove()
                        } else {
                            self.pendingExportData = nil
                        }
                        self.exportStatus = isCapture ? "Original saved to Photos" : "Copy saved to Photos"
                    } else {
                        self.exportStatus = "Save failed. Your photo is still available. \(error?.localizedDescription ?? "Please retry.")"
                    }
                    if isCapture {
                        self.sessionLogger.recordCapture(
                            status: success ? "saved" : "save_failed",
                            measurements: self.measurements,
                            issues: self.issues,
                            advice: self.advice
                        )
                    }
                }
            }
        }
    }

    nonisolated(unsafe) let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoQueue = DispatchQueue(label: "camera.video.queue")
    private let motionManager = CMMotionManager()
    private let coachingEngine = CoachingEngine()
    private let beautifyEngine = BeautifyEngine()
    private let sessionLogger = SessionLogger()
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private var lastAnalysis = Date.distantPast
    private var cameraPosition: AVCaptureDevice.Position = .back
    private var currentRollDegrees = 0.0
    private var currentMotionMagnitude = 0.0

    var sessionLogURL: URL? {
        sessionLogger.exportURL()
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionDenied = false
            if reviewImage == nil && !isAnalyzingPhoto { configureAndStart() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.permissionDenied = !granted
                    if granted { self?.start() }
                }
            }
        default:
            permissionDenied = true
        }
    }

    func stop() {
        cameraReady = false
        let session = session
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
        motionManager.stopDeviceMotionUpdates()
    }

    func switchCamera() {
        guard !isCapturing else { return }
        cameraPosition = cameraPosition == .back ? .front : .back
        isFrontCamera = cameraPosition == .front
        cameraReady = false
        coachingEngine.reset()
        configureAndStart()
    }

    func clearStillPhoto() {
        coachingEngine.reset()
        analysisID = UUID()
        isAnalyzingPhoto = false
        reviewImage = nil
        reframedImage = nil
        tiltedImage = nil
        leveledImage = nil
        beautifiedImage = nil
        reframeSuggestion = nil
        beautifyResult = nil
        captureStatus = nil
        advice = Advice(type: "waiting", recipient: "Camera", instruction: "Start camera", tone: .waiting)
    }

    func analyzeStillPhoto(data: Data) {
        stop()
        let requestID = UUID()
        analysisID = requestID
        isAnalyzingPhoto = true
        captureStatus = "Analyzing photo..."

        videoQueue.async { [weak self] in
            guard let self,
                  let image = UIImage(data: data) else {
                Task { @MainActor [weak self] in
                    guard self?.analysisID == requestID else { return }
                    self?.isAnalyzingPhoto = false
                    self?.captureStatus = "Could not read photo"
                    self?.start()
                }
                return
            }

            let normalizedImage = self.normalizedImage(image)
            guard let cgImage = normalizedImage.cgImage else {
                Task { @MainActor [weak self] in
                    guard self?.analysisID == requestID else { return }
                    self?.isAnalyzingPhoto = false
                    self?.captureStatus = "Could not read photo"
                    self?.start()
                }
                return
            }

            let now = Date()
            let analysis = self.analyzeImage(cgImage: cgImage, orientation: .up)

            Task { @MainActor [weak self] in
                guard let self, self.analysisID == requestID else { return }
                self.isAnalyzingPhoto = false
                let nextIssues = self.coachingEngine.issues(for: analysis.measurements, posePackage: self.selectedPosePackage)
                let nextAdvice = self.coachingEngine.selectAdvice(from: nextIssues, now: now.addingTimeInterval(2))
                let suggestion = self.reframeSuggestion(for: analysis.measurements, imageSize: normalizedImage.size)
                self.reviewImage = normalizedImage
                self.reframeSuggestion = suggestion
                self.reframedImage = suggestion.flatMap { self.croppedImage(normalizedImage, to: $0.cropRect) }
                self.leveledImage = self.leveledImage(normalizedImage, measurements: analysis.measurements)
                self.tiltedImage = nil
                self.measurements = analysis.measurements
                self.applyBeautify(to: normalizedImage, measurements: analysis.measurements)
                self.issues = nextIssues
                self.advice = nextAdvice
                self.captureStatus = "Photo analyzed"
                self.sessionLogger.recordAdvice(nextAdvice, measurements: analysis.measurements, issues: nextIssues)
            }
        }
    }

    func simulateTilt(degrees: Double) {
        guard let reviewImage else { return }
        tiltedImage = rotatedImage(reviewImage, degrees: degrees)
        leveledImage = reviewImage
        captureStatus = degrees > 0 ? "Tilt right test" : "Tilt left test"
    }

    func refreshStillPhotoAdvice() {
        guard reviewImage != nil else { return }
        let now = Date()
        let nextIssues = coachingEngine.issues(for: measurements, posePackage: selectedPosePackage)
        let nextAdvice = coachingEngine.selectAdvice(from: nextIssues, now: now.addingTimeInterval(2))
        issues = nextIssues
        advice = nextAdvice
        sessionLogger.recordAdvice(nextAdvice, measurements: measurements, issues: nextIssues)
    }

    func setBeautifyStrength(_ strength: Int) {
        beautifySettings.strength = max(0, min(10, strength))
        refreshBeautify()
    }

    func refreshBeautify() {
        guard let reviewImage else {
            beautifiedImage = nil
            beautifyResult = nil
            return
        }

        applyBeautify(to: reviewImage, measurements: measurements)
    }

    func capturePhoto() {
        guard cameraReady, !isCapturing, !hasUnsavedCapture, !isSaving, !isAnalyzingPhoto, reviewImage == nil else { return }
        isCapturing = true
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        let photoOutput = photoOutput
        captureStatus = "Capturing..."
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning, photoOutput.connection(with: .video) != nil else {
                Task { @MainActor in
                    self.isCapturing = false
                    self.captureStatus = "Camera is not ready. Please try again."
                }
                return
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureAndStart() {
        startMotion()
        let cameraPosition = cameraPosition
        let photoOutput = photoOutput
        let session = session
        let videoQueue = videoQueue
        let angle = videoRotation
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            if self.configuredCameraPosition == cameraPosition {
                if !session.isRunning { session.startRunning() }
                return
            }
            session.beginConfiguration()
            session.sessionPreset = .photo
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                session.commitConfiguration()
                Task { @MainActor [weak self] in self?.captureStatus = "Camera unavailable. Try switching cameras or reopen the app." }
                return
            }

            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.setSampleBufferDelegate(self, queue: videoQueue)

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                photoOutput.maxPhotoQualityPrioritization = .quality
            }

            for captureOutput in [output as AVCaptureOutput, photoOutput as AVCaptureOutput] {
                if let connection = captureOutput.connection(with: .video) {
                    if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = cameraPosition == .front
                    }
                }
            }

            session.commitConfiguration()
            self.configuredCameraPosition = cameraPosition

            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    private func applyBeautify(to image: UIImage, measurements: Measurements) {
        let beautify = beautifyEngine.apply(to: image, measurements: measurements, settings: beautifySettings)
        beautifyResult = beautify.result
        beautifiedImage = beautifySettings.strength > 0 ? beautify.image : nil
    }

    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.12
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.currentRollDegrees = PreviewGeometry.rollDegrees(
                gravityX: motion.gravity.x, gravityY: motion.gravity.y,
                rotation: Double(self.videoRotation), mirrored: self.isFrontCamera
            )
            let rotationRate = motion.rotationRate
            self.currentMotionMagnitude = sqrt(
                rotationRate.x * rotationRate.x
                + rotationRate.y * rotationRate.y
                + rotationRate.z * rotationRate.z
            )
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

    private nonisolated func groupAnalysis(people: [DetectionBox], faces: [DetectionBox]) -> GroupAnalysis? {
        let personLikeBoxes = people.isEmpty ? faces.map { estimatePersonFromFace($0) } : people
        guard personLikeBoxes.count > 1 || faces.count > 1 else { return nil }

        let groupBounds = rectContainingRects(personLikeBoxes.map(\.rect))
        let faceVisibilityRatio = Double(faces.count) / Double(max(1, personLikeBoxes.count))
        let nearestEdge = personLikeBoxes
            .flatMap { box in
                [
                    Double(box.rect.minX),
                    Double(box.rect.minY),
                    Double(1 - box.rect.maxX),
                    Double(1 - box.rect.maxY)
                ]
            }
            .min() ?? 1
        let edgeCrowding = min(1, max(0, (0.06 - nearestEdge) / 0.06))
        let centers = personLikeBoxes.map { Double($0.rect.midX) }.sorted()
        let gaps = zip(centers, centers.dropFirst()).map { $1 - $0 }
        let averageWidth = personLikeBoxes.reduce(0) { $0 + Double($1.rect.width) } / Double(personLikeBoxes.count)
        let spacingScore = gaps.isEmpty
            ? nil
            : max(0, (gaps.reduce(0, +) / Double(gaps.count)) / max(0.001, averageWidth))

        return GroupAnalysis(
            peopleCount: personLikeBoxes.count,
            faceCount: faces.count,
            groupBounds: groupBounds,
            faceVisibilityRatio: min(1, faceVisibilityRatio),
            edgeCrowdingScore: edgeCrowding,
            spacingScore: spacingScore
        )
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

    private nonisolated func skyOrOpenAreaRatio(in pixelBuffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0 }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let sampleMaxY = max(1, height / 3)
        let step = max(1, min(width, height) / 90)

        var openPixels = 0
        var sampledPixels = 0

        for y in stride(from: 0, to: sampleMaxY, by: step) {
            let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in stride(from: 0, to: width, by: step) {
                let offset = x * 4
                let blue = Double(row[offset])
                let green = Double(row[offset + 1])
                let red = Double(row[offset + 2])
                let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                let blueDominant = blue > red * 1.08 && blue > green * 0.95
                let brightOpen = luminance > 170

                if blueDominant || brightOpen {
                    openPixels += 1
                }
                sampledPixels += 1
            }
        }

        return sampledPixels > 0 ? Double(openPixels) / Double(sampledPixels) : 0
    }

    private nonisolated func poseKeypoints(from observations: [VNHumanBodyPoseObservation]) -> [String: DetectionPoint] {
        guard let observation = observations.max(by: { $0.confidence < $1.confidence }),
              let recognizedPoints = try? observation.recognizedPoints(.all) else {
            return [:]
        }

        return recognizedPoints.reduce(into: [String: DetectionPoint]()) { result, entry in
            guard entry.value.confidence > 0.15 else { return }
            result[String(describing: entry.key)] = DetectionPoint(
                point: CGPoint(x: entry.value.location.x, y: 1 - entry.value.location.y),
                confidence: CGFloat(entry.value.confidence)
            )
        }
    }

    private nonisolated func poseAnalysis(
        from points: [String: DetectionPoint],
        person: DetectionBox?,
        face: DetectionBox?
    ) -> PoseAnalysis? {
        guard !points.isEmpty else { return nil }

        let visiblePoints = points.values.filter { $0.confidence > 0.2 }
        let confidence = visiblePoints.isEmpty
            ? 0
            : visiblePoints.reduce(0) { $0 + Double($1.confidence) } / Double(visiblePoints.count)

        let leftShoulder = point(namedAny: ["leftShoulder"], in: points)
        let rightShoulder = point(namedAny: ["rightShoulder"], in: points)
        let leftHip = point(namedAny: ["leftHip", "leftUpLeg"], in: points)
        let rightHip = point(namedAny: ["rightHip", "rightUpLeg"], in: points)
        let leftWrist = point(namedAny: ["leftWrist", "leftHand"], in: points)
        let rightWrist = point(namedAny: ["rightWrist", "rightHand"], in: points)
        let leftElbow = point(namedAny: ["leftElbow", "leftForearm"], in: points)
        let rightElbow = point(namedAny: ["rightElbow", "rightForearm"], in: points)
        let leftAnkle = point(namedAny: ["leftAnkle", "leftFoot"], in: points)
        let rightAnkle = point(namedAny: ["rightAnkle", "rightFoot"], in: points)
        let neck = point(namedAny: ["neck"], in: points)
        let nose = point(namedAny: ["nose", "head"], in: points)

        let shoulderLineAngle = angleDegrees(from: leftShoulder?.point, to: rightShoulder?.point)
        let shoulderHeightAsymmetry = normalizedVerticalDelta(leftShoulder?.point, rightShoulder?.point, person: person)
        let shoulderMid = midpoint(leftShoulder?.point, rightShoulder?.point)
        let hipMid = midpoint(leftHip?.point, rightHip?.point)
        let torsoAngle = angleDegrees(from: shoulderMid, to: hipMid).map { $0 - 90 }
        let shoulderWidth = distance(leftShoulder?.point, rightShoulder?.point)
        let hipWidth = distance(leftHip?.point, rightHip?.point)
        let bodySquareness = zipValues(shoulderWidth, hipWidth).map { shoulder, hip in
            min(1, max(0, shoulder / max(0.001, hip)) / 1.35)
        }
        let bodyProfile = bodySquareness.map { 1 - $0 }

        let wristFaceDistance = [leftWrist, rightWrist]
            .compactMap { wrist in distanceFrom(point: wrist?.point, to: face?.rect) }
            .min()
        let torsoRect = rectContaining([leftShoulder?.point, rightShoulder?.point, leftHip?.point, rightHip?.point].compactMap { $0 })
        let elbowTorsoDistances = [leftElbow, rightElbow]
            .compactMap { elbow in distanceFrom(point: elbow?.point, to: torsoRect) }
        let wristTorsoDistances = [leftWrist, rightWrist]
            .compactMap { wrist in distanceFrom(point: wrist?.point, to: torsoRect) }
        let armTorsoDistances = elbowTorsoDistances + wristTorsoDistances
        let armsFlat = armTorsoDistances.isEmpty
            ? nil
            : min(1, max(0, (0.055 - (armTorsoDistances.reduce(0, +) / Double(armTorsoDistances.count))) / 0.055))
        let wristEdgeDistance = [leftWrist, rightWrist]
            .compactMap { wrist in edgeDistance(wrist?.point) }
            .min()
        let visibleArmJoints = [leftShoulder, rightShoulder, leftElbow, rightElbow, leftWrist, rightWrist]
            .filter { ($0?.confidence ?? 0) > 0.2 }
            .count
        let armVisibility = Double(visibleArmJoints) / 6
        let stanceWidth = distance(leftAnkle?.point, rightAnkle?.point)
        let headToTorsoRatio = zipValues(face?.rect.height, distance(shoulderMid, hipMid)).map { head, torso in
            Double(head / max(0.001, torso))
        }
        let headAnchor = nose?.point ?? face.map { CGPoint(x: $0.rect.midX, y: $0.rect.midY) }
        let shoulderAnchor = neck?.point ?? shoulderMid
        let shouldersHigh = zipValues(headAnchor, shoulderAnchor).map { head, shoulder in
            let reference = Double(person?.rect.height ?? 1)
            return min(1, max(0, (0.16 - Double(abs(shoulder.y - head.y)) / max(0.001, reference)) / 0.16))
        }

        return PoseAnalysis(
            confidence: confidence,
            visibleKeypointCount: visiblePoints.count,
            shoulderLineAngleDegrees: shoulderLineAngle,
            shoulderHeightAsymmetry: shoulderHeightAsymmetry,
            torsoAngleDegrees: torsoAngle,
            wristToFaceDistance: wristFaceDistance,
            armVisibilityScore: armVisibility,
            stanceWidth: stanceWidth,
            headToTorsoRatio: headToTorsoRatio,
            shouldersHighScore: shouldersHigh,
            bodySquarenessScore: bodySquareness,
            bodyProfileScore: bodyProfile,
            armsFlatAgainstBodyScore: armsFlat,
            minWristEdgeDistance: wristEdgeDistance
        )
    }

    private nonisolated func faceAnalysis(from observation: VNFaceObservation?, face: DetectionBox?) -> FaceAnalysis? {
        guard let observation,
              let face,
              let landmarks = observation.landmarks else {
            return nil
        }

        let leftEye = landmarkPoints(landmarks.leftEye, in: face.rect)
        let rightEye = landmarkPoints(landmarks.rightEye, in: face.rect)
        let nose = landmarkPoints(landmarks.nose, in: face.rect)
        let outerLips = landmarkPoints(landmarks.outerLips, in: face.rect)
        let medianLine = landmarkPoints(landmarks.medianLine, in: face.rect)
        let allPoints = leftEye + rightEye + nose + outerLips + medianLine

        let eyeVisibility = Double([leftEye, rightEye].filter { $0.count >= 3 }.count) / 2
        let occlusion = min(1, max(0, 1 - (Double(allPoints.count) / 26)))
        let leftEyeCenter = center(of: leftEye)
        let rightEyeCenter = center(of: rightEye)
        let noseCenter = center(of: nose)
        let lipsCenter = center(of: outerLips)
        let eyeCenter = midpoint(leftEyeCenter, rightEyeCenter)
        let eyeSpan = distance(leftEyeCenter, rightEyeCenter)
        let yaw = zipValues(noseCenter, eyeCenter).flatMap { nose, eyes in
            eyeSpan.map { span in
                Double((nose.x - eyes.x) / max(0.001, CGFloat(span)))
            }
        }
        let pitch = zipValues(noseCenter, lipsCenter).map { nose, lips in
            Double((lips.y - nose.y) / max(0.001, face.rect.height))
        }

        return FaceAnalysis(
            confidence: Double(observation.confidence),
            landmarkPointCount: allPoints.count,
            eyeVisibilityScore: eyeVisibility,
            yawEstimate: yaw,
            pitchEstimate: pitch,
            occlusionScore: occlusion
        )
    }

    private nonisolated func point(named name: String, in points: [String: DetectionPoint]) -> DetectionPoint? {
        let target = normalizedJointName(name)
        return points.first { entry in
            normalizedJointName(entry.key).contains(target)
        }?.value
    }

    private nonisolated func point(namedAny names: [String], in points: [String: DetectionPoint]) -> DetectionPoint? {
        for name in names {
            if let point = point(named: name, in: points) {
                return point
            }
        }

        return nil
    }

    private nonisolated func normalizedJointName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private nonisolated func midpoint(_ first: CGPoint?, _ second: CGPoint?) -> CGPoint? {
        guard let first, let second else { return nil }
        return CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }

    private nonisolated func distance(_ first: CGPoint?, _ second: CGPoint?) -> Double? {
        guard let first, let second else { return nil }
        return hypot(Double(first.x - second.x), Double(first.y - second.y))
    }

    private nonisolated func distanceFrom(point: CGPoint?, to rect: CGRect?) -> Double? {
        guard let point, let rect else { return nil }
        if rect.contains(point) { return 0 }

        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(Double(dx), Double(dy))
    }

    private nonisolated func edgeDistance(_ point: CGPoint?) -> Double? {
        guard let point else { return nil }
        return Double(min(point.x, point.y, 1 - point.x, 1 - point.y))
    }

    private nonisolated func rectContaining(_ points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: max(0.001, maxX - minX), height: max(0.001, maxY - minY))
    }

    private nonisolated func rectContainingRects(_ rects: [CGRect]) -> CGRect? {
        guard let first = rects.first else { return nil }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }

    private nonisolated func center(of points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let total = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }
        return CGPoint(x: total.x / CGFloat(points.count), y: total.y / CGFloat(points.count))
    }

    private nonisolated func landmarkPoints(_ region: VNFaceLandmarkRegion2D?, in faceRect: CGRect) -> [CGPoint] {
        guard let region else { return [] }
        return region.normalizedPoints.map { point in
            CGPoint(
                x: faceRect.minX + point.x * faceRect.width,
                y: faceRect.maxY - point.y * faceRect.height
            )
        }
    }

    private nonisolated func angleDegrees(from first: CGPoint?, to second: CGPoint?) -> Double? {
        guard let first, let second else { return nil }
        return atan2(Double(second.y - first.y), Double(second.x - first.x)) * 180 / .pi
    }

    private nonisolated func normalizedVerticalDelta(_ first: CGPoint?, _ second: CGPoint?, person: DetectionBox?) -> Double? {
        guard let first, let second else { return nil }
        return Double(abs(first.y - second.y) / max(0.001, person?.rect.height ?? 1))
    }

    private nonisolated func zipValues<A, B>(_ first: A?, _ second: B?) -> (A, B)? {
        guard let first, let second else { return nil }
        return (first, second)
    }

    private nonisolated func analyzeImage(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> (measurements: Measurements, issues: [PhotoIssue]) {
        let humanRequest = VNDetectHumanRectanglesRequest()
        humanRequest.upperBodyOnly = false
        let faceRequest = VNDetectFaceLandmarksRequest()
        let poseRequest = VNDetectHumanBodyPoseRequest()
        let horizonRequest = VNDetectHorizonRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        do {
            try handler.perform([humanRequest, faceRequest, poseRequest, horizonRequest])
        } catch {
            let emptyMeasurements = stillMeasurements(
                person: nil,
                face: nil,
                faceAnalysis: nil,
                poseKeypoints: [:],
                poseAnalysis: nil,
                faceLuminance: nil,
                backgroundLuminance: nil,
                horizonAngleDegrees: nil,
                horizonConfidence: 0,
                skyOrOpenAreaRatio: 0
            )
            return (emptyMeasurements, [])
        }

        let people = (humanRequest.results ?? [])
            .map {
                DetectionBox(
                    rect: normalizedTopLeftRect($0.boundingBox),
                    confidence: CGFloat($0.confidence),
                    label: "person"
                )
            }
            .filter { $0.confidence > 0.25 }

        let human = people
            .max { $0.confidence < $1.confidence }

        let faceObservations = faceRequest.results ?? []
        let faces = faceObservations
            .map {
                DetectionBox(
                    rect: normalizedTopLeftRect($0.boundingBox),
                    confidence: CGFloat($0.confidence),
                    label: "face"
                )
            }
            .filter { $0.confidence > 0.25 }

        let faceObservation = faceObservations
            .max { $0.confidence < $1.confidence }

        let face = faces.max { $0.confidence < $1.confidence }

        let person = human ?? face.map { estimatePersonFromFace($0) }
        let poseKeypoints = poseKeypoints(from: poseRequest.results ?? [])
        let horizon = horizonRequest.results?.first
        let measurements = stillMeasurements(
            person: person,
            face: face,
            groupAnalysis: groupAnalysis(people: people, faces: faces),
            faceAnalysis: faceAnalysis(from: faceObservation, face: face),
            poseKeypoints: poseKeypoints,
            poseAnalysis: poseAnalysis(from: poseKeypoints, person: person, face: face),
            faceLuminance: face.flatMap { luminance(in: cgImage, normalizedRect: $0.rect) },
            backgroundLuminance: luminance(in: cgImage, normalizedRect: nil),
            horizonAngleDegrees: horizon.map { Double($0.angle) * 180 / .pi },
            horizonConfidence: horizon == nil ? 0 : 0.72,
            skyOrOpenAreaRatio: skyOrOpenAreaRatio(in: cgImage)
        )

        return (measurements, [])
    }

    private func reframeSuggestion(for measurements: Measurements, imageSize: CGSize) -> ReframeSuggestion? {
        guard let person = measurements.personBox,
              person.confidence > 0.35,
              imageSize.width > 0,
              imageSize.height > 0 else {
            return nil
        }

        let imageAspectRatio = imageSize.width / imageSize.height
        let targetAspectRatio = imageAspectRatio < 1 ? CGFloat(3.0 / 4.0) : CGFloat(4.0 / 3.0)
        let personRect = person.rect
        let tightCrop = personRect.insetBy(dx: -personRect.width * 0.42, dy: -personRect.height * 0.18)
        var crop = tightCrop.union(CGRect(
            x: personRect.midX - personRect.width * 0.85,
            y: max(0, personRect.minY - 0.08),
            width: personRect.width * 1.7,
            height: personRect.height * 1.24
        ))

        crop = expand(crop, toAspectRatio: targetAspectRatio)
        crop = clamp(crop)

        let issues = coachingEngine.issues(for: measurements, includePosture: false)
        let instruction = reframeInstruction(for: issues, crop: crop)
        let fullFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
        let cropChanged = abs(crop.minX - fullFrame.minX) > 0.02
            || abs(crop.minY - fullFrame.minY) > 0.02
            || abs(crop.width - fullFrame.width) > 0.02
            || abs(crop.height - fullFrame.height) > 0.02

        guard cropChanged else { return nil }

        return ReframeSuggestion(
            cropRect: crop,
            targetAspectRatio: targetAspectRatio,
            instruction: instruction,
            confidence: Double(person.confidence),
            reason: issues.first?.type ?? "balanced_crop"
        )
    }

    private func reframeInstruction(for issues: [PhotoIssue], crop: CGRect) -> String {
        if issues.contains(where: { $0.type == "headroom_too_large" }) {
            return "Crop lower"
        }

        if issues.contains(where: { $0.type == "scene_excluded" || $0.type == "subject_too_close" }) {
            return "Use a wider frame"
        }

        if issues.contains(where: { $0.type == "subject_too_far" }) {
            return "Crop closer"
        }

        if crop.minX > 0.08 {
            return "Shift frame right"
        }

        if crop.maxX < 0.92 {
            return "Shift frame left"
        }

        return "Suggested reframe"
    }

    private func expand(_ rect: CGRect, toAspectRatio aspectRatio: CGFloat) -> CGRect {
        var next = rect
        let currentAspectRatio = next.width / max(0.001, next.height)

        if currentAspectRatio < aspectRatio {
            let newWidth = next.height * aspectRatio
            next.origin.x -= (newWidth - next.width) / 2
            next.size.width = newWidth
        } else {
            let newHeight = next.width / aspectRatio
            next.origin.y -= (newHeight - next.height) / 2
            next.size.height = newHeight
        }

        return next
    }

    private func clamp(_ rect: CGRect) -> CGRect {
        var next = rect
        next.size.width = min(1, max(0.1, next.width))
        next.size.height = min(1, max(0.1, next.height))
        next.origin.x = min(max(0, next.origin.x), 1 - next.width)
        next.origin.y = min(max(0, next.origin.y), 1 - next.height)
        return next
    }

    private nonisolated func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private func croppedImage(_ image: UIImage, to normalizedRect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let pixelRect = CGRect(
            x: normalizedRect.minX * CGFloat(cgImage.width),
            y: normalizedRect.minY * CGFloat(cgImage.height),
            width: normalizedRect.width * CGFloat(cgImage.width),
            height: normalizedRect.height * CGFloat(cgImage.height)
        ).integral

        guard let cropped = cgImage.cropping(to: pixelRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    private func leveledImage(_ image: UIImage, measurements: Measurements) -> UIImage? {
        guard let horizonAngle = measurements.horizonAngleDegrees,
              measurements.horizonConfidence > 0.55,
              abs(horizonAngle) > 3 else {
            return nil
        }

        return rotatedImage(image, degrees: -horizonAngle)
    }

    private func rotatedImage(_ image: UIImage, degrees: Double) -> UIImage {
        let radians = CGFloat(degrees) * .pi / 180
        let sourceSize = image.size
        let rotatedRect = CGRect(origin: .zero, size: sourceSize)
            .applying(CGAffineTransform(rotationAngle: radians))
        let outputSize = CGSize(width: abs(rotatedRect.width), height: abs(rotatedRect.height))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale

        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))
            context.cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            context.cgContext.rotate(by: radians)
            image.draw(in: CGRect(
                x: -sourceSize.width / 2,
                y: -sourceSize.height / 2,
                width: sourceSize.width,
                height: sourceSize.height
            ))
        }
    }

    private nonisolated func stillMeasurements(
        person: DetectionBox?,
        face: DetectionBox?,
        groupAnalysis: GroupAnalysis? = nil,
        faceAnalysis: FaceAnalysis?,
        poseKeypoints: [String: DetectionPoint],
        poseAnalysis: PoseAnalysis?,
        faceLuminance: Double?,
        backgroundLuminance: Double?,
        horizonAngleDegrees: Double?,
        horizonConfidence: Double,
        skyOrOpenAreaRatio: Double
    ) -> Measurements {
        Measurements(
            personBox: person,
            faceBox: face,
            groupAnalysis: groupAnalysis,
            faceAnalysis: faceAnalysis,
            poseKeypoints: poseKeypoints,
            poseAnalysis: poseAnalysis,
            faceLuminance: faceLuminance,
            backgroundLuminance: backgroundLuminance,
            horizonAngleDegrees: horizonAngleDegrees,
            horizonY: horizonAngleDegrees == nil ? nil : 0.5,
            horizonConfidence: horizonConfidence,
            cameraRollDegrees: 0,
            cameraMotion: 0,
            cameraStable: true,
            skyOrOpenAreaRatio: skyOrOpenAreaRatio,
            timestamp: Date()
        )
    }

    private nonisolated func luminance(in cgImage: CGImage, normalizedRect: CGRect?) -> Double? {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data),
              cgImage.bitsPerPixel >= 24 else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = max(1, cgImage.bitsPerPixel / 8)
        let rect = normalizedRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        let minX = max(0, min(width - 1, Int(rect.minX * CGFloat(width))))
        let maxX = max(minX + 1, min(width, Int(rect.maxX * CGFloat(width))))
        let minY = max(0, min(height - 1, Int(rect.minY * CGFloat(height))))
        let maxY = max(minY + 1, min(height, Int(rect.maxY * CGFloat(height))))
        let step = max(1, min(width, height) / 100)
        let bitmapInfo = cgImage.bitmapInfo
        let alphaInfo = CGImageAlphaInfo(rawValue: bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)
        let byteOrder = bitmapInfo.intersection(.byteOrderMask)
        let alphaFirst = alphaInfo == .premultipliedFirst || alphaInfo == .first || alphaInfo == .noneSkipFirst
        let bgrOrder = byteOrder == .byteOrder32Little

        var total = 0.0
        var count = 0

        for y in stride(from: minY, to: maxY, by: step) {
            let row = bytes.advanced(by: y * bytesPerRow)
            for x in stride(from: minX, to: maxX, by: step) {
                let pixel = row.advanced(by: x * bytesPerPixel)
                let colorOffset = alphaFirst ? 1 : 0
                let redIndex = bgrOrder ? colorOffset + 2 : colorOffset
                let greenIndex = colorOffset + 1
                let blueIndex = bgrOrder ? colorOffset : colorOffset + 2

                guard max(redIndex, greenIndex, blueIndex) < bytesPerPixel else { continue }

                let red = Double(pixel[redIndex])
                let green = Double(pixel[greenIndex])
                let blue = Double(pixel[blueIndex])
                total += 0.2126 * red + 0.7152 * green + 0.0722 * blue
                count += 1
            }
        }

        return count > 0 ? total / Double(count) : nil
    }

    private nonisolated func skyOrOpenAreaRatio(in cgImage: CGImage) -> Double {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data),
              cgImage.bitsPerPixel >= 24 else {
            return 0
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = max(1, cgImage.bitsPerPixel / 8)
        let sampleMaxY = max(1, height / 3)
        let step = max(1, min(width, height) / 90)
        let bitmapInfo = cgImage.bitmapInfo
        let alphaInfo = CGImageAlphaInfo(rawValue: bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)
        let byteOrder = bitmapInfo.intersection(.byteOrderMask)
        let alphaFirst = alphaInfo == .premultipliedFirst || alphaInfo == .first || alphaInfo == .noneSkipFirst
        let bgrOrder = byteOrder == .byteOrder32Little

        var openPixels = 0
        var sampledPixels = 0

        for y in stride(from: 0, to: sampleMaxY, by: step) {
            let row = bytes.advanced(by: y * bytesPerRow)
            for x in stride(from: 0, to: width, by: step) {
                let pixel = row.advanced(by: x * bytesPerPixel)
                let colorOffset = alphaFirst ? 1 : 0
                let redIndex = bgrOrder ? colorOffset + 2 : colorOffset
                let greenIndex = colorOffset + 1
                let blueIndex = bgrOrder ? colorOffset : colorOffset + 2

                guard max(redIndex, greenIndex, blueIndex) < bytesPerPixel else { continue }

                let red = Double(pixel[redIndex])
                let green = Double(pixel[greenIndex])
                let blue = Double(pixel[blueIndex])
                let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                let blueDominant = blue > red * 1.08 && blue > green * 0.95
                let brightOpen = luminance > 170

                if blueDominant || brightOpen {
                    openPixels += 1
                }
                sampledPixels += 1
            }
        }

        return sampledPixels > 0 ? Double(openPixels) / Double(sampledPixels) : 0
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
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
        let faceRequest = VNDetectFaceLandmarksRequest()
        let poseRequest = VNDetectHumanBodyPoseRequest()
        let horizonRequest = VNDetectHorizonRequest()
        let frameAspectRatio = CGFloat(CVPixelBufferGetWidth(pixelBuffer)) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let frameRotation = connection.videoRotationAngle
        let frameMirrored = connection.isVideoMirrored
        Task { @MainActor [weak self] in
            guard let self, self.reviewImage == nil, !self.isAnalyzingPhoto,
                  self.videoRotation == frameRotation, self.isFrontCamera == frameMirrored else { return }
            self.previewAspectRatio = frameAspectRatio
            self.cameraReady = true
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([humanRequest, faceRequest, poseRequest, horizonRequest])
        } catch {
            return
        }

        let people = (humanRequest.results ?? [])
            .map {
                DetectionBox(
                    rect: normalizedTopLeftRect($0.boundingBox),
                    confidence: CGFloat($0.confidence),
                    label: "person"
                )
            }
            .filter { $0.confidence > 0.25 }

        let human = people
            .max { $0.confidence < $1.confidence }

        let faceObservations = faceRequest.results ?? []
        let faces = faceObservations
            .map {
                DetectionBox(
                    rect: normalizedTopLeftRect($0.boundingBox),
                    confidence: CGFloat($0.confidence),
                    label: "face"
                )
            }
            .filter { $0.confidence > 0.25 }

        let faceObservation = faceObservations
            .max { $0.confidence < $1.confidence }

        let face = faces.max { $0.confidence < $1.confidence }

        let person = human ?? face.map { estimatePersonFromFace($0) }
        let poseKeypoints = poseKeypoints(from: poseRequest.results ?? [])
        let poseAnalysis = poseAnalysis(from: poseKeypoints, person: person, face: face)
        let faceAnalysis = faceAnalysis(from: faceObservation, face: face)
        let faceLuminance = face.flatMap { luminance(in: pixelBuffer, normalizedRect: $0.rect) }
        let backgroundLuminance = luminance(in: pixelBuffer, normalizedRect: nil)
        let horizon = horizonRequest.results?.first
        let hasHorizon = horizon != nil
        let horizonAngleDegrees = horizon.map { Double($0.angle) * 180 / .pi }
        let skyOrOpenAreaRatio = skyOrOpenAreaRatio(in: pixelBuffer)

        Task { @MainActor [weak self] in
            guard let self, self.reviewImage == nil, !self.isAnalyzingPhoto,
                  self.videoRotation == frameRotation, self.isFrontCamera == frameMirrored else { return }
            self.previewAspectRatio = frameAspectRatio
            self.cameraReady = true
            let cameraMotion = self.currentMotionMagnitude
            let nextMeasurements = Measurements(
                personBox: person,
                faceBox: face,
                groupAnalysis: self.groupAnalysis(people: people, faces: faces),
                faceAnalysis: faceAnalysis,
                poseKeypoints: poseKeypoints,
                poseAnalysis: poseAnalysis,
                faceLuminance: faceLuminance,
                backgroundLuminance: backgroundLuminance,
                horizonAngleDegrees: horizonAngleDegrees,
                horizonY: hasHorizon ? 0.5 : nil,
                horizonConfidence: hasHorizon ? 0.72 : 0,
                cameraRollDegrees: self.currentRollDegrees,
                cameraMotion: cameraMotion,
                cameraStable: cameraMotion < 0.22,
                skyOrOpenAreaRatio: skyOrOpenAreaRatio,
                timestamp: now
            )
            let nextIssues = self.guidedSession.prioritizedIssues(
                self.coachingEngine.issues(for: nextMeasurements, includePosture: false)
            )
            let nextAdvice = self.coachingEngine.selectAdvice(from: nextIssues, now: now, fallback: self.guidedSession.advice)
            self.measurements = nextMeasurements
            self.issues = nextIssues
            self.advice = nextAdvice
            self.sessionLogger.recordAdvice(nextAdvice, measurements: nextMeasurements, issues: nextIssues)
        }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        guard let error else { return }
        Task { @MainActor [weak self] in
            self?.isCapturing = false
            self?.captureStatus = "Capture failed: \(error.localizedDescription)"
        }
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            Task { @MainActor [weak self] in
                self?.isCapturing = false
                self?.captureStatus = "Capture failed: \(error.localizedDescription)"
            }
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            Task { @MainActor [weak self] in
                self?.isCapturing = false
                self?.captureStatus = "Capture failed"
            }
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isCapturing = false
            self.latestCaptureData = data
            self.pendingCaptureData = data
            self.hasUnsavedCapture = true
            self.latestPhotoThumbnail = UIImage(data: data)
            self.captureStatus = nil
            do {
                try Self.captureStore.retain(data)
            } catch {
                self.captureStatus = "Recovery copy unavailable. Keep the app open until the photo is saved or shared."
            }
            self.savePhotoData(data, isCapture: true)
        }
    }
}
