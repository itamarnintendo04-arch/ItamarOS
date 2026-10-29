import Foundation
import SwiftUI

struct NativeAppManifest: Codable {
    struct Component: Codable {
        let id: String
        let version: String
        let platform: String
    }

    let schemaVersion: Int
    let version: String
    let components: [Component]
}

@MainActor
final class ReleaseMonitor: ObservableObject {
    @Published var status = "Not checked"
    @Published var availableVersion: String?
    @Published var lastChecked: Date?

    private let manifestURL = URL(string: "https://raw.githubusercontent.com/itamarnintendo04-arch/ItamarOS/main/updates/native-apps.json")!

    func check() async {
        status = "Checking GitHub release information…"
        do {
            var req = URLRequest(url: manifestURL)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let manifest = try JSONDecoder().decode(NativeAppManifest.self, from: data)
            guard manifest.schemaVersion == 1 else {
                throw URLError(.cannotParseResponse)
            }
            lastChecked = Date()
            if manifest.version.compare("1.1.0", options: .numeric) == .orderedDescending {
                availableVersion = manifest.version
                status = "New version information: \(manifest.version). Install using the official App Store/TestFlight when a signed release is actually published."
            } else {
                availableVersion = nil
                status = "Latest source version information: 1.1.0. Native app binary release is not published yet."
            }
        } catch {
            status = "Update check unavailable: \(error.localizedDescription)"
        }
    }
}
