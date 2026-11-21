import SwiftUI
import UniformTypeIdentifiers
import CryptoKit
import Security
import ZIPFoundation
import LocalAuthentication
import UIKit

@main
struct ItamarOSMobileInstaller: App {
    @StateObject private var vault = CertificateVault()
    var body: some Scene {
        WindowGroup {
            MainScreen().environmentObject(vault)
                .preferredColorScheme(.dark)
                .tint(.cyan)
        }
    }
}

struct MainScreen: View {
    @EnvironmentObject private var vault: CertificateVault
    @State private var importing = false
    @State private var selectedTab = 0
    @State private var alertText: String?
    @State private var pendingCertificateFiles: [URL] = []
    @State private var certificatePassword = ""
    @State private var confirmCertificatePassword = false
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                Form {
                    Section("Desktop-managed certificates") {
                        Label("Signing identities are managed by ItamarOS Installer on your computer.",
                              systemImage: "desktopcomputer")
                        Text("Open Signing Certificates on the computer to import P12 and provisioning profiles. Then pair over Wi-Fi and select an available identity in the Wi-Fi tab.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Privacy") {
                        Label("Only certificate names, expiration and availability sync to this iPhone.",
                              systemImage: "lock.shield")
                        Text("Private keys and passwords remain on the computer. Previously imported iPhone certificates are not transferred automatically.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Certificates")
            }
            .tabItem { Label("Certificates", systemImage: "checkmark.shield.fill") }.tag(0)
            StorefrontScreen()
                .tabItem { Label("Store", systemImage: "bag.fill") }.tag(1)
            CustomIPAScreen()
                .tabItem { Label("Custom IPA", systemImage: "square.and.arrow.down.on.square") }.tag(2)
            WiFiCompanionScreen()
                .tabItem { Label("Wi-Fi", systemImage: "wifi") }.tag(4)
            NavigationStack {
                Form {
                    Section("Appearance") {
                        NavigationLink { ChangeAppIconView() } label: {
                            Label("Change App Icon", systemImage: "paintpalette.fill")
                        }
                    }
                    Section("Computer signing") {
                        Text("Choose signing identities in Wi-Fi Companion after pairing with the computer.")
                        Label("P12 passwords are never requested by the iPhone.", systemImage: "lock.shield")
                    }
                    Section("Important") {
                        Text("Wi-Fi Companion connects to a paired Windows installer over a local encrypted connection. The computer shares device information and downloads official IPAs automatically. Apple verifies signatures and provisioning; unsigned developer builds still require signing.")
                            .font(.footnote)
                    }
                }
                .navigationTitle("Settings")
            }.tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(3)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.zip, .data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let files):
                pendingCertificateFiles = files
                certificatePassword = ""
                confirmCertificatePassword = true
            case .failure(let error):
                alertText = error.localizedDescription
            }
        }
        .sheet(isPresented: $confirmCertificatePassword, onDismiss: {
            certificatePassword = ""
            pendingCertificateFiles = []
        }) {
            NavigationStack {
                Form {
                    Section("Certificate password") {
                        SecureField("Password for the selected P12", text: $certificatePassword)
                            .textContentType(.password)
                            .privacySensitive()
                        Text("This is your certificate password, not your Apple Account password. No TXT file is searched. If the P12 has an empty password, leave this field blank.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Section("Import files") {
                        Text("\(pendingCertificateFiles.count) selected")
                        Text("Only import signing certificates you own or are authorized to use.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Import certificate", systemImage: "checkmark.shield.fill") {
                        do {
                            let count = try vault.importFiles(pendingCertificateFiles, password: certificatePassword)
                            alertText = "Imported \(count) certificate(s) to your private vault."
                        } catch {
                            alertText = error.localizedDescription
                        }
                        certificatePassword = ""
                        pendingCertificateFiles = []
                        confirmCertificatePassword = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .navigationTitle("Import Certificate")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") {
                            certificatePassword = ""
                            pendingCertificateFiles = []
                            confirmCertificatePassword = false
                        }
                    }
                }
            }
        }
        .alert("ItamarOS Installer", isPresented: Binding(get: { alertText != nil },
                                                            set: { if !$0 { alertText = nil } })) {
            Button("OK") { alertText = nil }
        } message: {
            Text(alertText ?? "")
        }
    }
    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.largeTitle).foregroundStyle(.cyan)
                .frame(width: 64, height: 64)
                .background(.cyan.opacity(0.15), in: RoundedRectangle(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 6) {
                Text("ItamarOS Installer").font(.title2.bold())
                Text("Your private certificate vault").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding()
    }
    private func certificateCard(_ cert: CertificateRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: cert.dateExpired ? "xmark.shield.fill" : "checkmark.shield")
                    .foregroundStyle(cert.dateExpired ? .red : .cyan)
                Text(cert.name).font(.headline).lineLimit(2)
                Spacer()
                if vault.selected?.id == cert.id {
                    Text("SELECTED").font(.caption2.bold()).foregroundStyle(.cyan)
                }
            }
            Label(cert.statusLabel, systemImage: "calendar")
                .font(.subheadline)
                .foregroundStyle(cert.dateExpired ? .red : .secondary)
            if let date = cert.certificateExpires {
                Text("Certificate expires: \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let date = cert.profileExpires {
                Text("Provisioning profile expires: \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Button("Use this certificate") {
                    vault.choose(cert)
                }.buttonStyle(.borderedProminent)
                    .disabled(cert.dateExpired)
                Spacer()
                Button("Delete", role: .destructive) { vault.delete(cert) }
                    .buttonStyle(.bordered)
            }.font(.footnote)
        }
        .padding()
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }
}
