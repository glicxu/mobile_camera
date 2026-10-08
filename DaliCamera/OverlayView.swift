import SwiftUI

struct OverlayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let advice: Advice
    let measurements: Measurements
    let issues: [PhotoIssue]
    let debugEnabled: Bool
    var reframeSuggestion: ReframeSuggestion? = nil
    var contentAspectRatio: CGFloat? = nil
    var guidedAction: GuidedAction? = nil
    @State private var directionAnimation = false

    var body: some View {
        GeometryReader { proxy in
            let contentRect = contentRect(in: proxy.size)

            ZStack {
                ruleOfThirds(in: contentRect)

                if debugEnabled, let person = measurements.personBox {
                    box(person.rect, in: contentRect, color: .teal, label: "person detected")
                }

                if debugEnabled, let face = measurements.faceBox {
                    box(face.rect, in: contentRect, color: .yellow, label: "face detected")
                }

                if let reframeSuggestion {
                    reframeOverlay(reframeSuggestion, in: contentRect)
                }

                if debugEnabled, let horizonAngle = measurements.horizonAngleDegrees {
                    horizonLine(angleDegrees: horizonAngle, y: measurements.horizonY ?? 0.5, in: contentRect)
                }

                if debugEnabled {
                    poseLines(in: contentRect)
                    posePoints(in: contentRect)
                }

                directionHint(in: contentRect)
                coachingStatusBadge(in: contentRect)

                if debugEnabled {
                    debugPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 130)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                directionAnimation = true
            }
        }
    }

    private func ruleOfThirds(in rect: CGRect) -> some View {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + rect.width / 3, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width / 3, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX + rect.width * 2 / 3, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 2 / 3, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height / 3))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height / 3))
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 2 / 3))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 2 / 3))
        }
        .stroke(.white.opacity(0.18), lineWidth: 1)
    }

    @ViewBuilder
    private func directionHint(in contentRect: CGRect) -> some View {
        if let direction = advice.visualGuidanceDirection {
            movementGuide(direction, in: contentRect)
        } else if let guidedAction {
            Image(systemName: guidedAction.symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(coachingColor)
                .shadow(radius: 10)
                .accessibilityHidden(true)
        } else if !advice.type.hasPrefix("guided_"), advice.type != "ready", let symbol = advice.directionSymbol {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(coachingColor)
                .shadow(radius: 10)
                .accessibilityHidden(true)
        }
    }

    private func coachingStatusBadge(in contentRect: CGRect) -> some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.68))
                .frame(width: 32, height: 32)
            Circle()
                .fill(coachingColor)
                .frame(width: 20, height: 20)
                .overlay { Circle().stroke(.white.opacity(0.9), lineWidth: 2) }
                .shadow(color: coachingColor.opacity(0.95), radius: 8)
        }
            .position(x: contentRect.midX, y: contentRect.minY + 30)
            .accessibilityHidden(true)
    }

    private var coachingColor: Color {
        switch advice.tone {
        case .ready: return .green
        case .warning, .danger: return .orange
        case .waiting: return .yellow
        }
    }

    private func movementGuide(_ direction: VisualGuidanceDirection, in contentRect: CGRect) -> some View {
        let offset = directionAnimation ? direction.movementOffset : .zero

        return VStack(spacing: 8) {
            Image(systemName: direction.symbol)
                .font(.system(size: 52, weight: .bold))
                .frame(width: 82, height: 82)
                .foregroundStyle(.white)
                .background(coachingColor.opacity(0.92), in: Circle())
                .overlay { Circle().stroke(.white.opacity(0.9), lineWidth: 3) }
                .shadow(color: .black.opacity(0.65), radius: 10)
                .offset(offset)

            Text(advice.instruction)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: min(200, max(140, contentRect.width * 0.48)))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.72), in: Capsule())
                .overlay { Capsule().stroke(.white.opacity(0.35), lineWidth: 1) }
        }
        .position(guidePosition(for: direction, in: contentRect))
        .accessibilityHidden(true)
    }

    private func guidePosition(for direction: VisualGuidanceDirection, in rect: CGRect) -> CGPoint {
        let horizontalInset = min(112, rect.width * 0.27)
        let verticalInset = min(132, rect.height * 0.25)

        switch direction {
        case .left:
            return CGPoint(x: rect.minX + horizontalInset, y: rect.midY)
        case .right:
            return CGPoint(x: rect.maxX - horizontalInset, y: rect.midY)
        case .up:
            return CGPoint(x: rect.midX, y: rect.minY + verticalInset)
        case .down:
            return CGPoint(x: rect.midX, y: rect.maxY - verticalInset)
        case .closer, .farther, .rotateLeft, .rotateRight:
            return CGPoint(x: rect.midX, y: rect.midY)
        }
    }

    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("roll \(measurements.cameraRollDegrees, specifier: "%.1f") deg")
            Text("motion \(measurements.cameraMotion, specifier: "%.2f") stable \(measurements.cameraStable ? "yes" : "no")")
            Text("horizon \(measurements.horizonAngleDegrees ?? 999, specifier: "%.1f") deg conf \(measurements.horizonConfidence, specifier: "%.2f")")
            Text("open \(measurements.skyOrOpenAreaRatio, specifier: "%.2f") pose \(measurements.poseKeypoints.count)")
            Text("face \(measurements.faceLuminance ?? -1, specifier: "%.0f") bg \(measurements.backgroundLuminance ?? -1, specifier: "%.0f")")
            if let face = measurements.faceAnalysis {
                Text("face yaw \(face.yawEstimate ?? 999, specifier: "%.2f") pitch \(face.pitchEstimate ?? 999, specifier: "%.2f") eyes \(face.eyeVisibilityScore, specifier: "%.2f")")
            }
            if let pose = measurements.poseAnalysis {
                Text("arms \(pose.armVisibilityScore, specifier: "%.2f") square \(pose.bodySquarenessScore ?? -1, specifier: "%.2f") flat \(pose.armsFlatAgainstBodyScore ?? -1, specifier: "%.2f")")
            }
            if let reframeSuggestion {
                Text("reframe \(reframeSuggestion.reason) conf \(reframeSuggestion.confidence, specifier: "%.2f")")
            }
            Text("issues \(issues.map(\.type).joined(separator: ", "))")
                .lineLimit(3)
        }
        .font(.caption.monospaced())
        .foregroundStyle(.white)
        .padding(10)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 8))
    }

    private func box(_ rect: CGRect, in contentRect: CGRect, color: Color, label: String) -> some View {
        let drawRect = CGRect(
            x: contentRect.minX + rect.minX * contentRect.width,
            y: contentRect.minY + rect.minY * contentRect.height,
            width: rect.width * contentRect.width,
            height: rect.height * contentRect.height
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

    private func reframeOverlay(_ suggestion: ReframeSuggestion, in contentRect: CGRect) -> some View {
        let cropRect = CGRect(
            x: contentRect.minX + suggestion.cropRect.minX * contentRect.width,
            y: contentRect.minY + suggestion.cropRect.minY * contentRect.height,
            width: suggestion.cropRect.width * contentRect.width,
            height: suggestion.cropRect.height * contentRect.height
        )

        return ZStack(alignment: .topLeading) {
            Path { path in
                path.addRect(contentRect)
                path.addRect(cropRect)
            }
            .fill(.black.opacity(0.38), style: FillStyle(eoFill: true))

            Rectangle()
                .stroke(.yellow, style: StrokeStyle(lineWidth: 4, dash: [12, 7]))
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)

            Text(suggestion.instruction)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(.black)
                .background(.yellow, in: RoundedRectangle(cornerRadius: 6))
                .position(x: min(cropRect.maxX - 58, max(cropRect.minX + 58, cropRect.midX)), y: max(contentRect.minY + 20, cropRect.minY - 18))
        }
    }

    private func horizonLine(angleDegrees: Double, y: CGFloat, in contentRect: CGRect) -> some View {
        let lineLength = hypot(contentRect.width, contentRect.height)
        let centerY = contentRect.minY + max(0, min(1, y)) * contentRect.height

        return Rectangle()
            .fill(.cyan.opacity(0.86))
            .frame(width: lineLength, height: 2)
            .rotationEffect(.degrees(angleDegrees))
            .position(x: contentRect.midX, y: centerY)
            .shadow(radius: 4)
    }

    private func posePoints(in contentRect: CGRect) -> some View {
        ForEach(Array(measurements.poseKeypoints.keys.sorted()), id: \.self) { key in
            if let point = measurements.poseKeypoints[key] {
                Circle()
                    .fill(.orange)
                    .frame(width: 7, height: 7)
                    .position(
                        x: contentRect.minX + point.point.x * contentRect.width,
                        y: contentRect.minY + point.point.y * contentRect.height
                    )
            }
        }
    }

    private func poseLines(in contentRect: CGRect) -> some View {
        Path { path in
            for connection in poseConnections {
                guard let first = point(named: connection.0),
                      let second = point(named: connection.1),
                      first.confidence > 0.2,
                      second.confidence > 0.2 else {
                    continue
                }

                path.move(to: drawPoint(first.point, in: contentRect))
                path.addLine(to: drawPoint(second.point, in: contentRect))
            }
        }
        .stroke(.orange.opacity(0.86), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        .shadow(radius: 3)
    }

    private var poseConnections: [(String, String)] {
        [
            ("leftShoulder", "rightShoulder"),
            ("leftShoulder", "leftForearm"),
            ("leftForearm", "leftHand"),
            ("rightShoulder", "rightForearm"),
            ("rightForearm", "rightHand"),
            ("leftShoulder", "leftUpLeg"),
            ("rightShoulder", "rightUpLeg"),
            ("leftUpLeg", "rightUpLeg"),
            ("leftUpLeg", "leftLeg"),
            ("leftLeg", "leftFoot"),
            ("rightUpLeg", "rightLeg"),
            ("rightLeg", "rightFoot"),
            ("neck", "nose")
        ]
    }

    private func point(named name: String) -> DetectionPoint? {
        for target in normalizedJointAliases(for: name) {
            if let point = measurements.poseKeypoints.first(where: { entry in
                normalizedJointName(entry.key).contains(target)
            })?.value {
                return point
            }
        }

        return nil
    }

    private func normalizedJointAliases(for name: String) -> [String] {
        let normalized = normalizedJointName(name)
        let aliases: [String: [String]] = [
            "lefthip": ["lefthip", "leftupleg"],
            "righthip": ["righthip", "rightupleg"],
            "leftelbow": ["leftelbow", "leftforearm"],
            "rightelbow": ["rightelbow", "rightforearm"],
            "leftwrist": ["leftwrist", "lefthand"],
            "rightwrist": ["rightwrist", "righthand"],
            "leftankle": ["leftankle", "leftfoot"],
            "rightankle": ["rightankle", "rightfoot"],
            "nose": ["nose", "head"]
        ]

        return aliases[normalized] ?? [normalized]
    }

    private func normalizedJointName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func drawPoint(_ point: CGPoint, in contentRect: CGRect) -> CGPoint {
        CGPoint(
            x: contentRect.minX + point.x * contentRect.width,
            y: contentRect.minY + point.y * contentRect.height
        )
    }

    private func unusedCompatibilityPoint(named name: String) -> DetectionPoint? {
        let target = normalizedJointName(name)
        return measurements.poseKeypoints.first { entry in
            normalizedJointName(entry.key).contains(target)
        }?.value
    }

    private func contentRect(in size: CGSize) -> CGRect {
        guard let contentAspectRatio else {
            return CGRect(origin: .zero, size: size)
        }

        return PreviewGeometry.fittedRect(in: size, aspectRatio: contentAspectRatio)
    }

}

struct DigitalDepthOfFocusOverlay: View {
    let measurements: Measurements
    let focusPoint: CGPoint?
    let level: Int
    var contentAspectRatio: CGFloat? = nil

    var body: some View {
        GeometryReader { proxy in
            let contentRect = contentRect(in: proxy.size)
            let subjectRect = subjectRect(in: contentRect)

            if let subjectRect {
                Path { path in
                    path.addRect(contentRect)
                    path.addRoundedRect(
                        in: subjectRect,
                        cornerSize: CGSize(
                            width: min(subjectRect.width, subjectRect.height) * 0.28,
                            height: min(subjectRect.width, subjectRect.height) * 0.28
                        )
                    )
                }
                .fill(.ultraThinMaterial, style: FillStyle(eoFill: true))
                .opacity(0.30 + Double(max(0, min(5, level))) * 0.09)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func subjectRect(in contentRect: CGRect) -> CGRect? {
        let candidates = [measurements.personBox?.rect, measurements.salientObjectBox?.rect, measurements.faceBox?.rect]
            .compactMap { $0 }
        let selected = focusPoint.flatMap { point in
            candidates.first(where: { $0.insetBy(dx: -0.04, dy: -0.04).contains(point) })
        }

        let normalized: CGRect
        if let selected {
            normalized = selected.insetBy(dx: -selected.width * 0.22, dy: -selected.height * 0.18)
        } else if let person = measurements.personBox?.rect {
            normalized = person.insetBy(dx: -person.width * 0.16, dy: -person.height * 0.10)
        } else if let face = measurements.faceBox?.rect {
            normalized = CGRect(
                x: face.minX - face.width * 1.1,
                y: face.minY - face.height * 0.45,
                width: face.width * 3.2,
                height: face.height * 4.7
            )
        } else if let focusPoint {
            normalized = CGRect(x: focusPoint.x - 0.18, y: focusPoint.y - 0.24, width: 0.36, height: 0.48)
        } else {
            return nil
        }

        let minX = max(0, normalized.minX)
        let minY = max(0, normalized.minY)
        let maxX = min(1, normalized.maxX)
        let maxY = min(1, normalized.maxY)
        guard maxX > minX, maxY > minY else { return nil }
        return CGRect(
            x: contentRect.minX + minX * contentRect.width,
            y: contentRect.minY + minY * contentRect.height,
            width: (maxX - minX) * contentRect.width,
            height: (maxY - minY) * contentRect.height
        )
    }

    private func contentRect(in size: CGSize) -> CGRect {
        guard let contentAspectRatio else { return CGRect(origin: .zero, size: size) }
        return PreviewGeometry.fittedRect(in: size, aspectRatio: contentAspectRatio)
    }
}
