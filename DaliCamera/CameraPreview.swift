import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool
    let onRotationChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.videoGravity = .resizeAspect
        view.videoPreviewLayer.session = session
        view.mirrored = mirrored
        view.onRotationChange = onRotationChange
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        uiView.mirrored = mirrored
        uiView.onRotationChange = onRotationChange
        uiView.setNeedsLayout()
    }
}

final class PreviewView: UIView {
    var mirrored = false
    var onRotationChange: ((CGFloat) -> Void)?
    private var lastRotation: CGFloat?

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let orientation = window?.windowScene?.interfaceOrientation else { return }
        let angle: CGFloat
        switch orientation {
        case .landscapeLeft: angle = 180
        case .landscapeRight: angle = 0
        case .portraitUpsideDown: angle = 270
        default: angle = 90
        }
        if let connection = videoPreviewLayer.connection {
            if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = mirrored
            }
        }
        if lastRotation != angle {
            lastRotation = angle
            DispatchQueue.main.async { [weak self] in self?.onRotationChange?(angle) }
        }
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
