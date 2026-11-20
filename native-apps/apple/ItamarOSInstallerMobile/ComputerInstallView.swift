import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// USB installation preparation does not require an OTA manifest.
/// The Mac/Windows device-install tool receives the user-approved IPA
/// through Files/AirDrop/file sharing and requests installation via Apple's
/// device service. The iPhone app cannot silently install arbitrary IPAs.
struct ComputerInstallView: View {
    let originalIPA: URL?
    let expectedBundleIdentifier: String?

    @Environment(\.dismiss) private var dismiss
    @State private var selectingSignedIPA = false
    @State private var chosenSignedIPA: IPAInspection?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("USB installation — no manifest") {
                    Label("Install using your computer", systemImage: "cable.connector")
                        .font(.headline)
                    Text("A website, HTTPS link, or manifest file is not required. Use ItamarOS Installer on Windows with your iPhone connected by USB, or a trusted Apple-supported installation tool on Mac.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("1. Prepare a signed IPA") {
                    if let originalIPA {
                        ShareLink(item: originalIPA) {
                            Label("Export original IPA to sign on your computer",
                                  systemImage: "square.and.arrow.up")
                        }
                        Text("This original IPA may be unsigned. Do not attempt installation until it has been signed with a valid identity and provisioning profile for your device.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        selectingSignedIPA = true
                    } label: {
                        Label(chosenSignedIPA == nil ? "Choose your signed IPA" : "Choose another signed IPA",
                              systemImage: "doc.badge.plus")
                    }
                    if let chosenSignedIPA {
                        LabeledContent("Selected IPA", value: chosenSignedIPA.fileName)
                        LabeledContent("Bundle ID", value: chosenSignedIPA.bundleIdentifier)
                        Text("This file passed the IPA structure and Bundle ID checks. Its code signature has not been cryptographically verified here; iOS will decide if the certificate and provisioning are acceptable.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("2. Transfer to Windows or Mac") {
                    if let chosenSignedIPA {
                        ShareLink(item: chosenSignedIPA.url) {
                            Label("Share IPA with computer", systemImage: "square.and.arrow.up")
                        }
                        LabeledContent("File sharing", value: "Files / iCloud Drive / AirDrop")
                    } else {
                        Label("Select a signed IPA above to share it with your computer.",
                              systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("3. Install over USB") {
                    Text("1. Connect and unlock your iPhone with a USB cable.")
                    Text("2. If asked, tap Trust This Computer.")
                    Text("3. On Windows, open ItamarOS Installer → My iPhone → Install Local IPA.")
                    Text("4. Choose the signed IPA from your computer and approve the installation.")
                    Text("5. iOS verifies the signature, provisioning profile and device eligibility.")
                    Link("Open Windows Installer release",
                         destination: URL(string: "https://github.com/itamarnintendo04-arch/ItamarOS/releases/tag/windows-installer-2026.11.20-preview.1")!)
                }

                Section {
                    Text("No manifest is required for USB installation. This iPhone app cannot initiate a USB installer on a computer without its cooperation. A successfully signed IPA does not guarantee that Apple will permit installation.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Install with Computer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $selectingSignedIPA,
                allowedContentTypes: [UTType(filenameExtension: "ipa", conformingTo: .data) ?? .data]
            ) { result in
                switch result {
                case .success(let url):
                    do {
                        let inspection = try IPAAnalyzer.importIPA(url)
                        if let expected = expectedBundleIdentifier,
                           expected != inspection.bundleIdentifier {
                            try? FileManager.default.removeItem(at: inspection.url)
                            throw VaultError.message("The selected IPA has a different Bundle ID from the app you chose.")
                        }
                        chosenSignedIPA = inspection
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .alert("IPA selection", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}
