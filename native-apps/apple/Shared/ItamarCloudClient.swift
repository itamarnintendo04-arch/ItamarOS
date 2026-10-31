#if os(iOS)
import Foundation
import SwiftUI
import Security

// A real remote client when a Supabase URL and PUBLISHABLE key are configured.
// Never put a service-role key, Apple Account password or signing certificates here.
enum ItamarCloudSettings {
    static var endpoint: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ITAMAROS_SUPABASE_URL") as? String,
              let url = URL(string: value),
              url.scheme == "https", url.host?.hasSuffix(".supabase.co") == true else { return nil }
        return url
    }
    static var publishableKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "ITAMAROS_SUPABASE_PUBLISHABLE_KEY") as? String,
              !key.isEmpty else { return nil }
        return key
    }
    static var configured: Bool { endpoint != nil && publishableKey != nil }
}

struct ItamarCloudRoom: Identifiable, Decodable {
    let id: UUID
    let title: String
    let kind: String
    let owner_id: UUID
    var muted: Bool?
    var latest_at: String?
}

struct ItamarCloudMessage: Identifiable, Decodable {
    let id: UUID
    let room_id: UUID
    let sender_id: UUID
    let body: String
    let created_at: String
}

struct ItamarCloudUpdate: Identifiable, Decodable {
    let id: UUID
    let room_id: UUID
    let title: String
    let body: String
    let created_at: String
}

struct ItamarCloudProfile: Decodable {
    let id: UUID
    let username: String
    let display_name: String
    let about: String
}

private struct ItamarCloudToken: Codable {
    let access: String
    let refresh: String
    let userID: UUID
    let expires: Date
}

enum ItamarCloudError: LocalizedError {
    case unconfigured, invalidResponse, unauthorized, server(String)
    var errorDescription: String? {
        switch self {
        case .unconfigured: "Cloud messaging has not been configured."
        case .invalidResponse: "Invalid response from the messaging service."
        case .unauthorized: "Please sign in again."
        case .server(let detail): detail
        }
    }
}

@MainActor
final class ItamarCloudClient: ObservableObject {
    @Published private(set) var signedIn = false
    @Published private(set) var rooms = [ItamarCloudRoom]()
    @Published private(set) var channels = [ItamarCloudRoom]()
    @Published private(set) var updates = [ItamarCloudUpdate]()
    @Published private(set) var messages = [ItamarCloudMessage]()
    @Published private(set) var profile: ItamarCloudProfile?
    @Published var status = ""
    private var token: ItamarCloudToken?
    private let service = "org.itamaros.mobile.cloud.auth"
    private let account = "session"

    var userID: UUID? { token?.userID }

    init() {
        if let data = readToken(),
           let saved = try? JSONDecoder().decode(ItamarCloudToken.self, from: data) {
            token = saved
            signedIn = true
        }
    }

    private func readToken() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private func saveToken(_ newToken: ItamarCloudToken) {
        token = newToken
        signedIn = true
        guard let data = try? JSONEncoder().encode(newToken) else { return }
        let key: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(key as CFDictionary)
        var entry = key
        entry[kSecValueData as String] = data
        entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(entry as CFDictionary, nil)
    }

    func signOut() {
        let key: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(key as CFDictionary)
        token = nil
        signedIn = false
        rooms = []
        channels = []
        updates = []
        messages = []
        profile = nil
        status = "Signed out on this device."
    }

    private func raw(_ path: String, method: String = "GET",
                     body: [String: Any]? = nil, bearer: String? = nil,
                     prefer: String? = nil) async throws -> Data {
        guard let base = ItamarCloudSettings.endpoint,
              let key = ItamarCloudSettings.publishableKey,
              let url = URL(string: path, relativeTo: base)?.absoluteURL else {
            throw ItamarCloudError.unconfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bearer {
            request.setValue("Bearer " + bearer, forHTTPHeaderField: "Authorization")
        }
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ItamarCloudError.invalidResponse }
        if (200..<300).contains(http.statusCode) { return data }
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let message = (obj?["msg"] ?? obj?["error_description"] ?? obj?["message"] ?? obj?["error"]) as? String
        if http.statusCode == 401 { throw ItamarCloudError.unauthorized }
        throw ItamarCloudError.server(message ?? "Server returned HTTP \(http.statusCode)")
    }

    private func tokenFromResponse(_ data: Data) throws -> ItamarCloudToken {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = obj["access_token"] as? String,
              let refresh = obj["refresh_token"] as? String,
              let user = obj["user"] as? [String: Any],
              let idText = user["id"] as? String,
              let id = UUID(uuidString: idText) else { throw ItamarCloudError.invalidResponse }
        let seconds = (obj["expires_in"] as? NSNumber)?.doubleValue ?? 3600
        return ItamarCloudToken(access: access, refresh: refresh,
                                userID: id, expires: Date().addingTimeInterval(seconds))
    }

    func signIn(email: String, password: String) async throws {
        let data = try await raw("/auth/v1/token?grant_type=password", method: "POST",
                                 body: ["email": email, "password": password])
        saveToken(try tokenFromResponse(data))
        try await refresh()
    }

