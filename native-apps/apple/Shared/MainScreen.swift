import SwiftUI

struct MainScreen: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            #if os(tvOS)
            TVStoreView()
                .tabItem { Label("Store", systemImage: "bag.fill") }
            TVStreamingView()
                .tabItem { Label("Streaming", systemImage: "play.tv.fill") }
            #else
            #if os(iOS)
            ItamarMessengerView()
                .tabItem { Label("Messages", systemImage: "message.fill") }
            #endif
            NativeGameView()
                .tabItem { Label("Games", systemImage: "gamecontroller.fill") }
            LocalMediaView()
                .tabItem { Label("Player", systemImage: "play.rectangle.fill") }
            #if os(iOS)
            IPAImportView()
                .tabItem { Label("IPA", systemImage: "shippingbox") }
            #endif
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
                    Text("Native app • Version 1.6.1")
                        .foregroundStyle(.secondary)
                    #if os(tvOS)
                    Label("Native Apple TV app with remote support", systemImage: "play.tv")
                    #elseif os(macOS)
                    Label("Native macOS app using SwiftUI", systemImage: "desktopcomputer")
                    #elseif os(visionOS)
                    Label("Native Apple Vision Pro app", systemImage: "visionpro")
                    #else
                    Label("Built for iPhone and iPad with SwiftUI", systemImage: "iphone")
                    #endif
                    Text("Games and preferences are stored in this app, not in the website. This app does not replace iOS, iPadOS or tvOS.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    #if os(iOS)
                    AppleAccountSignInView()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    #endif
                    Button("Check for app updates") {
                        Task { await releases.check() }
                    }
                    .buttonStyle(.borderedProminent)
                    Text(releases.status)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                    #if os(iOS)
                    Text("Messages, channels, updates and profiles are currently saved on this iPhone only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    #endif
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            }
            .navigationTitle("Home")
        }
        .task {
            if releases.lastChecked == nil { await releases.check() }
        }
    }
}
