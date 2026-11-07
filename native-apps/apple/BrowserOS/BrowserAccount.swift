import SwiftUI
import Security

/// BrowserOS uses the same ItamarOS account backend, but keeps its own device session.
@MainActor
final class BrowserAccount: ObservableObject {
    @Published private(set) var signedIn = false
    @Published private(set) var email = ""
    @Published var error = ""
    @Published var working = false

    private let service = "org.itamaros.browseros.session"
    private let endpoint = (Bundle.main.object(forInfoDictionaryKey: "ITAMAR_SUPABASE_URL") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    private let publicKey = (Bundle.main.object(forInfoDictionaryKey: "ITAMAR_SUPABASE_PUBLISHABLE_KEY") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

    private struct Session: Codable {
        var access_token: String
        var refresh_token: String
        var expires_at: Date
        var email: String
    }
    private var session: Session?

    init() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var data: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &data) == errSecSuccess,
           let bytes = data as? Data,
           let stored = try? JSONDecoder().decode(Session.self, from: bytes) {
            session = stored
            email = stored.email
            // A cached token alone is not proof of an active login.
            signedIn = false
        }
    }

    var configured: Bool {
        guard let url = URL(string: endpoint), url.scheme == "https" else { return false }
        return !publicKey.isEmpty
    }

    private func save(_ value: Session) {
        session = value
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = try? JSONEncoder().encode(value)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
        email = value.email
        signedIn = true
    }

    private func authRequest(path: String, body: [String: String]) async throws -> [String: Any] {
        guard configured, let url = URL(string: endpoint + path) else {
            throw NSError(domain: "BrowserOS", code: 1, userInfo: [NSLocalizedDescriptionKey: "ItamarOS account service is not configured for this build."])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publicKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = (json["msg"] ?? json["error_description"] ?? json["message"] ?? "Sign in failed") as? String ?? "Sign in failed"
            throw NSError(domain: "BrowserOS", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return json
    }

    func signIn(email: String, password: String) async {
        guard !working else { return }
        working = true; error = ""
        defer { working = false }
        do {
            let json = try await authRequest(path: "/auth/v1/token?grant_type=password", body: ["email": email, "password": password])
            guard let access = json["access_token"] as? String,
                  let refresh = json["refresh_token"] as? String else {
                throw NSError(domain: "BrowserOS", code: 3, userInfo: [NSLocalizedDescriptionKey: "No valid account session returned."])
            }
            let seconds = json["expires_in"] as? Double ?? 3600
            save(Session(access_token: access, refresh_token: refresh, expires_at: Date().addingTimeInterval(seconds), email: email))
        } catch { self.error = error.localizedDescription }
    }

    func restore() async {
        guard let previous = session else { return }
        working = true
        defer { working = false }
        do {
            let json = try await authRequest(path: "/auth/v1/token?grant_type=refresh_token", body: ["refresh_token": previous.refresh_token])
            guard let access = json["access_token"] as? String,
                  let refresh = json["refresh_token"] as? String else { throw URLError(.userAuthenticationRequired) }
            save(Session(access_token: access, refresh_token: refresh,
                         expires_at: Date().addingTimeInterval(json["expires_in"] as? Double ?? 3600),
                         email: previous.email))
        } catch {
            signOut()
        }
    }

    func signOut() {
        session = nil
        signedIn = false
        email = ""
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ] as CFDictionary)
    }
}

struct BrowserAccountGate: View {
    @StateObject private var account = BrowserAccount()
    @State private var email = ""
    @State private var password = ""
    @State private var checked = false

    var body: some View {
        Group {
            if !checked {
                ProgressView("Checking ItamarOS account…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if account.signedIn {
                BrowserHome()
                    .environmentObject(account)
            } else {
                ZStack {
                    Color(red: 0.035, green: 0.065, blue: 0.12).ignoresSafeArea()
                    ScrollView {
                        VStack(spacing: 20) {
                            Image(systemName: "globe.americas.fill")
                                .font(.system(size: 78)).foregroundStyle(.cyan)
                            Text("BrowserOS").font(.largeTitle.bold())
                            Text("By ItamarOS").foregroundStyle(.cyan)
                            Text("Sign in to your ItamarOS account to browse.")
                                .foregroundStyle(.secondary)
                            if !account.configured {
                                Text("Account server configuration is missing. Browser access is disabled.")
                                    .foregroundStyle(.orange).multilineTextAlignment(.center)
                            }
                            TextField("Email", text: $email)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .padding().background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .padding().background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                            Button {
                                Task { await account.signIn(email: email, password: password) }
                            } label: {
                                Text(account.working ? "Signing in…" : "Sign in with ItamarOS")
                                    .font(.headline).frame(maxWidth: .infinity).padding(16)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!account.configured || account.working || email.isEmpty || password.isEmpty)
                            if !account.error.isEmpty {
                                Text(account.error).foregroundStyle(.orange).multilineTextAlignment(.center)
                            }
                            Text("A valid ItamarOS account is required. No guest mode.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(24).frame(maxWidth: 440)
                        .frame(maxWidth: .infinity, minHeight: 600)
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
        .task {
            guard !checked else { return }
            await account.restore()
            checked = true
        }
    }
}
