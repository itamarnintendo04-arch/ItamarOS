import Foundation
import Combine
import CryptoKit
import Security
import ZIPFoundation

struct CertificateRecord: Identifiable, Codable {
    var id: UUID
    var name: String
    var importedAt: Date
    var certificateExpires: Date?
    var profileExpires: Date?
    var hasProvisioningProfile: Bool
    var fingerprint: String
    var effectiveExpiry: Date? {
        [certificateExpires, profileExpires].compactMap { $0 }.min()
    }
    var dateExpired: Bool {
        effectiveExpiry.map { $0 <= Date() } ?? false
    }
    var statusLabel: String {
        if dateExpired { return "Expired — cannot select automatically" }
        if let expires = effectiveExpiry {
            return "Date valid until \(expires.formatted(date: .abbreviated, time: .omitted)) • Not revocation-verified"
        }
        return "Expiration unknown — check certificate and profile"
    }
}

private struct PrivateCertificate: Codable {
    let info: CertificateRecord
    let p12: Data
    let password: String
    let mobileprovision: Data?
}

enum VaultError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let text) = self { return text }
        return "Certificate import failed."
    }
}

private enum EncryptedStore {
    private static let service = "net.itamaros.installer.mobile.keys"
    private static let keyName = "aes256-v1"
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ItamarOSCertificateVault", isDirectory: true)
    }
    private static func encryptionKey() throws -> SymmetricKey {
        let request: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data, data.count == 32 {
            return SymmetricKey(data: data)
        }
        var data = Data(repeating: 0, count: 32)
        let result = data.withUnsafeMutableBytes { raw in
            SecRandomCopyBytes(kSecRandomDefault, 32, raw.baseAddress!)
        }
        guard result == errSecSuccess else {
            throw VaultError.message("iPhone Keychain could not generate an encryption key.")
        }
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultError.message("Could not store the private encryption key in iOS Keychain.")
        }
        return SymmetricKey(data: data)
    }
    fileprivate static func save(_ record: PrivateCertificate) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let clear = try JSONEncoder().encode(record)
        let sealed = try AES.GCM.seal(clear, using: encryptionKey())
        guard let encrypted = sealed.combined else {
            throw VaultError.message("Encryption failed.")
        }
        let destination = folder.appendingPathComponent(record.info.id.uuidString + ".vault")
        try encrypted.write(to: destination, options: [.atomic, .completeFileProtection])
    }
    fileprivate static func loadAll() -> [PrivateCertificate] {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: folder,
                             includingPropertiesForKeys: nil) else { return [] }
        guard let key = try? encryptionKey() else { return [] }
        return urls.filter { $0.pathExtension == "vault" }.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let box = try? AES.GCM.SealedBox(combined: data),
                  let clear = try? AES.GCM.open(box, using: key) else { return nil }
            return try? JSONDecoder().decode(PrivateCertificate.self, from: clear)
        }
    }
    fileprivate static func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(id.uuidString + ".vault"))
    }
}

@MainActor
final class CertificateVault: ObservableObject {
    @Published private(set) var records: [CertificateRecord] = []
    @Published var autoSelect: Bool = UserDefaults.standard.object(forKey: "certificate-auto-select") as? Bool ?? true
    @Published private var manualId: UUID?

    init() {
        manualId = UserDefaults.standard.string(forKey: "preferred-certificate-id").flatMap(UUID.init(uuidString:))
        reload()
    }

    var selected: CertificateRecord? {
        let candidates = records.filter { !$0.dateExpired }
        if autoSelect {
            // Only auto-select when a real expiry can be extracted. Expiry does not verify Apple revocation.
            return candidates.filter { $0.certificateExpires != nil }
                .sorted { ($0.effectiveExpiry ?? .distantPast) > ($1.effectiveExpiry ?? .distantPast) }
                .first
        }
        return candidates.first(where: { $0.id == manualId })
    }

    func saveAutoPreference() {
        UserDefaults.standard.set(autoSelect, forKey: "certificate-auto-select")
    }

