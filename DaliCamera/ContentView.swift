import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraModel()

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
                adviceCard
                controls
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 18)

            if camera.permissionDenied {
                permissionView
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
