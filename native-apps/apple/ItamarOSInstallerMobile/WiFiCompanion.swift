import SwiftUI
import Foundation
import CryptoKit
import Security
import Network
import AVFoundation

/// First-party local-network pairing. No P12/passwords are transmitted.
/// The TLS certificate is pinned to the fingerprint shown in the computer's
/// pairing QR; no globally trusted CA or HTTP exceptions are required.
struct LANPairingDetails {
    var host: String
    var port: Int
    var code: String
    var fingerprint: String

    init(link: String) throws {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count < 1500, let parts = URLComponents(string: trimmed),
              parts.scheme == "itamaros", parts.host == "pair" else {
            throw PairingFailure.message("Scan the QR shown by ItamarOS Installer on your computer.")
        }
        let fields = Dictionary(
            (parts.queryItems ?? []).compactMap { item -> (String, String)? in
                guard let value = item.value else { return nil }
                return (item.name, value)
            }, uniquingKeysWith: { previous, _ in previous })
        let h = fields["host"] ?? ""
        let p = Int(fields["port"] ?? "") ?? 0
        let c = fields["code"] ?? ""
        let fp = (fields["fp"] ?? "").lowercased()
        guard p > 0 && p <= 65535,
              c.count == 8 && c.allSatisfy(\.isNumber),
              fp.count == 64 && fp.allSatisfy({ $0.isHexDigit }),
              !h.isEmpty, h.count < 254,
              !h.contains("/") && !h.contains(":") && !h.contains("@")
        else {
            throw PairingFailure.message("The QR contains invalid pairing details.")
        }
        // Local networks only; pinning protects the endpoint against a
        // spoofed .local name, router DNS response, or hostile service.
        let partsOfIP = h.split(separator: ".").compactMap { Int($0) }
        let privateIPv4 = partsOfIP.count == 4 &&
            partsOfIP.allSatisfy { (0...255).contains($0) } && (
            partsOfIP[0] == 10 ||
            (partsOfIP[0] == 172 && (16...31).contains(partsOfIP[1])) ||
            (partsOfIP[0] == 192 && partsOfIP[1] == 168) ||
            partsOfIP[0] == 127)
        guard privateIPv4 || h.hasSuffix(".local") || h.hasSuffix(".local.") else {
            throw PairingFailure.message("Pairing must use a private Wi-Fi address.")
        }
        host = h
        port = p
        code = c
        fingerprint = fp
    }
}

enum PairingFailure: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}

struct LANDevice: Identifiable {
    let name: String
    let udid: String
    var id: String { udid }
}

struct LANSigningIdentity: Identifiable {
    let id: String
    let name: String
    let expires: String
    let available: Bool
    let hasProfile: Bool
}

struct LANOfficialApp: Identifiable {
    let id: String
    let name: String
    let description: String
    let signed: Bool
}

