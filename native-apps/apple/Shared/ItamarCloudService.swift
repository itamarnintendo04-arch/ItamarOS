#if os(iOS)
import Foundation
import SwiftUI
import Security

enum ItamarCloudConfig {
    static let url = (Bundle.main.object(forInfoDictionaryKey: "ITAMAR_SUPABASE_URL") as? String ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    static let publicKey = (Bundle.main.object(forInfoDictionaryKey: "ITAMAR_SUPABASE_PUBLISHABLE_KEY") as? String ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    static var enabled: Bool {
        guard let parsed = URL(string: url) else { return false }
        return parsed.scheme == "https" && !publicKey.isEmpty
    }
}

struct ItamarCloudRoom: Codable, Identifiable {
    let id: UUID
    let title: String
    let kind: String
    let owner_id: UUID
    let muted: Bool?
    let latest_at: String?
}

struct ItamarCloudMessage: Codable, Identifiable {
    let id: UUID
    let room_id: UUID
    let sender_id: UUID
    let body: String
    let created_at: String
}

struct ItamarCloudUpdate: Codable, Identifiable {
    let id: UUID
    let room_id: UUID
    let title: String
    let body: String
    let created_at: String
}

struct ItamarCloudProfile: Codable {
    let id: UUID
    let username: String
    let display_name: String
    let about: String
}

private struct CloudUser: Codable {
    let id: UUID
}

private struct CloudToken: Codable {
    let access_token: String
    let refresh_token: String
    let user: CloudUser?
}

private struct CloudSignupReply: Decodable {
    let access_token: String?
    let refresh_token: String?
    let user: CloudUser?
}

private struct CloudError: Decodable {
    let message: String?
    let msg: String?
    let error_description: String?
    let error: String?
    let hint: String?
}

private struct CloudStoredToken: Codable {
    let access: String
    let refresh: String
    let userID: UUID
}

enum ItamarCloudError: LocalizedError {
    case unavailable
    case unauthenticated
    case badResponse(String)
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Connect a Supabase project before enabling internet messaging."
        case .unauthenticated: return "Please sign in again."
        case .badResponse(let text): return text
        }
    }
}

private enum CloudKeychain {
    static let account = "itamaros-connect-session"
    static let service = "org.itamaros.mobile"
    static func save(_ session: CloudStoredToken) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var attributes = base
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }
    static func load() -> CloudStoredToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var output: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &output) == errSecSuccess,
              let data = output as? Data else { return nil }
        return try? JSONDecoder().decode(CloudStoredToken.self, from: data)
    }
    static func clear() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary)
    }
}

@MainActor
final class ItamarCloudService: ObservableObject {
    @Published private(set) var userID: UUID?
    @Published private(set) var profile: ItamarCloudProfile?
    @Published private(set) var rooms: [ItamarCloudRoom] = []
    @Published private(set) var channels: [ItamarCloudRoom] = []
    @Published private(set) var updates: [ItamarCloudUpdate] = []
    @Published var status = ""
    private var session: CloudStoredToken?
    private var notificationsInitialized = false
    private var lastUpdateIDs = Set<UUID>()

    var isSignedIn: Bool { session != nil && userID != nil }

    init() {
        session = CloudKeychain.load()
        userID = session?.userID
    }

