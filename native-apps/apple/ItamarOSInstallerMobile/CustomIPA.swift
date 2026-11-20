import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

// The application reads app metadata without executing or loading unsigned code.
struct IPAInspection: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    let bundleIdentifier: String
    let version: String
}

enum CertificateMatchLevel: Int, Comparable {
    case rejected = 0
    case reviewRequired = 1
    case preflightMatch = 2
    static func < (lhs: CertificateMatchLevel, rhs: CertificateMatchLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    var title: String {
        switch self {
        case .rejected: return "Not compatible"
        case .reviewRequired: return "Needs review"
        case .preflightMatch: return "Preflight match"
        }
    }
    var icon: String {
        switch self {
        case .rejected: return "xmark.circle.fill"
        case .reviewRequired: return "questionmark.circle.fill"
        case .preflightMatch: return "checkmark.shield.fill"
        }
    }
}

struct CertificateMatch: Identifiable {
    let id: UUID
    let name: String
    let expiry: Date?
    let level: CertificateMatchLevel
    let reason: String
}

enum IPAAnalyzer {
    static func importIPA(_ source: URL) throws -> IPAInspection {
        let scope = source.startAccessingSecurityScopedResource()
        defer { if scope { source.stopAccessingSecurityScopedResource() } }
        guard source.pathExtension.lowercased() == "ipa" else {
            throw VaultError.message("Choose an IPA file from Files.")
        }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CustomIPAs", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let path = folder.appendingPathComponent(UUID().uuidString + ".ipa")
        try FileManager.default.copyItem(at: source, to: path)
        do {
            return try inspectLocalIPA(path, displayName: source.lastPathComponent)
        } catch {
            try? FileManager.default.removeItem(at: path)
            throw error
        }
    }

    static func inspectLocalIPA(_ path: URL, displayName: String? = nil) throws -> IPAInspection {
        guard path.pathExtension.lowercased() == "ipa" else {
            throw VaultError.message("This is not an IPA archive.")
        }
        let bytes = try path.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard bytes > 0 && bytes < 2_000_000_000 else {
            throw VaultError.message("The IPA is empty or exceeds the 2 GB import limit.")
        }
        guard let archive = Archive(url: path, accessMode: .read) else {
            throw VaultError.message("IPA is not a readable ZIP archive.")
        }
        var metadata: Entry?
        for entry in archive {
            guard entry.path.range(of: #"^Payload/[^/]+\.app/Info\.plist$"#,
                                   options: .regularExpression) != nil else { continue }
            metadata = entry
            break
        }
        guard let entry = metadata, entry.uncompressedSize <= 1_000_000 else {
            throw VaultError.message("IPA does not contain a valid app Info.plist.")
        }
        var plistBytes = Data()
        _ = try archive.extract(entry) { chunk in
            if plistBytes.count + chunk.count > 1_000_000 {
                throw VaultError.message("IPA Info.plist exceeds the safety limit.")
            }
            plistBytes.append(chunk)
        }
        guard let plist = try PropertyListSerialization.propertyList(from: plistBytes,
                                    options: [], format: nil) as? [String: Any],
              let bundle = plist["CFBundleIdentifier"] as? String,
              bundle.count >= 3 && bundle.count < 240 && bundle.contains(".") else {
            throw VaultError.message("IPA has no readable application Bundle ID.")
        }
        let version = plist["CFBundleShortVersionString"] as? String ?? "Unknown"
        return IPAInspection(url: path, fileName: displayName ?? path.lastPathComponent,
                             bundleIdentifier: bundle, version: version)
    }
}

struct CustomIPAScreen: View {
    @EnvironmentObject private var vault: CertificateVault
    @AppStorage("installer.target.udid") private var deviceUDID = ""
    @State private var importing = false
    @State private var application: IPAInspection?
    @State private var errorText: String?
    @State private var selectedMatchID: UUID?
    @State private var showSigner = false
    @State private var showInstallManifest = false

    private var matches: [CertificateMatch] {
        guard let application else { return [] }
        return vault.matchesForCustomIPA(bundleIdentifier: application.bundleIdentifier,
                                          targetUDID: deviceUDID)
    }

