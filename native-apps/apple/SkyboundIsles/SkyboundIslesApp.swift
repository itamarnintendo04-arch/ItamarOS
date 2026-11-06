import SwiftUI

@main
struct SkyboundIslesApp: App {
    @StateObject private var cloud = ItamarCloudService()
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if cloud.isSignedIn {
                    OpenWorldAdventureView()
                } else {
                    SkyboundSignInView()
                }
            }
            .environmentObject(cloud)
        }
    }
}

private struct SkyboundSignInView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var errorMessage = ""
    var body: some View {
        Form {
            Section("Skybound Isles") {
                Text("Sign in with your ItamarOS account to explore.")
                TextField("Email",text:$email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                SecureField("Password",text:$password)
                Button(busy ? "Signing in..." : "Sign in") {
                    Task {
                        busy=true
                        defer {busy=false}
                        do {
                            try await cloud.signIn(email:email,password:password)
                            errorMessage=""
                        } catch {
                            errorMessage=error.localizedDescription
                        }
                    }
                }
                .disabled(busy || email.isEmpty || password.isEmpty)
                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Skybound Isles")
    }
}
