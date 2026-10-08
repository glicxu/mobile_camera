import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool
    let onRotationChange: (CGFloat) -> Void
    let onTap: (_ previewPoint: CGPoint, _ devicePoint: CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.videoGravity = .resizeAspect
        view.videoPreviewLayer.session = session
        view.mirrored = mirrored
        view.onRotationChange = onRotationChange
        view.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        uiView.mirrored = mirrored
        uiView.onRotationChange = onRotationChange
        uiView.onTap = onTap
        uiView.setNeedsLayout()
    }
}

final class PreviewView: UIView {
    var mirrored = false
    var onRotationChange: ((CGFloat) -> Void)?
    var onTap: ((CGPoint, CGPoint) -> Void)?
    private var lastRotation: CGFloat?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
        isUserInteractionEnabled = true
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let point = recognizer.location(in: self)
        let unitPoint = CGPoint(x: point.x / bounds.width, y: point.y / bounds.height)
        let devicePoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
        guard (0...1).contains(devicePoint.x), (0...1).contains(devicePoint.y) else { return }
        onTap?(unitPoint, devicePoint)
    }

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
