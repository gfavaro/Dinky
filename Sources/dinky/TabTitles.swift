import AppKit

/// Accessibility titles, cached by window identity and refreshed only on title events.
/// AX work stays off the main thread; missing titles are cached too.
final class TabTitles {
    private struct Cached { let title: String? }
    private var cache: [Window.Identity: Cached] = [:]
    private var pending: [Window.Identity: UInt64] = [:]
    private var wanted: Set<Window.Identity> = []
    private var generation: UInt64 = 0
    private let queue = DispatchQueue(label: "dinky.tabs.titles", qos: .utility)
    var changed: (() -> Void)?
    private let readTitle: (Window.Identity) -> String?

    init(readTitle: @escaping (Window.Identity) -> String? = TabTitles.accessibilityTitle) {
        self.readTitle = readTitle
    }

    private static func accessibilityTitle(_ identity: Window.Identity) -> String? {
        guard let element = axWindow(pid: identity.pid, wid: identity.id, timeout: 0.15) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    func keep(_ identities: Set<Window.Identity>) {
        wanted = identities
        cache = cache.filter { identities.contains($0.key) }
        pending = pending.filter { identities.contains($0.key) }
    }

    func invalidate(_ id: UInt32) {
        cache = cache.filter { $0.key.id != id }
        pending = pending.filter { $0.key.id != id }
    }

    func title(for window: Window) -> String {
        let identity = window.identity
        if cache[identity] == nil, pending[identity] == nil, wanted.contains(identity) {
            generation &+= 1
            let token = generation
            pending[identity] = token
            let read = readTitle
            queue.async { [weak self] in
                let raw = read(identity)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = raw.flatMap { $0.isEmpty ? nil : $0 }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.wanted.contains(identity), self.pending[identity] == token else { return }
                    self.pending[identity] = nil
                    self.cache[identity] = Cached(title: title)
                    self.changed?()
                }
            }
        }
        return cache[identity]?.title ?? window.appName ?? window.bundleID ?? "Window"
    }
}
