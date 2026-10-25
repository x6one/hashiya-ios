#if DEBUG
import UIKit
import ObjectiveC.runtime

/// Opt-in event receipts. No extra view, recognizer, publication or user data.
/// The public UIWindow entry point forwards exactly once to its original IMP.
/// Only bounded scalar/class receipts are collected during dispatch; formatting
/// and NSLog run later, after dispatch has returned. This still measures an
/// instrumented build, not an unobservable or timing-neutral execution.
@MainActor enum NotesDockInputTrace {
    private static let enabled = ProcessInfo.processInfo.arguments.contains("--test-notes-dock-input")
    private static var installed = false
    private static var depth = 0
    private static var nextContact = 0
    private static var actions = 0
    private static var sequence = 0
    private static var dropped = 0
    private static var scheduled = false
    private static var contacts: [UInt: Int] = [:]
    private static var receipts: [Receipt] = []

    private struct Receipt {
        let kind: Int
        let contact: Int
        let time: TimeInterval
        var object: UInt = 0
        var owner: UInt = 0
        var type: AnyClass?
        var phase = -1
        var x: CGFloat = 0
        var y: CGFloat = 0
        var a = 0
        var b = 0
        var c = 0
        var d = 0
    }

    static func installIfNeeded() {
        guard enabled, !installed else { return }
        guard let original = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.sendEvent(_:))),
              let observer = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.tayya_notesSendEvent(_:))) else {
            NSLog("TayyaNotesInput installFailed=missingPublicWindowMethod"); return
        }
        receipts.reserveCapacity(512)
        contacts.reserveCapacity(8)
        method_exchangeImplementations(original, observer)
        installed = true
        NSLog("TayyaNotesInput installed=1 version=2 phase=began,moved,ended,cancelled forwarding=once")
    }

    private static func identity(_ object: AnyObject?) -> UInt {
        object.map { UInt(bitPattern: ObjectIdentifier($0)) } ?? 0
    }
    private static func append(_ receipt: Receipt) {
        if receipts.count >= 512 { receipts.removeFirst(64); dropped += 64 }
        receipts.append(receipt)
    }

    /// kind4/5 = action before/after; kind6/7/8 = chrome appear/update/disappear.
    static func notes(_ kind: Int, expanded: Bool, visible: Bool, targetNotes: Bool,
                      workspace: AnyObject, margins: AnyObject) {
        guard enabled else { return }
        if kind == 4 { actions += 1 }
        // Correlate only an unambiguous synchronous single-contact dispatch.
        // Lifecycle/async receipts retain action/model IDs, not a stale finger.
        let current = depth > 0 && contacts.count == 1 ? (contacts.values.first ?? 0) : 0
        var receipt = Receipt(kind: kind, contact: current, time: ProcessInfo.processInfo.systemUptime)
        receipt.phase = depth == 0 ? -1 : current == 0 ? -2 : 0
        receipt.object = identity(workspace); receipt.owner = identity(margins)
        receipt.a = expanded ? 1 : 0; receipt.b = visible ? 1 : 0
        receipt.c = targetNotes ? 1 : 0; receipt.d = actions
        append(receipt)
        if depth == 0 { requestFlush() }
    }

    fileprivate static func willDispatch(_ event: UIEvent, window: UIWindow) {
        depth += 1
        capture(event, window: window, after: false)
    }
    fileprivate static func didDispatch(_ event: UIEvent, window: UIWindow) {
        capture(event, window: window, after: true)
        depth -= 1
        if event.allTouches?.contains(where: { $0.phase == .ended || $0.phase == .cancelled }) == true {
            requestFlush()
        }
    }
    private static func capture(_ event: UIEvent, window: UIWindow, after: Bool) {
        guard event.type == .touches, let touches = event.allTouches else { return }
        for touch in touches {
            let key = identity(touch)
            if !after, touch.phase == .began, contacts[key] == nil {
                if contacts.count >= 16 { contacts.removeAll(keepingCapacity: true); dropped += 1 }
                nextContact += 1; contacts[key] = nextContact
            }
            guard let current = contacts[key] else { continue }
            let point = touch.location(in: window)
            var receipt = Receipt(kind: after ? 1 : 0, contact: current,
                                  time: ProcessInfo.processInfo.systemUptime)
            receipt.object = identity(touch.view); receipt.owner = identity(window)
            receipt.type = touch.view.map { type(of: $0) }
            receipt.phase = touch.phase.rawValue; receipt.x = point.x; receipt.y = point.y
            append(receipt)
            // Capture arbitration at both ends, not on every drawing movement.
            if touch.phase == .began || touch.phase == .ended || touch.phase == .cancelled {
                var view = touch.view
                var level = 0
                while let owner = view, level < 12 {
                    var ancestor = Receipt(kind: 2, contact: current, time: receipt.time)
                    ancestor.object = identity(owner); ancestor.owner = identity(owner.superview)
                    ancestor.type = type(of: owner); ancestor.phase = touch.phase.rawValue
                    ancestor.a = level; ancestor.b = after ? 1 : 0
                    append(ancestor)
                    let gestures = owner.gestureRecognizers ?? []
                    if gestures.count > 8 {
                        var omitted = Receipt(kind: 9, contact: current, time: receipt.time)
                        omitted.owner = identity(owner); omitted.a = gestures.count - 8
                        append(omitted)
                    }
                    for gesture in gestures.prefix(8) {
                        var recognizer = Receipt(kind: 3, contact: current, time: receipt.time)
                        recognizer.object = identity(gesture); recognizer.owner = identity(owner)
                        recognizer.type = type(of: gesture); recognizer.phase = touch.phase.rawValue
                        recognizer.a = gesture.state.rawValue; recognizer.b = gesture.isEnabled ? 1 : 0
                        recognizer.c = gesture.cancelsTouchesInView ? 1 : 0
                        recognizer.d = (after ? 4 : 0) | (gesture.delaysTouchesBegan ? 1 : 0) | (gesture.delaysTouchesEnded ? 2 : 0)
                        append(recognizer)
                    }
                    view = owner.superview; level += 1
                }
                if view != nil {
                    var omitted = Receipt(kind: 10, contact: current, time: receipt.time)
                    omitted.a = 1
                    append(omitted)
                }
            }
            if after, touch.phase == .ended || touch.phase == .cancelled { contacts.removeValue(forKey: key) }
        }
    }

    /// AX reads after an unsuccessful press can export an unfinished contact.
    /// Never log inline from UIKit's input dispatch or force a UI update.
    static func requestFlush(allowUnfinished: Bool = false) {
        guard enabled, depth == 0, contacts.isEmpty || allowUnfinished, !receipts.isEmpty, !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async {
            scheduled = false
            guard depth == 0, contacts.isEmpty || allowUnfinished else { return }
            let batch = receipts
            receipts.removeAll(keepingCapacity: true)
            for receipt in batch {
                sequence += 1
                // One bounded record per item avoids the previous1KB truncation.
                let name = receipt.type.map { String(NSStringFromClass($0).prefix(100)) } ?? "none"
                NSLog("TayyaNotesInput seq=%d contact=%d kind=%d uptime=%.6f phase=%d object=%llu owner=%llu class=%@ x=%.2f y=%.2f a=%d b=%d c=%d d=%d dropped=%d",
                      sequence, receipt.contact, receipt.kind, receipt.time, receipt.phase,
                      receipt.object, receipt.owner, name, receipt.x, receipt.y,
                      receipt.a, receipt.b, receipt.c, receipt.d, dropped)
            }
        }
    }
}

extension UIWindow {
    @objc dynamic fileprivate func tayya_notesSendEvent(_ event: UIEvent) {
        NotesDockInputTrace.willDispatch(event, window: self)
        // Swapped selector invokes the original UIWindow.sendEvent exactly once.
        tayya_notesSendEvent(event)
        NotesDockInputTrace.didDispatch(event, window: self)
    }
}
#endif
