import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

struct BeautifyEngine {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    func apply(to image: UIImage, measurements: Measurements, settings: BeautifySettings) -> (image: UIImage, result: BeautifyResult) {
        let strength = settings.normalizedStrength
        let skyApplied = settings.landscapeSkyEnabled && measurements.skyOrOpenAreaRatio >= 0.08
        let landscapeColorApplied = settings.landscapeColorEnabled
        let landscapeApplied = skyApplied || landscapeColorApplied
        let result = BeautifyResult(
            settings: settings,
            faceDetected: measurements.faceBox != nil,
            personDetected: measurements.personBox != nil,
            landscapeApplied: landscapeApplied,
            landscapeColorApplied: landscapeColorApplied,
            skyApplied: skyApplied,
            debugValues: debugValues(for: measurements, settings: settings)
        )

        guard strength > 0, let input = CIImage(image: image) else {
            return (image, result)
        }

        var output = input

        if landscapeApplied {
            output = polishLandscape(
                in: output,
                extent: input.extent,
                strength: strength,
                openAreaRatio: measurements.skyOrOpenAreaRatio,
                enrichColor: landscapeColorApplied,
                enhanceSky: skyApplied
            ) ?? output
        }

        if let face = measurements.faceBox {
            let skinMask = skinMask(
                extent: input.extent,
                normalizedTopLeftRect: face.rect,
                landmarks: measurements.faceLandmarks,
                strength: strength
            )

            if settings.faceBrightnessEnabled, let skinMask {
                output = brightenSkin(
                    in: output,
                    mask: skinMask,
                    strength: strength
                ) ?? output
            }

            if settings.blemishReductionEnabled, let skinMask {
                output = reduceBlemishes(
                    in: output,
                    extent: input.extent,
                    mask: skinMask,
                    strength: strength
                ) ?? output
            }

            if settings.skinSmoothingEnabled, let skinMask {
                output = smoothSkin(
                    in: output,
                    extent: input.extent,
                    faceRect: face.rect,
                    mask: skinMask,
                    strength: strength
                ) ?? output
            }

            output = reshapeFeatures(
                in: output,
                extent: input.extent,
                faceRect: face.rect,
                faceAnalysis: measurements.faceAnalysis,
                landmarks: measurements.faceLandmarks,
                settings: settings
            )
        }

        guard let cgImage = context.createCGImage(output.cropped(to: input.extent), from: input.extent) else {
            return (image, result)
        }

