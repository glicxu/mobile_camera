#!/usr/bin/env swift

import AppKit
import AVFoundation
import CoreVideo

private let width = 886
private let height = 1920
private let fps: Int32 = 30
private let durationSeconds = 30.0
private let crossfadeSeconds = 0.55

private struct Scene {
    let sourceURL: URL
    let start: Double
    let end: Double
}

private enum PreviewError: Error, CustomStringConvertible {
    case usage
    case image(String)
    case writer(String)
    case reader(String)
    case missingTrack(String)

    var description: String {
        switch self {
        case .usage:
            return "usage: render_app_preview.swift OUTPUT_DIR AUDIO_WAV LIVE_COACHING PRO_CONTROLS FILTER_BEAUTIFY RESULT"
        case .image(let message), .writer(let message), .reader(let message), .missingTrack(let message):
            return message
        }
    }
}

private func loadCGImage(_ url: URL) throws -> CGImage {
    guard let image = NSImage(contentsOf: url) else {
        throw PreviewError.image("Could not open image: \(url.path)")
    }
    var rect = CGRect(origin: .zero, size: image.size)
    guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
        throw PreviewError.image("Could not decode image: \(url.path)")
    }
    return cgImage
}

private func fillRect(for image: CGImage, scale: CGFloat = 1, xOffset: CGFloat = 0, yOffset: CGFloat = 0) -> CGRect {
    let canvas = CGSize(width: width, height: height)
    let imageSize = CGSize(width: image.width, height: image.height)
    let baseScale = max(canvas.width / imageSize.width, canvas.height / imageSize.height)
    let drawSize = CGSize(width: imageSize.width * baseScale * scale, height: imageSize.height * baseScale * scale)
    return CGRect(
        x: (canvas.width - drawSize.width) / 2 + xOffset,
        y: (canvas.height - drawSize.height) / 2 + yOffset,
        width: drawSize.width,
        height: drawSize.height
    )
}

private func draw(_ image: CGImage, in context: CGContext, alpha: CGFloat, progress: Double, direction: CGFloat) {
    let eased = CGFloat(progress * progress * (3 - 2 * progress))
    let scale = 1 + 0.022 * eased
    let yOffset = direction * 12 * (eased - 0.5)
    context.saveGState()
    context.setAlpha(alpha)
    context.interpolationQuality = .high
    context.draw(image, in: fillRect(for: image, scale: scale, yOffset: yOffset))
    context.restoreGState()
}

private func writeJPEG(_ image: CGImage, to url: URL) throws {
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.94]) else {
        throw PreviewError.image("Could not encode storyboard frame: \(url.path)")
    }
    try data.write(to: url, options: .atomic)
}

private func renderStoryboard(_ images: [CGImage], outputDirectory: URL) throws {
    let names = [
        "01-live-coaching-886x1920.jpg",
        "02-professional-controls-886x1920.jpg",
        "03-filter-and-beautify-886x1920.jpg",
        "04-beautiful-result-886x1920.jpg",
    ]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    for (index, image) in images.enumerated() {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw PreviewError.image("Could not create storyboard canvas")
        }
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: fillRect(for: image))
        guard let rendered = context.makeImage() else {
            throw PreviewError.image("Could not render storyboard frame")
        }
        try writeJPEG(rendered, to: outputDirectory.appendingPathComponent(names[index]))
    }
}

private func makeSilentVideo(scenes: [Scene], images: [CGImage], outputURL: URL) throws {
    try? FileManager.default.removeItem(at: outputURL)
    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 12_000_000,
            AVVideoExpectedSourceFrameRateKey: fps,
            AVVideoMaxKeyFrameIntervalKey: fps * 2,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264High40,
        ],
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
    )
    guard writer.canAdd(input) else { throw PreviewError.writer("Cannot add preview video input") }
    writer.add(input)
    guard writer.startWriting() else { throw PreviewError.writer(writer.error?.localizedDescription ?? "Could not start video writer") }
    writer.startSession(atSourceTime: .zero)

    let frameCount = Int(durationSeconds * Double(fps))
    for frameIndex in 0..<frameCount {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
        autoreleasepool {
            var buffer: CVPixelBuffer?
            guard let pool = adaptor.pixelBufferPool,
                  CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
                  let pixelBuffer = buffer else {
                return
            }
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
            guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                  ) else { return }

            context.setFillColor(NSColor.black.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let time = Double(frameIndex) / Double(fps)
            let sceneIndex = scenes.lastIndex(where: { time >= $0.start }) ?? 0
            let scene = scenes[sceneIndex]
            let localProgress = min(1, max(0, (time - scene.start) / (scene.end - scene.start)))
            let direction: CGFloat = sceneIndex.isMultiple(of: 2) ? 1 : -1
            let fadeStart = scene.end - crossfadeSeconds
            if sceneIndex + 1 < scenes.count, time >= fadeStart {
                let fade = CGFloat(min(1, max(0, (time - fadeStart) / crossfadeSeconds)))
                draw(images[sceneIndex], in: context, alpha: 1 - fade, progress: localProgress, direction: direction)
                draw(images[sceneIndex + 1], in: context, alpha: fade, progress: 0, direction: -direction)
            } else {
                draw(images[sceneIndex], in: context, alpha: 1, progress: localProgress, direction: direction)
            }
            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: fps)
            if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                fputs("Frame append failed: \(writer.error?.localizedDescription ?? "unknown error")\n", stderr)
            }
        }
    }
    input.markAsFinished()
    writer.endSession(atSourceTime: CMTime(seconds: durationSeconds, preferredTimescale: 600))
    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting { semaphore.signal() }
    semaphore.wait()
    guard writer.status == .completed else {
        throw PreviewError.writer(writer.error?.localizedDescription ?? "Video writer did not complete")
    }
}

