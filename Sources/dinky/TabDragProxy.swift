import AppKit
import DinkyLayout

/// A small cursor-following label. The actual windows stay in their tiles until release.
final class TabDragProxy {
    private var panel: NSPanel?
    private let label = NSTextField(labelWithString: "")

    func contains(_ id: WindowID) -> Bool { panel.map { UInt32($0.windowNumber) == id } ?? false }

    func show(title: String, at point: CGPoint, space: UInt64, above id: WindowID) {
        if panel == nil {
            let view = NSView(frame: CGRect(x: 0, y: 0, width: 220, height: 28))
            view.wantsLayer = true
            view.layer?.cornerRadius = 6
            label.frame = CGRect(x: 10, y: 6, width: 200, height: 17)
            label.font = .systemFont(ofSize: 12, weight: .semibold)
            label.lineBreakMode = .byTruncatingTail
            view.addSubview(label)
            panel = layoutPanel(view, ignoresMouse: true)
        }
        guard let panel else { return }
        panel.contentView?.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        label.stringValue = title
        placeLayoutPanel(panel, frame: CGRect(x: point.x + 12, y: point.y + 12, width: 220, height: 28), space: space, above: id)
    }

    func hide() { panel?.orderOut(nil) }
}
