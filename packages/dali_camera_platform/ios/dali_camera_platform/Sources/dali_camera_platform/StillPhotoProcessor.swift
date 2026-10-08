import UIKit
import CoreImage
import Vision

/// File-backed processing. Geometry and effects reuse the native reference algorithms.
final class StillPhotoProcessor {
    private let context = CIContext()
    private let algorithms = ReferenceMeasurementAlgorithms()

    private func load(_ photo: PhotoHandle) throws -> UIImage {
        guard let input = CIImage(contentsOf: URL(fileURLWithPath: photo.path), options: [.applyOrientationProperty: true]),
              let cgImage = context.createCGImage(input, from: input.extent) else { throw error("Cannot decode photo") }
        return UIImage(cgImage: cgImage)
    }
    private func error(_ message: String) -> NSError {
        NSError(domain: "DaliProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    private func rect(_ value: CGRect) -> [String: Double] {
        ["x": Double(value.minX), "y": Double(value.minY), "width": Double(value.width), "height": Double(value.height)]
    }
    private func box(_ value: DetectionBox?) -> [[String: Any]] {
        guard let value else { return [] }
        var result: [String: Any] = rect(value.rect)
        result["confidence"] = value.confidence; result["label"] = value.label
        return [result]
    }
    private func reflected(_ value: Any) -> [String: Any] {
        var result: [String: Any] = [:]
        for child in Mirror(reflecting: value).children {
            guard let label = child.label else { continue }
            let mirror = Mirror(reflecting: child.value)
            if mirror.displayStyle == .optional { result[label] = mirror.children.first?.value ?? NSNull() }
            else { result[label] = child.value }
        }
        return result
    }
    func analyze(_ photo: PhotoHandle) throws -> String {
        let image = try load(photo)
        let measurements = try algorithms.analyzeImage(cgImage: image.cgImage!, orientation: .up).measurements
        var packet: [String: Any] = [
            "schemaVersion": 1, "sourceId": photo.id, "frameId": "still-\(photo.id)", "configurationId": "still-\(photo.id)",
            "timestamp": Int(Date().timeIntervalSince1970 * 1000), "imageWidth": image.cgImage!.width,
            "imageHeight": image.cgImage!.height, "displayRotationDegrees": 0, "front": false,
            "people": box(measurements.personBox), "faces": box(measurements.faceBox),
            "peopleStatus": "valid", "faceStatus": "valid", "peopleScope": "multiple",
            "motionStatus": "unsupported", "luminanceScale": 255, "saliencyStatus": "valid",
            "openAreaStatus": "valid", "openAreaRatio": measurements.skyOrOpenAreaRatio,
            "horizonStatus": measurements.horizonAngleDegrees == nil ? "unavailable" : "valid",
            "horizonConfidence": measurements.horizonConfidence,
            "backgroundLuminance": measurements.backgroundLuminance as Any? ?? NSNull(),
            "faceLuminance": measurements.faceLuminance as Any? ?? NSNull(),
            "poseStatus": "valid", "poseKeypoints": measurements.poseKeypoints.mapValues { value in
                ["x": value.point.x, "y": value.point.y, "confidence": value.confidence]
            }
        ]
        if let group = measurements.groupAnalysis {
            var value = reflected(group); value["groupBounds"] = group.groupBounds.map(rect) ?? [:]
            packet["groupAnalysis"] = value
        }
        if let face = measurements.faceAnalysis { packet["faceAnalysis"] = reflected(face) }
        if let pose = measurements.poseAnalysis { packet["poseAnalysis"] = reflected(pose) }
        if let angle = measurements.horizonAngleDegrees { packet["horizon"] = ["angleDegrees": angle, "normalizedY": 0.5] }
        if let object = box(measurements.salientObjectBox).first { packet["salientObject"] = object }
        if let suggestion = algorithms.reframeSuggestion(for: measurements, imageSize: image.size) {
            packet["reframe"] = ["crop": rect(suggestion.cropRect), "instruction": suggestion.instruction,
                "confidence": suggestion.confidence, "reason": suggestion.reason]
        }
        packet["issues"] = CoachingEngine().issues(for: measurements, includePosture: true).map {
            ["type": $0.type, "instruction": $0.instruction, "recipient": $0.recipient, "severity": $0.severity]
        }
        let data = try JSONSerialization.data(withJSONObject: packet, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
    func render(_ photo: PhotoHandle, recipe: String) throws -> UIImage {
        guard recipe.utf8.count < 16384,
              let request = try JSONSerialization.jsonObject(with: Data(recipe.utf8)) as? [String: Any],
              request["version"] as? Int == 1 else { throw error("Unsupported photo recipe") }
        let treatment = request["treatment"] as? String ?? "original"
        guard ["original", "reframe", "level", "enhance", "portrait", "landscape"].contains(treatment) else { throw error("Unknown treatment") }
        let strength = max(0, min(5, request["strength"] as? Int ?? 0))
        let flags = request["flags"] as? [String: Bool] ?? [:]
        let filter = request["filter"] as? [Double] ?? Array(repeating: 0, count: 7)
        guard filter.count == 7, filter.allSatisfy({ $0.isFinite }) else { throw error("Invalid filter parameters") }
        var image = try load(photo)
        let measurements = try algorithms.analyzeImage(cgImage: image.cgImage!, orientation: .up).measurements
        image = PhotoFilterEngine().apply(to: image, settings: PhotoFilterSettings(exposure: Int(filter[0].clamped(-5, 5)), warmth: Int(filter[1].clamped(-5, 5)), color: Int(filter[2].clamped(0, 5)), contrast: Int(filter[3].clamped(-5, 5)), softness: Int(filter[4].clamped(0, 5)), detail: Int(filter[5].clamped(0, 5)), blueSky: Int(filter[6].clamped(0, 5))))
        switch treatment {
        case "reframe":
            guard let suggestion = algorithms.reframeSuggestion(for: measurements, imageSize: image.size),
                  let cropped = algorithms.croppedImage(image, to: suggestion.cropRect) else { throw error("No confident reframe is available") }
            image = cropped
        case "level":
            guard let leveled = algorithms.leveledImage(image, measurements: measurements) else { throw error("No confident horizon correction is available") }
            image = leveled
        case "enhance":
            var settings = EnhanceSettings(); settings.strength = strength
            settings.autoToneEnabled = flags["autoTone"] ?? true; settings.warmthEnabled = flags["warmth"] ?? true
            settings.vibranceEnabled = flags["vibrance"] ?? true; settings.clarityEnabled = flags["clarity"] ?? true
            settings.noiseReductionEnabled = flags["noiseReduction"] ?? true; settings.subjectEmphasisEnabled = flags["subjectEmphasis"] ?? true
            image = EnhanceEngine().apply(to: image, measurements: measurements, settings: settings).image
        case "portrait", "landscape":
            var settings = BeautifySettings(); settings.strength = strength
            let portrait = treatment == "portrait"
            settings.landscapeSkyEnabled = !portrait && (flags["sky"] ?? true)
            settings.landscapeColorEnabled = !portrait && (flags["landscapeColor"] ?? true)
            settings.faceBrightnessEnabled = portrait && (flags["faceBrightness"] ?? true)
            settings.skinSmoothingEnabled = portrait && (flags["skinSmoothing"] ?? true)
            settings.blemishReductionEnabled = portrait && (flags["blemishReduction"] ?? true)
            settings.eyeEnlargementEnabled = portrait && (flags["eyeEnlargement"] ?? true)
            settings.lipPlumpingEnabled = portrait && (flags["lipPlumping"] ?? false)
            if portrait && measurements.faceBox == nil && strength > 0 { throw error("No face is available for Portrait Polish") }
            image = BeautifyEngine().apply(to: image, measurements: measurements, settings: settings).image
        default: break
        }
        let depth = max(0, min(5, request["depth"] as? Int ?? 0))
        if depth > 0 {
            let point = request["focus"] as? [String: Double]
            let focus = point.flatMap { value -> CGPoint? in
                guard let x = value["x"], let y = value["y"], x.isFinite, y.isFinite else { return nil }
                return CGPoint(x: x.clamped(0, 1), y: y.clamped(0, 1))
            }
            image = DepthBlurEngine().apply(to: image, measurements: measurements, focusPoint: focus, level: depth)
        }
        return image
    }
}

private extension Double { func clamped(_ low: Double, _ high: Double) -> Double { Swift.min(high, Swift.max(low, self)) } }
