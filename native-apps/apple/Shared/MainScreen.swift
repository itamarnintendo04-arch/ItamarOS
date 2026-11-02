import SwiftUI

struct MainScreen: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.lodge.fill") }
            #if os(tvOS)
            TVStoreView()
                .tabItem { Label("Store", systemImage: "bag.fill") }
            TVStreamingView()
                .tabItem { Label("Streaming", systemImage: "play.tv.fill") }
            #else
            #if os(iOS)
            Group {
                if ItamarCloudConfig.enabled {
                    ItamarOnlineMessengerView()
                } else {
                    ItamarMessengerView()
                }
            }
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
            #endif
            NativeGameView()
                .tabItem { Label("Games", systemImage: "gamecontroller.fill") }
            LocalMediaView()
                .tabItem { Label("Player", systemImage: "play.square.stack.fill") }
            #if os(iOS)
            IPAImportView()
                .tabItem { Label("IPA", systemImage: "shippingbox") }
            #endif
            #endif
            NativeSettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.2.fill") }
        }
        .tint(Color(red:0.28,green:0.77,blue:1))
        #if os(iOS)
        .toolbarBackground(Color(red:0.055,green:0.105,blue:0.225),for:.tabBar)
        .toolbarBackground(.visible,for:.tabBar)
        #endif
    }
}

struct DashboardView: View {
    @EnvironmentObject private var releases: ReleaseMonitor

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 14) {
                        Image("BrandMark")
                            .resizable().scaledToFit().frame(width: 108, height: 108)
                            .padding(18)
                            .background(.white.opacity(0.09),
                                in:RoundedRectangle(cornerRadius:28))
                        Text("ItamarOS")
                            .font(.system(size:40,weight:.black,design:.rounded))
                            .foregroundStyle(.white)
                        Text("Your space. Your games. Your world.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.77))
                        Label("NATIVE EXPERIENCE 1.7",systemImage:"sparkles")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(red:0.52,green:0.9,blue:1))
                            .padding(.horizontal,15).padding(.vertical,8)
                            .background(.white.opacity(0.13),
                                in:Capsule())
                    }
                    .frame(maxWidth:.infinity).padding(26)
                    .background(
                        LinearGradient(colors:[
                            Color(red:0.23,green:0.29,blue:0.68),
                            Color(red:0.09,green:0.17,blue:0.39),
                            Color(red:0.035,green:0.085,blue:0.21)],
                            startPoint:.topLeading,endPoint:.bottomTrailing),
                        in:RoundedRectangle(cornerRadius:30))
                    .overlay(RoundedRectangle(cornerRadius:30)
                        .stroke(.cyan.opacity(0.35),lineWidth:1))
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
                    Text(ItamarCloudConfig.enabled ? "ItamarOS Connect: cloud messaging is configured." : "Messages are local drafts until a secure messaging backend is configured.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    #endif
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            }
            .background(Color(red:0.045,green:0.085,blue:0.18).ignoresSafeArea())
            .navigationTitle("Home")
        }
        .task {
            if releases.lastChecked == nil { await releases.check() }
        }
    }
}
