#if os(iOS)
import Foundation
import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

/// Local IPA manager. User email labels are not authenticated Apple sessions.
/// Apple credentials and signing keys belong only in the authorized signing tool.
struct IPAImportView: View {
    private struct ImportedIPA {
        let url: URL
        let fileName: String
        let bytes: Int64
        let sha256: String
    }

    private enum IPAImportError: LocalizedError {
        case wrongExtension
        case emptyFile

        var errorDescription: String? {
            switch self {
            case .wrongExtension: return "Select a .ipa file."
            case .emptyFile: return "This IPA is empty."
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
                VStack(alignment: .leading, spacing: 20) {
                    Label("IPA Files", systemImage: "shippingbox")
                        .font(.title.bold())

                    AppleAccountSignInView()
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Free Apple Account limits", systemImage: "info.circle")
                            .font(.headline)
                        Text("• Up to 3 personal-development apps installed per device.\n• Development provisioning generally expires after 7 days.\n• Up to 10 registered App IDs in a 7-day period.\n• The 5 saved profiles above are an ItamarOS UI limit, not an Apple allowance.")
                            .font(.subheadline)
                        Link("Verify current limits with Apple",
                             destination: URL(string: "https://developer.apple.com/help/account/basics/about-your-developer-account/")!)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("IPA import", systemImage: "doc.badge.plus")
                            .font(.headline)
                        Button { isPickingFile = true } label: {
                            Label("Choose IPA from Files", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isImporting)

                        if isImporting { ProgressView("Importing IPA locally…") }

                        if let file = importedIPA {
                            LabeledContent("File", value: file.fileName)
                            LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file))
                            LabeledContent("SHA-256", value: file.sha256)
                            LabeledContent("Type", value: "IPA (unverified)")
                            LabeledContent("Signature", value: "Not checked")
                            LabeledContent("Installation", value: "Not installed")

                            ShareLink(item: file.url, preview: SharePreview(file.fileName)) {
                                Label("Send IPA to a compatible signing tool", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Install with an external tool", systemImage: "lock.shield")
                            .font(.headline)
                        Text("1. Set up AltStore Classic and AltServer on a trusted computer.\n2. Sign in with your own Apple Account inside the signing tool.\n3. Import the IPA using the share control above, or open the published ItamarOS source in AltStore.\n4. Approve installation on your device. ItamarOS cannot verify completion from here.")
                        Link("Open Sideloadly for Windows or Mac",
                             destination: URL(string: "https://sideloadly.io/")!)
                        Link("Official AltStore Classic instructions",
                             destination: URL(string: "https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows")!)
                        Link("ItamarOS downloads and available builds",
                             destination: URL(string: "https://itamaros-web-emulator.onrender.com/downloads.html")!)
                        Text("Selecting an account or importing an IPA does not sign, install, or update anything automatically. Do not provide credentials to unknown signing websites.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .frame(maxWidth: 680)
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
            message = "Could not open Files: \(error.localizedDescription)"
        case .success(let source):
            isImporting = true
            message = "Importing locally…"
            Task {
                do {
                    let file = try await Task.detached(priority: .userInitiated) {
                        try Self.makeLocalCopy(of: source)
                    }.value
                    let previous = importedIPA?.url
                    importedIPA = file
                    message = "IPA imported locally. Signing and installation have not occurred."
                    if let previous, previous != file.url {
                        try? FileManager.default.removeItem(at: previous)
                    }
                } catch {
                    message = "Import failed: \(error.localizedDescription)"
                }
                isImporting = false
            }
        }
    }

    private static func makeLocalCopy(of source: URL) throws -> ImportedIPA {
        guard source.pathExtension.lowercased() == "ipa" else {
            throw IPAImportError.wrongExtension
        }
        let granted = source.startAccessingSecurityScopedResource()
        defer { if granted { source.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        let attrs = try fm.attributesOfItem(atPath: source.path)
        let bytes = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        guard bytes > 0 else { throw IPAImportError.emptyFile }
        let folder = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImportedIPAs", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let local = folder.appendingPathComponent(UUID().uuidString + "-" + source.lastPathComponent)
        try fm.copyItem(at: source, to: local)
        let stream = try FileHandle(forReadingFrom: local)
        defer { try? stream.close() }
        var checksum = SHA256()
        while true {
            guard let chunk = try stream.read(upToCount: 1024 * 1024), !chunk.isEmpty else { break }
            checksum.update(data: chunk)
        }
        let sha256 = checksum.finalize().map { String(format: "%02x", $0) }.joined()
        return ImportedIPA(url: local, fileName: source.lastPathComponent, bytes: bytes, sha256: sha256)
    }
}
#endif
