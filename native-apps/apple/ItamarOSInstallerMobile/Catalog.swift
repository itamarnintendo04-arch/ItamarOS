import SwiftUI
import Foundation

private struct RemoteAsset: Decodable {
    var name: String
    var browser_download_url: URL?
    var size: Int?
}

private struct RemoteRelease: Decodable {
    var tag_name: String
    var assets: [RemoteAsset]
}

struct ItamarApp: Identifiable {
    var id: String
    var name: String
    var description: String
    var iconURL: URL?
    var repo: String
    var sourceURL: URL?
    var version: String = "Source available"
    var ipa: URL?
    var signed: Bool { ipa != nil }
}

@MainActor
final class ItamarAppCatalog: ObservableObject {
    @Published var apps: [ItamarApp] = []
    @Published var loading = false
    @Published var error: String?
    @Published var downloadingId: String?
    @Published var downloaded: [String: URL] = [:]

    private let root = "https://raw.githubusercontent.com/itamarnintendo04-arch"
    private let githubAPI = "https://api.github.com/repos/itamarnintendo04-arch"
    private let metadata: [String: (name: String, description: String, icon: String)] = [
        "ItamarOSiOS": ("ItamarOS", "The complete native ItamarOS mobile experience.", "iOS/Assets.xcassets/AppIcon.appiconset/Icon.png"),
        "CloudClimbiOS": ("Cloud Climb", "Platform adventure with colorful worlds and characters.", "CloudClimb/Assets.xcassets/CloudClimbAppIcon.appiconset/Icon.png"),
        "ItamarOSGamesiOS": ("ItamarOS Games", "An original collection of ItamarOS games.", "ItamarOSGames/Assets.xcassets/GamesIcon.appiconset/Icon.png"),
        "SkyboundIslesiOS": ("Skybound Isles", "Explore floating islands and secrets.", "SkyboundIsles/Assets.xcassets/SkyboundIcon.appiconset/Icon.png"),
        "ArenaRushiOS": ("Arena Rush", "An original arena game.", ""),
        "BrowserOSiOS": ("BrowserOS", "The ItamarOS web browser.", ""),
        "ScreenBalanceiOS": ("ItamarOS Screen Balance", "Screen-time balance and family features.", ""),
        "ItamarCutiOS": ("ItamarCut", "Edit videos with ItamarOS.", "ItamarCut/Assets.xcassets/ItamarCutIcon.appiconset/Icon.png"),
        "VoiceRecorderiOS": ("Voice Recorder", "Record and organize audio.", "VoiceRecorder/Assets.xcassets/VoiceRecorderIcon.appiconset/Icon.png")
    ]

