#if os(iOS)
import SwiftUI
import LocalAuthentication

struct ItamarDesktopPairRoute: Identifiable {
    let request: String
    var isCloudClimb:Bool = false
    var id: String { request }
}

struct ItamarDesktopPairApprovalView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let request: String
    var isCloudClimb:Bool = false
    @State private var busy = false
    @State private var result = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(isCloudClimb ? "Approve Cloud Climb" : "Approve This Computer") {
                    Text(isCloudClimb
                        ? "Connect Cloud Climb using your existing ItamarOS account without scanning a QR code."
                        : "Use your existing ItamarOS Connect account to sign in on your computer without another SMS.")
                    Text(isCloudClimb
                        ? "Compare this code with the one displayed in Cloud Climb:"
                        : "Compare this code with the one displayed on your computer:")
                    Text(String(request.prefix(6)).uppercased())
                        .font(.system(.title,design:.monospaced)).bold()
                    Text(isCloudClimb
                        ? "Only approve a Cloud Climb login you started. Face ID or Touch ID is required; the linked app receives temporary account access."
                        : "Only approve a computer you are using. Biometric confirmation is required. Only approve a device you recognize; a pending desktop login can access your account.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    if cloud.isSignedIn {
                        Button(busy ? "Approving…" :
                            (isCloudClimb ? "Approve Cloud Climb" : "Approve This Computer")) {
                            busy = true
                            Task {
                                do {
                                    let verifier=LAContext()
                                    var authError:NSError?
                                    guard verifier.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                                     error:&authError) else {
                                        throw NSError(domain:"ItamarOSApproval",code:1,userInfo:[
                                            NSLocalizedDescriptionKey:"Face ID or Touch ID must be set up before approving."
                                        ])
                                    }
                                    let passed=try await verifier.evaluatePolicy(
                                        .deviceOwnerAuthenticationWithBiometrics,
                                        localizedReason:isCloudClimb
                                            ? "Confirm connecting Cloud Climb with your ItamarOS account"
                                            : "Approve a login on another device using your ItamarOS account")
                                    guard passed else {
                                        throw NSError(domain:"ItamarOSApproval",code:2,userInfo:[
                                            NSLocalizedDescriptionKey:"Biometric authentication was not completed."
                                        ])
                                    }
                                    try await cloud.approveDesktopPairing(request:request)
                                    result = isCloudClimb
                                        ? "Approved. Return to Cloud Climb to finish sign-in."
                                        : "Approved. Return to your computer."
                                } catch { result = error.localizedDescription }
                                busy = false
                            }
                        }.disabled(busy || result.hasPrefix("Approved"))
                    } else {
                        Text("Sign in to ItamarOS Connect on this phone first.")
                    }
                    if !result.isEmpty { Text(result).font(.caption) }
                    if isCloudClimb && result.hasPrefix("Approved") {
                        Button("Return to Cloud Climb") {
                            if let url=URL(string:"cloudclimb://login-return"){
                                openURL(url)
                            }
                        }
                    }
                    Button("Cancel",role:.cancel) { dismiss() }
                }
            }.navigationTitle(isCloudClimb ? "Cloud Climb Login" : "Desktop Login")
        }
    }
}
#endif
