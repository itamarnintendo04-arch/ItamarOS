import Foundation
import SwiftUI
import CryptoKit
import Security
import LocalAuthentication
import UserNotifications
import UIKit

private enum ConnectionConfig {
    static let base = "https://slqjkysinhfkqjoigfuz.supabase.co"
    // Supabase publishable keys are public by design. Never ship a secret/service_role key.
    static let publicKey = "sb_publishable__WVo13dRVkDYChuGxHxk9A_CDoVR9ts"
    static let storageKey = "itamaros.approval.session"
    static let deviceKey = "itamaros.approval.device.private"
    static let deviceIDKey = "itamaros.approval.device.id"
}
private struct LinkSession: Codable {
    let access: String
    let refresh: String
    let expiresAt: Date
    let email: String
    let deviceID: String?
}
struct SignInRequest: Identifiable {
    let id: String
    let service: String
    let matchNumber: String
    let challenge: String
    let expiresAt: Date
}
@MainActor
final class ItamarApprovals: ObservableObject {
    @Published private(set) var linkedEmail: String = ""
    @Published private(set) var requests: [SignInRequest] = []
    @Published var message = ""
    @Published private(set) var approvalServiceReady = false
    private var session: LinkSession?
    private var pushToken: String?

    init() {
        if let saved = SecureKeychain.read(ConnectionConfig.storageKey),
           let decoded = try? JSONDecoder().decode(LinkSession.self, from: saved) {
            session = decoded
            linkedEmail = decoded.email
        }
    }
    private static func encoded(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    private func post(_ path: String, data: [String: Any], bearer: String? = nil) async throws -> [String: Any] {
        guard let url = URL(string: ConnectionConfig.base + path) else { throw VaultFailure.text("Invalid server address.") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(ConnectionConfig.publicKey, forHTTPHeaderField: "apikey")
        if let bearer = bearer { req.setValue("Bearer " + bearer, forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: data)
        req.timeoutInterval = 20
        let (received, response) = try await URLSession.shared.data(for: req)
        let payload = (try? JSONSerialization.jsonObject(with: received)) as? [String: Any] ?? [:]
        guard let http = response as? HTTPURLResponse else { throw VaultFailure.text("Could not contact ItamarOS.") }
        guard (200..<300).contains(http.statusCode) else {
            throw VaultFailure.text((payload["error_description"] as? String) ?? (payload["msg"] as? String)
                ?? (payload["error"] as? String) ?? "Unable to connect to ItamarOS.")
        }
        return payload
    }
    private func store(_ value: LinkSession) throws {
        try SecureKeychain.save(JSONEncoder().encode(value), key: ConnectionConfig.storageKey)
        session = value
        linkedEmail = value.email
    }
    private func valid() async throws -> LinkSession {
        guard var existing = session else { throw VaultFailure.text("Connect an ItamarOS account first.") }
        if existing.expiresAt.timeIntervalSinceNow > 90 { return existing }
        let info = try await post("/auth/v1/token?grant_type=refresh_token",
            data: ["refresh_token": existing.refresh])
        guard let access = info["access_token"] as? String,
              let refresh = info["refresh_token"] as? String else {
            throw VaultFailure.text("Session expired. Reconnect your ItamarOS account.")
        }
        existing = LinkSession(access: access, refresh: refresh,
            expiresAt: Date().addingTimeInterval((info["expires_in"] as? Double) ?? 3500),
            email: existing.email, deviceID: existing.deviceID)
        try store(existing)
        return existing
    }
    func sendLinkCode(email: String) async throws {
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleaned.contains("@"), cleaned.count <= 254 else {
            throw VaultFailure.text("Enter a valid ItamarOS email address.")
        }
        _ = try await post("/auth/v1/otp", data: ["email": cleaned, "create_user": false])
        message = "If the account exists, an email verification code has been sent."
    }
    func connect(email: String, code: String) async throws {
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard code.count == 6 && code.allSatisfy({ $0.isNumber }) else {
            throw VaultFailure.text("Enter the six-digit email code.")
        }
        let info = try await post("/auth/v1/verify",
            data: ["email": cleaned, "token": code, "type": "email"])
        guard let access = info["access_token"] as? String,
              let refresh = info["refresh_token"] as? String else {
            throw VaultFailure.text("Could not verify this email account.")
        }
        let value = LinkSession(access: access, refresh: refresh,
            expiresAt: Date().addingTimeInterval((info["expires_in"] as? Double) ?? 3500),
            email: cleaned, deviceID: nil)
        try store(value)
        message = "Email verified. Your ItamarOS account is connected."
        // Approval enrolment is an optional second stage. Never report the
        // email sign-in itself as failed because an Edge Function is not deployed.
        do {
            try await enroll()
            approvalServiceReady = true
            message = "Account connected. Sign-in approvals are ready."
            enableNotifications()
        } catch {
            approvalServiceReady = false
            message = "Account connected. Approval service unavailable: " + error.localizedDescription
        }
    }
    private func identity() throws -> P256.Signing.PrivateKey {
        if let existing = SecureKeychain.read(ConnectionConfig.deviceKey),
           let key = try? P256.Signing.PrivateKey(rawRepresentation: existing) {
            return key
        }
        let key = P256.Signing.PrivateKey()
        try SecureKeychain.save(key.rawRepresentation, key: ConnectionConfig.deviceKey)
        return key
    }
    func enroll() async throws {
        let active = try await valid()
        let key = try identity()
        var payload: [String: Any] = [
            "action": "enroll",
            "public_key": Self.encoded(key.publicKey.x963Representation),
            "device_name": UIDevice.current.name
        ]
        if let pushToken = pushToken { payload["apns_token"] = pushToken }
        let response = try await post("/functions/v1/itamar-authenticator",
            data: payload, bearer: active.access)
        guard let id = response["device_id"] as? String else {
            throw VaultFailure.text("Device registration is not available yet.")
        }
        try store(LinkSession(access: active.access, refresh: active.refresh,
            expiresAt: active.expiresAt, email: active.email, deviceID: id))
        approvalServiceReady = true
    }
    func enableNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
            }
        }
    }
    func updatePushToken(_ token: String) async {
        pushToken = token
        if !linkedEmail.isEmpty {
            do { try await enroll() }
            catch { message = error.localizedDescription }
        }
    }
    func refresh() async {
        guard session != nil else { return }
        // If the approval backend is unavailable, keep the verified account
        // connected. Polling is only meaningful after successful enrolment.
        if session?.deviceID == nil { return }
        do {
            let active = try await valid()
            let data = try await post("/functions/v1/itamar-authenticator",
                data: ["action": "pending"], bearer: active.access)
            let elements = data["requests"] as? [[String: Any]] ?? []
            approvalServiceReady = true
            requests = elements.compactMap { entry in
                guard let id = entry["id"] as? String,
                      let service = entry["service"] as? String,
                      let number = entry["match_number"] as? String,
                      let challenge = entry["challenge"] as? String,
                      let expiry = entry["expires_at"] as? String else { return nil }
                let parser = ISO8601DateFormatter()
                parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let parsed = parser.date(from: expiry) ?? ISO8601DateFormatter().date(from: expiry)
                return SignInRequest(id: id, service: service, matchNumber: number,
                    challenge: challenge, expiresAt: parsed ?? Date().addingTimeInterval(60))
            }
        } catch {
            approvalServiceReady = false
            message = "Approval service unavailable: " + error.localizedDescription
        }
    }
    func decide(_ entry: SignInRequest, approve: Bool) async throws {
        let active = try await valid()
        guard let deviceID = active.deviceID else {
            throw VaultFailure.text("Device is not linked. Connect again to approve.")
        }
        guard entry.expiresAt > Date() else { throw VaultFailure.text("This request has expired.") }
        if approve {
            let context = LAContext()
            let valid = try await context.evaluatePolicy(.deviceOwnerAuthentication,
                localizedReason: "Approve sign in to " + entry.service)
            guard valid else { throw VaultFailure.text("Device verification failed.") }
        }
        let decision = approve ? "approved" : "denied"
        let challenge = entry.id + "." + entry.challenge + "." + decision
        let signature = try identity().signature(for: Data(challenge.utf8))
        _ = try await post("/functions/v1/itamar-authenticator",
            data: [
                "action": "decide",
                "request_id": entry.id,
                "device_id": deviceID,
                "decision": decision,
                "signature": Self.encoded(signature.rawRepresentation)
            ], bearer: active.access)
        message = approve ? "Sign-in approved." : "Sign-in denied."
        await refresh()
    }
    func disconnect() {
        SecureKeychain.remove(ConnectionConfig.storageKey)
        SecureKeychain.remove(ConnectionConfig.deviceKey)
        session = nil
        linkedEmail = ""
        approvalServiceReady = false
        requests = []
        message = "Disconnected locally. Revoke the old device in account security settings."
    }
}