        return (UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation), result)
    }

    /// Enhances sky colors and definition in clouds already present in the photo.
    /// The chroma mask and upper-frame gradient keep the adjustment away from
    /// people and most foreground objects; this does not synthesize new clouds.
    private func polishLandscape(
        in image: CIImage,
        extent: CGRect,
        strength: Double,
        openAreaRatio: Double,
        enrichColor: Bool,
        enhanceSky: Bool
    ) -> CIImage? {
        // Landscape levels intentionally run hotter than portrait levels.
        // Level 3 maps to the former level-5 treatment; levels 4–5 extend
        // beyond it for a deliberately dramatic, stylized result.
        let landscapeStrength: Double
        if strength <= 0.6 {
            landscapeStrength = strength / 0.6
        } else {
            landscapeStrength = 1 + (strength - 0.6) * 0.875
        }
        var scene = image

        if enrichColor {
            let vibrance = CIFilter.vibrance()
            vibrance.inputImage = scene
            vibrance.amount = Float(0.16 + 0.42 * landscapeStrength)
            scene = vibrance.outputImage ?? scene

            let controls = CIFilter.colorControls()
            controls.inputImage = scene
            controls.contrast = Float(1 + 0.07 * landscapeStrength)
            controls.saturation = Float(1 + 0.08 * landscapeStrength)
            scene = controls.outputImage ?? scene
        }

        guard enhanceSky else { return scene.cropped(to: extent) }
        guard let mask = skyMask(for: image, extent: extent) else { return scene.cropped(to: extent) }
        let confidence = min(1, max(0.25, (openAreaRatio - 0.08) / 0.42))
        let skyCurve = pow(landscapeStrength, 1.3)
        // The high-end term deliberately accelerates levels 4–5. Level 3 is
        // vivid and usable, level 4 is dramatic, and level 5 is intentionally
        // stylized rather than natural.
        let highEndBoost = pow(landscapeStrength, 4)

        let channelMix = CIFilter.colorMatrix()
        channelMix.inputImage = scene
        channelMix.rVector = CIVector(x: max(0.15, 1 - 0.18 * skyCurve - 0.20 * highEndBoost), y: 0, z: 0, w: 0)
        channelMix.gVector = CIVector(x: 0, y: max(0.55, 1 - 0.03 * skyCurve - 0.08 * highEndBoost), z: 0, w: 0)
        channelMix.bVector = CIVector(x: 0, y: 0, z: min(3.2, 1 + 0.35 * skyCurve + 0.55 * highEndBoost), w: 0)
        channelMix.biasVector = CIVector(x: 0, y: 0, z: min(0.25, 0.02 * skyCurve + 0.10 * highEndBoost), w: 0)
        guard var adjusted = channelMix.outputImage else { return nil }

        let vibrance = CIFilter.vibrance()
        vibrance.inputImage = adjusted
        vibrance.amount = Float(min(1.8, 0.28 + 0.55 * skyCurve + 0.45 * highEndBoost))
        adjusted = vibrance.outputImage ?? adjusted

        let skyColor = CIFilter.colorControls()
        skyColor.inputImage = adjusted
        skyColor.contrast = Float(min(1.5, 1 + 0.10 * skyCurve + 0.12 * highEndBoost))
        skyColor.saturation = Float(min(2.2, 1 + 0.28 * skyCurve + 0.35 * highEndBoost))
        adjusted = skyColor.outputImage ?? adjusted

        let cloudDetail = CIFilter.highlightShadowAdjust()
        cloudDetail.inputImage = adjusted
        cloudDetail.shadowAmount = Float(0.08 * skyCurve)
        cloudDetail.highlightAmount = Float(max(0.20, 1 - 0.30 * skyCurve - 0.18 * highEndBoost))
        adjusted = cloudDetail.outputImage ?? adjusted

        let crispness = CIFilter.unsharpMask()
        crispness.inputImage = adjusted
        crispness.radius = Float(1.1 + 1.8 * skyCurve)
        crispness.intensity = Float(0.12 + 0.35 * skyCurve + 0.20 * highEndBoost)
        adjusted = crispness.outputImage?.cropped(to: extent) ?? adjusted

        return blend(
            adjusted,
            over: scene,
            mask: maskWithOpacity(mask, opacity: min(1, (0.50 + 0.50 * skyCurve) * confidence))
        )?.cropped(to: extent)
    }

    private func skyMask(for image: CIImage, extent: CGRect) -> CIImage? {
        let blueAndCloudMask = CIFilter.colorMatrix()
        blueAndCloudMask.inputImage = image
        blueAndCloudMask.rVector = CIVector(x: -0.45, y: -0.45, z: -0.45, w: 0)
        blueAndCloudMask.gVector = CIVector(x: -0.10, y: -0.10, z: -0.10, w: 0)
        blueAndCloudMask.bVector = CIVector(x: 1.05, y: 1.05, z: 1.05, w: 0)
        blueAndCloudMask.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        blueAndCloudMask.biasVector = CIVector(x: -0.08, y: -0.08, z: -0.08, w: 0)
        guard let chroma = blueAndCloudMask.outputImage else { return nil }

        let clamp = CIFilter.colorClamp()
        clamp.inputImage = chroma
        clamp.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
        clamp.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        guard let clampedChroma = clamp.outputImage else { return nil }

        let upperFrame = CIFilter.linearGradient()
        upperFrame.point0 = CGPoint(x: extent.midX, y: extent.minY + extent.height * 0.28)
        upperFrame.point1 = CGPoint(x: extent.midX, y: extent.minY + extent.height * 0.66)
        upperFrame.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 1)
        upperFrame.color1 = CIColor(red: 1, green: 1, blue: 1, alpha: 1)
        guard let upperMask = upperFrame.outputImage?.cropped(to: extent) else { return nil }

        let multiply = CIFilter.multiplyCompositing()
        multiply.inputImage = clampedChroma
        multiply.backgroundImage = upperMask
        guard let combined = multiply.outputImage?.cropped(to: extent) else { return nil }

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = combined.clampedToExtent()
        blur.radius = Float(max(extent.width, extent.height) * 0.006)
        return blur.outputImage?.cropped(to: extent)
    }

    private func brightenSkin(
        in image: CIImage,
        mask: CIImage,
        strength: Double
    ) -> CIImage? {
        let controls = CIFilter.colorControls()
        controls.inputImage = image
        controls.brightness = Float(0.015 + 0.10 * pow(strength, 1.2))
        controls.contrast = Float(1 + 0.025 * strength)
        controls.saturation = Float(1 - 0.045 * strength)
        guard let adjusted = controls.outputImage else { return nil }
        return blend(adjusted, over: image, mask: maskWithOpacity(mask, opacity: 0.35 + strength * 0.55))
    }

    private func reduceBlemishes(
        in image: CIImage,
        extent: CGRect,
        mask: CIImage,
        strength: Double
    ) -> CIImage? {
        let cleanup = CIFilter.noiseReduction()
        cleanup.inputImage = image
        cleanup.noiseLevel = Float(0.02 + 0.10 * strength)
        cleanup.sharpness = Float(0.44 - 0.18 * strength)
        guard let cleaned = cleanup.outputImage?.cropped(to: extent) else { return nil }
        return blend(cleaned, over: image, mask: maskWithOpacity(mask, opacity: 0.10 + 0.40 * strength))
    }

    private func smoothSkin(
        in image: CIImage,
        extent: CGRect,
        faceRect: CGRect,
        mask: CIImage,
        strength: Double
    ) -> CIImage? {
        let curve = pow(strength, 1.15)
        let facePixelWidth = faceRect.width * extent.width
        let radius = min(34, max(1.2, facePixelWidth * (0.008 + 0.024 * curve)))
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = image.clampedToExtent()
        blur.radius = Float(radius)
        guard let blurred = blur.outputImage?.cropped(to: extent) else { return nil }
        return blend(blurred, over: image, mask: maskWithOpacity(mask, opacity: 0.10 + 0.65 * curve))
    }

    private func reshapeFeatures(
        in image: CIImage,
        extent: CGRect,
        faceRect: CGRect,
        faceAnalysis: FaceAnalysis?,
        landmarks: FaceLandmarkGeometry?,
        settings: BeautifySettings
    ) -> CIImage {
        guard let landmarks else { return image }
        let strength = settings.normalizedStrength
        let reshapeStrength = max(0, min(1, (strength - 0.2) / 0.8))
        guard reshapeStrength > 0 else { return image }

        let isNearFrontal = abs(faceAnalysis?.yawEstimate ?? 0) < 0.38
            && (faceAnalysis?.occlusionScore ?? 0) < 0.55
        guard isNearFrontal else { return image }

        let facePixelWidth = faceRect.width * extent.width
        var output = image

        if settings.eyeEnlargementEnabled, landmarks.hasEyes,
           (faceAnalysis?.eyeVisibilityScore ?? 1) >= 0.9 {
            for eye in [landmarks.leftEye, landmarks.rightEye] {
                guard let center = center(of: eye), let bounds = bounds(of: eye) else { continue }
                let radius = max(facePixelWidth * 0.105, bounds.width * extent.width * 0.95)
                output = bump(
                    output,
                    center: coreImagePoint(center, extent: extent),
                    radius: radius,
                    scale: 0.18 * pow(reshapeStrength, 1.2)
                )
            }
        }

        if settings.lipPlumpingEnabled, landmarks.hasLips,
           let center = center(of: landmarks.outerLips),
           let bounds = bounds(of: landmarks.outerLips) {
            let radius = max(facePixelWidth * 0.14, bounds.width * extent.width * 0.72)
            output = bump(
                output,
                center: coreImagePoint(center, extent: extent),
                radius: radius,
                scale: 0.12 * pow(reshapeStrength, 1.25)
            )
        }

        return output
    }

    private func bump(_ image: CIImage, center: CGPoint, radius: CGFloat, scale: Double) -> CIImage {
        let filter = CIFilter.bumpDistortion()
        filter.inputImage = image
        filter.center = center
        filter.radius = Float(radius)
        filter.scale = Float(scale)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }

    private func skinMask(
        extent: CGRect,
        normalizedTopLeftRect rect: CGRect,
        landmarks: FaceLandmarkGeometry?,
        strength: Double
    ) -> CIImage? {
        let maximumMaskDimension: CGFloat = 1_024
        let maskScale = min(1, maximumMaskDimension / max(extent.width, extent.height))
        let size = CGSize(
            width: max(1, extent.width * maskScale),
            height: max(1, extent.height * maskScale)
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let face = pixelRect(rect, size: size)
                .insetBy(dx: -rect.width * size.width * 0.20, dy: -rect.height * size.height * 0.24)
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: face)

            UIColor.black.setFill()
            if let landmarks {
                for eye in [landmarks.leftEye, landmarks.rightEye] {
                    if let eyeRect = bounds(of: eye) {
                        let pixels = pixelRect(eyeRect, size: size)
                        context.cgContext.fillEllipse(in: pixels.insetBy(
                            dx: -pixels.width * 0.55,
                            dy: -pixels.height * 1.1
                        ))
                    }
                }
                if let lipRect = bounds(of: landmarks.outerLips) {
                    let pixels = pixelRect(lipRect, size: size)
                    context.cgContext.fillEllipse(in: pixels.insetBy(
                        dx: -pixels.width * 0.28,
                        dy: -pixels.height * 0.7
                    ))
                }
            }
        }

        guard var mask = CIImage(image: image) else { return nil }
        if maskScale < 1 {
            mask = mask.transformed(by: CGAffineTransform(scaleX: 1 / maskScale, y: 1 / maskScale))
        }
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = mask.clampedToExtent()
        blur.radius = Float(max(extent.width, extent.height) * (0.012 + 0.006 * pow(strength, 1.15)))
        return blur.outputImage?.cropped(to: extent)
    }

    private func maskWithOpacity(_ mask: CIImage, opacity: Double) -> CIImage {
        let amount = CGFloat(min(1, max(0, opacity)))
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = mask
        matrix.rVector = CIVector(x: amount, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: amount, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: amount, w: 0)
        return matrix.outputImage ?? mask
    }

    private func blend(_ foreground: CIImage, over background: CIImage, mask: CIImage) -> CIImage? {
        let blend = CIFilter.blendWithMask()
        blend.inputImage = foreground
        blend.backgroundImage = background
        blend.maskImage = mask
        return blend.outputImage
    }

    private func pixelRect(_ rect: CGRect, size: CGSize) -> CGRect {
        CGRect(
            x: rect.minX * size.width,
            y: rect.minY * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }

    private func coreImagePoint(_ point: CGPoint, extent: CGRect) -> CGPoint {
        CGPoint(
            x: extent.minX + point.x * extent.width,
            y: extent.minY + (1 - point.y) * extent.height
        )
    }

    private func center(of points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let total = points.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
        }
        return CGPoint(x: total.x / CGFloat(points.count), y: total.y / CGFloat(points.count))
    }

    private func bounds(of points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { partial, point in
            partial.union(CGRect(origin: point, size: .zero))
        }
    }

    private func debugValues(for measurements: Measurements, settings: BeautifySettings) -> [String: Double] {
        let strength = settings.normalizedStrength
        let reshape = max(0, min(1, (strength - 0.2) / 0.8))
        return [
            "level": Double(settings.strength),
            "strength": strength,
            "face_detected": measurements.faceBox == nil ? 0 : 1,
            "person_detected": measurements.personBox == nil ? 0 : 1,
            "open_area_ratio": measurements.skyOrOpenAreaRatio,
            "landscape_color": settings.landscapeColorEnabled && measurements.skyOrOpenAreaRatio >= 0.08 ? strength : 0,
            "landscape_sky": settings.landscapeSkyEnabled && measurements.skyOrOpenAreaRatio >= 0.08 ? strength : 0,
            "landmarks_detected": measurements.faceLandmarks == nil ? 0 : 1,
            "skin_brightening": settings.faceBrightnessEnabled ? strength : 0,
            "skin_smoothing": settings.skinSmoothingEnabled ? strength : 0,
            "blemish_reduction": settings.blemishReductionEnabled ? strength : 0,
            "eye_enlargement": settings.eyeEnlargementEnabled ? reshape : 0,
            "lip_plumping": settings.lipPlumpingEnabled ? reshape : 0
        ]
    }
}

