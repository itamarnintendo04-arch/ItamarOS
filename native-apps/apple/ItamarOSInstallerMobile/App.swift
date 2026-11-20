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
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        HStack(spacing: 10) {
                            Label("Import ZIP / P12", systemImage: "square.and.arrow.down")
                                .font(.headline)
                            Spacer()
                            Button { importing = true } label: {
                                Image(systemName: "plus.circle.fill").font(.title2)
                            }
                        }
                        .padding(.horizontal)
                        Text("Import your own certificate archives directly from Files. Nothing is uploaded to ItamarOS.")
                            .font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
                        if vault.records.isEmpty {
                            ContentUnavailableView("No certificates yet", systemImage: "lock.shield",
                                description: Text("Add a ZIP containing a P12 and password TXT, or import P12 and TXT files."))
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
            CatalogScreen()
                .tabItem { Label("ItamarOS Apps", systemImage: "square.grid.2x2.fill") }.tag(1)
            CustomIPAScreen()
                .tabItem { Label("Custom IPA", systemImage: "square.and.arrow.down.on.square") }.tag(2)
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
                        Text("A TXT password is read once during import, then stored encrypted. This app does not send keys or passwords to a server.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Important") {
                        Text("Custom IPA preflight checks your device UDID, app Bundle ID, matching identity and expiry dates. It does not revoke-check, sign, or directly install IPAs on iOS. Use a supported signed installation method.")
                            .font(.footnote)
                    }
                }
                .navigationTitle("Settings")
            }.tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(3)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.zip, .data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let files):
                do {
                    let count = try vault.importFiles(files)
                    alertText = "Imported \(count) certificate(s). \(vault.records.count) are saved on this iPhone."
                } catch {
                    alertText = error.localizedDescription
                }
            case .failure(let error):
                alertText = error.localizedDescription
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
