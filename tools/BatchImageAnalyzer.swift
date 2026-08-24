import CoreGraphics
import Foundation
import ImageIO
import Vision

struct ImageResult {
    let fileName: String
    let imagePath: String
    let imageSize: CGSize
    let measurements: Measurements
    let issues: [PhotoIssue]
}

struct SignalSummary {
    let name: String
    let values: [Double]
    let coverageCount: Int
    let totalCount: Int
    let duplicateMaxDelta: Double?

    var coverageRatio: Double {
        guard totalCount > 0 else { return 0 }
        return Double(coverageCount) / Double(totalCount)
    }

    var minValue: Double? {
        values.min()
    }

    var maxValue: Double? {
        values.max()
    }

    var meanValue: Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var range: Double? {
        guard let minValue, let maxValue else { return nil }
        return maxValue - minValue
    }

    var rating: String {
        if coverageRatio < 0.6 {
            return "weak coverage"
        }

        if let duplicateMaxDelta, duplicateMaxDelta > 0.08 {
            return "unstable"
        }

        if let range, range < 0.06 {
            return "low separation"
        }

        return "promising"
    }
}

final class BatchImageAnalyzer {
    private let coachingEngine = CoachingEngine()

    func analyze(urls: [URL]) -> [ImageResult] {
        urls.compactMap { url in
            guard let loaded = loadImage(url) else {
                return nil
            }

            let measurements = analyze(cgImage: loaded.image, orientation: loaded.orientation)
            let issues = coachingEngine.issues(for: measurements, includePosture: true)
            return ImageResult(
                fileName: url.lastPathComponent,
                imagePath: url.path,
                imageSize: CGSize(width: loaded.image.width, height: loaded.image.height),
                measurements: measurements,
                issues: issues
            )
        }
    }

    private func analyze(cgImage: CGImage, orientation: CGImagePropertyOrientation) -> Measurements {
        let humanRequest = VNDetectHumanRectanglesRequest()
        humanRequest.upperBodyOnly = false
        let faceRequest = VNDetectFaceLandmarksRequest()
        let poseRequest = VNDetectHumanBodyPoseRequest()
        let horizonRequest = VNDetectHorizonRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        do {
            try handler.perform([humanRequest, faceRequest, poseRequest, horizonRequest])
        } catch {
            return emptyMeasurements()
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

        return Measurements(
            personBox: person,
            faceBox: face,
            groupAnalysis: groupAnalysis(people: people, faces: faces),
            faceAnalysis: faceAnalysis(from: faceObservation, face: face),
            poseKeypoints: poseKeypoints,
            poseAnalysis: poseAnalysis(from: poseKeypoints, person: person, face: face),
            faceLuminance: face.flatMap { luminance(in: cgImage, normalizedRect: $0.rect) },
            backgroundLuminance: luminance(in: cgImage, normalizedRect: nil),
            horizonAngleDegrees: horizon.map { Double($0.angle) * 180 / .pi },
            horizonY: horizon == nil ? nil : 0.5,
            horizonConfidence: horizon == nil ? 0 : 0.72,
            cameraRollDegrees: 0,
            cameraMotion: 0,
            cameraStable: true,
            skyOrOpenAreaRatio: skyOrOpenAreaRatio(in: cgImage),
            timestamp: Date()
        )
    }

    private func loadImage(_ url: URL) -> (image: CGImage, orientation: CGImagePropertyOrientation)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = properties?[kCGImagePropertyOrientation] as? UInt32
        return (cgImage, CGImagePropertyOrientation(rawValue: rawOrientation ?? 1) ?? .up)
    }

    private func emptyMeasurements() -> Measurements {
        Measurements(
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
    }

    private func normalizedTopLeftRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
    }

    private func estimatePersonFromFace(_ face: DetectionBox) -> DetectionBox {
        let width = min(0.9, face.rect.width * 3.1)
        let height = min(0.95, face.rect.height * 5.4)
        let x = min(max(0, face.rect.midX - width / 2), 1 - width)
        let y = min(max(0, face.rect.minY - face.rect.height * 0.65), 1 - height)

        return DetectionBox(
            rect: CGRect(x: x, y: y, width: width, height: height),
            confidence: max(0.35, face.confidence * 0.72),
            label: "person estimated"
        )
    }

