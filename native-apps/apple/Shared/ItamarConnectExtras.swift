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

struct ItamarMessageReaction: Decodable {
    let message_id: UUID
    let user_id: UUID
    let emoji: String
}
struct ItamarReactionCount: Identifiable {
    let emoji: String
    let count: Int
    var id: String { emoji }
}
struct ItamarDeliveryReceipt: Decodable {
    let message_id: UUID
    let delivered_at: String?
    let read_at: String?
}
struct ItamarReceiptSummary {
    let delivered: Int
    let read: Int
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
    func groupInvite(room: UUID) async throws -> String {
        let data = try await request("/rest/v1/rpc/itamar_make_group_invite",
            method:"POST",data:["p_room":room.uuidString.lowercased()])
        return try JSONDecoder().decode(String.self, from:data)
    }
    func acceptGroupInvite(code: String) async throws {
        _ = try await request("/rest/v1/rpc/itamar_accept_group_invite",
            method:"POST",data:["p_secret":code])
        try await reload()
    }
    func updateGroupDetails(room: UUID, name: String, description: String, avatar: String?) async throws {
        _ = try await request("/rest/v1/rpc/itamar_set_group_details",
            method:"POST",data:["p_room":room.uuidString.lowercased(),
                "p_title":name,"p_description":description,
                "p_avatar":avatar as Any? ?? NSNull()])
        try await reload()
    }
    func updateProfilePreferences(avatar: String?, receipts: Bool) async throws {
        _ = try await request("/rest/v1/rpc/itamar_set_profile_prefs",method:"POST",
            data:["p_avatar":avatar as Any? ?? NSNull(),"p_receipts":receipts])
        try await reload()
    }
    func editMessage(id: UUID, text: String) async throws {
        _ = try await request("/rest/v1/rpc/itamar_edit_message",method:"POST",
            data:["p_message":id.uuidString.lowercased(),"p_body":text])
    }
    func deleteMessage(id: UUID) async throws {
        _ = try await request("/rest/v1/rpc/itamar_delete_message",method:"POST",
            data:["p_message":id.uuidString.lowercased()])
    }
    func sendOnceText(room: UUID, text: String) async throws {
        _ = try await request("/rest/v1/rpc/itamar_send_once_text",method:"POST",
            data:["p_room":room.uuidString.lowercased(),"p_text":text])
    }
    func openOnceText(message: UUID) async throws -> String {
        let data = try await request("/rest/v1/rpc/itamar_open_once_text",method:"POST",
            data:["p_message":message.uuidString.lowercased()])
        return try JSONDecoder().decode(String.self,from:data)
    }
    func acknowledge(room:UUID, opened: Bool) async throws {
        _ = try await request("/rest/v1/rpc/itamar_ack_messages",method:"POST",
            data:["p_room":room.uuidString.lowercased(),"p_opened":opened])
    }
    func receiptSummaries(for messages:[ItamarCloudMessage]) async throws -> [UUID:ItamarReceiptSummary] {
        let outgoing=Array(messages.filter{$0.sender_id==userID}.suffix(40))
        guard !outgoing.isEmpty else { return [:] }
        let ids=outgoing.map{$0.id.uuidString.lowercased()}.joined(separator:",")
        let data=try await request("/rest/v1/itamar_message_receipts",
            query:[URLQueryItem(name:"message_id",value:"in.(\(ids))"),
                   URLQueryItem(name:"select",value:"message_id,delivered_at,read_at")])
        let rows=try JSONDecoder().decode([ItamarDeliveryReceipt].self,from:data)
        var summary=[UUID:ItamarReceiptSummary]()
        for row in rows {
            let old=summary[row.message_id] ?? ItamarReceiptSummary(delivered:0,read:0)
            summary[row.message_id]=ItamarReceiptSummary(
                delivered:old.delivered+(row.delivered_at == nil ? 0 : 1),
                read:old.read+(row.read_at == nil ? 0 : 1))
        }
        return summary
    }
    func messageReceipts(id: UUID) async throws -> ItamarReceiptSummary {
        let data = try await request("/rest/v1/itamar_message_receipts",
            query:[URLQueryItem(name:"message_id",value:"eq.\(id.uuidString.lowercased())"),
                   URLQueryItem(name:"select",value:"delivered_at,read_at")])
        let receipts=try JSONDecoder().decode([ItamarDeliveryReceipt].self,from:data)
        return ItamarReceiptSummary(
            delivered:receipts.filter{$0.delivered_at != nil}.count,
            read:receipts.filter{$0.read_at != nil}.count)
    }


    func sendReply(room:UUID, to parent:UUID, body:String) async throws {
        _ = try await request("/rest/v1/rpc/itamar_send_reply",method:"POST",
            data:["p_room":room.uuidString.lowercased(),
                  "p_parent":parent.uuidString.lowercased(),"p_body":body])
    }
    func sendDisappearing(room:UUID,body:String,seconds:Int) async throws {
        guard [3600,86400,604800].contains(seconds) else { return }
        _ = try await request("/rest/v1/rpc/itamar_send_disappearing_text",
            method:"POST",data:["p_room":room.uuidString.lowercased(),
                                 "p_body":body,"p_seconds":seconds])
    }
    func setReaction(message:UUID,emoji:String) async throws {
        _ = try await request("/rest/v1/rpc/itamar_react",method:"POST",
            data:["p_message":message.uuidString.lowercased(),"p_emoji":emoji])
    }
    func removeReaction(message:UUID) async throws {
        _ = try await request("/rest/v1/rpc/itamar_remove_reaction",method:"POST",
            data:["p_message":message.uuidString.lowercased()])
    }
    func reactions(for messageIDs:[UUID]) async throws -> [UUID:[ItamarReactionCount]] {
        guard !messageIDs.isEmpty else { return [:] }
        let query=messageIDs.suffix(80).map{$0.uuidString.lowercased()}.joined(separator:",")
        let data=try await request("/rest/v1/itamar_reactions",
            query:[URLQueryItem(name:"message_id",value:"in.(\(query))"),
                   URLQueryItem(name:"select",value:"message_id,user_id,emoji")])
        let entries=try JSONDecoder().decode([ItamarMessageReaction].self,from:data)
        var grouped=[UUID:[String:Int]]()
        for reaction in entries {
            grouped[reaction.message_id,default:[:]][reaction.emoji,default:0]+=1
        }
        return grouped.mapValues { map in
            map.map { ItamarReactionCount(emoji:$0.key,count:$0.value) }
                .sorted { $0.emoji < $1.emoji }
        }
    }
    func blockUser(_ target:UUID) async throws {
        guard let me=userID,me != target else { return }
        _ = try await request("/rest/v1/itamar_blocks",method:"POST",
            data:["blocker_id":me.uuidString.lowercased(),
                  "blocked_id":target.uuidString.lowercased()])
    }
    func reportMessage(_ message:UUID,reason:String,details:String="") async throws {
        guard ["Spam","Harassment","Threats","Other"].contains(reason) else { return }
        _ = try await request("/rest/v1/rpc/itamar_report_message",method:"POST",
            data:["p_message":message.uuidString.lowercased(),
                  "p_reason":reason,"p_detail":String(details.prefix(500))])
    }

}
#endif
