import SwiftUI

@main
struct ItamarOSApp: App {
    @StateObject private var releases = ReleaseMonitor()
    #if os(iOS)
    @StateObject private var appleAccounts = LocalAppleAccountStore()
    @StateObject private var messages = ItamarMessagesStore()
    @StateObject private var cloud = ItamarCloudService()
    @State private var parentRoute: ItamarParentRoute?
    #endif

    @ViewBuilder
    private var home: some View {
        #if os(iOS)
        MainScreen()
            .environmentObject(releases)
            .environmentObject(appleAccounts)
            .environmentObject(messages)
            .environmentObject(cloud)
            .onOpenURL { url in
                guard url.scheme?.lowercased() == "itamaros",
                      url.host?.lowercased() == "parent",
                      let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "invite" })?.value,
                      code.count == 32,
                      code.allSatisfy({ $0.isHexDigit }) else { return }
                parentRoute = ItamarParentRoute(inviteCode: code)
            }
            .sheet(item: $parentRoute) { route in
                if ItamarCloudConfig.enabled {
                    ItamarCloudParentRegistrationView(inviteCode: route.inviteCode)
                        .environmentObject(cloud)
                } else {
                    ItamarParentRegistrationView(inviteCode: route.inviteCode)
                        .environmentObject(messages)
                }
            }
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
