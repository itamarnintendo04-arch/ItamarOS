#if os(iOS)
import UIKit
import UserNotifications
import Foundation

extension Notification.Name {
    static let itamarPushTokenUpdated=Notification.Name("itamaros-push-token-updated")
}

@MainActor
final class ItamarPushAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application:UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken:Data){
        let token=deviceToken.map{String(format:"%02x",$0)}.joined()
        UserDefaults.standard.set(token,forKey:"itamaros.push.apnsToken")
        NotificationCenter.default.post(name:.itamarPushTokenUpdated,object:nil)
    }
    func application(_ application:UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error:Error){
        // No secrets or device identifiers in logs; show an actionable local status.
        UserDefaults.standard.set("APNs registration unavailable. Check signing and Push Notifications entitlement.",
                                  forKey:"itamaros.push.lastError")
    }

    static func requestOptIn() async -> Bool {
        do{
            let allowed=try await UNUserNotificationCenter.current()
                .requestAuthorization(options:[.alert,.badge,.sound])
            if allowed {
                UserDefaults.standard.set(true,forKey:"itamaros.push.enabled")
                UIApplication.shared.registerForRemoteNotifications()
            }
            return allowed
        }catch{return false}
    }
}
#endif
