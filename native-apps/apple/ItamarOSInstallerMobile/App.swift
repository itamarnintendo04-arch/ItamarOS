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
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        HStack(spacing: 10) {
                            Label("Import your P12", systemImage: "square.and.arrow.down")
                                .font(.headline)
                            Spacer()
                            Button { importing = true } label: {
                                Image(systemName: "plus.circle.fill").font(.title2)
                            }
                        }
                        .padding(.horizontal)
                        Text("Choose a P12 or ZIP from Files, then enter its password securely. TXT files are not needed; private keys stay on this iPhone.")
                            .font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
                        if vault.records.isEmpty {
                            ContentUnavailableView("No certificates yet", systemImage: "lock.shield",
                                description: Text("Import an authorized .p12 certificate and a matching .mobileprovision file. You will be asked for its password."))
                                .padding(.top, 40)
                        }
                        ForEach(vault.records) { cert in
                            certificateCard(cert)
                        }
                    }.padding(.vertical)
                }
                .navigationTitle("Certificates")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Import") { importing = true }
                    }
                }
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
                    Section("Selected certificate") {
                        if let selected = vault.selected {
                            Text(selected.name)
                            Text(selected.statusLabel).foregroundStyle(selected.dateExpired ? .red : .secondary)
                        } else {
                            Text("No certificate selected")
                        }
                        Toggle("Prefer the newest valid certificate automatically", isOn: $vault.autoSelect)
                            .onChange(of: vault.autoSelect) { value in
                                vault.saveAutoPreference()
                            }
                    }
                    Section("Privacy") {
                        Label("Stored encrypted only on this iPhone", systemImage: "lock.shield")
                        Label("Encryption key stays in iOS Keychain", systemImage: "key.fill")
                        Text("Enter your P12 password when you import a certificate. The certificate and its password are stored encrypted on this iPhone, never sent to a server.")
                            .font(.footnote).foregroundStyle(.secondary)
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
