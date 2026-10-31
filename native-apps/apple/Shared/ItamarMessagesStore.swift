#if os(iOS)
import Foundation
import SwiftUI

// Offline-first local data. This is NOT an internet chat service.
struct ItamarMessage: Codable, Identifiable {
    var id = UUID()
    var text: String
    var createdAt = Date()
}

struct ItamarThread: Codable, Identifiable {
    enum Kind: String, Codable { case chat, channel }
    var id = UUID()
    var title: String
    var kind: Kind
    var muted = false
    var messages: [ItamarMessage] = []
}

struct ItamarActivity: Codable, Identifiable {
    var id = UUID()
    var threadID: UUID
    var title: String
    var detail: String
    var date = Date()
}

struct ItamarProfile: Codable {
    var name = ""
    var username = ""
    var description = ""
}

struct ItamarParent: Codable {
    var name = ""
    var email = ""
    var relationship = "Parent"
    var invitation = ""
}

@MainActor
final class ItamarMessagesStore: ObservableObject {
    @Published private(set) var profile = ItamarProfile()
    @Published private(set) var threads: [ItamarThread] = []
    @Published private(set) var activities: [ItamarActivity] = []
    @Published private(set) var invitation: String?
    @Published private(set) var parent = ItamarParent()
    @Published private(set) var notificationsPreferred = false

    private struct StoredState: Codable {
        var profile: ItamarProfile
        var threads: [ItamarThread]
        var activities: [ItamarActivity]
        var invitation: String?
        var parent: ItamarParent
        var notificationsPreferred: Bool
    }

    private var location: URL? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return directory.appendingPathComponent("itamaros-messages-preview.json")
    }

    init() {
        if let location, let bytes = try? Data(contentsOf: location),
           let state = try? JSONDecoder().decode(StoredState.self, from: bytes) {
            profile = state.profile
            threads = state.threads
            activities = state.activities
            invitation = state.invitation
            parent = state.parent
            notificationsPreferred = state.notificationsPreferred
        } else {
            threads = [ItamarThread(title: "My notes", kind: .chat)]
        }
    }

    private func persist() {
        guard let location else { return }
        let state = StoredState(profile: profile, threads: threads, activities: activities,
                                invitation: invitation, parent: parent,
                                notificationsPreferred: notificationsPreferred)
        do {
            let directory = location.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let bytes = try JSONEncoder().encode(state)
            try bytes.write(to: location, options: .atomic)
        } catch {
            // Keep unsaved changes in memory; never upload private text to a remote server.
            print("ItamarOS local messages could not be saved: \(error.localizedDescription)")
        }
    }

    func updateProfile(name: String, username: String, description: String) -> String? {
        let sanitizedName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(70))
        let handle = username.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased().replacingOccurrences(of: "@", with: "")
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_.")
        guard !sanitizedName.isEmpty else { return "Enter a display name." }
        guard (3...24).contains(handle.count),
              handle.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Username must be 3–24 characters: a–z, numbers, _ or ."
        }
        profile = ItamarProfile(name: sanitizedName, username: handle,
                                description: String(description.prefix(160)))
        persist()
        return nil
    }

    func createThread(title: String, kind: ItamarThread.Kind) {
        let cleaned = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(90))
        guard !cleaned.isEmpty else { return }
        let thread = ItamarThread(title: cleaned, kind: kind)
        threads.insert(thread, at: 0)
        addActivity(thread, detail: kind == .channel ? "Channel created locally" : "Conversation created locally")
        persist()
    }

    func send(text: String, in threadID: UUID) {
        let cleaned = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4000))
        guard !cleaned.isEmpty, let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[index].messages.append(ItamarMessage(text: cleaned))
        let thread = threads[index]
        addActivity(thread, detail: thread.kind == .channel ? "New local channel post" : "New local message")
        persist()
    }

    func setMuted(_ mute: Bool, for threadID: UUID) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[index].muted = mute
        persist()
    }

    func deleteThread(_ threadID: UUID) {
        threads.removeAll { $0.id == threadID }
        activities.removeAll { $0.threadID == threadID }
        persist()
    }

    var visibleActivities: [ItamarActivity] {
        activities.filter { event in
            guard let thread = threads.first(where: { $0.id == event.threadID }) else { return false }
            return !thread.muted
        }.sorted { $0.date > $1.date }
    }

    private func addActivity(_ thread: ItamarThread, detail: String) {
        activities.insert(ItamarActivity(threadID: thread.id, title: thread.title, detail: detail), at: 0)
        if activities.count > 250 { activities = Array(activities.prefix(250)) }
    }

    func setNotificationsPreferred(_ enabled: Bool) {
        notificationsPreferred = enabled
        persist()
    }

    func createParentInvitation() -> String {
        // Random opaque invite value; contains no profile, email, or contact data.
        let value = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        invitation = value
        persist()
        return value
    }

    func saveLocalParent(name: String, email: String, relationship: String, code: String) {
        parent = ItamarParent(name: String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(70)),
                              email: String(email.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)),
                              relationship: String(relationship.prefix(40)),
                              invitation: code)
        persist()
    }
}
#endif
