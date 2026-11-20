import Foundation
import SwiftUI

private struct CatalogEnvelope: Decodable {
    let schema_version: Int
    let apps: [ItamarApp]
}

struct ItamarApp: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let category: String
    let bundle_id: String
    let release_tag: String
    let asset_name: String
    let source_path: String
    let icon_path: String
    let requires_signing: Bool

    private static let ownerRepo = "itamarnintendo04-arch/ItamarOS"

    var releaseURL: URL? {
        guard release_tag.range(of: #"^[a-zA-Z0-9_.-]+$"#, options: .regularExpression) != nil else { return nil }
        return URL(string: "https://github.com/\(Self.ownerRepo)/releases/tag/\(release_tag)")
    }

    var ipaURL: URL? {
        guard asset_name.range(of: #"^[a-zA-Z0-9_.-]+\.ipa$"#, options: .regularExpression) != nil else { return nil }
        return URL(string: "https://github.com/\(Self.ownerRepo)/releases/download/\(release_tag)/\(asset_name)")
    }

    var iconURL: URL? {
        guard !icon_path.isEmpty && !icon_path.contains("..") else { return nil }
        return URL(string: "https://raw.githubusercontent.com/\(Self.ownerRepo)/main/\(icon_path)")
    }

    var sourceURL: URL? {
        guard !source_path.contains("..") else { return nil }
        return URL(string: "https://github.com/\(Self.ownerRepo)/tree/main/\(source_path)")
    }

    var version: String {
        release_tag.replacingOccurrences(of: "-preview.1", with: " • Preview")
    }
}

@MainActor
final class ItamarAppCatalog: ObservableObject {
    @Published private(set) var apps: [ItamarApp] = []
    @Published var loading = false
    @Published var error: String?
    @Published var downloadingId: String?
    @Published private(set) var downloaded: [String: URL] = [:]

    func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            guard let url = URL(string: "https://raw.githubusercontent.com/itamarnintendo04-arch/ItamarOS/main/catalog/ios-apps.json") else {
                throw VaultError.message("ItamarOS catalog URL is unavailable.")
            }
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 25
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw VaultError.message("ItamarOS catalog is currently unavailable.")
            }
            guard data.count < 250_000 else {
                throw VaultError.message("The catalog response was unexpectedly large.")
            }
            let envelope = try JSONDecoder().decode(CatalogEnvelope.self, from: data)
            guard envelope.schema_version == 1 else {
                throw VaultError.message("Update the installer to read the latest catalog.")
            }
            apps = envelope.apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func download(_ app: ItamarApp) async {
        guard downloadingId == nil else { return }
        guard let link = app.ipaURL else {
            error = "The release does not have a downloadable IPA yet."
            return
        }
        downloadingId = app.id
        defer { downloadingId = nil }
        do {
            var request = URLRequest(url: link)
            request.timeoutInterval = 90
            let (temp, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw VaultError.message("No published IPA is available for \(app.name) yet. Check its Release page.")
            }
            if response.expectedContentLength > 2_000_000_000 {
                throw VaultError.message("The selected IPA exceeds the 2 GB limit.")
            }
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("CatalogDownloads", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let candidate = folder.appendingPathComponent(UUID().uuidString + ".ipa")
            try FileManager.default.moveItem(at: temp, to: candidate)
            do {
                let inspected = try IPAAnalyzer.inspectLocalIPA(candidate)
                guard inspected.bundleIdentifier == app.bundle_id else {
                    throw VaultError.message("Downloaded IPA has an unexpected Bundle ID. Nothing was installed.")
                }
                let destination = folder.appendingPathComponent(app.id + "-UNSIGNED.ipa")
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: candidate, to: destination)
                downloaded[app.id] = destination
            } catch {
                try? FileManager.default.removeItem(at: candidate)
                throw error
            }
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct CatalogScreen: View {
    @EnvironmentObject private var vault: CertificateVault
    @StateObject private var catalog = ItamarAppCatalog()
    @State private var chosenApp: ItamarApp?
    @State private var filter = ""

    private var listedApps: [ItamarApp] {
        guard !filter.isEmpty else { return catalog.apps }
        return catalog.apps.filter {
            $0.name.localizedCaseInsensitiveContains(filter)
                || $0.category.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    Text("All ItamarOS iPhone apps from the official main repository. Developer IPAs need Apple signing and provisioning before installation.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if catalog.loading { ProgressView("Checking app releases…") }
                    if catalog.apps.isEmpty && !catalog.loading {
                        ContentUnavailableView("No apps loaded", systemImage: "wifi.exclamationmark",
                                               description: Text("Check your connection and tap Refresh."))
                    }
                    ForEach(listedApps) { app in
                        HStack(alignment: .top, spacing: 15) {
                            AsyncImage(url: app.iconURL) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Image(systemName: app.category == "Games" ? "gamecontroller.fill" : "app.fill")
                                        .font(.title)
                                        .foregroundStyle(.cyan)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                            .frame(width: 68, height: 68)
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            VStack(alignment: .leading, spacing: 8) {
                                Text(app.name).font(.headline)
                                Text(app.description).font(.caption).foregroundStyle(.secondary)
                                Text("Unsigned developer IPA")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Button {
                                    chosenApp = app
                                } label: {
                                    Label("Install", systemImage: "arrow.down.app.fill")
                                        .frame(minWidth: 96)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                if let release = app.releaseURL {
                                    Link("View release", destination: release).font(.caption)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding()
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                    }
                }.padding()
            }
            .searchable(text: $filter, prompt: "Search ItamarOS apps")
            .navigationTitle("ItamarOS Apps")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await catalog.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await catalog.refresh() }
            .sheet(item: $chosenApp) { app in
                AppInstallSheet(app: app, catalog: catalog)
                    .environmentObject(vault)
            }
            .alert("App Catalog", isPresented: Binding(get: { catalog.error != nil },
                                                     set: { if !$0 { catalog.error = nil } })) {
                Button("OK") { catalog.error = nil }
            } message: { Text(catalog.error ?? "") }
        }
    }
}

private struct AppInstallSheet: View {
    let app: ItamarApp
    @ObservedObject var catalog: ItamarAppCatalog
    @EnvironmentObject private var vault: CertificateVault
    @Environment(\.dismiss) private var dismiss
    @AppStorage("installer.target.udid") private var deviceUDID = ""
    @State private var showingSigner = false
    @State private var showingManifest = false

    private var candidates: [CertificateMatch] {
        vault.matchesForCustomIPA(bundleIdentifier: app.bundle_id, targetUDID: deviceUDID)
    }

    private var approvedCandidate: CertificateMatch? {
        let compatible = candidates.filter { $0.level == .preflightMatch }
        return vault.autoSelect ? compatible.first : compatible.first(where: { $0.id == vault.selected?.id })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("App") {
                    LabeledContent("Name", value: app.name)
                    LabeledContent("Bundle ID", value: app.bundle_id)
                    LabeledContent("Build type", value: "Unsigned developer preview")
                }
                Section("Your certificate") {
                    if let best = approvedCandidate {
                        Label(best.name, systemImage: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        Text(best.reason).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Label("No matching personal signing certificate has passed the local checks.",
                              systemImage: "exclamationmark.shield")
                            .foregroundStyle(.orange)
                        Text("Import a certificate you own under Certificates. A matching P12, Apple provisioning profile and the iPhone UDID are required.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(candidates.prefix(3)) { match in
                            Text("\(match.name): \(match.reason)")
                                .font(.caption)
                        }
                    }
                    TextField("iPhone UDID from trusted computer", text: $deviceUDID)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.caption.monospaced())
                }
                Section("1. Download") {
                    if let file = catalog.downloaded[app.id] {
                        Label("IPA downloaded and Bundle ID checked", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        ShareLink(item: file) {
                            Label("Save developer IPA to Files", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            Task { await catalog.download(app) }
                        } label: {
                            Label(catalog.downloadingId == app.id ? "Downloading IPA…" : "Download IPA",
                                  systemImage: "arrow.down.circle")
                        }
                        .disabled(catalog.downloadingId != nil)
                    }
                }
                Section("2. Sign") {
                    Button {
                        showingSigner = true
                    } label: {
                        Label("Open authorized IPA signer", systemImage: "signature")
                    }
                    .disabled(catalog.downloaded[app.id] == nil || approvedCandidate == nil)
                    Text("The selected certificate is used for compatibility checks. To protect saved private keys, the current signing workspace requires you to select your authorized P12 and profile again; they are not sent automatically to a remote web page.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("3. Install through iOS") {
                    Button {
                        showingManifest = true
                    } label: {
                        Label("Install with HTTPS manifest", systemImage: "iphone.and.arrow.forward")
                    }
                    Text("The signed IPA must be hosted by an authorized distributor with a valid HTTPS manifest. iOS controls the actual installation. This installer cannot silently install an unsigned IPA.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Install \(app.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSigner) {
                EmbeddedIPASignerView()
            }
            .sheet(isPresented: $showingManifest) {
                ManifestInstallView()
            }
        }
    }
}
