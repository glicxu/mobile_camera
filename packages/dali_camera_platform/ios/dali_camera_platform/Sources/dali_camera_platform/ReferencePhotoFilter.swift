import CoreImage

/// Operation order and coefficients from the native PhotoFilterEngine.
/// Parameters: exposure, warmth, color, contrast, softness, detail, blueSky.
enum ReferencePhotoFilter {
    static func apply(_ input: CIImage, parameters: [Double]) -> CIImage {
        let p = parameters.enumerated().map { index, value in
            min(5, max([0, 1, 3].contains(index) ? -5 : 0, value)) / 5
        }
        let exposure = p[0], warmth = p[1], color = p[2], contrast = p[3]
        let softness = p[4], detail = p[5], blueSky = p[6]
        var output = input
        if softness > 0 {
            output = output.applyingFilter("CINoiseReduction", parameters: ["inputNoiseLevel": 0.012 + 0.055 * softness, "inputSharpness": 0.38 - 0.16 * softness]).cropped(to: input.extent)
        }
        if exposure != 0 {
            output = output.applyingFilter("CIHighlightShadowAdjust", parameters: ["inputShadowAmount": max(0, 0.22 * exposure), "inputHighlightAmount": 1 - max(0, 0.10 * exposure)])
        }
        output = output.applyingFilter("CIColorControls", parameters: ["inputBrightness": 0.055 * exposure, "inputSaturation": 1 + 0.30 * color, "inputContrast": 1 + 0.13 * contrast - 0.04 * softness])
        if color > 0 { output = output.applyingFilter("CIVibrance", parameters: ["inputAmount": 0.36 * color]) }
        if warmth != 0 {
            output = output.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 6500 - 820 * warmth, y: 0)])
        }
        if blueSky > 0 {
            output = output.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 1 - 0.05 * blueSky, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 1 + 0.02 * blueSky, z: 0, w: 0), "inputBVector": CIVector(x: 0, y: 0, z: 1 + 0.18 * blueSky, w: 0), "inputBiasVector": CIVector(x: 0, y: 0, z: 0.018 * blueSky, w: 0)])
        }
        if detail > 0 {
            output = output.applyingFilter("CIUnsharpMask", parameters: ["inputRadius": 1.1 + 1.9 * detail, "inputIntensity": 0.10 + 0.34 * detail]).cropped(to: input.extent)
        }
        return output.cropped(to: input.extent)
    }
}