    func signUp(email: String, password: String) async throws {
        let data = try await raw("/auth/v1/signup", method: "POST",
                                 body: ["email": email, "password": password])
        if let newToken = try? tokenFromResponse(data) {
            saveToken(newToken)
            try await refresh()
        } else {
            status = "Check your email to confirm your account, then sign in."
        }
    }

    private func currentAccess() async throws -> String {
        guard let token else { throw ItamarCloudError.unauthorized }
        if token.expires > Date().addingTimeInterval(45) { return token.access }
        let data = try await raw("/auth/v1/token?grant_type=refresh_token", method: "POST",
                                 body: ["refresh_token": token.refresh])
        let refreshed = try tokenFromResponse(data)
        saveToken(refreshed)
        return refreshed.access
    }

    private func call(_ path: String, method: String = "GET",
                      body: [String: Any]? = nil, prefer: String? = nil) async throws -> Data {
        try await raw(path, method: method, body: body,
                      bearer: currentAccess(), prefer: prefer)
    }

    private func decodeArray<T: Decodable>(_ data: Data, as type: T.Type) throws -> [T] {
        try JSONDecoder().decode([T].self, from: data)
    }

    private func scalar(_ data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        if let value = object as? String { return value }
        throw ItamarCloudError.invalidResponse
    }

    func refresh() async throws {
        try await loadProfile()
        try await loadRooms()
        try await loadUpdates()
    }

    func loadProfile() async throws {
        guard let id = userID else { throw ItamarCloudError.unauthorized }
        let data = try await call("/rest/v1/itamar_profiles?id=eq.\(id.uuidString.lowercased())&select=id,username,display_name,about&limit=1")
        profile = try decodeArray(data, as: ItamarCloudProfile.self).first
    }

    func saveProfile(name: String, username: String, about: String) async throws {
        guard let id = userID else { throw ItamarCloudError.unauthorized }
        let handle = username.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased().replacingOccurrences(of: "@", with: "")
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_.")
        guard (3...24).contains(handle.count),
              handle.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ItamarCloudError.server("Enter a name and a username with 3–24 letters, digits, _ or .")
        }
        _ = try await call("/rest/v1/itamar_profiles?on_conflict=id", method: "POST",
                           body: ["id": id.uuidString.lowercased(), "username": handle,
                                  "display_name": String(name.prefix(70)), "about": String(about.prefix(160))],
                           prefer: "resolution=merge-duplicates,return=minimal")
        try await loadProfile()
    }

    func loadRooms() async throws {
        let data = try await call("/rest/v1/rpc/itamar_my_rooms", method: "POST", body: [:])
        rooms = try decodeArray(data, as: ItamarCloudRoom.self)
    }

    func loadChannels() async throws {
        let data = try await call("/rest/v1/itamar_rooms?kind=eq.channel&select=id,title,kind,owner_id&limit=100&order=created_at.desc")
        channels = try decodeArray(data, as: ItamarCloudRoom.self)
    }

    func createRoom(kind: String, title: String, username: String? = nil) async throws {
        var body: [String: Any] = ["p_kind": kind, "p_title": title]
        if let username { body["p_username"] = username }
        _ = try scalar(call("/rest/v1/rpc/itamar_create_room", method: "POST", body: body))
        try await loadRooms()
    }

    func join(channel: UUID) async throws {
        _ = try await call("/rest/v1/rpc/itamar_join_channel", method: "POST",
                           body: ["p_room": channel.uuidString.lowercased()])
        try await loadRooms()
    }

    func loadMessages(room: UUID) async throws {
        let id = room.uuidString.lowercased()
        let data = try await call("/rest/v1/itamar_messages?room_id=eq.\(id)&select=id,room_id,sender_id,body,created_at&order=created_at.asc&limit=100")
        messages = try decodeArray(data, as: ItamarCloudMessage.self)
    }

    func send(text: String, room: UUID) async throws {
        guard let id = userID else { throw ItamarCloudError.unauthorized }
        let text = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4000))
        guard !text.isEmpty else { return }
        _ = try await call("/rest/v1/itamar_messages", method: "POST",
                           body: ["room_id": room.uuidString.lowercased(),
                                  "sender_id": id.uuidString.lowercased(), "body": text],
                           prefer: "return=minimal")
        try await loadMessages(room: room)
    }

    func setMuted(_ muted: Bool, room: UUID) async throws {
        _ = try await call("/rest/v1/rpc/itamar_set_mute", method: "POST",
                           body: ["p_room": room.uuidString.lowercased(), "p_muted": muted])
        try await refresh()
    }

    func loadUpdates() async throws {
        let data = try await call("/rest/v1/rpc/itamar_my_updates", method: "POST", body: [:])
        updates = try decodeArray(data, as: ItamarCloudUpdate.self)
    }

    func createParentInvite() async throws -> String {
        try scalar(call("/rest/v1/rpc/itamar_create_parent_invite", method: "POST", body: [:]))
    }

    func redeemParentInvite(code: String, name: String, relationship: String) async throws {
        _ = try await call("/rest/v1/rpc/itamar_redeem_parent_invite", method: "POST",
                           body: ["p_code": code, "p_name": String(name.prefix(70)),
                                  "p_relationship": relationship])
        status = "Parent invite redeemed. This does not grant access to chat content."
    }
}
#endif
