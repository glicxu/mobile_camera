import SwiftUI

struct OverlayView: View {
    let advice: Advice
    let measurements: Measurements
    let issues: [PhotoIssue]
    let debugEnabled: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ruleOfThirds

                if let person = measurements.personBox {
                    box(person.rect, in: proxy.size, color: .teal, label: "person")
                }

                if let face = measurements.faceBox {
                    box(face.rect, in: proxy.size, color: .yellow, label: "face")
                }

                directionHint

                if debugEnabled {
                    debugPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 130)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var ruleOfThirds: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                path.move(to: CGPoint(x: width / 3, y: 0))
                path.addLine(to: CGPoint(x: width / 3, y: height))
                path.move(to: CGPoint(x: width * 2 / 3, y: 0))
                path.addLine(to: CGPoint(x: width * 2 / 3, y: height))
                path.move(to: CGPoint(x: 0, y: height / 3))
                path.addLine(to: CGPoint(x: width, y: height / 3))
                path.move(to: CGPoint(x: 0, y: height * 2 / 3))
                path.addLine(to: CGPoint(x: width, y: height * 2 / 3))
            }
            .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }

    private var directionHint: some View {
        Group {
            if advice.type != "ready", let arrow = arrowText(for: advice.instruction) {
                Text(arrow)
                    .font(.system(size: 54, weight: .heavy))
                    .foregroundStyle(.teal)
                    .shadow(radius: 10)
            }
        }
    }

    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("roll \(measurements.cameraRollDegrees, specifier: "%.1f") deg")
            Text("face \(measurements.faceLuminance ?? -1, specifier: "%.0f") bg \(measurements.backgroundLuminance ?? -1, specifier: "%.0f")")
            Text("issues \(issues.map(\.type).joined(separator: ", "))")
                .lineLimit(3)
        }
        .font(.caption.monospaced())
        .foregroundStyle(.white)
        .padding(10)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 8))
    }

    private func box(_ rect: CGRect, in size: CGSize, color: Color, label: String) -> some View {
        let drawRect = CGRect(
            x: rect.minX * size.width,
            y: rect.minY * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(color, lineWidth: 3)
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .foregroundStyle(.black)
                .background(color, in: RoundedRectangle(cornerRadius: 4))
                .offset(x: 5, y: -24)
        }
        .frame(width: drawRect.width, height: drawRect.height)
        .position(x: drawRect.midX, y: drawRect.midY)
    }

    private func arrowText(for instruction: String) -> String? {
        let lower = instruction.lowercased()
        if lower.contains("left") { return "<-" }
        if lower.contains("right") { return "->" }
        if lower.contains("raise") { return "^" }
        if lower.contains("lower") { return "v" }
        return nil
    }
}
