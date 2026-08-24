import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraModel()
    @State private var showTutor = true
    @State private var tutorStepIndex = 0

    private let tutorSteps = [
        TutorStep(
            title: "Frame the person",
            instruction: "Point the camera so the person is clearly visible. Keep their head, body, and feet inside the view when you want a full scenic photo.",
            symbolName: "person.crop.rectangle"
        ),
        TutorStep(
            title: "Tilt right",
            instruction: "Rotate the top of the phone slightly to the right. Stop when the horizon or background lines feel level.",
            symbolName: "rotate.right"
        )
    ]

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            OverlayView(
                advice: camera.advice,
                measurements: camera.measurements,
                issues: camera.issues,
                debugEnabled: camera.debugEnabled
            )

            VStack {
                topBar
                Spacer()
                if let captureStatus = camera.captureStatus {
                    Text(captureStatus)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 8)
                }
                adviceCard
                controls
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 18)

            if camera.permissionDenied {
                permissionView
            }

            if showTutor {
                tutorCard
            }
        }
        .background(Color.black)
        .task {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dali V1")
                    .font(.caption.bold())
                    .foregroundStyle(.teal)
                Text("Camera Coach")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                showTutor = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title3.bold())
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

            Button {
                camera.switchCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title3.bold())
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var tutorCard: some View {
        let step = tutorSteps[tutorStepIndex]

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: step.symbolName)
                    .font(.title2.bold())
                    .foregroundStyle(.teal)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("How to use Dali")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                        .textCase(.uppercase)
                    Text(step.title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }

                Spacer()

                Button {
                    showTutor = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.bold())
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.82))
            }

            Text(step.instruction)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("\(tutorStepIndex + 1) of \(tutorSteps.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.58))

                Spacer()

                Button {
                    tutorStepIndex = max(0, tutorStepIndex - 1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .foregroundStyle(tutorStepIndex == 0 ? .white.opacity(0.28) : .white)
                .disabled(tutorStepIndex == 0)

                Button {
                    if tutorStepIndex == tutorSteps.count - 1 {
                        showTutor = false
                    } else {
                        tutorStepIndex += 1
                    }
                } label: {
                    Text(tutorStepIndex == tutorSteps.count - 1 ? "Done" : "Next")
                        .font(.headline)
                        .frame(minWidth: 78, minHeight: 42)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(.teal, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: 460)
        .shadow(radius: 20)
    }

    private var adviceCard: some View {
        HStack(spacing: 12) {
            Text(camera.advice.recipient)
                .font(.caption.bold())
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 96)
                .padding(.vertical, 8)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

            Text(camera.advice.instruction)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(toneColor(camera.advice.tone).opacity(0.7), lineWidth: 1)
        }
        .padding(.bottom, 14)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                camera.capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 72, height: 72)
                    Circle()
                        .stroke(.black.opacity(0.35), lineWidth: 3)
                        .frame(width: 58, height: 58)
                }
                .accessibilityLabel("Take photo")
            }
            .buttonStyle(.plain)

            Button {
                camera.start()
            } label: {
                Label("Start", systemImage: "camera.fill")
                    .frame(minHeight: 44)
                    .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background(.teal, in: RoundedRectangle(cornerRadius: 8))

            Button {
                camera.debugEnabled.toggle()
            } label: {
                Label("Debug", systemImage: "slider.horizontal.3")
                    .frame(minHeight: 44)
                    .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 8))
        }
        .font(.headline)
    }

    private var permissionView: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
            Text("Camera permission needed")
                .font(.title2.bold())
            Text("Enable camera access in Settings to test Dali coaching.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(24)
        .foregroundStyle(.white)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
        .padding(24)
    }

    private func toneColor(_ tone: AdviceTone) -> Color {
        switch tone {
        case .waiting:
            return .white.opacity(0.35)
        case .ready:
            return .teal
        case .warning:
            return .yellow
        case .danger:
            return .red
        }
    }
}

private struct TutorStep {
    let title: String
    let instruction: String
    let symbolName: String
}
