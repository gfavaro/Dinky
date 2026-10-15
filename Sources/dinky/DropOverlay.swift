import AppKit
import DinkyLayout
import DinkyPrivate

final class DropOverlay {
    private var panel: NSPanel?
    private var shown: (frame: CGRect, zone: DropZone, window: WindowID)?

    var windowID: WindowID? { shown == nil ? nil : panel.map { UInt32($0.windowNumber) } }

    func contains(_ id: WindowID) -> Bool { panel.map { UInt32($0.windowNumber) == id } ?? false }

    func show(frame: CGRect, zone: DropZone, above target: WindowID, below dragged: WindowID) {
        if let shown, shown.frame == frame, shown.zone == zone, shown.window == dragged { return }
        let panel = self.panel ?? layoutPanel(DropOverlayView(frame: .zero), ignoresMouse: true)
        self.panel = panel
        let view = panel.contentView as! DropOverlayView
        view.zone = zone
        view.needsDisplay = true
        placeLayoutPanel(panel, frame: frame, space: dinky_window_space_id(target), above: dragged)
        shown = (frame, zone, dragged)
    }

    func hide(release: Bool = false) {
        if release {
            panel?.close()
            panel = nil
        } else { panel?.orderOut(nil) }
        shown = nil
    }
}

private final class DropOverlayView: NSView {
    var zone = DropZone.swap
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10)
        NSColor.windowBackgroundColor.withAlphaComponent(0.88).setFill()
        background.fill()
        for item in DropZones.frames(in: bounds) {
            let active = item.zone == zone
            let tile = NSBezierPath(roundedRect: item.frame.insetBy(dx: 3, dy: 3), xRadius: 7, yRadius: 7)
            (active ? NSColor.controlAccentColor.withAlphaComponent(0.25) : NSColor.labelColor.withAlphaComponent(0.04)).setFill()
            tile.fill()
            (active ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
            tile.lineWidth = active ? 2 : 1
            tile.stroke()
            let symbol: String
            let label: String
            switch item.zone {
            case .accordion: (symbol, label) = ("rectangle.3.group", "Accordion")
            case .left: (symbol, label) = ("arrow.left", "Left")
            case .right: (symbol, label) = ("arrow.right", "Right")
            case .above: (symbol, label) = ("arrow.up", "Above")
            case .below: (symbol, label) = ("arrow.down", "Below")
            case .swap: (symbol, label) = ("arrow.left.arrow.right", "Swap")
            }
            let fontSize = min(22, max(12, min(item.frame.width, item.frame.height) * 0.22))
            if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: fontSize, weight: active ? .semibold : .regular)
                    .applying(NSImage.SymbolConfiguration(paletteColors: [active ? .controlAccentColor : .labelColor]))) {
                let size = image.size
                image.draw(in: CGRect(x: item.frame.midX - size.width / 2, y: item.frame.midY - size.height / 2,
                                      width: size.width, height: size.height), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            }
        }
    }
}
