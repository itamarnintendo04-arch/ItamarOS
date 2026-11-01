import Foundation
import SwiftUI
#if os(iOS)
import UserNotifications
#endif

struct NativeAppManifest: Codable {
    struct Component: Codable {
        let id: String
        let version: String
        let platform: String
        let releaseStatus: String?
        let package: URL?
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
    private var foregroundCheckTask: Task<Void,Never>?

    func startAutomaticChecks() {
        guard foregroundCheckTask == nil else { return }
        foregroundCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if UserDefaults.standard.object(forKey:"itamaros.updates.autoCheck") as? Bool ?? true {
                    let due = self.lastChecked.map { Date().timeIntervalSince($0) > 1800 } ?? true
                    if due { await self.check() }
                }
                try? await Task.sleep(for: .seconds(1800))
            }
        }
    }

    private let manifestURL = URL(string: "https://raw.githubusercontent.com/itamarnintendo04-arch/ItamarOS/main/updates/native-apps.json")!

    private var platformComponentID: String {
        #if os(iOS)
        return "itamaros-ios"
        #elseif os(tvOS)
        return "itamaros-tvos"
        #elseif os(macOS)
        return "itamaros-macos-native"
        #elseif os(visionOS)
        return "itamaros-visionos"
        #else
        return "itamaros-ios"
        #endif
    }

    func check() async {
        status = "Checking GitHub release information…"
        availableVersion = nil
        do {
            var request = URLRequest(url: manifestURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let manifest = try JSONDecoder().decode(NativeAppManifest.self, from: data)
            guard manifest.schemaVersion == 1,
                  let component = manifest.components.first(where: { $0.id == platformComponentID }) else {
                throw URLError(.cannotParseResponse)
            }

            let installed = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
            let newerSource = component.version.compare(installed, options: .numeric) == .orderedDescending
            let hasInstallableRelease = component.package != nil
                && component.releaseStatus == "signed-release"

            lastChecked = Date()
            if newerSource && hasInstallableRelease {
                availableVersion = component.version
                #if os(iOS)
                if UserDefaults.standard.bool(forKey:"itamaros.updates.notify"),
                   UserDefaults.standard.string(forKey:"itamaros.updates.lastNotified") != component.version {
                    let content = UNMutableNotificationContent()
                    content.title = "ItamarOS update available"
                    content.body = "A signed update for version "+component.version+" is available. Open Software Updates to review it."
                    let request = UNNotificationRequest(identifier:"itamaros-update-"+component.version,
                                                        content:content,trigger:nil)
                    try? await UNUserNotificationCenter.current().add(request)
                    UserDefaults.standard.set(component.version,forKey:"itamaros.updates.lastNotified")
                }
                #endif
                status = "Version \(component.version) is published. Use its official signed distribution channel to update; iOS cannot silently install an IPA."
            } else if newerSource {
                status = "Source version \(component.version) is newer than your app (\(installed)), but no signed iPhone/iPad update is available for installation."
            } else {
                status = "Installed app: \(installed). Latest published source for this platform: \(component.version). No signed in-app update is available."
            }
        } catch {
            status = "Update check unavailable: \(error.localizedDescription)"
        }
    }
}
