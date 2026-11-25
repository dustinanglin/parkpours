import UIKit

/// Lets the app change which orientations it allows while it runs.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationMask: UIInterfaceOrientationMask = .allButUpsideDown

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationMask
    }
}

/// Closed, the passport is held upright: portrait only. Open, the fold is the
/// spine: landscape only.
@MainActor
enum OrientationLock {
    static func apply(isOpen: Bool) {
        let mask: UIInterfaceOrientationMask = isOpen ? .landscape : .portrait
        guard AppDelegate.orientationMask != mask else { return }
        AppDelegate.orientationMask = mask

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
            for window in windowScene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}
