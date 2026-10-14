import AppKit

/// Listen-only mouse events. No timer runs while idle or while dragging.
final class DragEvents {
    var onEvent: ((CGEventType, CGPoint, Int64) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private(set) var suppressed = false

    func start() {
        guard tap == nil else { return }
        let types: [CGEventType] = [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .keyDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                          eventsOfInterest: mask, callback: dragCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            fputs("drag: could not observe mouse events (Accessibility?)\n", stderr)
            return
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    var available: Bool { tap != nil }
    func suppressUntilRelease() { suppressed = true }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
    }

    deinit { stop() }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Cancel rather than commit a drag whose release may have been missed.
            suppressed = true
            onEvent?(.keyDown, event.location, 53)
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        if type == .leftMouseDown { suppressed = false }
        onEvent?(type, event.location, event.getIntegerValueField(.keyboardEventKeycode))
        if type == .leftMouseUp { suppressed = false }
    }
}

private func dragCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                          refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if let refcon { Unmanaged<DragEvents>.fromOpaque(refcon).takeUnretainedValue().handle(type, event) }
    return Unmanaged.passUnretained(event)
}
