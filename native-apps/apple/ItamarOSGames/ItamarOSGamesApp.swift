import SwiftUI

@main
struct ItamarOSGamesApp: App {
    @StateObject private var cloud = ItamarCloudService()
    var body: some Scene {
        WindowGroup {
            ItamarGamesLaunchView(content: GamesLibraryView())
                .environmentObject(cloud)
                .tint(.cyan)
        }
    }
}

private struct GamesLibraryView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error = ""
    @State private var selectedTab = 0
    @State private var showQR = false
    private let gameURL = URL(string:"cloudclimb://")!

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors:[.indigo,.blue,.cyan],
                    startPoint:.topLeading,endPoint:.bottomTrailing).ignoresSafeArea()
                if cloud.isSignedIn {
                    TabView(selection:$selectedTab) {
                        library.tabItem {Label("Games",systemImage:"gamecontroller.fill")}.tag(0)
                        statistics.tabItem {Label("Stats",systemImage:"chart.bar.fill")}.tag(1)
                        achievements.tabItem {Label("Achievements",systemImage:"trophy.fill")}.tag(2)
                        account.tabItem {Label("Account",systemImage:"person.crop.circle")}.tag(3)
                    }
                } else {
                    ScrollView {
                        VStack(spacing:18) {
                            Image(systemName:"gamecontroller.fill")
                                .font(.system(size:78)).foregroundStyle(.yellow)
                            Text("ItamarOS Games")
                                .font(.system(size:34,weight:.black,design:.rounded))
                            Text("Sign in to view your connected games, statistics and achievements.")
                                .multilineTextAlignment(.center)
                            TextField("Email",text:$email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(12).background(.white,in:RoundedRectangle(cornerRadius:12))
                                .foregroundStyle(.black)
                            SecureField("Password",text:$password)
                                .textContentType(.password)
                                .padding(12).background(.white,in:RoundedRectangle(cornerRadius:12))
                                .foregroundStyle(.black)
                            Button(busy ? "Signing in..." : "Sign in manually") {
                                Task {
                                    busy=true
                                    defer {busy=false}
                                    do {
                                        try await cloud.signIn(email:email,password:password)
                                        error=""
                                    } catch { self.error=error.localizedDescription }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(busy || email.isEmpty || password.isEmpty)
                            Button("Sign in with QR") {showQR=true}
                                .buttonStyle(.bordered)
                            Button("Open ItamarOS") {
                                if let url=URL(string:"itamaros://") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            if !error.isEmpty {Text(error).foregroundStyle(.yellow)}
                        }
                        .foregroundStyle(.white)
                        .padding(25)
                    }
                }
            }
            .navigationTitle("ItamarOS Games")
            .sheet(isPresented:$showQR) {
                NavigationStack {
                    ContentUnavailableView("QR sign-in",systemImage:"qrcode.viewfinder",
                        description:Text("Secure QR account pairing is not yet connected to the Games app. Use email and password for now."))
                    .toolbar {ToolbarItem(placement:.confirmationAction) {
                        Button("Done") {showQR=false}
                    }}
                }
            }
        }
    }

    private var library: some View {
        List {
            Section("Original ItamarOS Games") {
                NavigationLink {
                    OpenWorldAdventureView()
                } label: {
                    Label("Skybound Isles · 3D Open World",systemImage:"globe.europe.africa.fill")
                }
            }
            Section("Connected games") {
                HStack(spacing:14) {
                    Image(systemName:"cloud.fill")
                        .font(.largeTitle).foregroundStyle(.cyan)
                    VStack(alignment:.leading) {
                        Text("Cloud Climb").font(.headline)
                        Text("Available on this device if installed")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Link("Play",destination:gameURL)
                        .buttonStyle(.borderedProminent)
                }
            }
            Section {
                Text("Additional games will appear here when account-linked game data is supported.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
    private var statistics: some View {
        List {
            ContentUnavailableView("Statistics not synced yet",systemImage:"chart.bar",
                description:Text("Game sessions, play time and level records will appear after a secure game statistics service is connected."))
        }
    }
    private var achievements: some View {
        List {
            ContentUnavailableView("Achievements not synced yet",systemImage:"trophy",
                description:Text("Unlocked achievements will appear here once games report verified achievements to the account."))
        }
    }
    private var account: some View {
        List {
            Section("ItamarOS account") {
                if let name=cloud.profile?.username {Text("@"+name)}
                Text(cloud.userID?.uuidString ?? "Connected")
                    .font(.caption).textSelection(.enabled)
                Button("Sign Out",role:.destructive) {cloud.signOut()}
            }
        }
    }
}
