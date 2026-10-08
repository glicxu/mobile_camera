import Flutter
import UIKit
import AVFoundation
import Vision
import CoreMotion
import Photos
import PhotosUI
import CoreImage
import ImageIO
import UniformTypeIdentifiers

public final class DaliCameraPlatformPlugin: NSObject, FlutterPlugin, CameraHostApi, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, PHPickerViewControllerDelegate, UIDocumentPickerDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "dali.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private let motion = CMMotionManager()
    private let ci = CIContext()
    private let stillProcessor = StillPhotoProcessor()
    private let speech = SpeechShutterService()
    private var events: CameraEvents!
    private var preview: CameraView?
    private var device: AVCaptureDevice?
    private var front = false
    private var configuration = ""
    private var captureCompletion: ((Result<PhotoHandle, Error>) -> Void)?
    private var pickerCompletion: ((Result<PhotoImport, Error>) -> Void)?
    private let importQueue = DispatchQueue(label: "dali.import")
    private var lastFrame = CFAbsoluteTimeGetCurrent()
    private var lastState = CFAbsoluteTimeGetCurrent()
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
        plugin.speech.onState = { [weak plugin] listening, status in plugin?.events.voiceState(listening: listening, status: status) { _ in } }
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
            locked: device?.focusMode == .locked && device?.exposureMode == .locked,
            minimumZoom: Double(device?.minAvailableVideoZoomFactor ?? 1), maximumZoom: Double(device?.maxAvailableVideoZoomFactor ?? 1), currentZoom: Double(device?.videoZoomFactor ?? 1),
            supportsTap: device?.isFocusPointOfInterestSupported == true,
            minimumISO: device?.isExposureModeSupported(.custom) == true ? Double(device!.activeFormat.minISO) : nil,
            maximumISO: device?.isExposureModeSupported(.custom) == true ? Double(device!.activeFormat.maxISO) : nil,
            minimumShutter: device?.isExposureModeSupported(.custom) == true ? CMTimeGetSeconds(device!.activeFormat.minExposureDuration) : nil,
            maximumShutter: device?.isExposureModeSupported(.custom) == true ? min(0.5, CMTimeGetSeconds(device!.activeFormat.maxExposureDuration)) : nil,
            currentISO: Double(device?.iso ?? 100), currentShutter: device.map { CMTimeGetSeconds($0.exposureDuration) }, manualExposure: device?.exposureMode == .custom,
            currentAperture: device.map { Double($0.lensAperture) }, exposureOffset: device.map { Double($0.exposureTargetOffset) },
            cameraName: device?.localizedName, lensName: device?.deviceType == .builtInWideAngleCamera ? "Wide Angle" : device?.localizedName)
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
        preview?.container.depthLevel = 0
        preview?.container.subjectRect = nil
        preview?.container.setNeedsLayout()
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
    func stop() throws { active = false; generation = UUID(); speech.stop(); preview?.container.depthLevel = 0; preview?.container.setNeedsLayout(); motion.stopDeviceMotionUpdates(); queue.async { self.session.stopRunning() } }
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
        guard let data = try JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: String] else { throw failure("Invalid recovery manifest; original retained") }
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
        sheet.completionWithItemsHandler = { _, _, _, error in
            if let error { completion(.failure(error)) } else { completion(.success(())) }
        }
        presenter.present(sheet, animated: true)
    }
    func pickPhoto(completion: @escaping (Result<PhotoHandle?, Error>) -> Void) {
        beginPicker(folder: false, limit: 1) { result in completion(result.map { $0.photos.first }) }
    }
    func listPhotoLibrary(completion: @escaping (Result<PhotoLibrary, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion(.success(PhotoLibrary(photos: [], status: "denied"))) }; return
            }
            self.importQueue.async {
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let assets = PHAsset.fetchAssets(with: .image, options: options)
                let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .short
                var photos: [LibraryPhoto] = []
                assets.enumerateObjects { asset, _, _ in
                    photos.append(LibraryPhoto(id: asset.localIdentifier, title: asset.creationDate.map { formatter.string(from: $0) } ?? "Photo"))
                }
                let access = photos.isEmpty ? "empty" : status == .limited ? "limited" : "authorized"
                DispatchQueue.main.async { completion(.success(PhotoLibrary(photos: photos, status: access))) }
            }
        }
    }
    func loadLibraryPhoto(id: String, completion: @escaping (Result<PhotoHandle, Error>) -> Void) {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            completion(.failure(failure("Photo is no longer accessible"))); return
        }
        let options = PHImageRequestOptions(); options.isNetworkAccessAllowed = true; options.version = .original; options.deliveryMode = .highQualityFormat
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
            guard let data, info?[PHImageCancelledKey] as? Bool != true, info?[PHImageErrorKey] == nil else {
                DispatchQueue.main.async { completion(.failure(self.failure("Could not load library photo; check iCloud connectivity"))) }; return
            }
            self.importQueue.async {
                do {
                    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    defer { try? FileManager.default.removeItem(at: temporary) }
                    try data.write(to: temporary, options: .atomic)
                    let photo = try self.copyImportedPhoto(temporary)
                    DispatchQueue.main.async { completion(.success(photo)) }
                } catch { DispatchQueue.main.async { completion(.failure(error)) } }
            }
        }
    }
    func pickPhotos(folder: Bool, completion: @escaping (Result<PhotoImport, Error>) -> Void) {
        beginPicker(folder: folder, limit: folder ? 50 : 20, completion: completion)
    }
    private func beginPicker(folder: Bool, limit: Int, completion: @escaping (Result<PhotoImport, Error>) -> Void) {
        guard let presenter, pickerCompletion == nil else { completion(.failure(failure("Photo picker unavailable"))); return }
        pickerCompletion = completion
        if folder {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            picker.delegate = self
            presenter.present(picker, animated: true)
        } else {
            var config = PHPickerConfiguration(); config.filter = .images; config.selectionLimit = limit; config.selection = .ordered
            config.preferredAssetRepresentationMode = .current
            let picker = PHPickerViewController(configuration: config); picker.delegate = self
            presenter.present(picker, animated: true)
        }
    }
    private func finishImport(_ result: Result<PhotoImport, Error>) {
        DispatchQueue.main.async {
            let completion = self.pickerCompletion; self.pickerCompletion = nil
            completion?(result)
        }
    }
    private func copyImportedPhoto(_ sourceURL: URL) throws -> PhotoHandle {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let identifier = CGImageSourceGetType(source),
              let type = UTType(identifier as String), type.conforms(to: .image),
              CGImageSourceCopyPropertiesAtIndex(source, 0, nil) != nil else { throw failure("Cannot decode selected photo") }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let destination = directory.appendingPathComponent("import-\(id).\(type.preferredFilenameExtension ?? "jpg")")
        do { try FileManager.default.copyItem(at: sourceURL, to: destination) }
        catch { try? FileManager.default.removeItem(at: destination); throw error }
        return PhotoHandle(path: destination.path, id: id, unsaved: false, mimeType: type.preferredMIMEType)
    }
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        loadPickedPhotos(Array(results.prefix(20)), index: 0, photos: [], skipped: max(0, results.count - 20))
    }
    private func loadPickedPhotos(_ results: [PHPickerResult], index: Int, photos: [PhotoHandle], skipped: Int) {
        guard index < results.count else {
            if !results.isEmpty && photos.isEmpty { finishImport(.failure(failure("No readable images were found"))) }
            else { finishImport(.success(PhotoImport(photos: photos, skipped: Int64(skipped)))) }
            return
        }
        // Copy each temporary provider file inside its completion lifetime. Do not decode/recompress originals.
        results[index].itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
            var next = photos; var missed = skipped
            if error == nil, let url, let photo = try? self.copyImportedPhoto(url) { next.append(photo) }
            else { missed += 1 }
            self.loadPickedPhotos(results, index: index + 1, photos: next, skipped: missed)
        }
    }
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finishImport(.success(PhotoImport(photos: [], skipped: 0)))
    }
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let folder = urls.first else { finishImport(.success(PhotoImport(photos: [], skipped: 0))); return }
        importQueue.async {
            let access = folder.startAccessingSecurityScopedResource()
            defer { if access { folder.stopAccessingSecurityScopedResource() } }
            var photos: [PhotoHandle] = []; var skipped = 0
            let keys: [URLResourceKey] = [.isRegularFileKey, .contentTypeKey]
            guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
                self.finishImport(.failure(self.failure("Could not open folder"))); return
            }
            var candidates: [URL] = []
            var visited = 0
            for case let url as URL in enumerator {
                visited += 1
                if visited > 4096 { break }
                if enumerator.level > 16 { enumerator.skipDescendants(); continue }
                if let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true,
                   values.contentType?.conforms(to: .image) == true { candidates.append(url) }
            }
            candidates.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            skipped = max(0, candidates.count - 50)
            for url in candidates.prefix(50) {
                if let photo = try? self.copyImportedPhoto(url) { photos.append(photo) } else { skipped += 1 }
            }
            if photos.isEmpty { self.finishImport(.failure(self.failure("No readable images were found"))) }
            else { self.finishImport(.success(PhotoImport(photos: photos, skipped: Int64(skipped)))) }
        }
    }
    func analyzePhoto(photo: PhotoHandle, completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            do {
                let result = try autoreleasepool { try self.stillProcessor.analyze(photo) }
                DispatchQueue.main.async { completion(.success(result)) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    func renderEffects(original: PhotoHandle, recipe: String, completion: @escaping (Result<PhotoHandle, Error>) -> Void) {
        queue.async {
            do {
                let result = try autoreleasepool { () throws -> PhotoHandle in
                    var image = try self.stillProcessor.render(original, recipe: recipe)
                    let request = try JSONSerialization.jsonObject(with: Data(recipe.utf8)) as? [String: Any]
                    if let path = request?["watermarkPath"] as? String,
                       let mark = CIImage(contentsOf: URL(fileURLWithPath: path)), let input = CIImage(image: image) {
                        let extent = input.extent
                        let width = extent.width * 0.23
                        let scale = width / mark.extent.width
                        let margin = extent.width * 0.025
                        let positioned = mark.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                            .transformed(by: CGAffineTransform(translationX: extent.maxX - width - margin, y: extent.minY + margin))
                            .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.86)])
                        guard let output = self.ci.createCGImage(positioned.composited(over: input), from: extent) else { throw self.failure("Cannot render watermark") }
                        image = UIImage(cgImage: output)
                    }
                    guard let data = image.jpegData(compressionQuality: 0.95) else { throw self.failure("Cannot render effects") }
                    let handle = try self.newPhoto()
                    try data.write(to: URL(fileURLWithPath: handle.path), options: .atomic)
                    return handle
                }
                DispatchQueue.main.async { completion(.success(result)) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
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
                guard self.active, configurationId == self.configuration, let device = self.device, device.exposureMode != .custom else { throw self.failure("Camera changed or manual exposure active; refresh controls") }
                try device.lockForConfiguration(); defer { device.unlockForConfiguration() }
                device.setExposureTargetBias(Float(ev).clamped(device.minExposureTargetBias, device.maxExposureTargetBias), completionHandler: nil)
                if device.isFocusModeSupported(locked ? .locked : .continuousAutoFocus) { device.focusMode = locked ? .locked : .continuousAutoFocus }
                if device.isExposureModeSupported(locked ? .locked : .continuousAutoExposure) { device.exposureMode = locked ? .locked : .continuousAutoExposure }
                DispatchQueue.main.async { completion(.success(self.snapshot())) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    func renderStyle(original: PhotoHandle, matrix: [Double], softness: Double, detail: Double, watermarkPath: String?, completion: @escaping (Result<PhotoHandle, Error>) -> Void) {
        queue.async {
            do {
                guard matrix.count == 20, matrix.allSatisfy({ $0.isFinite }), softness.isFinite, detail.isFinite,
                      var image = CIImage(contentsOf: URL(fileURLWithPath: original.path), options: [.applyOrientationProperty: true]) else { throw self.failure("Invalid style or photo") }
                let extent = image.extent
                image = image.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: matrix[0], y: matrix[1], z: matrix[2], w: matrix[3]),
                    "inputGVector": CIVector(x: matrix[5], y: matrix[6], z: matrix[7], w: matrix[8]),
                    "inputBVector": CIVector(x: matrix[10], y: matrix[11], z: matrix[12], w: matrix[13]),
                    "inputAVector": CIVector(x: matrix[15], y: matrix[16], z: matrix[17], w: matrix[18]),
                    "inputBiasVector": CIVector(x: matrix[4]/255, y: matrix[9]/255, z: matrix[14]/255, w: matrix[19]/255)
                ])
                if softness > 0 { image = image.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: min(5, softness) * 0.3]).cropped(to: extent) }
                if detail > 0 { image = image.applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: 2, kCIInputIntensityKey: min(5, detail) * 0.08]).cropped(to: extent) }
                if let watermarkPath {
                    guard var mark = CIImage(contentsOf: URL(fileURLWithPath: watermarkPath)) else { throw self.failure("Cannot load watermark") }
                    let scale = extent.width * 0.28 / mark.extent.width
                    mark = mark.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    let margin = max(18, extent.width * 0.025)
                    mark = mark.transformed(by: CGAffineTransform(translationX: extent.maxX - mark.extent.maxX - margin, y: extent.minY - mark.extent.minY + margin))
                    mark = mark.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.86)])
                    image = mark.composited(over: image)
                }
                guard let output = self.ci.createCGImage(image, from: extent), let data = UIImage(cgImage: output).jpegData(compressionQuality: 0.95) else { throw self.failure("Cannot render style") }
                let handle = try self.newPhoto(); try data.write(to: URL(fileURLWithPath: handle.path), options: .atomic)
                DispatchQueue.main.async { completion(.success(handle)) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    func renderFilter(original: PhotoHandle, matrix: [Double], parameters: [Double], watermarkPath: String?, completion: @escaping (Result<PhotoHandle, Error>) -> Void) {
        queue.async {
            do {
                guard matrix.count == 20, matrix.allSatisfy({ $0.isFinite }), parameters.count == 7, parameters.allSatisfy({ $0.isFinite }),
                      var image = CIImage(contentsOf: URL(fileURLWithPath: original.path), options: [.applyOrientationProperty: true]) else { throw self.failure("Invalid style or photo") }
                let extent = image.extent
                image = ReferencePhotoFilter.apply(image, parameters: parameters)
                if let watermarkPath {
                    guard var mark = CIImage(contentsOf: URL(fileURLWithPath: watermarkPath)) else { throw self.failure("Cannot load watermark") }
                    let scale = extent.width * 0.28 / mark.extent.width
                    mark = mark.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    let margin = max(18, extent.width * 0.025)
                    mark = mark.transformed(by: CGAffineTransform(translationX: extent.maxX - mark.extent.maxX - margin, y: extent.minY - mark.extent.minY + margin))
                    mark = mark.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.86)])
                    image = mark.composited(over: image)
                }
                guard let output = self.ci.createCGImage(image, from: extent), let data = UIImage(cgImage: output).jpegData(compressionQuality: 0.95) else { throw self.failure("Cannot render style") }
                let handle = try self.newPhoto(); try data.write(to: URL(fileURLWithPath: handle.path), options: .atomic)
                DispatchQueue.main.async { completion(.success(handle)) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    func setZoom(configurationId: String, zoom: Double, completion: @escaping (Result<CameraSnapshot, Error>) -> Void) {
        queue.async {
            do {
                guard self.active, configurationId == self.configuration, zoom.isFinite, let device = self.device else { throw self.failure("Camera changed or invalid zoom") }
                try device.lockForConfiguration(); defer { device.unlockForConfiguration() }
                device.videoZoomFactor = CGFloat(zoom).clamped(device.minAvailableVideoZoomFactor, device.maxAvailableVideoZoomFactor)
                DispatchQueue.main.async { completion(.success(self.snapshot())) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    func meter(configurationId: String, x: Double, y: Double, focusOnly: Bool, completion: @escaping (Result<CameraSnapshot, Error>) -> Void) {
        guard let layer = preview?.layer, x.isFinite, y.isFinite else { completion(.failure(failure("No preview or invalid focus point"))); return }
        let point = layer.captureDevicePointConverted(fromLayerPoint: CGPoint(x: min(1, max(0, x)) * layer.bounds.width, y: min(1, max(0, y)) * layer.bounds.height))
        queue.async {
            do {
                guard self.active, configurationId == self.configuration, let device = self.device, device.isFocusPointOfInterestSupported else { throw self.failure("Focus point unavailable or camera changed") }
                try device.lockForConfiguration(); defer { device.unlockForConfiguration() }
                device.focusPointOfInterest = point
                if device.isFocusModeSupported(.autoFocus) { device.focusMode = .autoFocus }
                if !focusOnly && device.exposureMode != .custom && device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
                }
                DispatchQueue.main.async { completion(.success(self.snapshot())) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    func setManualExposure(configurationId: String, seconds: Double?, iso: Double?, resetFocus: Bool, completion: @escaping (Result<CameraSnapshot, Error>) -> Void) {
        queue.async {
            do {
                guard self.active, configurationId == self.configuration, let device = self.device else { throw self.failure("Camera changed; refresh controls") }
                try device.lockForConfiguration(); defer { device.unlockForConfiguration() }
                if let seconds, let iso {
                    guard seconds.isFinite, iso.isFinite, device.isExposureModeSupported(.custom) else { throw self.failure("Manual exposure unavailable") }
                    let duration = min(0.5, max(CMTimeGetSeconds(device.activeFormat.minExposureDuration), min(CMTimeGetSeconds(device.activeFormat.maxExposureDuration), seconds)))
                    device.setExposureModeCustom(duration: CMTime(seconds: duration, preferredTimescale: 1_000_000_000), iso: Float(iso).clamped(device.activeFormat.minISO, device.activeFormat.maxISO)) { _ in
                        DispatchQueue.main.async {
                            if self.active && configurationId == self.configuration { completion(.success(self.snapshot())) }
                            else { completion(.failure(self.failure("Camera changed"))) }
                        }
                    }
                } else {
                    if resetFocus && device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
                    if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
                    if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { device.whiteBalanceMode = .continuousAutoWhiteBalance }
                    device.setExposureTargetBias(0, completionHandler: nil)
                    DispatchQueue.main.async { completion(.success(self.snapshot())) }
                }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    func setVoicePhrase(phrase: String) throws { speech.customPhrase = phrase }
    func reconcilePrivatePhotos(retainedPaths: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            do {
                var keep = Set(retainedPaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path })
                if let pending = try self.recover() { keep.insert(URL(fileURLWithPath: pending.path).standardizedFileURL.path) }
                if FileManager.default.fileExists(atPath: self.directory.path) {
                    for url in try FileManager.default.contentsOfDirectory(at: self.directory, includingPropertiesForKeys: [.isRegularFileKey]) {
                        guard url.standardizedFileURL.deletingLastPathComponent() == self.directory.standardizedFileURL,
                              try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true,
                              !keep.contains(url.standardizedFileURL.path),
                              (url.lastPathComponent.hasPrefix("photo-") && url.pathExtension == "jpg") || url.lastPathComponent.hasPrefix("import-") else { continue }
                        try FileManager.default.removeItem(at: url)
                    }
                }
                DispatchQueue.main.async { completion(.success(())) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    func releasePhoto(photo: PhotoHandle) throws {
        let url = URL(fileURLWithPath: photo.path).standardizedFileURL
        guard url.deletingLastPathComponent() == directory.standardizedFileURL, (url.pathExtension == "jpg" || url.lastPathComponent.hasPrefix("import-")), try recover()?.id != photo.id else { return }
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    func openSettings() throws { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
    func setVoiceEnabled(enabled: Bool, completion: @escaping (Result<Bool, Error>) -> Void) { speech.setEnabled(enabled, completion: completion) }
    func setDepthPreview(configurationId: String, level: Int64, subjectRect: String?) throws {
        guard configurationId == configuration else { return }
        let value = subjectRect.flatMap { $0.data(using: .utf8) }.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Double] }
        let rect = value.flatMap { data -> CGRect? in
            guard let x = data["x"], let y = data["y"], let w = data["width"], let h = data["height"], [x,y,w,h].allSatisfy({ $0.isFinite }), w > 0, h > 0 else { return nil }
            return CGRect(x: x, y: y, width: w, height: h)
        }
        preview?.container.depthLevel = Int(max(0, min(5, level)))
        preview?.container.subjectRect = rect
        preview?.container.setNeedsLayout()
    }
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CFAbsoluteTimeGetCurrent(); guard active, now - lastFrame > 0.15, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrame = now; let epoch = generation
        let people = VNDetectHumanRectanglesRequest(); people.upperBodyOnly = false
        let faces = VNDetectFaceLandmarksRequest()
        let pose = VNDetectHumanBodyPoseRequest()
        let geometry = ReferenceMeasurementAlgorithms()
        let saliency = VNGenerateObjectnessBasedSaliencyImageRequest()
        let horizon = VNDetectHorizonRequest()
        do {
            let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
            try handler.perform([people, faces])
            var poseStatus = "unavailable"
            do { try handler.perform([pose]); poseStatus = "valid" } catch {}
            // Optional requests must not suppress working person/face analysis.
            var saliencyStatus = "unavailable"
            var horizonStatus = "unavailable"
            do { try handler.perform([saliency]); saliencyStatus = "valid" } catch {}
            do { try handler.perform([horizon]); horizonStatus = "valid" } catch {}
            func boxes(_ observations: [VNDetectedObjectObservation]) -> [[String: Any]] { observations.map { obs in
                let r = obs.boundingBox
                return ["x": r.minX, "y": 1-r.maxY, "width": r.width, "height": r.height, "confidence": obs.confidence, "label": "detection"]
            }}
            aspect = Double(CVPixelBufferGetWidth(buffer)) / Double(CVPixelBufferGetHeight(buffer))
            var data: [String: Any] = ["schemaVersion": 1, "frameId": "\(epoch):\(now)",
                "imageWidth": CVPixelBufferGetWidth(buffer), "imageHeight": CVPixelBufferGetHeight(buffer),
                "displayRotationDegrees": Int(rotation), "front": front,
                "motionStatus": motion.isDeviceMotionAvailable ? "valid" : "unsupported",
                "timestamp": Int(Date().timeIntervalSince1970 * 1000), "configurationId": configuration, "aspectRatio": aspect,
                "people": boxes(people.results ?? []), "faces": boxes(faces.results ?? []), "roll": currentRoll,
                "motion": currentMotion, "stable": currentMotion < 0.22, "peopleStatus": "valid", "faceStatus": "valid", "horizonStatus": horizonStatus, "openAreaStatus": "unsupported",
                "peopleScope": "multiple", "saliencyStatus": saliencyStatus]
            let humanBoxes = (people.results ?? []).map { DetectionBox(rect: geometry.normalizedTopLeftRect($0.boundingBox), confidence: CGFloat($0.confidence), label: "person") }
            let faceBoxes = (faces.results ?? []).map { DetectionBox(rect: geometry.normalizedTopLeftRect($0.boundingBox), confidence: CGFloat($0.confidence), label: "face") }
            let humanBox = humanBoxes.max { $0.confidence < $1.confidence }
            let faceBox = faceBoxes.max { $0.confidence < $1.confidence }
            let points = geometry.poseKeypoints(from: pose.results ?? [])
            data["poseStatus"] = poseStatus
            data["poseKeypoints"] = points.mapValues { ["x": $0.point.x, "y": $0.point.y, "confidence": $0.confidence] }
            if let value = geometry.poseAnalysis(from: points, person: humanBox, face: faceBox) { data["poseAnalysis"] = stillProcessor.reflected(value) }
            if let value = geometry.faceAnalysis(from: faces.results?.max { $0.confidence < $1.confidence }, face: faceBox) { data["faceAnalysis"] = stillProcessor.reflected(value) }
            if let cg = ci.createCGImage(CIImage(cvPixelBuffer: buffer), from: CIImage(cvPixelBuffer: buffer).extent) {
                data["luminanceScale"] = 255
                data["backgroundLuminance"] = geometry.luminance(in: cg, normalizedRect: nil)
                data["faceLuminance"] = faceBox.flatMap { geometry.luminance(in: cg, normalizedRect: $0.rect) }
                data["openAreaRatio"] = geometry.skyOrOpenAreaRatio(in: cg)
                data["openAreaStatus"] = "valid"
            }
            if let object = saliency.results?.first?.salientObjects?.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
                data["salientObject"] = boxes([object]).first
            }
            if let observation = horizon.results?.first {
                data["horizon"] = ["angleDegrees": Double(observation.angle) * 180 / .pi, "normalizedY": 0.5]
                data["horizonConfidence"] = observation.confidence
            }
            let json = String(data: try JSONSerialization.data(withJSONObject: data), encoding: .utf8)!
            DispatchQueue.main.async {
                if epoch == self.generation && self.active {
                    self.events.analysis(json: json) { _ in }
                    if now - self.lastState > 1 { self.lastState = now; self.events.state(snapshot: self.snapshot()) { _ in } }
                }
            }
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
private extension CGFloat { func clamped(_ low: CGFloat, _ high: CGFloat) -> CGFloat { Swift.min(high, Swift.max(low, self)) } }
private extension Float { func clamped(_ low: Float, _ high: Float) -> Float { Swift.min(high, Swift.max(low, self)) } }
private final class PreviewContainer: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var orientationChanged: ((UIInterfaceOrientation) -> Void)?
    var depthLevel = 0
    var subjectRect: CGRect?
    private let depth = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    override func layoutSubviews() {
        super.layoutSubviews()
        if let orientation = window?.windowScene?.interfaceOrientation { orientationChanged?(orientation) }
        if depth.superview == nil { depth.isUserInteractionEnabled = false; depth.isAccessibilityElement = false; addSubview(depth) }
        depth.frame = bounds
        depth.isHidden = depthLevel == 0 || subjectRect == nil
        depth.alpha = 0.30 + Double(depthLevel) * 0.09
        guard let subjectRect, let preview = layer as? AVCaptureVideoPreviewLayer else { return }
        let content = preview.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
        let subject = CGRect(x: content.minX + subjectRect.minX * content.width, y: content.minY + subjectRect.minY * content.height, width: subjectRect.width * content.width, height: subjectRect.height * content.height)
        let path = UIBezierPath(rect: content)
        path.append(UIBezierPath(roundedRect: subject, cornerRadius: min(subject.width, subject.height) * 0.28))
        let mask = CAShapeLayer(); mask.frame = bounds; mask.path = path.cgPath; mask.fillRule = .evenOdd
        depth.layer.mask = mask
    }
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
