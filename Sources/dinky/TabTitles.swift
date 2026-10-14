import AppKit

/// Accessibility titles, cached by window identity and refreshed only on title events.
/// AX work stays off the main thread; missing titles are cached too.
final class TabTitles {
    private struct Cached { let title: String? }
    private struct Pending {
        let token: UInt64
        var invalidated = false
    }
    private var cache: [Window.Identity: Cached] = [:]
    private var pending: [Window.Identity: Pending] = [:]
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
        guard wanted != identities else { return }
        wanted = identities
        cache = cache.filter { identities.contains($0.key) }
        pending = pending.filter { identities.contains($0.key) }
    }

    func invalidate(_ id: UInt32) {
        cache = cache.filter { $0.key.id != id }
        for identity in pending.keys where identity.id == id { pending[identity]?.invalidated = true }
    }

    func title(for window: Window) -> String {
        let identity = window.identity
        if cache[identity] == nil { requestTitle(for: identity) }
        return cache[identity]?.title ?? window.appName ?? window.bundleID ?? "Window"
    }

    private func requestTitle(for identity: Window.Identity) {
        guard pending[identity] == nil, wanted.contains(identity) else { return }
        generation &+= 1
        let token = generation
        pending[identity] = Pending(token: token)
        let read = readTitle
        queue.async { [weak self] in
            // A queued request may belong to a group that has already disappeared.
            guard DispatchQueue.main.sync(execute: {
                self?.wanted.contains(identity) == true && self?.pending[identity]?.token == token
            }) else { return }
            let raw = read(identity)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = raw.flatMap { $0.isEmpty ? nil : $0 }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.wanted.contains(identity), let request = self.pending[identity], request.token == token else { return }
                self.pending[identity] = nil
                if request.invalidated {
                    // Coalesce title events into one follow-up read, not one queued AX call per event.
                    self.requestTitle(for: identity)
                } else {
                    self.cache[identity] = Cached(title: title)
                    self.changed?()
                }
            }
        }
    }
}
