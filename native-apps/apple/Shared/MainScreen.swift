import SwiftUI

struct MainScreen: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            NativeGameView()
                .tabItem { Label("Games", systemImage: "gamecontroller.fill") }
            #if os(tvOS)
            TVStreamingView()
                .tabItem { Label("Streaming", systemImage: "play.tv.fill") }
            #else
            LocalMediaView()
                .tabItem { Label("Player", systemImage: "play.rectangle.fill") }
            #endif
            NativeSettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var releases: ReleaseMonitor

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image("BrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 125, height: 125)
                    Text("ItamarOS")
                        .font(.largeTitle.bold())
                    Text("Native app • Version 1.1")
                        .foregroundStyle(.secondary)
                    #if os(tvOS)
                    Label("Designed for Apple TV remote and tvOS", systemImage: "play.tv")
                    #else
                    Label("Built for iPhone and iPad with SwiftUI", systemImage: "iphone")
                    #endif
                    Text("Games and preferences are stored in this app, not in the website. This app does not replace iOS, iPadOS or tvOS.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Check for app updates") {
                        Task { await releases.check() }
                    }
                    .buttonStyle(.borderedProminent)
                    Text(releases.status)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            }
            .navigationTitle("Home")
        }
    }
}
