#if os(iOS)
import Foundation

struct ItamarSavedContact: Identifiable, Decodable {
    let id: UUID
    let username: String
    let display_name: String
    let nickname: String
}

struct ItamarPhoneSearchResult: Identifiable, Decodable {
    let id: UUID
    let username: String
    let display_name: String
}

struct ItamarPoll: Identifiable, Decodable {
    let id: UUID
    let room_id: UUID
    let question: String
    let options: [String]
    let multiple: Bool
    let closed: Bool
    let created_at: String
}

struct ItamarPollVote: Decodable {
    let poll_id: UUID
    let option_index: Int
}

@MainActor
extension ItamarCloudService {
    func savedContacts() async throws -> [ItamarSavedContact] {
        let raw = try await request("/rest/v1/rpc/itamar_my_contacts",
                                    method: "POST", data: [:])
        return try JSONDecoder().decode([ItamarSavedContact].self, from: raw)
    }

    func addContact(username: String, nickname: String = "") async throws {
        _ = try await request("/rest/v1/rpc/itamar_add_contact",
                              method: "POST", data: [
                                "p_username": username,
                                "p_nickname": nickname
                              ])
    }

    func lookupPhone(_ number: String) async throws -> ItamarPhoneSearchResult? {
        let raw = try await request("/rest/v1/rpc/itamar_find_verified_phone",
                              method: "POST", data: ["p_phone": number])
        return try JSONDecoder().decode([ItamarPhoneSearchResult].self, from: raw).first
    }

    func setPhoneDiscoverability(_ enabled: Bool) async throws {
        _ = try await request("/rest/v1/rpc/itamar_set_phone_discovery",
                              method: "POST", data: ["p_enabled": enabled])
    }

    func setPhoneForVerification(_ phone: String) async throws {
        // Supabase Auth sends a phone-change OTP. This does not itself verify ownership.
        _ = try await request("/auth/v1/user", method: "PUT", data: ["phone": phone])
    }

    func verifyPhoneChange(phone: String, otp: String) async throws {
        // Completing the OTP challenge is what sets auth.users.phone_confirmed_at.
        _ = try await request("/auth/v1/verify", method: "POST",
                              data: ["phone": phone, "token": otp, "type": "phone_change"])
    }

    func createGroup(title: String, usernames: [String]) async throws {
        _ = try await request("/rest/v1/rpc/itamar_create_group", method: "POST",
                              data: ["p_title": title, "p_usernames": usernames])
        try await reload()
    }

    func manageGroup(room: UUID, operation: String, username: String? = nil,
                     title: String? = nil) async throws {
        _ = try await request("/rest/v1/rpc/itamar_group_manage", method: "POST",
                              data: ["p_room": room.uuidString.lowercased(),
                                     "p_operation": operation,
                                     "p_username": username ?? "",
                                     "p_title": title ?? ""])
        try await reload()
    }

    func polls(in room: UUID) async throws -> [ItamarPoll] {
        let raw = try await request("/rest/v1/itamar_polls",
                          query: [URLQueryItem(name:"room_id",value:"eq.\(room.uuidString.lowercased())"),
                                  URLQueryItem(name:"select",value:"id,room_id,question,options,multiple,closed,created_at"),
                                  URLQueryItem(name:"order",value:"created_at.desc")])
        return try JSONDecoder().decode([ItamarPoll].self, from: raw)
    }

    func votes(in room: UUID) async throws -> [ItamarPollVote] {
        let raw = try await request("/rest/v1/itamar_votes",
                          query: [URLQueryItem(name:"select",value:"poll_id,option_index"),
                                  URLQueryItem(name:"itamar_polls.room_id",value:"eq.\(room.uuidString.lowercased())")])
        return try JSONDecoder().decode([ItamarPollVote].self, from: raw)
    }

    func pollResults(pollID: UUID) async throws -> [ItamarPollVote] {
        let raw = try await request("/rest/v1/itamar_votes",
                          query: [URLQueryItem(name:"poll_id",value:"eq.\(pollID.uuidString.lowercased())"),
                                  URLQueryItem(name:"select",value:"poll_id,option_index")])
        return try JSONDecoder().decode([ItamarPollVote].self, from: raw)
    }

    func createPoll(room: UUID, question: String, options: [String],
                    multiple: Bool = false) async throws {
        _ = try await request("/rest/v1/rpc/itamar_create_poll",
                              method: "POST", data: [
                                "p_room": room.uuidString.lowercased(),
                                "p_question": question,
                                "p_options": options,
                                "p_multiple": multiple
                              ])
    }

    func vote(poll: UUID, option: Int) async throws {
        _ = try await request("/rest/v1/rpc/itamar_vote_poll",
                              method:"POST", data:[
                                "p_poll": poll.uuidString.lowercased(),
                                "p_option": option
                              ])
    }
}
#endif
