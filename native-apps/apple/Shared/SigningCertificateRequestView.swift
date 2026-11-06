#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

/// Local-only request for credentials owned by the user.
/// The files are never uploaded or committed by this view.
struct SigningCertificateRequestView: View {
    @State private var certificateURL: URL?
    @State private var profileURL: URL?
    @State private var showCertificatePicker = false
    @State private var showProfilePicker = false
    @State private var teamID = ""
    @State private var message = ""

    var body: some View {
        Form {
            Section("Your Apple signing credentials") {
                Text("Use only certificates and provisioning profiles issued to you or your team.")
                Button(certificateURL == nil ? "Select .p12 certificate" : "Certificate selected: \(certificateURL!.lastPathComponent)") {
                    showCertificatePicker = true
                }
                Button(profileURL == nil ? "Select .mobileprovision profile" : "Profile selected: \(profileURL!.lastPathComponent)") {
                    showProfilePicker = true
                }
                TextField("Apple Developer Team ID", text:$teamID)
                    .textInputAutocapitalization(.characters)
                SecureField("Certificate password (enter during signing)", text:.constant(""))
                    .disabled(true)
                Text("This form only selects local files. Signing and secure password entry are not connected yet.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Status") {
                Text(message.isEmpty ? "Waiting for your credentials" : message)
            }
        }
        .navigationTitle("IPA signing")
        .fileImporter(isPresented:$showCertificatePicker,allowedContentTypes:[.data]) { result in
            switch result {
            case .success(let url):
                guard url.pathExtension.lowercased() == "p12" else {
                    message = "Choose a .p12 certificate."
                    return
                }
                certificateURL=url
                message="Certificate selected locally. Not uploaded."
            case .failure(let error): message=error.localizedDescription
            }
        }
        .fileImporter(isPresented:$showProfilePicker,allowedContentTypes:[.data]) { result in
            switch result {
            case .success(let url):
                guard url.pathExtension.lowercased() == "mobileprovision" else {
                    message="Choose a .mobileprovision profile."
                    return
                }
                profileURL=url
                message="Provisioning profile selected locally. Not uploaded."
            case .failure(let error): message=error.localizedDescription
            }
        }
    }
}
#endif