    private func groupAnalysis(people: [DetectionBox], faces: [DetectionBox]) -> GroupAnalysis? {
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

    private func poseKeypoints(from observations: [VNHumanBodyPoseObservation]) -> [String: DetectionPoint] {
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

    private func poseAnalysis(from points: [String: DetectionPoint], person: DetectionBox?, face: DetectionBox?) -> PoseAnalysis? {
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

        let shoulderMid = midpoint(leftShoulder?.point, rightShoulder?.point)
        let hipMid = midpoint(leftHip?.point, rightHip?.point)
        let shoulderWidth = distance(leftShoulder?.point, rightShoulder?.point)
        let hipWidth = distance(leftHip?.point, rightHip?.point)
        let bodySquareness = zipValues(shoulderWidth, hipWidth).map { shoulder, hip in
            min(1, max(0, shoulder / max(0.001, hip)) / 1.35)
        }
        let torsoRect = rectContaining([leftShoulder?.point, rightShoulder?.point, leftHip?.point, rightHip?.point].compactMap { $0 })
        let armTorsoDistances = ([leftElbow, rightElbow] + [leftWrist, rightWrist])
            .compactMap { distanceFrom(point: $0?.point, to: torsoRect) }
        let armsFlat = armTorsoDistances.isEmpty
            ? nil
            : min(1, max(0, (0.055 - (armTorsoDistances.reduce(0, +) / Double(armTorsoDistances.count))) / 0.055))
        let headAnchor = nose?.point ?? face.map { CGPoint(x: $0.rect.midX, y: $0.rect.midY) }
        let shoulderAnchor = neck?.point ?? shoulderMid
        let shouldersHigh = zipValues(headAnchor, shoulderAnchor).map { head, shoulder in
            let reference = Double(person?.rect.height ?? 1)
            return min(1, max(0, (0.16 - Double(abs(shoulder.y - head.y)) / max(0.001, reference)) / 0.16))
        }

        return PoseAnalysis(
            confidence: confidence,
            visibleKeypointCount: visiblePoints.count,
            shoulderLineAngleDegrees: angleDegrees(from: leftShoulder?.point, to: rightShoulder?.point),
            shoulderHeightAsymmetry: normalizedVerticalDelta(leftShoulder?.point, rightShoulder?.point, person: person),
            torsoAngleDegrees: angleDegrees(from: shoulderMid, to: hipMid).map { $0 - 90 },
            wristToFaceDistance: [leftWrist, rightWrist].compactMap { distanceFrom(point: $0?.point, to: face?.rect) }.min(),
            armVisibilityScore: Double([leftShoulder, rightShoulder, leftElbow, rightElbow, leftWrist, rightWrist].filter { ($0?.confidence ?? 0) > 0.2 }.count) / 6,
            stanceWidth: distance(leftAnkle?.point, rightAnkle?.point),
            headToTorsoRatio: zipValues(face?.rect.height, distance(shoulderMid, hipMid)).map { Double($0 / max(0.001, $1)) },
            shouldersHighScore: shouldersHigh,
            bodySquarenessScore: bodySquareness,
            bodyProfileScore: bodySquareness.map { 1 - $0 },
            armsFlatAgainstBodyScore: armsFlat,
            minWristEdgeDistance: [leftWrist, rightWrist].compactMap { edgeDistance($0?.point) }.min()
        )
    }

    private func faceAnalysis(from observation: VNFaceObservation?, face: DetectionBox?) -> FaceAnalysis? {
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
            eyeSpan.map { Double((nose.x - eyes.x) / max(0.001, CGFloat($0))) }
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

    private func luminance(in cgImage: CGImage, normalizedRect: CGRect?) -> Double? {
        guard let data = rgbaData(from: cgImage) else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let rect = normalizedRect.map {
            CGRect(
                x: $0.minX * CGFloat(width),
                y: $0.minY * CGFloat(height),
                width: $0.width * CGFloat(width),
                height: $0.height * CGFloat(height)
            ).integral
        } ?? CGRect(x: 0, y: 0, width: width, height: height)
        let step = max(1, min(width, height) / 120)
        var total = 0.0
        var count = 0

        for y in stride(from: max(0, Int(rect.minY)), to: min(height, Int(rect.maxY)), by: step) {
            for x in stride(from: max(0, Int(rect.minX)), to: min(width, Int(rect.maxX)), by: step) {
                let offset = (y * width + x) * 4
                let red = Double(data[offset])
                let green = Double(data[offset + 1])
                let blue = Double(data[offset + 2])
                total += 0.2126 * red + 0.7152 * green + 0.0722 * blue
                count += 1
            }
        }

        return count > 0 ? total / Double(count) : nil
    }

    private func skyOrOpenAreaRatio(in cgImage: CGImage) -> Double {
        guard let data = rgbaData(from: cgImage) else { return 0 }
        let width = cgImage.width
        let height = cgImage.height
        let step = max(1, min(width, height) / 90)
        let sampleMaxY = max(1, height / 3)
        var openPixels = 0
        var sampledPixels = 0

        for y in stride(from: 0, to: sampleMaxY, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = (y * width + x) * 4
                let red = Double(data[offset])
                let green = Double(data[offset + 1])
                let blue = Double(data[offset + 2])
                let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                if blue > red * 1.08 && blue > green * 0.95 || luminance > 170 {
                    openPixels += 1
                }
                sampledPixels += 1
            }
        }

        return sampledPixels > 0 ? Double(openPixels) / Double(sampledPixels) : 0
    }

    private func rgbaData(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }

    private func landmarkPoints(_ region: VNFaceLandmarkRegion2D?, in faceRect: CGRect) -> [CGPoint] {
        guard let region else { return [] }
        return region.normalizedPoints.map {
            CGPoint(x: faceRect.minX + $0.x * faceRect.width, y: faceRect.maxY - $0.y * faceRect.height)
        }
    }

    private func point(named name: String, in points: [String: DetectionPoint]) -> DetectionPoint? {
        let target = normalizedJointName(name)
        return points.first { normalizedJointName($0.key).contains(target) }?.value
    }

    private func point(namedAny names: [String], in points: [String: DetectionPoint]) -> DetectionPoint? {
        for name in names {
            if let point = point(named: name, in: points) {
                return point
            }
        }

        return nil
    }

    private func normalizedJointName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func midpoint(_ first: CGPoint?, _ second: CGPoint?) -> CGPoint? {
        guard let first, let second else { return nil }
        return CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }

    private func distance(_ first: CGPoint?, _ second: CGPoint?) -> Double? {
        guard let first, let second else { return nil }
        return hypot(Double(first.x - second.x), Double(first.y - second.y))
    }

    private func distanceFrom(point: CGPoint?, to rect: CGRect?) -> Double? {
        guard let point, let rect else { return nil }
        if rect.contains(point) { return 0 }
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(Double(dx), Double(dy))
    }

    private func edgeDistance(_ point: CGPoint?) -> Double? {
        guard let point else { return nil }
        return Double(min(point.x, point.y, 1 - point.x, 1 - point.y))
    }

    private func rectContaining(_ points: [CGPoint]) -> CGRect? {
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

    private func rectContainingRects(_ rects: [CGRect]) -> CGRect? {
        guard let first = rects.first else { return nil }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }

    private func center(of points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let total = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: total.x / CGFloat(points.count), y: total.y / CGFloat(points.count))
    }

    private func angleDegrees(from first: CGPoint?, to second: CGPoint?) -> Double? {
        guard let first, let second else { return nil }
        return atan2(Double(second.y - first.y), Double(second.x - first.x)) * 180 / .pi
    }

    private func normalizedVerticalDelta(_ first: CGPoint?, _ second: CGPoint?, person: DetectionBox?) -> Double? {
        guard let first, let second else { return nil }
        return Double(abs(first.y - second.y) / max(0.001, person?.rect.height ?? 1))
    }

    private func zipValues<A, B>(_ first: A?, _ second: B?) -> (A, B)? {
        guard let first, let second else { return nil }
        return (first, second)
    }
}

private func imageURLs(in directory: URL) -> [URL] {
    let extensions = Set(["jpg", "jpeg", "png", "heic", "heif"])
    guard let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: nil
    ) else {
        return []
    }

    let urls = enumerator.compactMap { $0 as? URL }
    return urls
        .filter { extensions.contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
}

private func format(_ value: Double?) -> String {
    guard let value else { return "--" }
    return String(format: "%.2f", value)
}

private func issueList(_ issues: [PhotoIssue]) -> String {
    guard !issues.isEmpty else { return "none" }
    return issues.prefix(6).map { "\($0.type): \($0.instruction)" }.joined(separator: "; ")
}

private func markdownReport(for results: [ImageResult], inputDirectory: URL) -> String {
    var lines: [String] = [
        "# Prototype 1 Image Analysis",
        "",
        "Generated: \(ISO8601DateFormatter().string(from: Date()))",
        "",
        "Input: `\(inputDirectory.path)`",
        "",
        "Images analyzed: \(results.count)",
        "",
        "| File | Person | Face | Pose | Top Issues | Metrics |",
        "| --- | ---: | ---: | ---: | --- | --- |"
    ]

    for result in results {
        let measurements = result.measurements
        let pose = measurements.poseAnalysis
        let face = measurements.faceAnalysis
        let group = measurements.groupAnalysis
        let metrics = [
            "face \(format(measurements.faceLuminance))",
            "bg \(format(measurements.backgroundLuminance))",
            "people \(group?.peopleCount ?? (measurements.personBox == nil ? 0 : 1))",
            "faces \(group?.faceCount ?? (measurements.faceBox == nil ? 0 : 1))",
            "yaw \(format(face?.yawEstimate))",
            "pitch \(format(face?.pitchEstimate))",
            "arms \(format(pose?.armVisibilityScore))",
            "square \(format(pose?.bodySquarenessScore))",
            "occ \(format(face?.occlusionScore))"
        ].joined(separator: ", ")
        let poseKeys = measurements.poseKeypoints.keys
            .sorted()
            .map { $0.replacingOccurrences(of: "VNHumanBodyPoseObservationJointName(rawValue: \"", with: "").replacingOccurrences(of: "\")", with: "") }
            .joined(separator: " ")
        lines.append("| \(result.fileName) | \(measurements.personBox == nil ? "no" : "yes") | \(measurements.faceBox == nil ? "no" : "yes") | \(pose?.visibleKeypointCount ?? 0) | \(issueList(result.issues)) | \(metrics)<br>`\(poseKeys)` |")
    }

    let issueCounts = Dictionary(grouping: results.flatMap(\.issues), by: \.type)
        .mapValues(\.count)
        .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }

    lines.append("")
    lines.append("## Issue Counts")
    lines.append("")
    for item in issueCounts {
        lines.append("- `\(item.key)`: \(item.value)")
    }

    lines.append("")
    lines.append("## Body Signal Strength")
    lines.append("")
    lines.append("| Signal | Coverage | Min | Mean | Max | Duplicate Delta | Rating |")
    lines.append("| --- | ---: | ---: | ---: | ---: | ---: | --- |")

    for summary in bodySignalSummaries(for: results) {
        lines.append("| \(summary.name) | \(summary.coverageCount)/\(summary.totalCount) | \(format(summary.minValue)) | \(format(summary.meanValue)) | \(format(summary.maxValue)) | \(format(summary.duplicateMaxDelta)) | \(summary.rating) |")
    }

    let armsFlatCount = results.filter { result in
        result.issues.contains { $0.type == "arms_flat_against_body" }
    }.count
    if results.count > 0, Double(armsFlatCount) / Double(results.count) > 0.8 {
        lines.append("")
        lines.append("Note: `arms_flat_against_body` fired on \(armsFlatCount)/\(results.count) images. Treat this signal as experimental/noisy until arm-body gap is improved.")
    }

    return lines.joined(separator: "\n")
}

private func bodySignalSummaries(for results: [ImageResult]) -> [SignalSummary] {
    let extractors: [(String, (ImageResult) -> Double?)] = [
        ("pose_confidence", { $0.measurements.poseAnalysis?.confidence }),
        ("person_box_area", { result in
            result.measurements.personBox.map { Double($0.rect.width * $0.rect.height) }
        }),
        ("shoulder_angle", { $0.measurements.poseAnalysis?.shoulderLineAngleDegrees }),
        ("shoulder_asymmetry", { $0.measurements.poseAnalysis?.shoulderHeightAsymmetry }),
        ("torso_angle", { $0.measurements.poseAnalysis?.torsoAngleDegrees }),
        ("arm_visibility", { $0.measurements.poseAnalysis?.armVisibilityScore }),
        ("arms_flat_score", { $0.measurements.poseAnalysis?.armsFlatAgainstBodyScore }),
        ("body_squareness", { $0.measurements.poseAnalysis?.bodySquarenessScore }),
        ("body_profile", { $0.measurements.poseAnalysis?.bodyProfileScore }),
        ("stance_width", { $0.measurements.poseAnalysis?.stanceWidth }),
        ("hand_edge_distance", { $0.measurements.poseAnalysis?.minWristEdgeDistance }),
        ("head_to_torso_ratio", { $0.measurements.poseAnalysis?.headToTorsoRatio }),
        ("shoulders_high", { $0.measurements.poseAnalysis?.shouldersHighScore })
    ]

    return extractors.map { name, extractor in
        let values = results.compactMap(extractor)
        return SignalSummary(
            name: name,
            values: values,
            coverageCount: values.count,
            totalCount: results.count,
            duplicateMaxDelta: duplicateMaxDelta(for: results, extractor: extractor)
        )
    }
}

private func duplicateMaxDelta(for results: [ImageResult], extractor: (ImageResult) -> Double?) -> Double? {
    let groups = Dictionary(grouping: results) { normalizedDuplicateName($0.fileName) }
    let deltas = groups.values.compactMap { group -> Double? in
        let values = group.compactMap(extractor)
        guard values.count > 1,
              let minValue = values.min(),
              let maxValue = values.max() else {
            return nil
        }
        return maxValue - minValue
    }
    return deltas.max()
}

private func normalizedDuplicateName(_ fileName: String) -> String {
    let url = URL(fileURLWithPath: fileName)
    var stem = url.deletingPathExtension().lastPathComponent
    if stem.hasSuffix("-2") {
        stem.removeLast(2)
    }
    return stem
}

private func jsonReport(for results: [ImageResult], inputDirectory: URL) throws -> Data {
    let payload: [String: Any] = [
        "generatedAt": ISO8601DateFormatter().string(from: Date()),
        "inputDirectory": inputDirectory.path,
        "images": results.map(jsonResult)
    ]

    return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
}

private func jsonResult(_ result: ImageResult) -> [String: Any] {
    [
        "fileName": result.fileName,
        "imagePath": result.imagePath,
        "imageSize": [
            "width": result.imageSize.width,
            "height": result.imageSize.height
        ],
        "issues": result.issues.map(jsonIssue),
        "measurements": jsonMeasurements(result.measurements)
    ]
}

private func jsonIssue(_ issue: PhotoIssue) -> [String: Any] {
    [
        "type": issue.type,
        "severity": issue.severity,
        "confidence": issue.confidence,
        "priority": issue.priority,
        "recipient": issue.recipient,
        "instruction": issue.instruction,
        "tone": "\(issue.tone)",
        "reasonData": issue.reasonData
    ]
}

private func jsonMeasurements(_ measurements: Measurements) -> [String: Any] {
    [
        "personBox": jsonBox(measurements.personBox),
        "faceBox": jsonBox(measurements.faceBox),
        "groupAnalysis": jsonGroupAnalysis(measurements.groupAnalysis),
        "faceAnalysis": jsonFaceAnalysis(measurements.faceAnalysis),
        "poseKeypoints": measurements.poseKeypoints
            .map { jsonPoint(key: $0.key, point: $0.value) }
            .sorted { ($0["key"] as? String ?? "") < ($1["key"] as? String ?? "") },
        "poseAnalysis": jsonPoseAnalysis(measurements.poseAnalysis),
        "faceLuminance": jsonValue(measurements.faceLuminance),
        "backgroundLuminance": jsonValue(measurements.backgroundLuminance),
        "horizonAngleDegrees": jsonValue(measurements.horizonAngleDegrees),
        "horizonConfidence": measurements.horizonConfidence,
        "skyOrOpenAreaRatio": measurements.skyOrOpenAreaRatio
    ]
}

private func jsonBox(_ box: DetectionBox?) -> Any {
    guard let box else { return NSNull() }
    return [
        "x": box.rect.minX,
        "y": box.rect.minY,
        "width": box.rect.width,
        "height": box.rect.height,
        "confidence": box.confidence,
        "label": box.label
    ]
}

private func jsonPoint(key: String, point: DetectionPoint) -> [String: Any] {
    [
        "key": key,
        "x": point.point.x,
        "y": point.point.y,
        "confidence": point.confidence
    ]
}

private func jsonPoseAnalysis(_ pose: PoseAnalysis?) -> Any {
    guard let pose else { return NSNull() }
    return [
        "confidence": pose.confidence,
        "visibleKeypointCount": pose.visibleKeypointCount,
        "shoulderLineAngleDegrees": jsonValue(pose.shoulderLineAngleDegrees),
        "shoulderHeightAsymmetry": jsonValue(pose.shoulderHeightAsymmetry),
        "torsoAngleDegrees": jsonValue(pose.torsoAngleDegrees),
        "wristToFaceDistance": jsonValue(pose.wristToFaceDistance),
        "armVisibilityScore": pose.armVisibilityScore,
        "stanceWidth": jsonValue(pose.stanceWidth),
        "headToTorsoRatio": jsonValue(pose.headToTorsoRatio),
        "shouldersHighScore": jsonValue(pose.shouldersHighScore),
        "bodySquarenessScore": jsonValue(pose.bodySquarenessScore),
        "bodyProfileScore": jsonValue(pose.bodyProfileScore),
        "armsFlatAgainstBodyScore": jsonValue(pose.armsFlatAgainstBodyScore),
        "minWristEdgeDistance": jsonValue(pose.minWristEdgeDistance)
    ]
}

private func jsonGroupAnalysis(_ group: GroupAnalysis?) -> Any {
    guard let group else { return NSNull() }
    return [
        "peopleCount": group.peopleCount,
        "faceCount": group.faceCount,
        "groupBounds": jsonRect(group.groupBounds),
        "faceVisibilityRatio": group.faceVisibilityRatio,
        "edgeCrowdingScore": group.edgeCrowdingScore,
        "spacingScore": jsonValue(group.spacingScore)
    ]
}

private func jsonRect(_ rect: CGRect?) -> Any {
    guard let rect else { return NSNull() }
    return [
        "x": rect.minX,
        "y": rect.minY,
        "width": rect.width,
        "height": rect.height
    ]
}

private func jsonFaceAnalysis(_ face: FaceAnalysis?) -> Any {
    guard let face else { return NSNull() }
    return [
        "confidence": face.confidence,
        "landmarkPointCount": face.landmarkPointCount,
        "eyeVisibilityScore": face.eyeVisibilityScore,
        "yawEstimate": jsonValue(face.yawEstimate),
        "pitchEstimate": jsonValue(face.pitchEstimate),
        "occlusionScore": face.occlusionScore
    ]
}

private func jsonValue(_ value: Double?) -> Any {
    value ?? NSNull()
}

@main
struct BatchImageAnalyzerMain {
    static func main() throws {
        let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let inputDirectory = CommandLine.arguments.dropFirst().first.map {
            URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath)
        } ?? defaultDirectory
        let output = URL(fileURLWithPath: "docs/prototype_1_download_image_analysis.md")
        let jsonOutput = URL(fileURLWithPath: "docs/prototype_1_download_image_analysis.json")
        let urls = imageURLs(in: inputDirectory)
        let results = BatchImageAnalyzer().analyze(urls: urls)
        try markdownReport(for: results, inputDirectory: inputDirectory).write(to: output, atomically: true, encoding: .utf8)
        try jsonReport(for: results, inputDirectory: inputDirectory).write(to: jsonOutput, options: .atomic)

        let personCount = results.filter { $0.measurements.personBox != nil }.count
        let faceCount = results.filter { $0.measurements.faceBox != nil }.count
        let poseCount = results.filter { $0.measurements.poseAnalysis != nil }.count
        let postureCount = results.filter { result in
            result.issues.contains { issue in
                [
                    "hand_near_face",
                    "arm_hidden",
                    "body_too_square",
                    "body_too_profile",
                    "arms_flat_against_body",
                    "hand_cut_off",
                    "shoulders_high",
                    "face_occluded",
                    "eyes_occluded",
                    "face_too_profile",
                    "face_turned_away",
                    "chin_too_high",
                    "chin_too_low"
                ].contains(issue.type)
            }
        }.count

        print("Analyzed \(results.count) images")
        print("input: \(inputDirectory.path)")
        print("person: \(personCount), face: \(faceCount), pose: \(poseCount), posture/face findings: \(postureCount)")
        print("report: \(output.path)")
        print("json: \(jsonOutput.path)")
    }
}
