import Foundation
import SwiftUI
import ZIPFoundation

// Official apps are always loaded from the signed-in source's first-party
// GitHub registry. Custom sources are unverified third-party catalogues,
// isolated from the personal certificate vault.
enum StoreSection: String, CaseIterable, Identifiable {
    case discover = "Discover"
    case apps = "Apps"
    case games = "Games"
    case updates = "Updates"
    case library = "Library"
    case sources = "Sources"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .discover: return "sparkles.rectangle.stack"
        case .apps: return "square.grid.2x2"
        case .games: return "gamecontroller"
        case .updates: return "arrow.clockwise.circle"
        case .library: return "square.stack"
        case .sources: return "books.vertical"
        }
    }
}

struct StoreSource: Codable, Identifiable {
    let id: String
    let name: String
    let url: String
    var enabled: Bool
    let official: Bool

    static let firstParty = StoreSource(
        id: "itamaros-official",
        name: "ItamarOS Official",
        url: "https://raw.githubusercontent.com/itamarnintendo04-arch/ItamarOS/main/catalog/ios-apps.json",
        enabled: true, official: true
    )
}

struct StoreItem: Identifiable, Hashable {
    let id: String
    let appID: String
    let name: String
    let summary: String
    let category: String
    let developer: String
    let bundleID: String
    let version: String
    let iconURL: URL?
    let screenshots: [URL]
    let downloadURL: URL
    let releaseURL: URL?
    let sourceID: String
    let sourceName: String
    let official: Bool
    let requiresSigning: Bool

    var isGame: Bool { category.caseInsensitiveCompare("Games") == .orderedSame }
}

struct StoreSourceEnvelope: Decodable {
    let schema_version: Int
    let name: String?
    let apps: [StoreSourceEntry]
}

struct StoreSourceEntry: Decodable {
    let id: String
    let name: String
    let description: String
    let category: String
    let bundle_id: String
    let version: String?
    let developer: String?
    let icon_url: String?
    let screenshots: [String]?
    let download_url: String?
    let release_url: String?
    let release_tag: String?
    let asset_name: String?
    let icon_path: String?
    let requires_signing: Bool?
}

enum StoreValidationError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let value): return value }
    }
}

@MainActor
final class ItamarStore: ObservableObject {
    @Published private(set) var sources: [StoreSource] = [.firstParty]
    @Published private(set) var items: [StoreItem] = []
    @Published private(set) var downloaded: [String: URL] = [:]
    @Published private(set) var loading = false
    @Published private(set) var downloadingID: String?
    @Published var error: String?
    @Published var query = ""

    private let sourcesKey = "itamaros.store.sources.v1"
    private let maxSourceCount = 20

    init() {
        loadSources()
        loadDownloads()
    }

