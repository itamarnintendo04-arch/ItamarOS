#if os(iOS)
import SwiftUI

struct ItamarDesktopPairRoute: Identifiable {
    let request: String
    var id: String { request }
}

struct ItamarDesktopPairApprovalView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @Environment(\.dismiss) private var dismiss
    let request: String
    @State private var busy = false
    @State private var result = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Approve this computer") {
                    Text("Use your existing ItamarOS Connect account to sign in on your computer without another SMS.")
                    Text("Compare this code with the one displayed on your computer:")
                    Text(String(request.prefix(6)).uppercased())
                        .font(.system(.title,design:.monospaced)).bold()
                    Text("Only approve a computer you are using. It will get temporary access to your messages, not your password or SMS code.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    if cloud.isSignedIn {
                        Button(busy ? "Approving…" : "Approve this computer") {
                            busy = true
                            Task {
                                do {
                                    try await cloud.approveDesktopPairing(request:request)
                                    result = "Approved. Return to your computer."
                                } catch { result = error.localizedDescription }
                                busy = false
                            }
                        }.disabled(busy || result.hasPrefix("Approved"))
                    } else {
                        Text("Sign in to ItamarOS Connect on this phone first.")
                    }
                    if !result.isEmpty { Text(result).font(.caption) }
                    Button("Cancel",role:.cancel) { dismiss() }
                }
            }.navigationTitle("Desktop login")
        }
    }
}
#endif