    func choose(_ record: CertificateRecord) {
        autoSelect = false
        manualId = record.id
        UserDefaults.standard.set(false, forKey: "certificate-auto-select")
        UserDefaults.standard.set(record.id.uuidString, forKey: "preferred-certificate-id")
    }

    func delete(_ record: CertificateRecord) {
        EncryptedStore.delete(record.id)
        if manualId == record.id {
            manualId = nil
            UserDefaults.standard.removeObject(forKey: "preferred-certificate-id")
        }
        reload()
    }

    private func reload() {
        records = EncryptedStore.loadAll().map(\.info).sorted {
            ($0.effectiveExpiry ?? .distantPast) > ($1.effectiveExpiry ?? .distantPast)
        }
    }

    func importFiles(_ sources: [URL]) throws -> Int {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        var collected: [URL] = []

        for (index, source) in sources.enumerated() {
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            let file = temp.appendingPathComponent("\(index)-\(source.lastPathComponent)")
            try FileManager.default.copyItem(at: source, to: file)
            guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) < 40_000_000 else {
                throw VaultError.message("An archive exceeds the 40 MB import limit.")
            }
            if file.pathExtension.lowercased() == "zip" {
                let unzipped = temp.appendingPathComponent("unpacked-\(index)", isDirectory: true)
                try FileManager.default.createDirectory(at: unzipped, withIntermediateDirectories: true)
                guard let archive = Archive(url: file, accessMode: .read) else {
                    throw VaultError.message("Could not open \(source.lastPathComponent) as a ZIP archive.")
                }
                var total: UInt64 = 0
                var count = 0
                for entry in archive {
                    count += 1
                    total += UInt64(entry.uncompressedSize)
                    let segments = entry.path.components(separatedBy: "/")
                    if entry.path.hasPrefix("/") || segments.contains("..") || count > 250 || total > 100_000_000 {
                        throw VaultError.message("ZIP contains unsafe paths or too much extracted data.")
                    }
                }
                try FileManager.default.unzipItem(at: file, to: unzipped)
                if let iterator = FileManager.default.enumerator(at: unzipped,
                                      includingPropertiesForKeys: [.isRegularFileKey],
                                      options: [.skipsHiddenFiles]) {
                    for case let item as URL in iterator {
                        if item.standardizedFileURL.path.hasPrefix(unzipped.standardizedFileURL.path + "/"),
                           (try? item.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                            collected.append(item)
                        }
                    }
                }
            } else {
                collected.append(file)
            }
        }
        let p12s = collected.filter { $0.pathExtension.lowercased() == "p12" }
        if p12s.isEmpty {
            throw VaultError.message("No .p12 certificate was found. Import a ZIP with a P12 and password TXT.")
        }
        if records.count + p12s.count > 100 {
            throw VaultError.message("This vault supports up to 100 certificates.")
        }
        let textFiles = collected.filter { $0.pathExtension.lowercased() == "txt" }
        let profiles = collected.filter { $0.pathExtension.lowercased() == "mobileprovision" }
        var imported = 0
        var problems: [String] = []
        for p12 in p12s {
            do {
                let candidate = textFiles.first {
                    $0.deletingLastPathComponent().standardizedFileURL == p12.deletingLastPathComponent().standardizedFileURL
                } ?? (textFiles.count == 1 ? textFiles.first : nil)
                guard let txt = candidate else {
                    throw VaultError.message("Matching password TXT not found.")
                }
                let password = try readPassword(txt)
                let p12Data = try Data(contentsOf: p12)
                let (name, expiry, fingerprint) = try inspect(p12Data, password: password)
                let matchingProfile = profiles.first {
                    $0.deletingLastPathComponent().standardizedFileURL == p12.deletingLastPathComponent().standardizedFileURL
                } ?? (profiles.count == 1 ? profiles.first : nil)
                let profileData = try matchingProfile.map { try Data(contentsOf: $0) }
                let profileExpiry = profileData.flatMap(Self.profileExpiration)
                let record = CertificateRecord(id: UUID(), name: name,
                    importedAt: Date(), certificateExpires: expiry,
                    profileExpires: profileExpiry, hasProvisioningProfile: profileData != nil,
                    fingerprint: fingerprint)
                try EncryptedStore.save(PrivateCertificate(info: record, p12: p12Data,
                                                password: password, mobileprovision: profileData))
                imported += 1
            } catch {
                problems.append("\(p12.lastPathComponent): \(error.localizedDescription)")
            }
        }
        reload()
        if imported == 0 {
            throw VaultError.message("No certificates imported.\n" + problems.joined(separator: "\n").prefix(700))
        }
        return imported
    }

    private func readPassword(_ url: URL) throws -> String {
        let raw = try Data(contentsOf: url)
        guard raw.count < 100_000, let txt = String(data: raw, encoding: .utf8) else {
            throw VaultError.message("TXT password file must contain readable UTF-8 text.")
        }
        let lines = txt.replacingOccurrences(of: "\u{FEFF}", with: "")
            .split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let line = lines.first else { throw VaultError.message("The TXT password file is empty.") }
        let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
        let text = (parts.count > 1 && ["password", "pass", "p12 password", "סיסמה"].contains(parts[0].lowercased()))
            ? parts[1].trimmingCharacters(in: .whitespaces) : line
        guard !text.isEmpty && text.count <= 512 else {
            throw VaultError.message("Could not read a certificate password from TXT.")
        }
        return text
    }

    private func inspect(_ p12: Data, password: String) throws -> (String, Date?, String) {
        var identities: CFArray?
        let status = SecPKCS12Import(p12 as CFData,
            [kSecImportExportPassphrase as String: password] as CFDictionary, &identities)
        guard status == errSecSuccess,
              let rows = identities as? [[String: Any]],
              let row = rows.first,
              let identity = row[kSecImportItemIdentity as String] as! SecIdentity? else {
            throw VaultError.message("P12 could not be unlocked with the matching TXT password.")
        }
        var cert: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &cert) == errSecSuccess, let cert else {
            throw VaultError.message("P12 does not contain a signing certificate.")
        }
        let subject = (SecCertificateCopySubjectSummary(cert) as String?) ?? "Certificate"
        let expiry: Date?
        if #available(iOS 18.0, *) {
            expiry = (SecCertificateCopyNotValidAfterDate(cert) as Date?)
        } else {
            expiry = nil
        }
        let hash = SHA256.hash(data: SecCertificateCopyData(cert) as Data)
            .map { String(format: "%02x", $0) }.joined()
        return (subject, expiry, hash)
    }

    private static func profileExpiration(_ data: Data) -> Date? {
        // The standard CMS mobileprovision contains an embedded XML property list.
        // This is for display only: it DOES NOT validate the CMS signature or device eligibility.
        let begin = Data("<plist".utf8)
        let end = Data("</plist>".utf8)
        guard let start = data.range(of: begin),
              let finish = data.range(of: end, in: start.lowerBound..<data.endIndex) else { return nil }
        let embedded = data.subdata(in: start.lowerBound..<finish.upperBound)
        guard let object = try? PropertyListSerialization.propertyList(from: embedded,
                          options: [], format: nil) as? [String: Any] else { return nil }
        return object["ExpirationDate"] as? Date
    }
}


