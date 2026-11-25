import CoreGraphics
import Foundation
import UIKit

enum HiddenWatermark {
    private static let step = 4
    private static let strength = 4

    private static func sign(column: Int, row: Int) -> Int {
        let value = (column &* 73_856_093) ^ (row &* 19_349_663) ^ 0x5A17
        return value & 1 == 0 ? -1 : 1
    }

    private static func pixels(_ image: UIImage) -> ([UInt8], Int, Int)? {
        guard let source = image.cgImage else { return nil }
        let width = source.width
        let height = source.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let address = buffer.baseAddress,
                  let context = CGContext(
                    data: address,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return false }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return rendered ? (bytes, width, height) : nil
    }

    static func embed(_ image: UIImage) -> UIImage {
        guard image.size.width >= 64, image.size.height >= 64,
              let (initial, width, height) = pixels(image) else { return image }
        var bytes = initial
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width - 1, by: step) {
                let delta = strength * sign(column: x / step, row: y / step)
                for (pixel, adjustment) in [(x, delta), (x + 1, -delta)] {
                    let offset = (y * width + pixel) * 4
                    for channel in 0..<3 {
                        bytes[offset + channel] = UInt8(max(0, min(255, Int(bytes[offset + channel]) + adjustment)))
                    }
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let output = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else { return image }
        return UIImage(cgImage: output, scale: image.scale, orientation: .up)
    }

    static func embed(data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return embed(image).jpegData(compressionQuality: 0.98)
    }

    static func detect(data: Data) -> Bool {
        guard let image = UIImage(data: data), image.size.width >= 64, image.size.height >= 64,
              let (bytes, width, height) = pixels(image) else { return false }
        var score = 0.0
        var samples = 0
        func luminance(_ offset: Int) -> Int {
            (Int(bytes[offset]) * 77 + Int(bytes[offset + 1]) * 150 + Int(bytes[offset + 2]) * 29) / 256
        }
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width - 1, by: step) {
                let first = (y * width + x) * 4
                let second = first + 4
                score += Double(sign(column: x / step, row: y / step) * (luminance(first) - luminance(second)))
                samples += 1
            }
        }
        return samples > 0 && score / Double(samples) > 0.75
    }
}
