import AppKit

/// Close exactly the requested window through its own AX close button. The app owns any save prompt.
final class TabCloser {
    private let queue = DispatchQueue(label: "dinky.tabs.close", qos: .userInitiated)
    private var pending: Set<Window.Identity> = []

    func close(_ window: Window, valid: @escaping () -> Bool) {
        guard pending.insert(window.identity).inserted else { return }
        let identity = window.identity
        queue.async { [weak self] in
            var value: CFTypeRef?
            let element = axWindow(pid: identity.pid, wid: identity.id, timeout: 0.2)
            var error = AXError.cannotComplete
            if let element,
               AXUIElementCopyAttributeValue(element, kAXCloseButtonAttribute as CFString, &value) == .success,
               let value, CFGetTypeID(value) == AXUIElementGetTypeID(),
               DispatchQueue.main.sync(execute: valid) {
                error = AXUIElementPerformAction(value as! AXUIElement, kAXPressAction as CFString)
            }
            let result = error
            DispatchQueue.main.async { [weak self] in
                self?.pending.remove(identity)
                if result != .success, valid() { NSSound.beep() }
            }
        }
    }
}