// All checks below are local, best-effort eligibility checks.
// They are NOT Apple signature, revocation, or installation verification.
extension CertificateVault {
    func matchesForCustomIPA(bundleIdentifier: String, targetUDID: String) -> [CertificateMatch] {
        let device = targetUDID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let results = EncryptedStore.loadAll().map { stored -> CertificateMatch in
            let cert = stored.info
            func reject(_ reason: String) -> CertificateMatch {
                CertificateMatch(id: cert.id, name: cert.name, expiry: cert.effectiveExpiry,
                                 level: .rejected, reason: reason)
            }
            func review(_ reason: String) -> CertificateMatch {
                CertificateMatch(id: cert.id, name: cert.name, expiry: cert.effectiveExpiry,
                                 level: .reviewRequired, reason: reason)
            }
            if cert.dateExpired { return reject("Certificate or profile expired.") }
            guard let p12Expiry = cert.certificateExpires, p12Expiry > Date() else {
                return review("Unable to confirm certificate expiration.")
            }
            guard let profileData = stored.mobileprovision else {
                return reject("Missing .mobileprovision for this signing identity.")
            }
            guard let profile = Self.readProfilePlist(profileData) else {
                return review("Cannot inspect this provisioning profile.")
            }
            guard let profileExpiry = profile["ExpirationDate"] as? Date else {
                return review("Provisioning profile has no readable expiration date.")
            }
            if profileExpiry <= Date() { return reject("Provisioning profile expired.") }
            guard let includedCerts = profile["DeveloperCertificates"] as? [Data],
                  !includedCerts.isEmpty else {
                return review("Profile's signing certificate list is unavailable.")
            }
            let matchesIdentity = includedCerts.contains { item in
                SHA256.hash(data: item).map { String(format: "%02x", $0) }.joined()
                    .caseInsensitiveCompare(cert.fingerprint) == .orderedSame
            }
            if !matchesIdentity {
                return reject("This P12 is not a signing identity in this profile.")
            }
            guard let entitlements = profile["Entitlements"] as? [String: Any],
                  let appId = (entitlements["application-identifier"] as? String)
                    ?? (entitlements["com.apple.application-identifier"] as? String) else {
                return review("Profile does not expose an application identifier.")
            }
            let components = appId.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            guard components.count == 2 else {
                return review("Profile app identifier cannot be interpreted.")
            }
            let allowed = String(components[1])
            if !(allowed == bundleIdentifier ||
                 (allowed.hasSuffix("*") && bundleIdentifier.hasPrefix(String(allowed.dropLast())))) {
                return reject("Provisioning profile does not match this IPA's Bundle ID.")
            }
            if let platforms = profile["Platform"] as? [String], !platforms.contains("iOS") {
                return reject("Provisioning profile is not for iOS.")
            }
            if device.isEmpty {
                return review("Enter your iPhone UDID to verify the device restriction.")
            }
            guard device.range(of: #"^[A-F0-9-]{16,48}$"#, options: .regularExpression) != nil else {
                return review("The entered device UDID format needs to be checked.")
            }
            if let registered = profile["ProvisionedDevices"] as? [String] {
                if !registered.contains(where: { $0.uppercased() == device }) {
                    return reject("This provisioning profile does not list the selected iPhone UDID.")
                }
            } else if (profile["ProvisionsAllDevices"] as? Bool) == true {
                return review("Enterprise profile: eligibility and authorization must be checked separately.")
            } else {
                return reject("App Store or unknown profile: not usable for direct device installation.")
            }
            return CertificateMatch(id: cert.id, name: cert.name,
                                    expiry: min(p12Expiry, profileExpiry),
                                    level: .preflightMatch,
                                    reason: "P12, Bundle ID, dates, and device UDID match. Apple verification still required.")
        }
        return results.sorted { lhs, rhs in
            if lhs.level != rhs.level { return lhs.level.rawValue > rhs.level.rawValue }
            return (lhs.expiry ?? .distantPast) > (rhs.expiry ?? .distantPast)
        }
    }

    private static func readProfilePlist(_ data: Data) -> [String: Any]? {
        // CMS contains a property-list payload. Do not trust its fields as verified
        // until Apple validates the CMS signature during installation.
        let startTag = Data("<plist".utf8)
        let endTag = Data("</plist>".utf8)
        guard let start = data.range(of: startTag),
              let end = data.range(of: endTag, in: start.lowerBound..<data.endIndex),
              end.upperBound - start.lowerBound < 1_000_000 else { return nil }
        let bytes = data.subdata(in: start.lowerBound..<end.upperBound)
        return (try? PropertyListSerialization.propertyList(from: bytes,
                      options: [], format: nil)) as? [String: Any]
    }
}
