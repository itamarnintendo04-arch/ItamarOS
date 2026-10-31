import SwiftUI

@main
struct ItamarOSApp: App {
    @StateObject private var releases = ReleaseMonitor()
    @AppStorage("itamaros.settings.language") private var language = "system"
    #if os(iOS)
    @StateObject private var appleAccounts = LocalAppleAccountStore()
    @StateObject private var messages = ItamarMessagesStore()
    @StateObject private var cloud = ItamarCloudService()
    @State private var parentRoute: ItamarParentRoute?
    @State private var contactRoute: ItamarContactRoute?
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
                guard url.scheme?.lowercased() == "itamaros" else { return }
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if url.host?.lowercased() == "parent",
                   let code = components?.queryItems?.first(where: { $0.name == "invite" })?.value,
                   code.count == 32, code.allSatisfy({ $0.isHexDigit }) {
                    parentRoute = ItamarParentRoute(inviteCode: code)
                } else if url.host?.lowercased() == "contact",
                          let username = components?.queryItems?.first(where: { $0.name == "username" })?.value,
                          (3...24).contains(username.count),
                          username.allSatisfy({ $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "_" || $0 == ".") }) {
                    contactRoute = ItamarContactRoute(username: username)
                }
            }
            .sheet(item: $contactRoute) { route in
                NavigationStack {
                    if ItamarCloudConfig.enabled {
                        ItamarConnectContactsView(initialUsername: route.username)
                            .environmentObject(cloud)
                    } else {
                        ContentUnavailableView("Connect not configured", systemImage: "person.crop.circle",
                            description: Text("An online account is needed to save this contact."))
                    }
                }
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
                .environment(\.locale, language == "system" ? Locale.autoupdatingCurrent : Locale(identifier: language))
        }
    }
}
