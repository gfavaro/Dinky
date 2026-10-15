import DinkyConfig
import AppKit
import DinkyPrivate

/// Panels belong to one native Space. They never activate Dinky or join every Space.
func layoutPanel(_ view: NSView, ignoresMouse: Bool) -> NSPanel {
    let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isReleasedWhenClosed = false
    panel.tabbingMode = .disallowed
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.ignoresMouseEvents = ignoresMouse
    panel.animationBehavior = .none
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.stationary, .ignoresCycle, .transient]
    panel.contentView = view
    if ignoresMouse { panel.setAccessibilityElement(false); panel.setAccessibilityHidden(true) }
    else {
        panel.setAccessibilityRole(.window)
        panel.setAccessibilityLabel("\(AppIdentity.name) drag preview")
    }
    return panel
}

func appKitLayoutFrame(_ rect: CGRect) -> CGRect {
    let height = NSScreen.screens.first?.frame.maxY ?? 0
    return CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
}

func placeLayoutPanel(_ panel: NSPanel, frame: CGRect, space: UInt64, above window: UInt32, order: NSWindow.OrderingMode = .above) {
    let converted = appKitLayoutFrame(frame)
    if panel.frame != converted { panel.setFrame(converted, display: true) }
    let id = UInt32(panel.windowNumber)
    if dinky_window_space_id(id) != space { dinky_border_move_to_space(id, space) }
    panel.order(order, relativeTo: Int(window))
}