    private func request(
        _ route: String, method: String = "GET",
        data: [String: Any]? = nil, authorized: Bool = true,
        query: [URLQueryItem] = [], allowRetry: Bool = true,
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        guard ItamarCloudConfig.enabled,
              let base = URL(string: ItamarCloudConfig.url + route),
              var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw ItamarCloudError.unavailable
        }
        parts.queryItems = query.isEmpty ? nil : query
        guard let url = parts.url else { throw ItamarCloudError.unavailable }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 20
        req.setValue(ItamarCloudConfig.publicKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key,value) in extraHeaders { req.setValue(value, forHTTPHeaderField: key) }
        if authorized {
            guard let token = session?.access else { throw ItamarCloudError.unauthenticated }
            req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        }
        if let data { req.httpBody = try JSONSerialization.data(withJSONObject: data) }
        let (result,response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ItamarCloudError.badResponse("Invalid server response") }
        if http.statusCode == 401 && authorized && allowRetry {
            try await refreshSession()
            return try await request(route, method: method, data: data, authorized: true,
                                     query: query, allowRetry: false, extraHeaders: extraHeaders)
        }
        guard (200...299).contains(http.statusCode) else {
            let message = try? JSONDecoder().decode(CloudError.self, from: result)
            throw ItamarCloudError.badResponse(message?.message ?? message?.msg ??
                message?.error_description ?? message?.error ?? "Server error: \(http.statusCode)")
        }
        return result
    }

    func signIn(email: String, password: String) async throws {
        let body = ["email": email.trimmingCharacters(in: .whitespacesAndNewlines), "password": password]
        let raw = try await request("/auth/v1/token", method: "POST", data: body,
                                    authorized: false, query: [URLQueryItem(name: "grant_type", value: "password")])
        let result = try JSONDecoder().decode(CloudToken.self, from: raw)
        guard let uid = result.user?.id else { throw ItamarCloudError.badResponse("Sign in failed") }
        setSession(access: result.access_token, refresh: result.refresh_token, userID: uid)
        try await reload()
    }

    func signUp(email: String, password: String) async throws {
        let body = ["email": email.trimmingCharacters(in: .whitespacesAndNewlines), "password": password]
        let raw = try await request("/auth/v1/signup", method: "POST", data: body, authorized: false)
        let result = try JSONDecoder().decode(CloudSignupReply.self, from: raw)
        if let access = result.access_token, let refresh = result.refresh_token,
           let uid = result.user?.id {
            setSession(access: access, refresh: refresh, userID: uid)
            try await reload()
        } else {
            status = "Check your email to confirm your account, then sign in."
        }
    }

    private func setSession(access: String, refresh: String, userID: UUID) {
        let value = CloudStoredToken(access: access, refresh: refresh, userID: userID)
        session = value
        self.userID = userID
        CloudKeychain.save(value)
    }

    private func refreshSession() async throws {
        guard let previous = session else { throw ItamarCloudError.unauthenticated }
        let raw = try await request("/auth/v1/token", method: "POST",
                                    data: ["refresh_token": previous.refresh],
                                    authorized: false, query: [URLQueryItem(name: "grant_type", value: "refresh_token")])
        let result = try JSONDecoder().decode(CloudToken.self, from: raw)
        setSession(access: result.access_token, refresh: result.refresh_token,
                   userID: result.user?.id ?? previous.userID)
    }

    func signOut() {
        session = nil; userID = nil; profile = nil
        rooms = []; channels = []; updates = []
        notificationsInitialized = false; lastUpdateIDs = []
        CloudKeychain.clear()
    }

    func reload() async throws {
        guard let userID else { return }
        async let profileData = request("/rest/v1/itamar_profiles",
            query: [URLQueryItem(name: "id", value: "eq.\(userID.uuidString.lowercased())"),
                    URLQueryItem(name: "select", value: "id,username,display_name,about")])
        async let roomsData = request("/rest/v1/rpc/itamar_my_rooms", method: "POST", data: [:])
        async let updatesData = request("/rest/v1/rpc/itamar_my_updates", method: "POST", data: [:])
        let profiles = try JSONDecoder().decode([ItamarCloudProfile].self, from: await profileData)
        let loadedRooms = try JSONDecoder().decode([ItamarCloudRoom].self, from: await roomsData)
        let loadedUpdates = try JSONDecoder().decode([ItamarCloudUpdate].self, from: await updatesData)
        profile = profiles.first
        rooms = loadedRooms
        // Local activity is limited to unmuted rooms by the server.
        updates = loadedUpdates
        if !notificationsInitialized {
            lastUpdateIDs = Set(loadedUpdates.map(\.id))
            notificationsInitialized = true
        } else {
            let fresh = loadedUpdates.filter { !lastUpdateIDs.contains($0.id) }
            lastUpdateIDs = Set(loadedUpdates.map(\.id))
            // Foreground in-app notifications only. Real background Push needs APNs.
            if !fresh.isEmpty {
                status = "\(fresh.count) new message update\(fresh.count == 1 ? "" : "s")"
            }
        }
    }

    func loadPublicChannels() async throws {
        let raw = try await request("/rest/v1/itamar_rooms",
            query: [URLQueryItem(name: "kind", value: "eq.channel"),
                    URLQueryItem(name: "select", value: "id,title,kind,owner_id"),
                    URLQueryItem(name: "order", value: "created_at.desc"),
                    URLQueryItem(name: "limit", value: "50")])
        channels = try JSONDecoder().decode([ItamarCloudRoom].self, from: raw)
    }

    func saveProfile(name: String, username: String, about: String) async throws {
        guard let userID else { throw ItamarCloudError.unauthenticated }
        let clean = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_.")
        guard (3...24).contains(clean.count), clean.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ItamarCloudError.badResponse("Enter a display name and a valid 3–24 character username.")
        }
        _ = try await request("/rest/v1/itamar_profiles", method: "POST",
            data: ["id": userID.uuidString.lowercased(), "username": clean,
                   "display_name": String(name.prefix(70)), "about": String(about.prefix(160))],
            extraHeaders: ["Prefer": "resolution=merge-duplicates"])
        try await reload()
    }

    func createRoom(kind: String, title: String, username: String? = nil) async throws {
        _ = try await request("/rest/v1/rpc/itamar_create_room", method: "POST",
            data: ["p_kind": kind, "p_title": title, "p_username": username ?? ""])
        try await reload()
    }

    func joinChannel(_ id: UUID) async throws {
        _ = try await request("/rest/v1/rpc/itamar_join_channel", method: "POST",
            data: ["p_room": id.uuidString.lowercased()])
        try await reload()
    }

    func setMuted(_ muted: Bool, roomID: UUID) async throws {
        guard let userID else { throw ItamarCloudError.unauthenticated }
        _ = try await request("/rest/v1/itamar_members", method: "PATCH", data: ["muted": muted],
            query: [URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString.lowercased())"),
                    URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())")])
        try await reload()
    }

    func messages(in roomID: UUID) async throws -> [ItamarCloudMessage] {
        let raw = try await request("/rest/v1/itamar_messages",
            query: [URLQueryItem(name: "room_id", value: "eq.\(roomID.uuidString.lowercased())"),
                    URLQueryItem(name: "select", value: "id,room_id,sender_id,body,created_at"),
                    URLQueryItem(name: "order", value: "created_at.asc"),
                    URLQueryItem(name: "limit", value: "100")])
        return try JSONDecoder().decode([ItamarCloudMessage].self, from: raw)
    }

    func send(_ text: String, in roomID: UUID) async throws {
        guard let userID else { throw ItamarCloudError.unauthenticated }
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4000))
        guard !clean.isEmpty else { return }
        _ = try await request("/rest/v1/itamar_messages", method: "POST",
            data: ["room_id": roomID.uuidString.lowercased(),
                   "sender_id": userID.uuidString.lowercased(), "body": clean])
        try await reload()
    }

    func createParentInvite() async throws -> String {
        let raw = try await request("/rest/v1/rpc/itamar_create_parent_invite", method: "POST", data: [:])
        return try JSONDecoder().decode(String.self, from: raw)
    }

    func redeemParentInvite(code: String, name: String, relationship: String) async throws {
        _ = try await request("/rest/v1/rpc/itamar_redeem_parent_invite", method: "POST",
            data: ["p_code": code, "p_name": name, "p_relationship": relationship])
    }
}
#endif