    private var preferred: CertificateMatch? {
        let eligible = matches.filter { $0.level == .preflightMatch }
        if vault.autoSelect {
            return eligible.first
        }
        return eligible.first(where: { $0.id == (selectedMatchID ?? vault.selected?.id) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    HStack(spacing: 14) {
                        Image(systemName: "shippingbox.and.arrow.backward.fill")
                            .font(.largeTitle).foregroundStyle(.cyan)
                            .frame(width: 58, height: 58)
                            .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Install your own IPA").font(.title2.bold())
                            Text("Device and certificate compatibility preview")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Button { importing = true } label: {
                        Label(application == nil ? "Choose custom IPA from Files" : "Choose another IPA",
                              systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.borderedProminent)

                    if let application {
                        VStack(alignment: .leading, spacing: 9) {
                            Label("Selected IPA", systemImage: "app.badge.checkmark").font(.headline)
                            Text(application.fileName).font(.subheadline.bold()).textSelection(.enabled)
                            Text("Bundle ID: \(application.bundleIdentifier)")
                                .font(.caption.monospaced()).foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            Text("Version: \(application.version)").font(.caption)
                        }.installerPanel()

                        VStack(alignment: .leading, spacing: 11) {
                            Text("Your iPhone's device UDID").font(.headline)
                            TextField("Enter UDID from your trusted computer", text: $deviceUDID)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.caption.monospaced())
                                .textFieldStyle(.roundedBorder)
                            Text("iOS apps cannot read the hardware UDID. Copy it from Finder, Apple Devices, or iTunes on a computer you trust. This value stays on your iPhone.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.installerPanel()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Certificate compatibility").font(.headline)
                            if matches.isEmpty {
                                Text("Import a P12 and the matching provisioning profile under Certificates first.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            ForEach(matches) { match in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Image(systemName: match.level.icon)
                                            .foregroundStyle(match.level == .preflightMatch ? .green :
                                                match.level == .rejected ? .red : .orange)
                                        VStack(alignment: .leading) {
                                            Text(match.name).font(.subheadline.bold())
                                            Text(match.level.title).font(.caption)
                                        }
                                        Spacer()
                                        if preferred?.id == match.id {
                                            Text("PREFERRED").font(.caption2.bold()).foregroundStyle(.cyan)
                                        }
                                    }
                                    Text(match.reason).font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let expiry = match.expiry {
                                        Text("Expiry: \(expiry.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                    if match.level == .preflightMatch && !vault.autoSelect {
                                        Button("Select for this IPA") { selectedMatchID = match.id }
                                            .font(.caption)
                                    }
                                }
                                .padding(.vertical, 9)
                                Divider()
                            }
                        }.installerPanel()

                        if let preferred {
                            Label("Preferred identity: \(preferred.name)", systemImage: "checkmark.shield")
                                .font(.subheadline).foregroundStyle(.green)
                        } else {
                            Label("No confirmed preflight match for this device and app",
                                  systemImage: "exclamationmark.shield")
                                .font(.subheadline).foregroundStyle(.orange)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Signing and installation").font(.headline)
                            Button { showSigner = true } label: {
                                Label("Sign IPA with my authorized certificate",
                                      systemImage: "signature")
                                    .frame(maxWidth: .infinity, minHeight: 42)
                            }
                            .buttonStyle(.borderedProminent)
                            Text("The signer processes files in a browser-based WebAssembly workspace. For privacy, select your IPA, P12 and provisioning profile there manually; saved private keys and TXT passwords are never automatically sent to the page.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button { showInstallManifest = true } label: {
                                Label("Install signed IPA using HTTPS manifest",
                                      systemImage: "arrow.down.app")
                                    .frame(maxWidth: .infinity, minHeight: 42)
                            }
                            .buttonStyle(.bordered)
                            Text("For a correctly signed IPA that is already hosted through an Apple-supported distribution method. Requires a real HTTPS manifest from the publisher. No silent installation.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .installerPanel()

                        ShareLink(item: application.url) {
                            Label("Export original IPA to a computer",
                                  systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 42)
                        }
                        .buttonStyle(.bordered)

                        Text("Only use certificates you own or have explicit authorization to use. An IPA is not installed simply by generating a signed file. Apple controls final device trust, profile eligibility, and installation.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView("No IPA selected", systemImage: "square.stack.3d.up",
                          description: Text("Choose a local IPA to inspect its Bundle ID and check saved signing profiles."))
                            .padding(.top, 28)
                    }
                }.padding()
            }
            .navigationTitle("Custom IPA")
            .sheet(isPresented: $showSigner) {
                EmbeddedIPASignerView()
            }
            .sheet(isPresented: $showInstallManifest) {
                ManifestInstallView()
            }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [UTType(filenameExtension: "ipa", conformingTo: .data) ?? .data]) { result in
                switch result {
                case .success(let url):
                    do {
                        application = try IPAAnalyzer.importIPA(url)
                        selectedMatchID = nil
                    } catch { errorText = error.localizedDescription }
                case .failure(let error):
                    errorText = error.localizedDescription
                }
            }
            .alert("Custom IPA", isPresented: Binding(get: { errorText != nil },
                                                     set: { if !$0 { errorText = nil } })) {
                Button("OK") { errorText = nil }
            } message: { Text(errorText ?? "") }
        }
    }
}

private struct InstallerPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }
}

private extension View {
    func installerPanel() -> some View {
        modifier(InstallerPanelModifier())
    }
}
