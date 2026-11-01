#if os(iOS)
import SwiftUI

/// Online identity is required for the iPhone/iPad app, not just the Messages tab.
/// A username is unique and stored on the server, never trusted from local defaults.
struct ItamarAccountGate: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @State private var checking = true
    @State private var error = ""

    var body: some View {
        Group {
            if !ItamarCloudConfig.enabled {
                ContentUnavailableView("Account service unavailable",
                    systemImage: "wifi.exclamationmark",
                    description: Text("This build needs a configured ItamarOS account server before you can use the app."))
            } else if !cloud.isSignedIn {
                NavigationStack { ItamarCloudLoginView() }
            } else if !cloud.deviceSyncEnabled {
                VStack(spacing: 18) {
                    ContentUnavailableView("Account sync is off",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("A saved username is needed to continue. Your conversations are not loaded until you choose to enable sync."))
                    Button("Enable account sync") {
                        cloud.setDeviceSync(true)
                        Task { try? await cloud.reload() }
                    }.buttonStyle(.borderedProminent)
                }.padding()
            } else if checking {
                ProgressView("Checking your username…")
            } else if cloud.profile == nil {
                NavigationStack { ItamarCloudProfileView(required: true) }
            } else {
                MainScreen()
            }
        }
        .task(id: cloud.isSignedIn) {
            checking = cloud.isSignedIn
            if cloud.isSignedIn && cloud.deviceSyncEnabled {
                do { try await cloud.reload(); error = "" }
                catch { error = error.localizedDescription }
            }
            checking = false
        }
        .alert("Account check failed", isPresented: Binding(
            get: { !error.isEmpty }, set: { if !$0 { error = "" } }
        )) {
            Button("Retry") {
                error = ""
                Task {
                    checking = true
                    do { try await cloud.reload() }
                    catch { error = error.localizedDescription }
                    checking = false
                }
            }
            Button("Cancel", role: .cancel) { error = "" }
        } message: { Text(error) }
    }
}
#endif
