#!/usr/bin/env swift

import AppKit
import Foundation

struct MarketingScreenshot {
    let source: String
    let output: String
    let label: String
    let headline: String
    let detail: String
    let accent: NSColor
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let screenshots = [
    MarketingScreenshot(
        source: "docs/app_store_assets/screenshots/final/iphone-01-real-photo-result-1179x2556.jpg",
        output: "docs/app_store_assets/screenshots/framed/iphone-01-beautiful-results-1179x2556.jpg",
        label: "BEAUTIFUL RESULTS",
        headline: "Let the Photo Speak",
        detail: "A vivid finish with the Dali Cam signature.",
        accent: NSColor(calibratedRed: 0.91, green: 0.68, blue: 0.22, alpha: 1)
    ),
    MarketingScreenshot(
        source: "docs/app_store_assets/screenshots/final/iphone-02-live-coaching-1179x2556.jpg",
        output: "docs/app_store_assets/screenshots/framed/iphone-02-live-coaching-1179x2556.jpg",
        label: "LIVE COACHING",
        headline: "Shoot With a Coach",
        detail: "Level, steadiness, and exposure—guided live.",
        accent: NSColor(calibratedRed: 0.20, green: 0.72, blue: 0.75, alpha: 1)
    ),
    MarketingScreenshot(
        source: "docs/app_store_assets/screenshots/source/iphone-03-professional-controls.png",
        output: "docs/app_store_assets/screenshots/framed/iphone-03-professional-controls-1179x2556.jpg",
        label: "PRO CONTROLS",
        headline: "Take Full Control",
        detail: "Focus, depth, and exposure at your fingertips.",
        accent: NSColor(calibratedRed: 0.20, green: 0.72, blue: 0.75, alpha: 1)
    ),
    MarketingScreenshot(
        source: "docs/app_store_assets/screenshots/source/iphone-04-filter-and-beautify.png",
        output: "docs/app_store_assets/screenshots/framed/iphone-04-filter-and-beautify-1179x2556.jpg",
        label: "EDIT & BEAUTIFY",
        headline: "Finish It Your Way",
        detail: "Enhance, filter, beautify, crop, and straighten.",
        accent: NSColor(calibratedRed: 0.91, green: 0.68, blue: 0.22, alpha: 1)
    ),
]

let canvasSize = NSSize(width: 1179, height: 2556)
let frameRect = NSRect(x: 105, y: 385, width: 969, height: 2101)
let screenRect = NSRect(x: 132, y: 412, width: 915, height: 1984)

func font(_ size: CGFloat, weight: NSFont.Weight) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

func drawText(
    _ text: String,
    rect: NSRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    (text as NSString).draw(
        in: rect,
        withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
    )
}

for item in screenshots {
    let sourceURL = root.appendingPathComponent(item.source)
    let outputURL = root.appendingPathComponent(item.output)
    guard let source = NSImage(contentsOf: sourceURL) else {
        fatalError("Unable to read \(sourceURL.path)")
    }

    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let canvas = NSImage(size: canvasSize)
    canvas.lockFocusFlipped(true)

    let background = NSGradient(colors: [
        NSColor(calibratedRed: 0.025, green: 0.047, blue: 0.075, alpha: 1),
        NSColor(calibratedRed: 0.025, green: 0.105, blue: 0.145, alpha: 1),
    ])!
    background.draw(in: NSRect(origin: .zero, size: canvasSize), angle: -90)

    let glow = NSBezierPath(ovalIn: NSRect(x: -180, y: -280, width: 850, height: 850))
    item.accent.withAlphaComponent(0.13).setFill()
    glow.fill()

    let label = item.label as NSString
    let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: font(25, weight: .bold),
        .foregroundColor: NSColor.black,
    ]
    let labelSize = label.size(withAttributes: labelAttributes)
    let pillRect = NSRect(x: 80, y: 62, width: labelSize.width + 48, height: 48)
    let pill = NSBezierPath(roundedRect: pillRect, xRadius: 24, yRadius: 24)
    item.accent.setFill()
    pill.fill()
    label.draw(at: NSPoint(x: pillRect.minX + 24, y: pillRect.minY + 9), withAttributes: labelAttributes)

    drawText(
        item.headline,
        rect: NSRect(x: 78, y: 126, width: 1023, height: 92),
        font: font(68, weight: .heavy),
        color: .white
    )
    drawText(
        item.detail,
        rect: NSRect(x: 80, y: 226, width: 1019, height: 82),
        font: font(31, weight: .medium),
        color: NSColor.white.withAlphaComponent(0.82)
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.68)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: 14)
    shadow.set()
    let frame = NSBezierPath(roundedRect: frameRect, xRadius: 76, yRadius: 76)
    NSColor(calibratedWhite: 0.015, alpha: 1).setFill()
    frame.fill()
    NSShadow().set()

    let accentFrame = NSBezierPath(roundedRect: frameRect, xRadius: 76, yRadius: 76)
    item.accent.withAlphaComponent(0.68).setStroke()
    accentFrame.lineWidth = 3
    accentFrame.stroke()

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screenRect, xRadius: 52, yRadius: 52).addClip()
    source.draw(
        in: screenRect,
        from: NSRect(origin: .zero, size: source.size),
        operation: .copy,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()

    let homeIndicator = NSBezierPath(
        roundedRect: NSRect(x: 459, y: 2431, width: 261, height: 11),
        xRadius: 5.5,
        yRadius: 5.5
    )
    NSColor.white.withAlphaComponent(0.55).setFill()
    homeIndicator.fill()

    canvas.unlockFocus()

    guard
        let tiff = canvas.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.96])
    else {
        fatalError("Unable to encode \(outputURL.path)")
    }
    try jpeg.write(to: outputURL)
    print(outputURL.path)
}