struct ApprovalsView: View {
    @EnvironmentObject private var approvals: ItamarApprovals
    @State private var email = ""
    @State private var code = ""
    @State private var sent = false
    @State private var busy = false
    @State private var alert: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("ItamarOS sign-in", systemImage: "checkmark.shield")
                        .font(.title2.bold())
                    Text("Approve sign-in requests to ItamarOS services, or sign in using email instead.")
                        .foregroundStyle(.secondary)
                    if approvals.linkedEmail.isEmpty {
                        VStack(alignment: .leading, spacing: 13) {
                            Text("Connect this device").font(.headline)
                            Text("Verify your ItamarOS account once with a six-digit email code.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            TextField("ItamarOS email address", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                            if sent {
                                TextField("Six-digit email code", text: $code)
                                    .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                                Button("Verify and connect") {
                                    Task {
                                        await run {
                                            try await approvals.connect(email: email, code: code)
                                        }
                                    }
                                }.buttonStyle(.borderedProminent).disabled(busy || code.count != 6)
                                Button("Resend code") {
                                    Task { await run { try await approvals.sendLinkCode(email: email) } }
                                }
                            } else {
                                Button("Send email code") {
                                    Task {
                                        await run {
                                            try await approvals.sendLinkCode(email: email)
                                            sent = true
                                        }
                                    }
                                }.buttonStyle(.borderedProminent).disabled(busy || !email.contains("@"))
                            }
                        }
                        .padding().background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        Label(approvals.linkedEmail, systemImage: "checkmark.circle.fill")
                            .font(.subheadline).foregroundStyle(.mint)
                        if !approvals.approvalServiceReady {
                            Label("Email sign-in connected; approvals are not active yet.",
                                  systemImage: "exclamationmark.shield")
                                .font(.footnote).foregroundStyle(.orange)
                            Button("Retry approval setup") {
                                Task { await run { try await approvals.enroll() } }
                            }.disabled(busy)
                        }
                        HStack {
                            Text("Pending sign-ins").font(.headline)
                            Spacer()
                            Button { Task { await approvals.refresh() } } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        if approvals.requests.isEmpty {
                            Text("No pending sign-in requests. Only approve requests you personally started.")
                                .foregroundStyle(.secondary)
                                .padding().frame(maxWidth: .infinity)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                        }
                        ForEach(approvals.requests) { entry in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(entry.service).font(.headline)
                                Text("Confirm this number matches the sign-in screen:")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text(entry.matchNumber)
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .monospacedDigit().foregroundStyle(.mint)
                                HStack {
                                    Button("Deny") {
                                        Task { await run { try await approvals.decide(entry, approve: false) } }
                                    }.buttonStyle(.bordered).disabled(busy)
                                    Spacer()
                                    Button("Approve with Face ID / Passcode") {
                                        Task { await run { try await approvals.decide(entry, approve: true) } }
                                    }.buttonStyle(.borderedProminent).disabled(busy)
                                }
                            }.padding().background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                        }
                        Button("Disconnect account", role: .destructive) { approvals.disconnect() }
                            .font(.footnote)
                    }
                    if !approvals.message.isEmpty {
                        Text(approvals.message).font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding()
            }
            .navigationTitle("Approvals")
            .task {
                while !Task.isCancelled {
                    await approvals.refresh()
                    try? await Task.sleep(nanoseconds: 10_000_000_000)
                }
            }
            .alert("ItamarOS", isPresented: Binding(
                get: { alert != nil }, set: { if !$0 { alert = nil } })) {
                Button("OK") { alert = nil }
            } message: { Text(alert ?? "") }
        }
    }
    private func run(_ work: @escaping () async throws -> Void) async {
        busy = true
        defer { busy = false }
        do { try await work() }
        catch { alert = error.localizedDescription }
    }
}
