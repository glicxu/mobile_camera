import CoreImage
import ImageIO
import UIKit

enum DaliWatermarkRenderer {
    // Apple documents CIContext rendering as thread-safe. Keep one context without
    // sharing mutable CIFilter instances; older SDKs omit its Sendable annotation.
    // https://developer.apple.com/documentation/coreimage/cicontext
    nonisolated(unsafe) private static let context = CIContext(options: [.cacheIntermediates: false])

    static func apply(
        to image: UIImage,
        signature: UIImage,
        relativeWidth: CGFloat = 0.28,
        relativeMargin: CGFloat = 0.025,
        opacity: CGFloat = 0.86
    ) -> UIImage {
        guard let sourceCGImage = image.cgImage,
              let signatureCGImage = signature.cgImage else { return image }

        var source = CIImage(cgImage: sourceCGImage)
            .oriented(CGImagePropertyOrientation(image.imageOrientation))
        if source.extent.origin != .zero {
            source = source.transformed(by: CGAffineTransform(
                translationX: -source.extent.minX,
                y: -source.extent.minY
            ))
        }

        let sourceExtent = source.extent.integral
        guard sourceExtent.width > 0, sourceExtent.height > 0 else { return image }

        let targetWidth = sourceExtent.width * min(0.5, max(0.08, relativeWidth))
        let signatureScale = targetWidth / CGFloat(signatureCGImage.width)
        let margin = max(18, sourceExtent.width * max(0, relativeMargin))

        var mark = CIImage(cgImage: signatureCGImage)
            .transformed(by: CGAffineTransform(scaleX: signatureScale, y: signatureScale))
        mark = mark.transformed(by: CGAffineTransform(
            translationX: sourceExtent.maxX - mark.extent.width - margin,
            y: sourceExtent.minY + margin
        ))
        mark = mark.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: min(1, max(0, opacity)))
        ])

        let composite = mark.composited(over: source)
        let colorSpace = sourceCGImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)
        guard let output = context.createCGImage(
            composite,
            from: sourceExtent,
            format: .RGBA8,
            colorSpace: colorSpace
        ) else { return image }

        return UIImage(cgImage: output, scale: image.scale, orientation: .up)
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
