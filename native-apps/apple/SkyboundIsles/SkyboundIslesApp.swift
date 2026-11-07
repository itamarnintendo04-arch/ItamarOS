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
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
        }
    }
}

private struct SkyboundSignInView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var errorMessage = ""
    @State private var musicOn = false
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName:"mountain.2.fill").font(.system(size:42)).foregroundStyle(.mint)
                    VStack(alignment:.leading) {
                        Text("Skybound Isles").font(.largeTitle.bold())
                        Text("Explore floating worlds").foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth:.infinity)
                Toggle("Original game soundtrack",isOn:$musicOn)
                    .onChange(of:musicOn) { _,value in
                        if value { GameMusic.shared.start(style:.adventure) } else { GameMusic.shared.stop() }
                    }
            }
            Section("Connect ItamarOS") {
                Button("Open ItamarOS") {
                    if let url=URL(string:"itamaros://") { UIApplication.shared.open(url) }
                }
                Section("Skybound Isles") {
                Text("Sign in with your ItamarOS account to explore.")
                TextField("Email",text:$email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                SecureField("Password",text:$password)
Button("Continue with Google") {
                    Task {
                        busy = true
                        defer { busy = false }
                        do { try await cloud.signInWithGoogle(callbackScheme: "skybound") }
                        catch { errorMessage = error.localizedDescription }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy)
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
        }
        .navigationTitle("Skybound Isles")
    }
}
