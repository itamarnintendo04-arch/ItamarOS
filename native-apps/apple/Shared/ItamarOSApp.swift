import SwiftUI

@main
struct ItamarOSApp: App {
    @StateObject private var releases = ReleaseMonitor()
    #if os(iOS)
    @StateObject private var appleAccounts = LocalAppleAccountStore()
    #endif

    @ViewBuilder
    private var home: some View {
        #if os(iOS)
        MainScreen()
            .environmentObject(releases)
            .environmentObject(appleAccounts)
        #else
        MainScreen()
            .environmentObject(releases)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            home.tint(Color(red: 0.13, green: 0.61, blue: 0.94))
        }
    }
}
