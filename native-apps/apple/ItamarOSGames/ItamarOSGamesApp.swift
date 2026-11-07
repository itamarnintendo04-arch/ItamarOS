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
    @State private var musicOn = false
    @AppStorage("games.played.cloudclimb") private var playedCloud = false
    @AppStorage("games.played.skybound") private var playedSky = false
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
                                GameSoundEffects.shared.play(.tap)
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
            Section("Soundtrack") {
                Toggle("Original menu music",isOn:$musicOn)
                    .onChange(of:musicOn) { _,enabled in
                        if enabled { GameMusic.shared.start(style:.clouds) } else { GameMusic.shared.stop() }
                    }
            }
            Section("Play instantly · No installation") {
                NavigationLink("Mini Games · Snake, 2048, Rock Paper Scissors & more") {
                    NativeGameView()
                }
            }
            Section("Your played games") {
                if !playedCloud && !playedSky {
                    Text("Games you play will appear here.").foregroundStyle(.secondary)
                }
                if playedCloud {
                    Button("Play Cloud Climb") { GameSoundEffects.shared.play(.tap); UIApplication.shared.open(gameURL) }
                }
                if playedSky {
                    NavigationLink("Play Skybound Isles") { OpenWorldAdventureView() }
                }
            }
            Section("Recommended for you") {
                if !playedCloud {
                    Button("Cloud Climb · 2D platformer") {
                        playedCloud=true
                        UIApplication.shared.open(gameURL)
                    }
                }
                if !playedSky {
                    NavigationLink {
                        OpenWorldAdventureView().onAppear { playedSky=true }
                    } label: {
                        Label("Skybound Isles · 3D exploration",systemImage:"globe")
                    }
                }
                if playedCloud && playedSky {
                    Text("More games coming soon.").foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Recommendations currently use play history on this device. Account-wide recommendations require game activity sync.")
                    .font(.caption).foregroundStyle(.secondary)
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
