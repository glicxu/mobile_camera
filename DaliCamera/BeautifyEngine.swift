import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

struct BeautifyEngine {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    func apply(to image: UIImage, measurements: Measurements, settings: BeautifySettings) -> (image: UIImage, result: BeautifyResult) {
        let strength = settings.normalizedStrength
        let result = BeautifyResult(
            settings: settings,
            faceDetected: measurements.faceBox != nil,
            personDetected: measurements.personBox != nil,
            debugValues: debugValues(for: measurements, strength: strength)
        )

        guard strength > 0,
              let input = CIImage(image: image) else {
            return (image, result)
        }

        var output = input

        if settings.faceBrightnessEnabled || settings.warmthEnabled || settings.clarityEnabled {
            output = portraitToneImage(from: output, settings: settings)
        }

        if settings.skinSmoothingEnabled,
           let face = measurements.faceBox,
           let smoothed = smoothedFaceImage(from: output, originalExtent: input.extent, faceRect: face.rect, strength: strength) {
            output = smoothed
        }

        if settings.subjectEmphasisEnabled {
            output = subjectEmphasisImage(from: output, strength: strength)
        }

        guard let cgImage = context.createCGImage(output.cropped(to: input.extent), from: input.extent) else {
            return (image, result)
        }

        return (
            UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation),
            result
        )
    }

    private func portraitToneImage(from image: CIImage, settings: BeautifySettings) -> CIImage {
        let strength = Float(settings.normalizedStrength)
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = image
        colorControls.brightness = settings.faceBrightnessEnabled ? 0.055 * strength : 0
        colorControls.contrast = 1 + (settings.clarityEnabled ? 0.035 * strength : 0)
        colorControls.saturation = 1 + (settings.warmthEnabled ? 0.045 * strength : 0)

        var output = colorControls.outputImage ?? image

        if settings.warmthEnabled {
            let temperature = CIFilter.temperatureAndTint()
            temperature.inputImage = output
            temperature.neutral = CIVector(x: 6500, y: 0)
            temperature.targetNeutral = CIVector(x: 6500 - 420 * CGFloat(strength), y: 0)
            output = temperature.outputImage ?? output
        }

        return output
    }

    private func smoothedFaceImage(
        from image: CIImage,
        originalExtent: CGRect,
        faceRect: CGRect,
        strength: Double
    ) -> CIImage? {
        let smoothingStrength = pow(strength, 1.35)

        guard let mask = faceMask(
            extent: originalExtent,
            normalizedTopLeftRect: faceRect,
            strength: smoothingStrength
        ) else {
            return nil
        }

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = image.clampedToExtent()
        blur.radius = Float(1.2 + smoothingStrength * 18)
        guard let blurred = blur.outputImage?.cropped(to: originalExtent) else {
            return nil
        }

        let blend = CIFilter.blendWithMask()
        blend.inputImage = blurred
        blend.backgroundImage = image
        blend.maskImage = mask
        return blend.outputImage
    }

    private func faceMask(extent: CGRect, normalizedTopLeftRect rect: CGRect, strength: Double) -> CIImage? {
        let size = CGSize(width: max(1, extent.width), height: max(1, extent.height))
        let maskOpacity = min(0.98, 0.55 + strength * 0.43)
        let horizontalPadding = 0.5 + strength * 0.35
        let verticalPadding = 0.62 + strength * 0.32
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let face = CGRect(
                x: rect.minX * size.width,
                y: rect.minY * size.height,
                width: rect.width * size.width,
                height: rect.height * size.height
            )
                .insetBy(dx: -rect.width * size.width * horizontalPadding, dy: -rect.height * size.height * verticalPadding)

            UIColor.white.withAlphaComponent(maskOpacity).setFill()
            context.cgContext.fillEllipse(in: face)
        }

        guard let mask = CIImage(image: image) else {
            return nil
        }

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = mask.clampedToExtent()
        blur.radius = Float(max(size.width, size.height) * (0.018 + strength * 0.014))
        return blur.outputImage?.cropped(to: extent)
    }

    private func subjectEmphasisImage(from image: CIImage, strength: Double) -> CIImage {
        let vignette = CIFilter.vignette()
        vignette.inputImage = image
        vignette.intensity = Float(0.18 * strength)
        vignette.radius = Float(1.35 + 0.45 * strength)
        return vignette.outputImage ?? image
    }

    private func debugValues(for measurements: Measurements, strength: Double) -> [String: Double] {
        var values: [String: Double] = [
            "strength": strength,
            "face_detected": measurements.faceBox == nil ? 0 : 1,
            "person_detected": measurements.personBox == nil ? 0 : 1
        ]

        if let face = measurements.faceLuminance {
            values["face_luminance_before"] = face
            values["estimated_face_lift"] = 14 * strength
        }

        values["skin_smoothing_radius"] = 1.2 + pow(strength, 1.35) * 18
        values["skin_smoothing_mask"] = min(0.98, 0.55 + pow(strength, 1.35) * 0.43)

        return values
    }
}
