import UIKit

/// A pan may begin after UIKit has rebased its translation. Keep the real
/// contact in the attached canvas's coordinates, rather than deriving it from
/// the recognition threshold. This also keeps short endpoint drags unambiguous.
final class InkPanGestureRecognizer: UIPanGestureRecognizer {
    private(set) var firstContact: CGPoint?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if firstContact == nil, let touch = touches.first, let view {
            firstContact = touch.location(in: view)
        }
        super.touchesBegan(touches, with: event)
    }
    override func reset() {
        super.reset()
        firstContact = nil
    }
}
