#if os(iOS)
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CryptoKit
import Security

// Apple Account labels stay in the local device Keychain. They are NOT signed-in
// sessions and must never contain Apple passwords, tokens or private signing keys.
private struct LocalSigningProfiles: Codable {
    var emails: [String] = []
    var selectedEmail: String? = nil
}

private enum SigningProfileStore {
    private static let service = "org.itamaros.local-signing-profile-labels"
    private static let account = "only-this-device"

    private static var identity: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func read() throws -> LocalSigningProfiles {
        var query = identity
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let result = SecItemCopyMatching(query as CFDictionary, &value)
        if result == errSecItemNotFound { return LocalSigningProfiles() }
        guard result == errSecSuccess, let data = value as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result))
        }
        return try JSONDecoder().decode(LocalSigningProfiles.self, from: data)
    }

    static func write(_ profiles: LocalSigningProfiles) throws {
        let data = try JSONEncoder().encode(profiles)
        var attributes = identity
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let changes: [String: Any] = [kSecValueData as String: data]
            let update = SecItemUpdate(identity as CFDictionary, changes as CFDictionary)
            guard update == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(update))
            }
        } else if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}

private struct SigningProfilesView: View {
    @State private var profiles = LocalSigningProfiles()
    @State private var newEmail = ""
    @State private var status = "Only account labels are stored in the device Keychain."
    @State private var isLoaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Apple account profiles", systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)
            Text("Save up to 5 email labels, and select exactly one active profile at a time. These are local labels, not logged-in Apple Developer sessions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(profiles.emails, id: \.self) { email in
                HStack {
                    Image(systemName: profiles.selectedEmail == email
                          ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(profiles.selectedEmail == email ? .blue : .secondary)
                    Button {
                        update {
                            $0.selectedEmail = email
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(email)
                                .lineLimit(1)
                            if profiles.selectedEmail == email {
                                Text("Selected on this device")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 4)
                    Button(role: .destructive) {
                        update {
                            $0.emails.removeAll { $0 == email }
                            if $0.selectedEmail == email {
                                $0.selectedEmail = nil
                            }
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Remove \(email)")
                }
                .padding(.vertical, 4)
            }

            if let selected = profiles.selectedEmail {
                Button("Disconnect selected profile") {
                    update { $0.selectedEmail = nil }
                }
                .font(.subheadline)
                .accessibilityHint("Deselects this label, without changing your actual Apple Account sign-in.")
                Text("Selected label: \(selected). Your Apple Account is NOT authenticated for signing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                TextField("Apple Account email", text: $newEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .accessibilityHint("Account label only. Never enter a password here.")
                Button("Add") { addEmail() }
                    .disabled(!isLoaded || profiles.emails.count >= 5)
            }
            Text("\(profiles.emails.count) of 5 saved · \(profiles.selectedEmail == nil ? "No active profile" : "1 active profile")")
                .font(.caption)
            if profiles.emails.count == 5 {
                Text("Five saved profiles is the limit. Remove one before adding another.")
                    .font(.caption)
            }
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("No passwords, verification codes or Apple authentication tokens are requested or saved. Sign in separately inside the signing application you choose.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Link("Open Sideloadly signing tool website", destination: URL(string: "https://sideloadly.io/")!)
                .font(.subheadline)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onAppear {
            guard !isLoaded else { return }
            do {
                profiles = try SigningProfileStore.read()
                isLoaded = true
            } catch {
                status = "Could not access local Keychain: \(error.localizedDescription)"
            }
        }
    }

    private func addEmail() {
        let email = newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.contains("@"), email.split(separator: "@").count == 2,
              email.split(separator: "@")[1].contains(".") else {
            status = "Enter a valid email address. Do not enter your Apple password."
            return
        }
        guard profiles.emails.count < 5 else {
            status = "The five-profile limit has been reached."
            return
        }
        guard !profiles.emails.contains(email) else {
            status = "This email label is already saved."
            return
        }
        update {
            $0.emails.append(email)
            if $0.selectedEmail == nil { $0.selectedEmail = email }
        }
        newEmail = ""
    }

    private func update(_ change: (inout LocalSigningProfiles) -> Void) {
        var updated = profiles
        change(&updated)
        do {
            try SigningProfileStore.write(updated)
            profiles = updated
            status = "Saved locally in this device's protected Keychain."
        } catch {
            status = "Could not save: \(error.localizedDescription)"
        }
    }
}

struct IPAImportView: View {
    private struct ImportedIPA {
        let url: URL
        let fileName: String
        let bytes: Int64
        let checksum: String
        let importedAt: Date
    }

    private enum IPAImportError: LocalizedError {
        case wrongExtension
        case emptyFile
        case invalidArchive

        var errorDescription: String? {
            switch self {
            case .wrongExtension:
                return "Choose a .ipa file."
            case .emptyFile:
                return "The selected file is empty."
            case .invalidArchive:
                return "Not a supported IPA ZIP archive."
            }
        }
    }

    @State private var isPickingFile = false
    @State private var isImporting = false
    @State private var importedIPA: ImportedIPA?
    @State private var message = "No IPA selected."

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("IPA Installer Setup", systemImage: "shippingbox")
                        .font(.title.bold())

                    SigningProfilesView()

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Free Apple Account limitations", systemImage: "info.circle")
                            .font(.headline)
                        Text("Apple's free Personal Team usually permits 3 sideloaded apps per device and development provisioning profiles that expire after 7 days. Accounts and apps are subject to Apple's own limits; 5 saved email labels here do NOT increase those limits.")
                        Text("To sign and install, a supported signing client on a Windows/Mac computer needs your own Apple Account authorization and a compatible iPhone or iPad. ItamarOS cannot silently install another iOS app.")
                        Text("Only one locally saved email label can be selected here. No Apple account password is stored by ItamarOS.")
                    }
                    .font(.subheadline)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    Button {
                        isPickingFile = true
                    } label: {
                        Label("Choose IPA from Files", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isImporting)

                    if isImporting {
                        ProgressView("Checking and copying IPA locally…")
                    }
                    if let file = importedIPA {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Imported IPA details", systemImage: "doc.text.magnifyingglass")
                                .font(.headline)
                            LabeledContent("Name", value: file.fileName)
                            LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file))
                            LabeledContent("Type", value: "IPA (ZIP container)")
                            LabeledContent("Imported", value: file.importedAt.formatted(date: .abbreviated, time: .shortened))
                            LabeledContent("SHA-256") {
                                Text(file.checksum)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }
                            LabeledContent("Code signature", value: "Not verified")
                            LabeledContent("Installation", value: "Not installed")
                            Text("This checks the file's ZIP header, not its developer identity, app permissions or malware safety. Bundle ID and signing certificate need a trusted IPA inspection tool.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            ShareLink(item: file.url, preview: SharePreview(file.fileName)) {
                                Label("Send IPA to signing tool", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            Link("Get Sideloadly for Windows or Mac", destination: URL(string: "https://sideloadly.io/")!)
                            Text("After sharing or transferring the IPA, finish signing and installation in the external client. The client—not ItamarOS—must handle account authentication, consent and installation.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }

                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    AppleAccountSignInView()
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    Link("Apple's developer account limits", destination: URL(string: "https://developer.apple.com/help/account/basics/about-your-developer-account")!)
                    Text("Sign in with Apple authorizes identity only. It does not sign IPAs, grant developer certificates or replace the external installer.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("IPA")
            .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.data]) { result in
                importFile(result)
            }
        }
    }

    @MainActor
    private func importFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            message = "Unable to open Files: \(error.localizedDescription)"
        case .success(let source):
            isImporting = true
            message = "Importing locally…"
            Task {
                do {
                    let file = try await Task.detached(priority: .userInitiated) {
                        try Self.makeLocalCopy(of: source)
                    }.value
                    let prior = importedIPA?.url
                    importedIPA = file
                    message = "IPA ready for export to a signing tool. No installation was performed."
                    if let prior, prior != file.url {
                        try? FileManager.default.removeItem(at: prior)
                    }
                } catch {
                    message = "Import failed: \(error.localizedDescription)"
                }
                isImporting = false
            }
        }
    }

    private static func makeLocalCopy(of source: URL) throws -> ImportedIPA {
        guard source.pathExtension.lowercased() == "ipa" else { throw IPAImportError.wrongExtension }
        let permission = source.startAccessingSecurityScopedResource()
        defer { if permission { source.stopAccessingSecurityScopedResource() } }

        let fileManager = FileManager.default
        let bytes = ((try fileManager.attributesOfItem(atPath: source.path))[.size] as? NSNumber)?.int64Value ?? 0
        guard bytes > 0 else { throw IPAImportError.emptyFile }

        let directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImportedIPAs", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(UUID().uuidString + "-" + source.lastPathComponent)
        try fileManager.copyItem(at: source, to: destination)
        do {
            let stream = try FileHandle(forReadingFrom: destination)
            defer { try? stream.close() }
            let prefix = try stream.read(upToCount: 4) ?? Data()
            guard prefix == Data([0x50, 0x4b, 0x03, 0x04]) else {
                throw IPAImportError.invalidArchive
            }
            var hasher = SHA256()
            hasher.update(data: prefix)
            while let chunk = try stream.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            let checksum = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            return ImportedIPA(url: destination, fileName: source.lastPathComponent,
                               bytes: bytes, checksum: checksum, importedAt: Date())
        } catch {
            try? fileManager.removeItem(at: destination)
            throw error
        }
    }
}
#endif
