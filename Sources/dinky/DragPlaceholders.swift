import AppKit
import DinkyLayout
import DinkyPrivate

// While a tiled window is dragged: a quiet outline of the tile it came from, and an accent-coloured one over the
// tile it would swap with. Two borderless panels that never take focus or clicks, kept just below the dragged
// window so they never cover it. They snap between tiles; nothing reflows until the drop.
final class DragPlaceholders {
    private var home: NSPanel?
    private var target: NSPanel?

    /// Show the outlines for a window being dragged: `home` is its tile, `target` the tile it would swap with.
    /// Rects are top-left global, as tiles are.
    func show(dragged: WindowID, home homeRect: CGRect, target targetRect: CGRect?, cornerRadius: CGFloat) {
        let home = self.home ?? Self.panel(PlaceholderView(tint: .secondaryLabelColor, fill: 0.06, stroke: 0.45))
        self.home = home
        place(home, at: homeRect, below: dragged, cornerRadius: cornerRadius)
        if let targetRect {
            let target = self.target ?? Self.panel(PlaceholderView(tint: .controlAccentColor, fill: 0.2, stroke: 0.9))
            self.target = target
            place(target, at: targetRect, below: dragged, cornerRadius: cornerRadius)
        } else { target?.orderOut(nil) }
    }

    func contains(_ id: WindowID) -> Bool {
        home.map { UInt32($0.windowNumber) == id } == true
            || target.map { UInt32($0.windowNumber) == id } == true
    }

    func hide(release: Bool = false) {
        if release {
            home?.close()
            target?.close()
            home = nil
            target = nil
        } else {
            home?.orderOut(nil)
            target?.orderOut(nil)
        }
    }

    private func place(_ panel: NSPanel, at rect: CGRect, below window: WindowID, cornerRadius: CGFloat) {
        (panel.contentView as! PlaceholderView).cornerRadius = cornerRadius
        let converted = appKitLayoutFrame(rect)
        if panel.frame != converted { panel.setFrame(converted, display: true) }
        let id = UInt32(panel.windowNumber), space = dinky_window_space_id(window)
        if dinky_window_space_id(id) != space { dinky_border_move_to_space(id, space) }
        panel.order(.below, relativeTo: Int(window))
    }

    private static func panel(_ view: PlaceholderView) -> NSPanel {
        layoutPanel(view, ignoresMouse: true)
    }
}

private final class PlaceholderView: NSView {
    private let tint: NSColor
    private let fill: CGFloat
    private let stroke: CGFloat
    var cornerRadius: CGFloat = 10 { didSet { if cornerRadius != oldValue { needsDisplay = true } } }

    init(tint: NSColor, fill: CGFloat, stroke: CGFloat) {
        self.tint = tint
        self.fill = fill
        self.stroke = stroke
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: cornerRadius, yRadius: cornerRadius)
        tint.withAlphaComponent(fill).setFill()
        path.fill()
        path.lineWidth = 3
        tint.withAlphaComponent(stroke).setStroke()
        path.stroke()
    }
}
