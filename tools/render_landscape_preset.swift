import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

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
    let filter = CIFilter.blendWithMask()
    filter.inputImage = foreground
    filter.backgroundImage = background
    filter.maskImage = mask
    return filter.outputImage
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

private func renderDramatic(_ image: CIImage, openAreaRatio: Double = 0.5) throws -> CIImage {
    let extent = image.extent
    let strength = 0.8
    let landscapeStrength = 1 + (strength - 0.6) * 0.875
    var scene = image

    let sceneVibrance = CIFilter.vibrance()
    sceneVibrance.inputImage = scene
    sceneVibrance.amount = Float(0.16 + 0.42 * landscapeStrength)
    scene = sceneVibrance.outputImage ?? scene

    let sceneControls = CIFilter.colorControls()
    sceneControls.inputImage = scene
    sceneControls.contrast = Float(1 + 0.07 * landscapeStrength)
    sceneControls.saturation = Float(1 + 0.08 * landscapeStrength)
    scene = sceneControls.outputImage ?? scene

    guard let mask = skyMask(for: image, extent: extent) else { return scene.cropped(to: extent) }
    let confidence = min(1, max(0.25, (openAreaRatio - 0.08) / 0.42))
    let skyCurve = pow(landscapeStrength, 1.3)
    let highEndBoost = pow(landscapeStrength, 4)

    let channelMix = CIFilter.colorMatrix()
    channelMix.inputImage = scene
    channelMix.rVector = CIVector(x: max(0.15, 1 - 0.18 * skyCurve - 0.20 * highEndBoost), y: 0, z: 0, w: 0)
    channelMix.gVector = CIVector(x: 0, y: max(0.55, 1 - 0.03 * skyCurve - 0.08 * highEndBoost), z: 0, w: 0)
    channelMix.bVector = CIVector(x: 0, y: 0, z: min(3.2, 1 + 0.35 * skyCurve + 0.55 * highEndBoost), w: 0)
    channelMix.biasVector = CIVector(x: 0, y: 0, z: min(0.25, 0.02 * skyCurve + 0.10 * highEndBoost), w: 0)
    guard var adjusted = channelMix.outputImage else { return scene.cropped(to: extent) }

    let skyVibrance = CIFilter.vibrance()
    skyVibrance.inputImage = adjusted
    skyVibrance.amount = Float(min(1.8, 0.28 + 0.55 * skyCurve + 0.45 * highEndBoost))
    adjusted = skyVibrance.outputImage ?? adjusted

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
    )?.cropped(to: extent) ?? scene.cropped(to: extent)
}

guard CommandLine.arguments.count == 3 else {
    fputs("usage: swift render_landscape_preset.swift input.jpg output.jpg\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let input = CIImage(contentsOf: inputURL, options: [.applyOrientationProperty: true]) else {
    throw NSError(domain: "DaliLandscapePreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load input image"])
}

let output = try renderDramatic(input)
let context = CIContext(options: [.useSoftwareRenderer: false])
guard let cgImage = context.createCGImage(output, from: input.extent),
      let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .jpeg, properties: [.compressionFactor: 0.95]) else {
    throw NSError(domain: "DaliLandscapePreview", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not render output image"])
}
try data.write(to: outputURL, options: .atomic)
