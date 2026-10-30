#if os(iOS)
import Foundation
import SwiftUI
import AuthenticationServices
import Security

// Native Sign in with Apple authenticates the iCloud account currently on the
// device. This is LOCAL profile management, not five concurrent Apple sessions,
// and it grants no authority to sign or install IPA applications.
private struct SavedAppleProfile: Codable, Identifiable {
    let id: String                  // Apple app-scoped user identifier, not a password
    var label: String               // Optional user-facing label
    let addedAt: Date
}

private struct SavedAppleProfiles: Codable {
    var profiles: [SavedAppleProfile]
    var activeID: String?
}

@MainActor
private final class LocalAppleAccountStore: ObservableObject {
    static let limit = 5

    @Published private(set) var profiles: [SavedAppleProfile] = []
    @Published private(set) var activeID: String?
    @Published var message = "Sign in using Apple's system sheet. No password is stored."

    private let service = "org.itamaros.mobile.local-apple-profiles.v1"
    private let record = "saved-profiles"

    init() {
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: record,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var returned: CFTypeRef?
        let status = SecItemCopyMatching(keychainQuery as CFDictionary, &returned)
        if status == errSecItemSuccess, let data = returned as? Data,
           let saved = try? JSONDecoder().decode(SavedAppleProfiles.self, from: data) {
            profiles = Array(saved.profiles.prefix(Self.limit))
            activeID = profiles.contains(where: { $0.id == saved.activeID })
                ? saved.activeID : nil
        } else if status != errSecItemItemNotFound {
            message = "Local profile storage could not be read (status \(status))."
        }
    }

    var activeProfile: SavedAppleProfile? {
        profiles.first { $0.id == activeID }
    }

    private func persist(profiles newProfiles: [SavedAppleProfile],
                         activeID newActiveID: String?,
                         successMessage: String) {
        let snapshot = SavedAppleProfiles(profiles: newProfiles, activeID: newActiveID)
        guard let data = try? JSONEncoder().encode(snapshot) else {
            message = "Could not encode the local account list."
            return
        }
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: record
        ]
        let removeStatus = SecItemDelete(lookup as CFDictionary)
        guard removeStatus == errSecSuccess || removeStatus == errSecItemNotFound else {
            message = "Unable to update protected local storage (status \(removeStatus))."
            return
        }
        let saveRequest: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: record,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(saveRequest as CFDictionary, nil)
        guard status == errSecSuccess else {
            message = "Unable to save profiles on this device (status \(status))."
            return
        }
        profiles = newProfiles
        activeID = newActiveID
        message = successMessage
    }

    func accept(_ credential: ASAuthorizationAppleIDCredential) {
        let identifier = credential.user
        guard !identifier.isEmpty else {
            message = "Apple did not return a usable account identifier."
            return
        }
        var next = profiles
        if !next.contains(where: { $0.id == identifier }) {
            guard next.count < Self.limit else {
                message = "All five local profile slots are in use. Remove one before adding another."
                return
            }
            let displayName = credential.fullName?.formatted()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let label = (displayName?.isEmpty == false)
                ? displayName! : "Apple Profile \(next.count + 1)"
            next.append(SavedAppleProfile(id: identifier, label: label, addedAt: Date()))
        }
        persist(profiles: next, activeID: identifier,
                successMessage: "Apple confirmed this device account. One local profile is active. No Apple password or signing certificate was saved.")
    }

    func rename(_ id: String, to text: String) {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !trimmed.isEmpty else {
            message = "Profile name cannot be empty."
            return
        }
        var next = profiles
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        next[index].label = trimmed
        persist(profiles: next, activeID: activeID, successMessage: "Local profile renamed.")
    }

    func logOut() {
        persist(profiles: profiles, activeID: nil,
                successMessage: "Signed out of ItamarOS locally. The system Apple account is unchanged.")
    }

    func remove(_ identifier: String) {
        persist(profiles: profiles.filter { $0.id != identifier },
                activeID: activeID == identifier ? nil : activeID,
                successMessage: "Local profile deleted. Apple authorization can be revoked in iPhone Settings.")
    }

    func activate(_ identifier: String) {
        guard profiles.contains(where: { $0.id == identifier }) else { return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: identifier) { state, error in
            Task { @MainActor in
                if state == .authorized {
                    self.persist(profiles: self.profiles, activeID: identifier,
                                 successMessage: "Local Apple profile selected. This is not an IPA signing session.")
                } else {
                    self.message = "This profile is not currently authorized on this iPhone. Sign in with the matching device Apple account to continue."
                }
            }
        }
    }

    func recheckActive() {
        guard let identifier = activeID else { return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: identifier) { state, error in
            Task { @MainActor in
                if state == .revoked || state == .notFound {
                    self.persist(profiles: self.profiles, activeID: nil,
                                 successMessage: "Apple authorization is no longer valid. Sign in again.")
                }
            }
        }
    }
}

struct AppleAccountSignInView: View {
    @StateObject private var store = LocalAppleAccountStore()
    @State private var editingID: String?
    @State private var profileLabel = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Apple Accounts", systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)
            Text("Saved profiles: \(store.profiles.count)/\(LocalAppleAccountStore.limit)")
                .font(.subheadline)
            Text("Stored only in this iPhone's protected Keychain. One profile can be active at a time. Apple's native sign-in uses the iCloud account on this device; it cannot open five different Apple ID sessions.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let active = store.activeProfile {
                HStack {
                    Label(active.label, systemImage: "checkmark.circle.fill")
                    Spacer()
                    Button("Sign out") { store.logOut() }
                        .buttonStyle(.bordered)
                }
                Text("Active locally; no Apple developer or IPA signing session.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if store.profiles.count < LocalAppleAccountStore.limit || store.activeProfile == nil {
                SignInWithAppleButton(.signIn, onRequest: { request in
                    request.requestedScopes = [.fullName]
                }, onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            store.accept(credential)
                        } else {
                            store.message = "Apple did not supply a supported account credential."
                        }
                    case .failure(let error):
                        store.message = "Apple authorization unavailable: \(error.localizedDescription)"
                    }
                })
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(height: 46)
                .disabled(store.profiles.count >= LocalAppleAccountStore.limit && store.activeProfile != nil)
            }

            if !store.profiles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Profiles saved on this device")
                        .font(.subheadline.bold())

                    ForEach(store.profiles) { profile in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(profile.label)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                                if profile.id == store.activeID {
                                    Text("Active")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Button("Select") { store.activate(profile.id) }
                                        .font(.caption)
                                }
                            }
                            HStack {
                                Button("Rename") {
                                    editingID = profile.id
                                    profileLabel = profile.label
                                }
                                Button("Remove", role: .destructive) { store.remove(profile.id) }
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }
                        .padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            if editingID != nil {
                HStack {
                    TextField("Local profile name", text: $profileLabel)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") {
                        if let id = editingID {
                            store.rename(id, to: profileLabel)
                        }
                        editingID = nil
                    }
                    Button("Cancel") { editingID = nil }
                }
                .font(.caption)
            }

            Text(store.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Signing limits with a free Apple Personal Team: up to 3 installed development apps per device, and provisioning generally expires after 7 days. Five local profile slots do not increase Apple's limits.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("This is a local identity manager, not an IPA signer. Never enter an Apple Account password in ItamarOS; installation requires a separate Apple-authorized signing method.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { store.recheckActive() }
    }
}
#endif
