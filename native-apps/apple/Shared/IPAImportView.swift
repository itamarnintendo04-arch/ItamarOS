#if os(iOS)
import Foundation
import SwiftUI
import UniformTypeIdentifiers

// iPhone/iPad: local IPA import and explicit hand-off to a user-selected tool.
// iOS apps cannot generally sign, install or update arbitrary IPA packages.
struct IPAImportView: View {
    private struct ImportedIPA {
        let url: URL
        let fileName: String
        let bytes: Int64
    }

    private enum IPAImportError: LocalizedError {
        case wrongExtension
        case emptyFile

        var errorDescription: String? {
            switch self {
            case .wrongExtension:
                return "Select a .ipa file. No file was imported."
            case .emptyFile:
                return "This IPA file is empty."
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
                VStack(alignment: .leading, spacing: 22) {
                    Label("IPA Files", systemImage: "shippingbox")
                        .font(.title.bold())

                    Text("Import an IPA file from Files, review its details and share it with a signing or installation tool you choose. ItamarOS does not upload your file to a server.")
                        .foregroundStyle(.secondary)

                    Button {
                        isPickingFile = true
                    } label: {
                        Label("Choose IPA from Files", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isImporting)

                    if isImporting {
                        ProgressView("Copying IPA into the app…")
                    }

                    if let file = importedIPA {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("File imported", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                            Text(file.fileName)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                            Text(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file))
                                .foregroundStyle(.secondary)

                            ShareLink(item: file.url, preview: SharePreview(file.fileName)) {
                                Label("Share IPA with a compatible tool", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }

                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    AppleAccountSignInView()
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Signing & installation", systemImage: "lock.shield")
                            .font(.headline)

                        Text("Importing and sharing an IPA does not sign or install it. iPhone requires an Apple-issued signature, valid provisioning and an installation method supported for your device.")

                        Text("ItamarOS cannot provide universal automatic IPA installation or a free signing certificate. For a personal development app, Xcode on a Mac can use a free Apple Account, with time-limited signing.")

                        Link("Apple's official developer account guide",
                             destination: URL(string: "https://developer.apple.com/help/account/basics/about-your-developer-account")!)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
            message = "Could not open Files: \(error.localizedDescription)"
        case .success(let source):
            isImporting = true
            message = "Importing locally…"
            Task {
                do {
                    let file = try await Task.detached(priority: .userInitiated) {
                        try Self.makeLocalCopy(of: source)
                    }.value

                    let priorURL = importedIPA?.url
                    importedIPA = file
                    message = "IPA imported. You can share it, but it has not been signed or installed."

                    if let priorURL = priorURL, priorURL != file.url {
                        try? FileManager.default.removeItem(at: priorURL)
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
        let scoped = source.startAccessingSecurityScopedResource()
        defer {
            if scoped { source.stopAccessingSecurityScopedResource() }
        }

        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: source.path)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard bytes > 0 else { throw IPAImportError.emptyFile }

        let directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImportedIPAs", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let localURL = directory.appendingPathComponent(UUID().uuidString + "-" + source.lastPathComponent)
        try fileManager.copyItem(at: source, to: localURL)

        return ImportedIPA(url: localURL, fileName: source.lastPathComponent, bytes: bytes)
    }
}
#endif
