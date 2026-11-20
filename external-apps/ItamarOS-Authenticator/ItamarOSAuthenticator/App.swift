import SwiftUI
import CryptoKit
import Security
import AVFoundation
import LocalAuthentication
import UIKit
import UserNotifications

@main
struct ItamarOSAuthenticatorApp: App {
    @StateObject private var vault = OTPVault()
    @StateObject private var approvals = ItamarApprovals()
    @UIApplicationDelegateAdaptor(PushDelegate.self) private var push
    var body: some Scene {
        WindowGroup {
            AppHome()
                .environmentObject(vault)
                .environmentObject(approvals)
                .preferredColorScheme(.dark)
                .tint(.mint)
                .task { await approvals.refresh() }
                .onReceive(NotificationCenter.default.publisher(for: .apnsReceived)) { note in
                    if let token = note.object as? String {
                        Task { await approvals.updatePushToken(token) }
                    }
                }
        }
    }
}
extension Notification.Name {
    static let apnsReceived = Notification.Name("ItamarOSAPNSTokenReceived")
}
final class PushDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .apnsReceived, object: token)
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
struct OTPEntry: Codable, Identifiable {
    let id: UUID
    var issuer: String
    var label: String
    var method: String
    var algorithm: String
    var period: Int
    var counter: UInt64
}
enum VaultFailure: LocalizedError {
    case text(String)
    var errorDescription: String? {
        if case .text(let message) = self { return message }
        return "Unknown authenticator error."
    }
}
enum SecureKeychain {
    static let service = "net.itamaros.authenticator.secure"
    static func save(_ data: Data, key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var payload = query
        payload[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        payload[kSecValueData as String] = data
        let code = SecItemAdd(payload as CFDictionary, nil)
        guard code == errSecSuccess else { throw VaultFailure.text("Unable to save this account securely.") }
    }
    static func read(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    static func remove(_ key: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ] as CFDictionary)
    }
}
enum OTP {
    static func base32(_ input: String) -> Data? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)
        var bits = 0, buffer = 0
        var bytes: [UInt8] = []
        var found = false
        for ch in input.uppercased().utf8 {
            if ch == 32 || ch == 45 || ch == 61 { continue }
            guard let index = alphabet.firstIndex(of: ch) else { return nil }
            found = true
            buffer = (buffer << 5) | index
            bits += 5
            if bits >= 8 {
                bits -= 8
                bytes.append(UInt8((buffer >> bits) & 255))
                buffer &= (1 << bits) - 1
            }
        }
        return found && !bytes.isEmpty ? Data(bytes) : nil
    }
    static func generate(secret: Data, counter: UInt64, algorithm: String) -> String {
        var time = counter.bigEndian
        let input = withUnsafeBytes(of: &time) { Data($0) }
        let key = SymmetricKey(data: secret)
        let mac: [UInt8]
        switch algorithm.uppercased() {
        case "SHA256":
            mac = Array(HMAC<SHA256>.authenticationCode(for: input, using: key))
        case "SHA512":
            mac = Array(HMAC<SHA512>.authenticationCode(for: input, using: key))
        default:
            mac = Array(HMAC<Insecure.SHA1>.authenticationCode(for: input, using: key))
        }
        let start = Int(mac[mac.count - 1] & 0x0f)
        let value = (UInt32(mac[start] & 0x7f) << 24)
            | (UInt32(mac[start + 1]) << 16)
            | (UInt32(mac[start + 2]) << 8)
            | UInt32(mac[start + 3])
        return String(format: "%06u", value % 1_000_000)
    }
}
@MainActor
final class OTPVault: ObservableObject {
    @Published var accounts: [OTPEntry] = []
    @Published var message: String?
    @Published var requireUnlock = UserDefaults.standard.bool(forKey: "requireUnlock")
    private let accountKey = "net.itamaros.authenticator.accounts"
    init() {
        if let data = UserDefaults.standard.data(forKey: accountKey),
           let saved = try? JSONDecoder().decode([OTPEntry].self, from: data) {
            accounts = saved
        }
    }
    func addURL(_ value: String) throws {
        guard let url = URLComponents(string: value),
              url.scheme?.lowercased() == "otpauth",
              let method = url.host?.lowercased(),
              method == "totp" || method == "hotp" else {
            throw VaultFailure.text("Scan a valid otpauth:// QR code.")
        }
        let fields = Dictionary((url.queryItems ?? []).map { ($0.name.lowercased(), $0.value ?? "") }, uniquingKeysWith: { _, new in new })
        guard (fields["digits"] ?? "6") == "6" else { throw VaultFailure.text("Only six-digit codes are supported.") }
        let period = Int(fields["period"] ?? "30") ?? 30
        guard (15...120).contains(period) else { throw VaultFailure.text("Invalid code period.") }
        let algorithm = (fields["algorithm"] ?? "SHA1").uppercased().replacingOccurrences(of: "-", with: "")
        guard ["SHA1", "SHA256", "SHA512"].contains(algorithm) else { throw VaultFailure.text("Unsupported verification algorithm.") }
        guard let encoded = fields["secret"], let secret = OTP.base32(encoded), secret.count >= 10 else {
            throw VaultFailure.text("Invalid or missing secret key.")
        }
        let path = String(url.path.dropFirst()).removingPercentEncoding ?? String(url.path.dropFirst())
        let parts = path.components(separatedBy: ":")
        let issuer = (fields["issuer"].flatMap { $0.isEmpty ? nil : $0 } ?? (parts.count > 1 ? parts[0] : "Account"))
        let label = (parts.last?.isEmpty == false ? parts.last! : "Account")
        let count = UInt64(fields["counter"] ?? "0") ?? 0
        try add(issuer: issuer, label: label, method: method, algorithm: algorithm, period: period, counter: count, key: secret)
    }
    func addManual(issuer: String, label: String, secret: String) throws {
        guard let key = OTP.base32(secret), key.count >= 10 else {
            throw VaultFailure.text("The setup key must be a valid Base32 secret.")
        }
        try add(issuer: issuer, label: label, method: "totp", algorithm: "SHA1", period: 30, counter: 0, key: key)
    }
    private func add(issuer: String, label: String, method: String, algorithm: String, period: Int, counter: UInt64, key: Data) throws {
        let entry = OTPEntry(id: UUID(), issuer: String(issuer.prefix(60)),
            label: String(label.prefix(100)), method: method, algorithm: algorithm,
            period: period, counter: counter)
        try SecureKeychain.save(key, key: entry.id.uuidString)
        accounts.append(entry)
        persist()
    }
    func value(_ entry: OTPEntry, at date: Date) -> String {
        guard let key = SecureKeychain.read(entry.id.uuidString) else { return "------" }
        let counter: UInt64 = entry.method == "hotp" ? entry.counter : UInt64(max(0, date.timeIntervalSince1970)) / UInt64(entry.period)
        return OTP.generate(secret: key, counter: counter, algorithm: entry.algorithm)
    }
    func nextHOTP(_ entry: OTPEntry) {
        guard let i = accounts.firstIndex(where: { $0.id == entry.id }) else { return }
        if accounts[i].counter < UInt64.max { accounts[i].counter += 1 }
        persist()
    }
    func remove(at offsets: IndexSet) {
        for i in offsets { SecureKeychain.remove(accounts[i].id.uuidString) }
        accounts.remove(atOffsets: offsets)
        persist()
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountKey)
        }
    }
    func authenticateDevice() async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return true }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock ItamarOS Authenticator")) == true
    }
}
struct AppHome: View {
    @EnvironmentObject private var vault: OTPVault
    @EnvironmentObject private var approvals: ItamarApprovals
    @State private var addAccount = false
    @State private var search = ""
    @State private var unlocked = false
    var body: some View {
        TabView {
            NavigationStack {
                TimelineView(.periodic(from: .now, by: 1)) { tick in
                    List {
                        if vault.accounts.isEmpty {
                            ContentUnavailablePlaceholder()
                        }
                        ForEach(vault.accounts.filter { search.isEmpty || ($0.issuer + " " + $0.label).localizedCaseInsensitiveContains(search) }) { item in
                            VStack(alignment: .leading, spacing: 9) {
                                Text(item.issuer).font(.headline)
                                Text(item.label).font(.footnote).foregroundStyle(.secondary)
                                HStack {
                                    Text(vault.value(item, at: tick.date))
                                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                                        .textSelection(.enabled)
                                        .privacySensitive()
                                    Spacer()
                                    if item.method == "hotp" {
                                        Button("Next") { vault.nextHOTP(item) }.buttonStyle(.bordered)
                                    } else {
                                        let remaining = item.period - (Int(tick.date.timeIntervalSince1970) % item.period)
                                        Text(String(remaining) + "s").font(.caption.monospacedDigit()).foregroundStyle(.mint)
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                        }
                        .onDelete { offsets in
                            let list = vault.accounts.filter { search.isEmpty || ($0.issuer + " " + $0.label).localizedCaseInsensitiveContains(search) }
                            let identifiers = offsets.compactMap { index in list.indices.contains(index) ? list[index].id : nil }
                            let positions = IndexSet(vault.accounts.indices.filter { identifiers.contains(vault.accounts[$0].id) })
                            vault.remove(at: positions)
                        }
                    }
                    .searchable(text: $search, prompt: "Search accounts")
                }
                .navigationTitle("Authenticator")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { addAccount = true } label: { Image(systemName: "plus.circle.fill") }
                            .accessibilityLabel("Add account")
                    }
                }
                .sheet(isPresented: $addAccount) { AddOTPView().environmentObject(vault) }
            }
            .tabItem { Label("Codes", systemImage: "number") }
            ApprovalsView()
                .tabItem { Label("Approvals", systemImage: "shield.lefthalf.filled") }
            NavigationStack {
                Form {
                    Section("Appearance") {
                        NavigationLink { ChangeAppIconView() } label: {
                            Label("Change App Icon", systemImage: "paintpalette.fill")
                        }
                    }
                    Section("Security") {
                        Toggle("Require device unlock", isOn: $vault.requireUnlock)
                            .onChange(of: vault.requireUnlock) { value in
                                UserDefaults.standard.set(value, forKey: "requireUnlock")
                            }
                        Text("Secrets are stored in iOS Keychain on this device.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("ItamarOS") {
                        Text("ItamarOS Authenticator • Version 1.4")
                        Text("Six-digit codes only")
                    }
                }
                .navigationTitle("Settings")
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .overlay {
            if vault.requireUnlock && !unlocked {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 18) {
                        Image(systemName: "lock.shield.fill").font(.system(size: 52)).foregroundStyle(.mint)
                        Text("Authenticator Locked").font(.title.bold())
                        Button("Unlock with Face ID / Passcode") {
                            Task { unlocked = await vault.authenticateDevice() }
                        }.buttonStyle(.borderedProminent)
                    }.padding()
                }
            }
        }
        .task {
            if vault.requireUnlock { unlocked = await vault.authenticateDevice() }
            else { unlocked = true }
        }
        .alert("ItamarOS Authenticator", isPresented: Binding(
            get: { vault.message != nil },
            set: { if !$0 { vault.message = nil } })) {
            Button("OK") { vault.message = nil }
        } message: {
            Text(vault.message ?? "")
        }
    }
}
struct ContentUnavailablePlaceholder: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "shield.checkered").font(.system(size: 42)).foregroundStyle(.mint)
            Text("No accounts yet").font(.headline)
            Text("Tap + to scan a QR code or add a setup key. Your codes are generated offline.")
                .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 45)
        .listRowBackground(Color.clear)
    }
}
struct AddOTPView: View {
    @EnvironmentObject private var vault: OTPVault
    @Environment(\.dismiss) private var dismiss
    @State private var scan = false
    @State private var issuer = "ItamarOS"
    @State private var label = ""
    @State private var secret = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Scan QR code") {
                    Button { scan = true } label: { Label("Scan setup QR", systemImage: "qrcode.viewfinder") }
                }
                Section("Or add manually") {
                    TextField("Service", text: $issuer)
                    TextField("Account email or username", text: $label)
                        .textInputAutocapitalization(.never)
                    SecureField("Base32 setup key", text: $secret)
                        .textInputAutocapitalization(.characters)
                    Button("Add six-digit account") {
                        do {
                            try vault.addManual(issuer: issuer, label: label, secret: secret)
                            dismiss()
                        } catch { vault.message = error.localizedDescription }
                    }
                    .disabled(issuer.isEmpty || label.isEmpty || secret.isEmpty)
                }
                Section {
                    Text("Setup keys must come from the service you're connecting. Never share your setup key or verification codes.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $scan) {
                QRCodeScanner { value in
                    scan = false
                    do {
                        try vault.addURL(value)
                        dismiss()
                    } catch { vault.message = error.localizedDescription }
                }
            }
        }
    }
}
struct QRCodeScanner: UIViewControllerRepresentable {
    let found: (String) -> Void
    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onCode = found
        return controller
    }
    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}
final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private let preview = AVCaptureVideoPreviewLayer()
    private var used = false
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        preview.session = session
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview.frame = view.bounds
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            DispatchQueue.global(qos: .utility).async { self.session.stopRunning() }
        }
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !used, let code = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        used = true
        onCode?(code)
    }
}