struct DepthBlurEngine {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    func apply(
        to image: UIImage,
        measurements: Measurements,
        focusPoint: CGPoint? = nil,
        level: Int
    ) -> UIImage {
        let level = max(0, min(5, level))
        guard level > 0,
              let input = CIImage(image: image),
              let normalizedSubject = subjectRect(from: measurements, focusPoint: focusPoint),
              let mask = subjectMask(extent: input.extent, normalizedRect: normalizedSubject) else {
            return image
        }

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = input.clampedToExtent()
        blur.radius = Float(3 + level * 4)
        guard let blurred = blur.outputImage?.cropped(to: input.extent) else { return image }

        let blend = CIFilter.blendWithMask()
        blend.inputImage = input
        blend.backgroundImage = blurred
        blend.maskImage = mask
        guard let output = blend.outputImage?.cropped(to: input.extent),
              let cgImage = context.createCGImage(output, from: input.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func subjectRect(from measurements: Measurements, focusPoint: CGPoint?) -> CGRect? {
        let candidates = [measurements.personBox?.rect, measurements.salientObjectBox?.rect, measurements.faceBox?.rect]
            .compactMap { $0 }
        let selected = focusPoint.flatMap { point in
            candidates.first(where: { $0.insetBy(dx: -0.04, dy: -0.04).contains(point) })
        }

        let rect: CGRect
        if let selected {
            rect = selected.insetBy(dx: -selected.width * 0.22, dy: -selected.height * 0.18)
        } else if let person = measurements.personBox?.rect {
            rect = person.insetBy(dx: -person.width * 0.16, dy: -person.height * 0.10)
        } else if let face = measurements.faceBox?.rect {
            rect = CGRect(
                x: face.minX - face.width * 1.1,
                y: face.minY - face.height * 0.45,
                width: face.width * 3.2,
                height: face.height * 4.7
            )
        } else if let focusPoint {
            rect = CGRect(x: focusPoint.x - 0.18, y: focusPoint.y - 0.24, width: 0.36, height: 0.48)
        } else {
            return nil
        }

        let minX = max(0, rect.minX)
        let minY = max(0, rect.minY)
        let maxX = min(1, rect.maxX)
        let maxY = min(1, rect.maxY)
        guard maxX > minX, maxY > minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func subjectMask(extent: CGRect, normalizedRect: CGRect) -> CIImage? {
        let maximumDimension: CGFloat = 1_024
        let scale = min(1, maximumDimension / max(extent.width, extent.height))
        let size = CGSize(width: max(1, extent.width * scale), height: max(1, extent.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let subject = CGRect(
                x: normalizedRect.minX * size.width,
                y: normalizedRect.minY * size.height,
                width: normalizedRect.width * size.width,
                height: normalizedRect.height * size.height
            )
            UIColor.white.setFill()
            UIBezierPath(
                roundedRect: subject,
                cornerRadius: min(subject.width, subject.height) * 0.28
            ).fill()
        }

        guard var mask = CIImage(image: rendered) else { return nil }
        if scale < 1 {
            mask = mask.transformed(by: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
        }
        let soften = CIFilter.gaussianBlur()
        soften.inputImage = mask.clampedToExtent()
        soften.radius = Float(max(extent.width, extent.height) * 0.018)
        return soften.outputImage?.cropped(to: extent)
    }
}