final class LANCompanionModel: NSObject, ObservableObject,
                               URLSessionDelegate, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published var pairingLink = ""
    @Published var state = "Not connected"
    @Published var discovered: [String] = []
    @Published var devices: [LANDevice] = []
    @Published var apps: [LANOfficialApp] = []
    @Published var certificates: [LANSigningIdentity] = []
    @Published var selectedCertificateID = ""
    @Published var selectedUDID = ""
    @Published var activeRequest = ""
    @Published var paired = false

    private var details: LANPairingDetails?
    private var token = ""
    private let browser = NetServiceBrowser()
    private var netServices: [NetService] = []
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 35
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    override init() {
        super.init()
        browser.delegate = self
    }

    func startDiscovery() {
        browser.stop()
        browser.searchForServices(ofType: "_itamaros._tcp.", inDomain: "local.")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didFind service: NetService, moreComing: Bool) {
        netServices.append(service)
        service.delegate = self
        service.resolve(withTimeout: 8)
        DispatchQueue.main.async {
            if !self.discovered.contains(service.name) {
                self.discovered.append(service.name)
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didRemove service: NetService, moreComing: Bool) {
        netServices.removeAll { $0 == service }
        DispatchQueue.main.async { self.discovered.removeAll { $0 == service.name } }
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        // Bonjour advertises the server. TLS fingerprint in the QR still
        // authenticates it; a network advertisement alone is not trusted.
        DispatchQueue.main.async {
            if self.state == "Not connected" {
                self.state = "Found \(sender.name). Scan its desktop QR to pair securely."
            }
        }
    }

    func useScannedQR(_ text: String) {
        DispatchQueue.main.async { self.pairingLink = text }
        Task { await pair(link: text) }
    }

    func pair(link: String) async {
        do {
            let parsed = try LANPairingDetails(link: link)
            details = parsed
            await MainActor.run {
                state = "Checking secure Wi-Fi pairing…"
                paired = false
            }
            let answer = try await api("POST", path: "/v1/pair", body: ["code": parsed.code],
                                       requiresSession: false)
            guard let key = answer["session"] as? String, key.count >= 36 else {
                throw PairingFailure.message("Computer did not return a valid pairing session.")
            }
            token = key
            await MainActor.run {
                paired = true
                state = "Secure Wi-Fi connection established."
            }
            try await reload()
        } catch {
            await MainActor.run {
                paired = false
                state = error.localizedDescription
            }
        }
    }

    func reload() async throws {
        async let fetchedDevices = api("GET", path: "/v1/devices")
        async let fetchedApps = api("GET", path: "/v1/apps")
        async let fetchedCertificates = api("GET", path: "/v1/certificates")
        let (deviceJSON, appJSON, certificateJSON) = try await (fetchedDevices, fetchedApps, fetchedCertificates)
        let deviceRows = (deviceJSON["devices"] as? [[String: Any]] ?? [])
            .compactMap { d -> LANDevice? in
                guard let id = d["udid"] as? String, !id.isEmpty else { return nil }
                return LANDevice(name: d["name"] as? String ?? "iPhone", udid: id)
            }
        let appRows = (appJSON["apps"] as? [[String: Any]] ?? [])
            .compactMap { d -> LANOfficialApp? in
                guard let id = d["id"] as? String,
                      let name = d["name"] as? String else { return nil }
                return LANOfficialApp(id: id, name: name,
                                      description: d["description"] as? String ?? "",
                                      signed: d["signed"] as? Bool ?? false)
            }
        let certificateRows = (certificateJSON["certificates"] as? [[String: Any]] ?? []).compactMap { item -> LANSigningIdentity? in
            guard let id = item["id"] as? String, let name = item["name"] as? String else { return nil }
            return LANSigningIdentity(id: id, name: name, expires: item["expires"] as? String ?? "",
                                      available: item["available"] as? Bool ?? false,
                                      hasProfile: item["has_profile"] as? Bool ?? false)
        }
        await MainActor.run {
            certificates = certificateRows
            if !certificateRows.contains(where: { $0.id == selectedCertificateID && $0.available }) {
                selectedCertificateID = certificateRows.first(where: { $0.available })?.id ?? ""
            }
            devices = deviceRows
            apps = appRows
            if !deviceRows.contains(where: { $0.udid == selectedUDID }) {
                selectedUDID = deviceRows.first?.udid ?? ""
            }
        }
    }

    func requestInstall(_ app: LANOfficialApp) async {
        guard paired else { return }
        guard !selectedUDID.isEmpty else {
            await MainActor.run { state = "The computer has not detected a paired iPhone yet." }
            return
        }
        do {
            await MainActor.run {
                activeRequest = app.id
                state = "Requesting \(app.name) from the computer…"
            }
            let result = try await api("POST", path: "/v1/request-install",
                                       body: ["app_id": app.id, "udid": selectedUDID,
                                              "certificate_id": selectedCertificateID])
            guard let id = result["request_id"] as? String else {
                throw PairingFailure.message("No installation request ID was returned.")
            }
            for _ in 0..<90 {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                let answer = try await api("GET", path: "/v1/requests/\(id)")
                guard let job = answer["request"] as? [String: Any],
                      let phase = job["state"] as? String else { continue }
                let detail = job["detail"] as? String ?? ""
                if ["installed", "failed", "denied", "requires_signing"].contains(phase) {
                    let update = phase == "installed" ? "Installed on iPhone."
                        : phase == "requires_signing" ? "Downloaded to computer; signing required."
                        : phase == "denied" ? "Declined by computer." : "Installation failed."
                    await MainActor.run {
                        state = [update, detail].filter { !$0.isEmpty }.joined(separator: " ")
                        activeRequest = ""
                    }
                    return
                }
            }
            await MainActor.run {
                state = "The request is still processing. Check ItamarOS Installer on the computer."
                activeRequest = ""
            }
        } catch {
            await MainActor.run {
                state = error.localizedDescription
                activeRequest = ""
            }
        }
    }

    private func api(_ method: String, path: String,
                     body: [String: String]? = nil, requiresSession: Bool = true) async throws -> [String: Any] {
        guard let details else {
            throw PairingFailure.message("No paired computer was selected.")
        }
        guard let url = URL(string: "https://\(details.host):\(details.port)\(path)") else {
            throw PairingFailure.message("Invalid local network address.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if requiresSession {
            request.setValue(token, forHTTPHeaderField: "X-ItamarOS-Session")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard data.count <= 250_000,
              let http = response as? HTTPURLResponse else {
            throw PairingFailure.message("Unexpected response from the local server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw PairingFailure.message(
                http.statusCode == 403 ? "Pairing code expired or is incorrect."
                : http.statusCode == 401 ? "Pairing session expired. Scan the QR again."
                : "Server returned error \(http.statusCode).")
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PairingFailure.message("The local server returned unreadable data.")
        }
        return object
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let certificate = SecTrustGetCertificateAtIndex(trust, 0),
              let expected = details?.fingerprint else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let actual = SHA256.hash(data: SecCertificateCopyData(certificate) as Data)
            .map { String(format: "%02x", $0) }.joined()
        guard actual == expected else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

struct WiFiCompanionScreen: View {
    @StateObject private var model = LANCompanionModel()
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Discover ItamarOS Installer") {
                    Label("Use the same Wi-Fi network as your Windows computer.",
                          systemImage: "wifi")
                    if model.discovered.isEmpty {
                        Text("No local server found yet. Make sure the desktop Wi-Fi Companion server is running. You can still scan its pairing QR.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ForEach(model.discovered, id: \.self) { name in
                            Label(name, systemImage: "desktopcomputer")
                        }
                    }
                    Button {
                        model.startDiscovery()
                    } label: {
                        Label("Search for local server", systemImage: "arrow.clockwise")
                    }
                }

                Section("Secure pairing") {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Scan pairing QR from computer", systemImage: "qrcode.viewfinder")
                    }
                    TextField("Or paste itamaros://pair?... link", text: $model.pairingLink)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Connect securely") {
                        Task { await model.pair(link: model.pairingLink) }
                    }
                    .disabled(model.pairingLink.isEmpty)
                    Text("The QR contains a temporary pairing code and certificate fingerprint. Connection is encrypted; no signing certificates or passwords are exchanged.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Connection") {
                    Label(model.state, systemImage: model.paired ? "checkmark.shield.fill" : "info.circle")
                        .foregroundStyle(model.paired ? .green : .secondary)
                    if model.paired {
                        Button("Refresh device information") {
                            Task {
                                do { try await model.reload() }
                                catch { model.state = error.localizedDescription }
                            }
                        }
                    }
                }

                if model.paired {
                    Section("Paired iPhone") {
                        if model.devices.isEmpty {
                            Text("The computer has not detected a paired iPhone. Connect by USB once, tap Trust, and enable Wi-Fi syncing in Apple Devices or iTunes if available.")
                                .font(.footnote)
                        } else {
                            Picker("Installation target", selection: $model.selectedUDID) {
                                ForEach(model.devices) { device in
                                    Text(device.name).tag(device.udid)
                                }
                            }
                            if let selected = model.devices.first(where: { $0.udid == model.selectedUDID }) {
                                LabeledContent("Device ID", value: selected.udid)
                                    .font(.caption.monospaced())
                            }
                        }
                    }
                    Section("Computer certificates") {
                        if model.certificates.isEmpty {
                            Text("No desktop signing identities are available. Add your P12 and provisioning profile in the computer app.")
                                .font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Picker("Signing identity", selection: $model.selectedCertificateID) {
                                Text("No identity (already signed IPA)").tag("")
                                ForEach(model.certificates.filter(\.available)) { identity in
                                    Text(identity.name).tag(identity.id)
                                }
                            }
                            if let identity = model.certificates.first(where: { $0.id == model.selectedCertificateID }) {
                                LabeledContent("Expires", value: String(identity.expires.prefix(10)))
                                Text(identity.hasProfile ? "Provisioning profile registered on computer" : "Provisioning profile missing")
                                    .font(.caption).foregroundStyle(identity.hasProfile ? Color.secondary : Color.orange)
                            }
                            Text("Names and status sync from the PC. Private keys, P12 files and passwords never leave it. Signing is not automatic.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Section("Official ItamarOS apps") {
                        Text("Apps are selected from the official releases catalog and downloaded by the computer. No IPA picker is needed.")
                            .font(.footnote).foregroundStyle(.secondary)
                        ForEach(model.apps) { app in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(app.name).font(.headline)
                                Text(app.description)
                                    .font(.caption).foregroundStyle(.secondary)
                                if !app.signed {
                                    Text("Developer preview • needs authorized signing")
                                        .font(.caption2).foregroundStyle(.orange)
                                }
                                Button {
                                    Task { await model.requestInstall(app) }
                                } label: {
                                    Label("Install", systemImage: "arrow.down.app")
                                }
                                .disabled(model.selectedUDID.isEmpty || !model.activeRequest.isEmpty)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                Section("Apple Wi-Fi Sync") {
                    Text("First connect the iPhone with USB and Trust This Computer. In Apple Devices for Windows (or iTunes), enable Wi-Fi syncing. This helps the Apple device service find your iPhone; it does not grant permission for unsigned app installation.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Wi-Fi Companion")
            .sheet(isPresented: $showCamera) {
                NavigationStack {
                    QRPairingCameraView { code in
                        showCamera = false
                        model.useScannedQR(code)
                    }
                    .navigationTitle("Scan Desktop QR")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") { showCamera = false }
                    } }
                }
            }
            .onAppear { model.startDiscovery() }
        }
    }
}

private struct QRPairingCameraView: UIViewControllerRepresentable {
    var onRead: (String) -> Void

    func makeUIViewController(context: Context) -> QRPairingController {
        let controller = QRPairingController()
        controller.onRead = onRead
        return controller
    }

    func updateUIViewController(_ uiViewController: QRPairingController, context: Context) {}
}

private final class QRPairingController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onRead: ((String) -> Void)?
    private let capture = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var alreadyHandled = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              capture.canAddInput(input) else { return }
        capture.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard capture.canAddOutput(output) else { return }
        capture.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: capture)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        preview = layer
        DispatchQueue.global(qos: .userInitiated).async { self.capture.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { self.capture.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !alreadyHandled,
              let qr = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
                .first(where: { $0.type == .qr }),
              let payload = qr.stringValue, payload.hasPrefix("itamaros://pair?") else { return }
        alreadyHandled = true
        onRead?(payload)
    }
}
