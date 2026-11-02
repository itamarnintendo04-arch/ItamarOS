#if os(iOS)
import UIKit
import SwiftUI

/// Requests a landscape scene while a Cloud Climb gameplay view is visible.
/// Both orientations remain allowed in the application's Info.plist, so the
/// app's login and account screens can return to portrait.
@MainActor
enum CloudClimbLandscape {
    static func setActive(_ active:Bool) {
        let mask:UIInterfaceOrientationMask = active ? .landscape : .portrait
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes
            where scene.activationState == .foregroundActive {
            if #available(iOS 16.0, *) {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations:mask),
                    errorHandler:{ _ in /* Device or system policy controls rotation. */ })
            }
        }
        UIViewController.attemptRotationToDeviceOrientation()
    }
}
#endif
