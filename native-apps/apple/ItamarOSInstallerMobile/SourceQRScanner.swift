import SwiftUI
import AVFoundation

/// Reads only HTTPS JSON source URLs from a user-approved QR scan. Does not
/// import or trust the source until the user confirms Add Community Source.
struct SourceQRScanner: UIViewControllerRepresentable {
    let onRead: (String) -> Void

    func makeUIViewController(context: Context) -> SourceQRController {
        let controller = SourceQRController()
        controller.onRead = onRead
        return controller
    }

    func updateUIViewController(_ controller: SourceQRController, context: Context) {}
}

final class SourceQRController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onRead: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var handled = false
    private let message = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        message.text = "Point your camera at a community source QR"
        message.textColor = .white
        message.textAlignment = .center
        message.numberOfLines = 0
        message.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(message)
        NSLayoutConstraint.activate([
            message.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            message.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            message.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { [weak self] in
                    if granted { self?.configureCamera() }
                    else { self?.message.text = "Camera access is required to scan a source QR." }
                }
            }
        default:
            message.text = "Camera permission is disabled. Paste the source URL instead."
        }
    }

    private func configureCamera() {
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            message.text = "Camera is unavailable. Paste the source URL instead."
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        preview = layer
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !handled,
              let qr = objects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
                .first(where: { $0.type == .qr }),
              let value = qr.stringValue,
              (try? ItamarStore.validateURL(value)) != nil else { return }
        handled = true
        onRead?(value)
    }
}
