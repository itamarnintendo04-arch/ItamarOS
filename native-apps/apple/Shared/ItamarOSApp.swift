import SwiftUI

@main
struct ItamarOSApp: App {
    @StateObject private var releases = ReleaseMonitor()

    var body: some Scene {
        WindowGroup {
            MainScreen()
                .environmentObject(releases)
                .tint(Color(red: 0.13, green: 0.61, blue: 0.94))
        }
    }
}