    func apps(for section: StoreSection) -> [StoreItem] {
        let query = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            let matches = query.isEmpty ||
                [item.name, item.summary, item.category, item.developer, item.sourceName]
                    .joined(separator: " ")
                    .localizedStandardContains(query)
            if !matches { return false }
            switch section {
            case .discover, .sources: return true
            case .apps: return !item.isGame
            case .games: return item.isGame
            case .updates: return downloaded[item.id] != nil
            case .library: return downloaded[item.id] != nil
            }
        }
    }

    func addSource(_ raw: String) async {
        do {
            let url = try Self.validateURL(raw)
            guard sources.count < maxSourceCount else {
                throw StoreValidationError.message("You can add up to \(maxSourceCount - 1) community sources.")
            }
            guard !sources.contains(where: { $0.url == url.absoluteString }) else {
                throw StoreValidationError.message("This source is already added.")
            }
            let source = StoreSource(id: UUID().uuidString, name: url.host ?? "Community",
                                     url: url.absoluteString, enabled: true, official: false)
            let loaded = try await fetch(source)
            guard !loaded.isEmpty else {
                throw StoreValidationError.message("This source has no valid iPhone apps.")
            }
            sources.append(source)
            saveSources()
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeSource(_ id: String) {
        guard id != StoreSource.firstParty.id else { return }
        sources.removeAll { $0.id == id && !$0.official }
        items.removeAll { $0.sourceID == id }
        saveSources()
    }

    func setEnabled(_ id: String, _ enabled: Bool) {
        guard id != StoreSource.firstParty.id, let index = sources.firstIndex(where: { $0.id == id }) else { return }
        sources[index].enabled = enabled
        saveSources()
        Task { await refresh() }
    }

    func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        var results = [StoreItem]()
        var failures = [String]()
        for source in sources where source.enabled {
            do {
                let records = try await fetch(source)
                results.append(contentsOf: records)
            } catch {
                failures.append(source.name + ": " + error.localizedDescription)
            }
        }
        // Distinct source-qualified IDs prevent community sources overwriting
        // or impersonating the ItamarOS first-party catalog.
        items = results.sorted { left, right in
            if left.official != right.official { return left.official }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
        if !failures.isEmpty {
            error = failures.joined(separator: "\n")
        } else {
            error = nil
        }
        loadDownloads()
    }

    private func fetch(_ source: StoreSource) async throws -> [StoreItem] {
        let url = try Self.validateURL(source.url)
        var request = URLRequest(url: url)
        request.timeoutInterval = 18
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              let actualURL = response.url, Self.isSafeHTTPS(actualURL) else {
            throw StoreValidationError.message("Source must respond over public HTTPS.")
        }
        guard data.count > 0 && data.count <= 450_000 else {
            throw StoreValidationError.message("Source response is empty or exceeds 450 KB.")
        }
        let envelope = try JSONDecoder().decode(StoreSourceEnvelope.self, from: data)
        guard envelope.schema_version == 1, envelope.apps.count <= 200 else {
            throw StoreValidationError.message("Unsupported source version or too many apps.")
        }
        let accepted: [StoreItem] = envelope.apps.compactMap { app in
            guard app.id.count >= 2 && app.id.count < 120 &&
                    app.id.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil,
                  app.name.count >= 1 && app.name.count < 130,
                  app.bundle_id.count >= 3 && app.bundle_id.count < 240 &&
                    app.bundle_id.contains("."),
                  app.category.count < 70 else { return nil }
            let link: URL?
            let releaseLink: URL?
            let iconLink: URL?
            if source.official {
                let tag = app.release_tag ?? ""
                let asset = app.asset_name ?? ""
                guard tag.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil,
                      asset.range(of: #"^[A-Za-z0-9._-]+\.ipa$"#, options: .regularExpression) != nil else { return nil }
                link = URL(string: "https://github.com/itamarnintendo04-arch/ItamarOS/releases/download/\(tag)/\(asset)")
                releaseLink = URL(string: "https://github.com/itamarnintendo04-arch/ItamarOS/releases/tag/\(tag)")
                let path = app.icon_path ?? ""
                iconLink = path.contains("..") || path.isEmpty ? nil :
                    URL(string: "https://raw.githubusercontent.com/itamarnintendo04-arch/ItamarOS/main/\(path)")
            } else {
                link = app.download_url.flatMap(URL.init(string:))
                releaseLink = app.release_url.flatMap(URL.init(string:))
                iconLink = app.icon_url.flatMap(URL.init(string:))
            }
            guard let link, Self.isSafeHTTPS(link),
                  link.path.lowercased().hasSuffix(".ipa") else { return nil }
            let screenURLs = (app.screenshots ?? []).prefix(6)
                .compactMap(URL.init(string:)).filter(Self.isSafeHTTPS)
            return StoreItem(
                id: source.id + "::" + app.id,
                appID: app.id, name: app.name, summary: String(app.description.prefix(400)),
                category: app.category, developer: source.official ? "ItamarOS" : String((app.developer ?? source.name).prefix(120)),
                bundleID: app.bundle_id, version: app.version ?? (app.release_tag ?? "Preview"),
                iconURL: iconLink.flatMap { Self.isSafeHTTPS($0) ? $0 : nil },
                screenshots: screenURLs,
                downloadURL: link,
                releaseURL: releaseLink.flatMap { Self.isSafeHTTPS($0) ? $0 : nil },
                sourceID: source.id, sourceName: source.official ? "ItamarOS Official" :
                    String((envelope.name ?? source.name).prefix(90)),
                official: source.official,
                requiresSigning: source.official ? true : (app.requires_signing ?? true)
            )
        }
        return accepted
    }

    func download(_ item: StoreItem) async {
        guard downloadingID == nil else { return }
        downloadingID = item.id
        defer { downloadingID = nil }
        do {
            // The downloaded filename and Bundle ID are checked before exposing
            // the file; never execute packages or pass them to the signer silently.
            var request = URLRequest(url: item.downloadURL)
            request.timeoutInterval = 120
            let (temp, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let finalURL = response.url, Self.isSafeHTTPS(finalURL) else {
                throw StoreValidationError.message("Download must be served using HTTPS.")
            }
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("StoreDownloads", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let candidate = dir.appendingPathComponent(UUID().uuidString + ".ipa")
            try FileManager.default.moveItem(at: temp, to: candidate)
            do {
                let scan = try IPAAnalyzer.inspectLocalIPA(candidate)
                guard scan.bundleIdentifier == item.bundleID else {
                    throw StoreValidationError.message("IPA Bundle ID differs from its source listing.")
                }
                let destination = dir.appendingPathComponent(
                    "\(item.sourceID)-\(item.appID).ipa"
                )
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: candidate, to: destination)
                downloaded[item.id] = destination
            } catch {
                try? FileManager.default.removeItem(at: candidate)
                throw error
            }
        } catch {
            error = error.localizedDescription
        }
    }

    private func loadDownloads() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StoreDownloads", isDirectory: true)
        var files = [String: URL]()
        for item in items {
            let file = dir.appendingPathComponent("\(item.sourceID)-\(item.appID).ipa")
            if FileManager.default.fileExists(atPath: file.path) {
                files[item.id] = file
            }
        }
        downloaded = files
    }

    private func loadSources() {
        guard let data = UserDefaults.standard.data(forKey: sourcesKey),
              let saved = try? JSONDecoder().decode([StoreSource].self, from: data) else { return }
        // Imported data can never replace the immutable first-party source.
        var seen = Set<String>([StoreSource.firstParty.url])
        let community = saved.filter { !$0.official }.prefix(maxSourceCount - 1).compactMap { source -> StoreSource? in
            guard let url = try? Self.validateURL(source.url),
                  seen.insert(url.absoluteString).inserted else { return nil }
            return StoreSource(id: UUID(uuidString: source.id) == nil ? UUID().uuidString : source.id,
                               name: String(source.name.prefix(90)), url: url.absoluteString,
                               enabled: source.enabled, official: false)
        }
        sources = [.firstParty] + community
    }

    private func saveSources() {
        UserDefaults.standard.set(try? JSONEncoder().encode(sources.filter { !$0.official }), forKey: sourcesKey)
    }

    static func validateURL(_ raw: String) throws -> URL {
        guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              isSafeHTTPS(url), raw.count <= 1200,
              url.user == nil, url.password == nil, url.fragment == nil else {
            throw StoreValidationError.message("Enter a public HTTPS source URL without credentials.")
        }
        return url
    }

    static func isSafeHTTPS(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(), !host.isEmpty,
              url.user == nil, url.password == nil else { return false }
        if host == "localhost" || host.hasSuffix(".local") ||
            host.hasSuffix(".internal") || host.hasSuffix(".lan") { return false }
        // Disallow numeric IP hosts including private ranges. DNS hostnames can
        // still resolve privately; OS network security is the final boundary.
        if host.contains(":") { return false }
        if host.split(separator: ".").allSatisfy({ Int($0) != nil }) { return false }
        return true
    }
}
