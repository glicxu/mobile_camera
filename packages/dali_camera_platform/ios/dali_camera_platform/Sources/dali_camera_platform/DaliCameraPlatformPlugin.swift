import Flutter
import UIKit
import AVFoundation
import Vision
import CoreMotion
import Photos
import PhotosUI
import CoreImage

public final class DaliCameraPlatformPlugin: NSObject, FlutterPlugin, CameraHostApi, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, PHPickerViewControllerDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "dali.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private let motion = CMMotionManager()
    private let ci = CIContext()
    private let speech = SpeechShutterService()
    private var events: CameraEvents!
    private var preview: CameraView?
    private var device: AVCaptureDevice?
    private var front = false
    private var configuration = ""
    private var captureCompletion: ((Result<PhotoHandle, Error>) -> Void)?
    private var pickerCompletion: ((Result<PhotoHandle?, Error>) -> Void)?
    private var lastFrame = CFAbsoluteTimeGetCurrent()
    private var currentRoll = 0.0
    private var currentMotion = 0.0
    private var active = false
    private var generation = UUID()
    private var aspect = 0.75
    private var rotation: CGFloat = 90
    private var capturing = false
    private var presenter: UIViewController? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
    }
    public static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = DaliCameraPlatformPlugin()
        plugin.events = CameraEvents(binaryMessenger: registrar.messenger())
        plugin.speech.onShutter = { [weak plugin] in
            guard let plugin, plugin.active, !plugin.capturing else { return }
            plugin.events.voiceShutter { _ in }
        }
        CameraHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: plugin)
        registrar.register(CameraViewFactory(plugin: plugin), withId: "dali/camera")
    }
    private func failure(_ message: String) -> NSError { NSError(domain: "Dali", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    private var directory: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Dali", isDirectory: true) }
    private var manifest: URL { directory.appendingPathComponent("pending.json") }
    private func newPhoto() throws -> PhotoHandle {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID().uuidString
        return PhotoHandle(path: directory.appendingPathComponent("photo-\(id).jpg").path, id: id, unsaved: false)
    }
    private func snapshot() -> CameraSnapshot {
        CameraSnapshot(ready: active, front: front, configurationId: configuration, aspectRatio: aspect,
            minimumEV: Double(device?.minExposureTargetBias ?? 0), maximumEV: Double(device?.maxExposureTargetBias ?? 0),
            currentEV: Double(device?.exposureTargetBias ?? 0),
            supportsLock: device?.isFocusModeSupported(.locked) == true && device?.isExposureModeSupported(.locked) == true,
            locked: device?.focusMode == .locked && device?.exposureMode == .locked)
    }
    func start(front: Bool, completion: @escaping (Result<CameraSnapshot, Error>) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { allowed in DispatchQueue.main.async {
                if allowed { self.start(front: front, completion: completion) }
                else { completion(.failure(self.failure("Camera permission denied. Open Settings to enable it."))) }
            }}
            return
        }
        guard status == .authorized else { completion(.failure(failure("Camera permission denied. Open Settings to enable it."))); return }
        self.front = front
        let epoch = UUID(); generation = epoch
        let orientation = presenter?.view.window?.windowScene?.interfaceOrientation ?? .portrait
        rotation = orientation == .landscapeLeft ? 180 : orientation == .landscapeRight ? 0 : orientation == .portraitUpsideDown ? 270 : 90
        queue.async {
            do {
                guard self.generation == epoch else { throw self.failure("Session superseded") }
                self.session.stopRunning(); self.session.beginConfiguration()
                self.session.inputs.forEach { self.session.removeInput($0) }
                self.session.outputs.forEach { self.session.removeOutput($0) }
                self.session.sessionPreset = .photo
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back) else {
                    self.session.commitConfiguration(); throw self.failure("Camera unavailable")
                }
                let input = try AVCaptureDeviceInput(device: device)
                self.session.addInput(input); self.session.addOutput(self.photoOutput)
                let video = AVCaptureVideoDataOutput()
                video.alwaysDiscardsLateVideoFrames = true
                video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                video.setSampleBufferDelegate(self, queue: self.queue); self.session.addOutput(video)
                for output in [video as AVCaptureOutput, self.photoOutput] {
                    if let connection = output.connection(with: .video) {
                        if connection.isVideoRotationAngleSupported(self.rotation) { connection.videoRotationAngle = self.rotation }
                        if connection.isVideoMirroringSupported { connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = front }
                    }
                }
                self.session.commitConfiguration(); self.device = device
                self.configuration = UUID().uuidString; self.session.startRunning(); self.active = true
                DispatchQueue.main.async {
                    guard self.generation == epoch else { return }
                    self.preview?.layer.session = self.session; self.preview?.layer.videoGravity = .resizeAspect
                    if let connection = self.preview?.layer.connection {
                        if connection.isVideoRotationAngleSupported(self.rotation) { connection.videoRotationAngle = self.rotation }
                        if connection.isVideoMirroringSupported { connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = front }
                    }
                    self.motion.startDeviceMotionUpdates(to: .main) { sample, _ in
                        if let acceleration = sample?.userAcceleration { self.currentMotion = sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z) }
                        guard let gravity = sample?.gravity, hypot(gravity.x, gravity.y) > 0.15 else { self.currentRoll = 0; return }
                        var degrees = atan2(gravity.x, -gravity.y) * 180 / .pi - Double(self.rotation - 90)
                        while degrees > 180 { degrees -= 360 }; while degrees < -180 { degrees += 360 }
                        self.currentRoll = front ? -degrees : degrees
                    }
                    completion(.success(self.snapshot())); self.events.state(snapshot: self.snapshot()) { _ in }
                }
            } catch { self.active = false; DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    func stop() throws { active = false; generation = UUID(); speech.stop(); motion.stopDeviceMotionUpdates(); queue.async { self.session.stopRunning() } }
    func capture(completion: @escaping (Result<PhotoHandle, Error>) -> Void) {
        do {
            guard active, !capturing, try recover() == nil else { throw failure("Save or discard the retained original first") }
            capturing = true; captureCompletion = completion
            queue.async { self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]), delegate: self) }
        } catch { completion(.failure(error)) }
    }
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async {
            self.capturing = false; let completion = self.captureCompletion; self.captureCompletion = nil
            do {
                if let error { throw error }
                guard let bytes = photo.fileDataRepresentation() else { throw self.failure("No photo data") }
                var handle = try self.newPhoto(); handle.unsaved = true
                try bytes.write(to: URL(fileURLWithPath: handle.path), options: .atomic)
                do { try JSONSerialization.data(withJSONObject: ["path": handle.path, "id": handle.id]).write(to: self.manifest, options: .atomic) }
                catch { self.events.error(code: "recovery", message: "Original captured but relaunch recovery unavailable: \(error.localizedDescription)") { _ in } }
                completion?(.success(handle))
            } catch { completion?(.failure(error)) }
        }
    }
    func recover() throws -> PhotoHandle? {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return nil }
        let data = try JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as! [String: String]
        guard let path = data["path"], let id = data["id"], FileManager.default.fileExists(atPath: path) else { throw failure("Recovery original missing") }
        return PhotoHandle(path: path, id: id, unsaved: true)
    }
    func save(photo: PhotoHandle, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { DispatchQueue.main.async { completion(.failure(self.failure("Photos access denied; original retained"))) }; return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: URL(fileURLWithPath: photo.path), options: nil)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    do {
                        guard success else { throw error ?? self.failure("Photos save failed") }
                        if try self.recover()?.id == photo.id { try FileManager.default.removeItem(at: self.manifest) }
                        completion(.success(()))
                    } catch { completion(.failure(error)) }
                }
            }
        }
    }
    func discard(photo: PhotoHandle) throws {
        if try recover()?.id == photo.id { try FileManager.default.removeItem(at: manifest); try FileManager.default.removeItem(atPath: photo.path) }
    }
    func share(photo: PhotoHandle, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let presenter else { completion(.failure(failure("No presenter"))); return }
        let sheet = UIActivityViewController(activityItems: [URL(fileURLWithPath: photo.path)], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = presenter.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        presenter.present(sheet, animated: true); completion(.success(()))
    }
    func pickPhoto(completion: @escaping (Result<PhotoHandle?, Error>) -> Void) {
        guard let presenter, pickerCompletion == nil else { completion(.failure(failure("Photo picker unavailable"))); return }
        pickerCompletion = completion
        var config = PHPickerConfiguration(); config.filter = .images; config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config); picker.delegate = self; presenter.present(picker, animated: true)
    }
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true); let completion = pickerCompletion; pickerCompletion = nil
        guard let first = results.first else { completion?(.success(nil)); return }
        first.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
            do {
                if let error { throw error }
                guard let image = image as? UIImage, let data = image.jpegData(compressionQuality: 0.98) else { throw self.failure("Cannot load photo") }
                let handle = try self.newPhoto(); try data.write(to: URL(fileURLWithPath: handle.path), options: .atomic)
                DispatchQueue.main.async { completion?(.success(handle)) }
            } catch { DispatchQueue.main.async { completion?(.failure(error)) } }
        }
    }
    func render(original: PhotoHandle, rotationDegrees: Double, crop: Bool, strength: Double, completion: @escaping (Result<PhotoHandle, Error>) -> Void) {
        queue.async {
            do {
                guard var image = CIImage(contentsOf: URL(fileURLWithPath: original.path), options: [.applyOrientationProperty: true]) else { throw self.failure("Cannot decode photo") }
                image = image.transformed(by: CGAffineTransform(rotationAngle: CGFloat(rotationDegrees * .pi / 180)))
                if crop { image = image.cropped(to: image.extent.insetBy(dx: image.extent.width * 0.08, dy: image.extent.height * 0.08)) }
                if strength > 0 { image = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1 + strength * 0.12]) }
                guard let output = self.ci.createCGImage(image, from: image.extent), let data = UIImage(cgImage: output).jpegData(compressionQuality: 0.95) else { throw self.failure("Cannot render photo") }
                let handle = try self.newPhoto(); try data.write(to: URL(fileURLWithPath: handle.path), options: .atomic)
                DispatchQueue.main.async { completion(.success(handle)) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    func setControls(configurationId: String, ev: Double, locked: Bool, completion: @escaping (Result<CameraSnapshot, Error>) -> Void) {
        queue.async {
            do {
                guard self.active, configurationId == self.configuration, let device = self.device else { throw self.failure("Camera changed; refresh controls") }
                try device.lockForConfiguration(); defer { device.unlockForConfiguration() }
                device.setExposureTargetBias(Float(ev).clamped(device.minExposureTargetBias, device.maxExposureTargetBias), completionHandler: nil)
                if device.isFocusModeSupported(locked ? .locked : .continuousAutoFocus) { device.focusMode = locked ? .locked : .continuousAutoFocus }
                if device.isExposureModeSupported(locked ? .locked : .continuousAutoExposure) { device.exposureMode = locked ? .locked : .continuousAutoExposure }
                DispatchQueue.main.async { completion(.success(self.snapshot())) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    func openSettings() throws { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
    func setVoiceEnabled(enabled: Bool, completion: @escaping (Result<Bool, Error>) -> Void) { speech.setEnabled(enabled, completion: completion) }
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CFAbsoluteTimeGetCurrent(); guard active, now - lastFrame > 0.15, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrame = now; let epoch = generation
        let people = VNDetectHumanRectanglesRequest(); let faces = VNDetectFaceRectanglesRequest()
        do {
            try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up).perform([people, faces])
            func boxes(_ observations: [VNDetectedObjectObservation]) -> [[String: Any]] { observations.map { obs in
                let r = obs.boundingBox
                return ["x": r.minX, "y": 1-r.maxY, "width": r.width, "height": r.height, "confidence": obs.confidence, "label": "detection"]
            }}
            aspect = Double(CVPixelBufferGetWidth(buffer)) / Double(CVPixelBufferGetHeight(buffer))
            let data: [String: Any] = ["schemaVersion": 1, "frameId": "\(epoch):\(now)",
                "imageWidth": CVPixelBufferGetWidth(buffer), "imageHeight": CVPixelBufferGetHeight(buffer),
                "displayRotationDegrees": Int(rotation), "front": front,
                "motionStatus": motion.isDeviceMotionAvailable ? "valid" : "unsupported",
                "timestamp": Int(Date().timeIntervalSince1970 * 1000), "configurationId": configuration, "aspectRatio": aspect,
                "people": boxes(people.results ?? []), "faces": boxes(faces.results ?? []), "roll": currentRoll,
                "motion": currentMotion, "stable": currentMotion < 0.22, "peopleStatus": "valid", "faceStatus": "valid", "horizonStatus": "unsupported", "openAreaStatus": "unsupported"]
            let json = String(data: try JSONSerialization.data(withJSONObject: data), encoding: .utf8)!
            DispatchQueue.main.async { if epoch == self.generation && self.active { self.events.analysis(json: json) { _ in } } }
        } catch { DispatchQueue.main.async { self.events.error(code: "analysis", message: error.localizedDescription) { _ in } } }
    }
    fileprivate func attach(_ view: CameraView) { preview = view; view.layer.session = session }
    fileprivate func updateOrientation(_ orientation: UIInterfaceOrientation) {
        let angle: CGFloat = orientation == .landscapeLeft ? 180 : orientation == .landscapeRight ? 0 : orientation == .portraitUpsideDown ? 270 : 90
        guard active, angle != rotation else { return }
        rotation = angle; generation = UUID()
        if let connection = preview?.layer.connection, connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
        queue.async {
            for output in self.session.outputs {
                if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
            }
        }
    }
}
private extension Float { func clamped(_ low: Float, _ high: Float) -> Float { min(high, max(low, self)) } }
private final class PreviewContainer: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var orientationChanged: ((UIInterfaceOrientation) -> Void)?
    override func layoutSubviews() { super.layoutSubviews(); if let orientation = window?.windowScene?.interfaceOrientation { orientationChanged?(orientation) } }
}
private final class CameraView: NSObject, FlutterPlatformView {
    let container = PreviewContainer()
    var layer: AVCaptureVideoPreviewLayer { container.layer as! AVCaptureVideoPreviewLayer }
    func view() -> UIView { container }
    init(frame: CGRect) { super.init(); container.frame = frame; layer.videoGravity = .resizeAspect }
}
private final class CameraViewFactory: NSObject, FlutterPlatformViewFactory {
    let plugin: DaliCameraPlatformPlugin
    init(plugin: DaliCameraPlatformPlugin) { self.plugin = plugin }
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let view = CameraView(frame: frame)
        view.container.orientationChanged = { [weak plugin] orientation in plugin?.updateOrientation(orientation) }
        plugin.attach(view); return view
    }
}
