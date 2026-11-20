import SwiftUI
import Foundation
import UIKit

/// Launches an Apple-supported OTA installation request for a user-provided,
/// publicly reachable HTTPS manifest. This does not sign or host an IPA.
struct ManifestInstallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var manifestAddress = ""
    @State private var warning: String?
    @State private var acknowledged = false
    @State private var launched = false

    private var validatedManifest: URL? {
        let trimmed = manifestAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 2048,
              let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.fragment == nil,
              let url = components.url else { return nil }
        let normalizedHost = host.lowercased()
        // A private or loopback address cannot serve an iOS OTA manifest;
        // require a normal HTTPS domain instead of a local server.
        guard normalizedHost != "localhost",
              !normalizedHost.hasSuffix(".local"),
              !normalizedHost.hasPrefix("127."),
              !normalizedHost.hasPrefix("10."),
              !normalizedHost.hasPrefix("192.168."),
              !normalizedHost.hasPrefix("172.16."),
              !normalizedHost.hasPrefix("172.17."),
              !normalizedHost.hasPrefix("172.18."),
              !normalizedHost.hasPrefix("172.19."),
              !normalizedHost.hasPrefix("172.2"),
              !normalizedHost.hasPrefix("172.30."),
              !normalizedHost.hasPrefix("172.31."),
              !normalizedHost.contains(":") else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Apple OTA Installation", systemImage: "iphone.gen3.radiowaves.left.and.right")
                        .font(.headline)
                    Text("Use a manifest URL supplied by your organization or developer for a properly signed IPA. The manifest and IPA must be hosted using HTTPS.")
                        .font(.subheadline)
                }
                Section("HTTPS manifest URL") {
                    TextField("https://example.com/install/manifest.plist", text: $manifestAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    if !manifestAddress.isEmpty && validatedManifest == nil {
                        Label("Enter a valid HTTPS URL from a trusted publisher.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                    }
                }
                Section("Before you proceed") {
                    Text("Only install apps you trust and are authorized to use. A valid ad-hoc or enterprise provisioning profile and Apple-approved distribution are required. iOS makes the final installation decision.")
                        .font(.footnote)
                    Toggle("I trust this publisher and understand that iOS may reject the installation.", isOn: $acknowledged)
                    Button {
                        guard let manifest = validatedManifest else {
                            warning = "A trusted HTTPS manifest URL is required."
                            return
                        }
                        var components = URLComponents()
                        components.scheme = "itms-services"
                        components.host = ""
                        components.queryItems = [
                            URLQueryItem(name: "action", value: "download-manifest"),
                            URLQueryItem(name: "url", value: manifest.absoluteString)
                        ]
                        guard let installURL = components.url else {
                            warning = "Could not prepare an iOS installation request."
                            return
                        }
                        UIApplication.shared.open(installURL, options: [:]) { success in
                            if !success {
                                warning = "iOS could not open the manifest. Check the HTTPS URL and the distribution configuration."
                            } else {
                                launched = true
                            }
                        }
                    } label: {
                        Label("Request iOS installation", systemImage: "arrow.down.app.fill")
                    }
                    .disabled(!acknowledged || validatedManifest == nil)
                    if launched {
                        Label("Installation request sent to iOS. Check the Home Screen or Settings for installation status.", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
                Section {
                    Text("This screen does not upload IPAs or P12 files, does not check whether a hosting link is trustworthy, and cannot bypass Apple's signature, trust, or device-eligibility checks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Install signed IPA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Installation", isPresented: Binding(
                get: { warning != nil },
                set: { if !$0 { warning = nil } }
            )) {
                Button("OK") { warning = nil }
            } message: {
                Text(warning ?? "")
            }
        }
    }
}