    private func request(_ address: URL) async throws -> Data {
        var request = URLRequest(url: address)
        request.setValue("ItamarOS-Installer-iPhone/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 25
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else {
            throw VaultError.message("The ItamarOS catalog is temporarily unavailable.")
        }
        return data
    }

    private func latestRelease(repo: String) async -> RemoteRelease? {
        guard let url = URL(string: "\(githubAPI)/\(repo)/releases/latest"),
              let data = try? await request(url) else { return nil }
        return try? JSONDecoder().decode(RemoteRelease.self, from: data)
    }

    func refresh() async {
        if loading { return }
        loading = true
        error = nil
        defer { loading = false }
        let indexURL = URL(string: "\(root)/ItamarOS/main/native-apps/apple/project.yml")!
        do {
            let data = try await request(indexURL)
            guard let yaml = String(data: data, encoding: .utf8) else {
                throw VaultError.message("Invalid app catalog response.")
            }
            let regex = try NSRegularExpression(pattern: #"(?m)^  ([A-Za-z0-9_]+iOS):\s*$"#)
            let whole = NSRange(yaml.startIndex..<yaml.endIndex, in: yaml)
            let targets = regex.matches(in: yaml, range: whole).compactMap { match -> String? in
                guard let range = Range(match.range(at: 1), in: yaml) else { return nil }
                return String(yaml[range])
            }
            async let mainRelease = latestRelease(repo: "ItamarOS")
            async let authRelease = latestRelease(repo: "ItamarOS-Authenticator")
            let release = await mainRelease
            let standalone = await authRelease
            let rows: [ItamarApp] = targets.map { target in
                let spec = metadata[target]
                let shortName = String(target.dropLast(3))
                let display = spec?.name ?? shortName
                let artwork = spec?.icon ?? ""
                let icon = artwork.isEmpty ? nil : URL(string: "\(root)/ItamarOS/main/native-apps/apple/\(artwork)")
                let folder = artwork.split(separator: "/").first.map(String.init) ?? shortName
                let foundIPA = release?.assets.first(where: { asset in
                    let simple = asset.name.lowercased().replacingOccurrences(of: "-", with: "")
                        .replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "")
                    let wanted = shortName.lowercased().replacingOccurrences(of: "-", with: "")
                    return asset.name.lowercased().hasSuffix(".ipa") &&
                        !simple.contains("unsigned") && simple.contains(wanted)
                })
                return ItamarApp(
                    id: target, name: display, description: spec?.description ?? "An ItamarOS iPhone app.",
                    iconURL: icon, repo: "ItamarOS",
                    sourceURL: URL(string: "https://github.com/itamarnintendo04-arch/ItamarOS/tree/main/native-apps/apple/\(folder)"),
                    version: (foundIPA != nil ? release?.tag_name : nil) ?? "Source available",
                    ipa: foundIPA?.browser_download_url
                )
            }
            var all = rows
            let authIPA = standalone?.assets.first(where: { asset in
                let lower = asset.name.lowercased()
                return lower.hasSuffix(".ipa") && !lower.contains("unsigned")
            })
            all.append(ItamarApp(
                id: "ItamarOS-Authenticator", name: "ItamarOS Authenticator",
                description: "Approve account sign-ins and generate six-digit verification codes.",
                iconURL: URL(string: "\(root)/ItamarOS-Authenticator/main/assets/icon-source.png"),
                repo: "ItamarOS-Authenticator",
                sourceURL: URL(string: "https://github.com/itamarnintendo04-arch/ItamarOS-Authenticator"),
                version: (authIPA != nil ? standalone?.tag_name : nil) ?? "Source available",
                ipa: authIPA?.browser_download_url))
            apps = all.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func download(_ app: ItamarApp) async {
        guard let url = app.ipa, url.scheme == "https", url.host == "github.com",
              url.path.hasPrefix("/itamarnintendo04-arch/") else { return }
        downloadingId = app.id
        defer { downloadingId = nil }
        do {
            let (temp, response) = try await URLSession.shared.download(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw VaultError.message("The download failed or the release is unavailable.")
            }
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destination = dir.appendingPathComponent(app.id + ".ipa")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temp, to: destination)
            downloaded[app.id] = destination
        } catch { self.error = error.localizedDescription }
    }
}

struct CatalogScreen: View {
    @StateObject private var catalog = ItamarAppCatalog()
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    Text("Browse the official ItamarOS iPhone projects. Only published signed IPA releases can be downloaded.")
                        .font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    if catalog.loading { ProgressView("Checking releases...") }
                    ForEach(catalog.apps) { app in
                        HStack(alignment: .top, spacing: 15) {
                            AsyncImage(url: app.iconURL) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Image(systemName: "app.fill")
                                        .font(.title).foregroundStyle(.cyan)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                            .frame(width: 68, height: 68)
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            VStack(alignment: .leading, spacing: 6) {
                                Text(app.name).font(.headline)
                                Text(app.description).font(.caption).foregroundStyle(.secondary)
                                Text(app.version).font(.caption2).foregroundStyle(.cyan)
                                HStack {
                                    if let saved = catalog.downloaded[app.id] {
                                        ShareLink(item: saved) {
                                            Label("Share downloaded IPA", systemImage: "square.and.arrow.up")
                                        }.font(.footnote)
                                    } else if app.signed {
                                        Button {
                                            Task { await catalog.download(app) }
                                        } label: {
                                            Label(catalog.downloadingId == app.id ? "Downloading" : "Download IPA",
                                                  systemImage: "arrow.down.circle")
                                        }
                                        .font(.footnote)
                                        .disabled(catalog.downloadingId != nil)
                                    } else {
                                        Label("Signed IPA not published", systemImage: "clock")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                if let source = app.sourceURL {
                                    Link("View source", destination: source).font(.caption)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding()
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                    }
                }.padding()
            }
            .navigationTitle("ItamarOS Apps")
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await catalog.refresh() } } label: { Image(systemName: "arrow.clockwise") }
            }}
            .task { await catalog.refresh() }
            .alert("Catalog", isPresented: Binding(get: { catalog.error != nil },
                                                   set: { if !$0 { catalog.error = nil } })) {
                Button("OK") { catalog.error = nil }
            } message: { Text(catalog.error ?? "") }
        }
    }
}
