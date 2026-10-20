import UIKit
import XCTest

@MainActor func studioTestWindow(_ controller: UIViewController) throws -> (UIWindow, UIWindow?) {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let previous = scene.windows.first { $0.isKeyWindow }
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 900, height: 1000)
    window.rootViewController = controller
    window.makeKeyAndVisible()
    controller.view.layoutIfNeeded()
    return (window, previous)
}