private func mux(videoURL: URL, audioURL: URL, outputURL: URL) throws {
    try? FileManager.default.removeItem(at: outputURL)
    let videoAsset = AVURLAsset(url: videoURL)
    let audioAsset = AVURLAsset(url: audioURL)
    guard let sourceVideoTrack = videoAsset.tracks(withMediaType: .video).first else {
        throw PreviewError.missingTrack("Silent preview has no video track")
    }
    guard let sourceAudioTrack = audioAsset.tracks(withMediaType: .audio).first else {
        throw PreviewError.missingTrack("AudioLab file has no audio track")
    }

    let composition = AVMutableComposition()
    guard let compositionVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
          let compositionAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        throw PreviewError.writer("Could not create preview composition tracks")
    }
    try compositionVideo.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: durationSeconds, preferredTimescale: 600)), of: sourceVideoTrack, at: .zero)
    let audioDuration = min(audioAsset.duration, CMTime(seconds: durationSeconds, preferredTimescale: 600))
    try compositionAudio.insertTimeRange(CMTimeRange(start: .zero, duration: audioDuration), of: sourceAudioTrack, at: .zero)

    let reader = try AVAssetReader(asset: composition)
    let videoOutput = AVAssetReaderTrackOutput(track: compositionVideo, outputSettings: nil)
    let audioOutput = AVAssetReaderTrackOutput(track: compositionAudio, outputSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 48_000,
        AVNumberOfChannelsKey: 2,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ])
    guard reader.canAdd(videoOutput), reader.canAdd(audioOutput) else {
        throw PreviewError.reader("Could not configure preview media reader")
    }
    reader.add(videoOutput)
    reader.add(audioOutput)

    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: sourceVideoTrack.formatDescriptions.first as! CMFormatDescription?)
    let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 48_000,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 256_000,
    ])
    videoInput.expectsMediaDataInRealTime = false
    audioInput.expectsMediaDataInRealTime = false
    guard writer.canAdd(videoInput), writer.canAdd(audioInput) else {
        throw PreviewError.writer("Could not configure final preview writer")
    }
    writer.add(videoInput)
    writer.add(audioInput)
    guard writer.startWriting(), reader.startReading() else {
        throw PreviewError.writer(writer.error?.localizedDescription ?? reader.error?.localizedDescription ?? "Could not start final preview encoding")
    }
    writer.startSession(atSourceTime: .zero)

    let group = DispatchGroup()
    let videoQueue = DispatchQueue(label: "dali.preview.video")
    let audioQueue = DispatchQueue(label: "dali.preview.audio")
    group.enter()
    videoInput.requestMediaDataWhenReady(on: videoQueue) {
        while videoInput.isReadyForMoreMediaData {
            if let sample = videoOutput.copyNextSampleBuffer() {
                if !videoInput.append(sample) { reader.cancelReading(); break }
            } else {
                videoInput.markAsFinished()
                group.leave()
                break
            }
        }
    }
    group.enter()
    audioInput.requestMediaDataWhenReady(on: audioQueue) {
        while audioInput.isReadyForMoreMediaData {
            if let sample = audioOutput.copyNextSampleBuffer() {
                if !audioInput.append(sample) { reader.cancelReading(); break }
            } else {
                audioInput.markAsFinished()
                group.leave()
                break
            }
        }
    }
    group.wait()
    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting { semaphore.signal() }
    semaphore.wait()
    guard writer.status == .completed, reader.status == .completed else {
        throw PreviewError.writer(writer.error?.localizedDescription ?? reader.error?.localizedDescription ?? "Final preview encoding did not complete")
    }
}

do {
    guard CommandLine.arguments.count == 7 else { throw PreviewError.usage }
    let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let audioURL = URL(fileURLWithPath: CommandLine.arguments[2])
    let sourceURLs = CommandLine.arguments[3...6].map { URL(fileURLWithPath: $0) }
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    let storyboardDirectory = outputDirectory.appendingPathComponent("storyboard", isDirectory: true)
    try FileManager.default.createDirectory(at: storyboardDirectory, withIntermediateDirectories: true)
    let images = try sourceURLs.map(loadCGImage)
    try renderStoryboard(images, outputDirectory: storyboardDirectory)

    let scenes = [
        Scene(sourceURL: sourceURLs[0], start: 0, end: 7.7),
        Scene(sourceURL: sourceURLs[1], start: 7.7, end: 12.8),
        Scene(sourceURL: sourceURLs[2], start: 12.8, end: 20.5),
        Scene(sourceURL: sourceURLs[3], start: 20.5, end: 30),
    ]
    let silentURL = outputDirectory.appendingPathComponent("dali-cam-app-preview-silent.mp4")
    let finalURL = outputDirectory.appendingPathComponent("dali-cam-app-preview-30s.mp4")
    try makeSilentVideo(scenes: scenes, images: images, outputURL: silentURL)
    try mux(videoURL: silentURL, audioURL: audioURL, outputURL: finalURL)
    try? FileManager.default.removeItem(at: silentURL)
    print(finalURL.path)
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
