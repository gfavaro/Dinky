import AppKit
import DinkyLayout

/// One nonactivating panel per visible group; discarded as soon as the group or Space disappears.
final class TabBars {
    private struct Key: Hashable {
        let space: UInt64
        let members: [WindowID]
    }
    private var panels: [Key: NSPanel] = [:]
    private var groups: [Key: TabGroup] = [:]
    private var shells: [Key: NSPanel] = [:]
    var select: ((WindowID) -> Void)?
    var close: ((WindowID) -> Void)?
    var reorder: ((WindowID, Int, [WindowID]) -> Void)?
    var drag: ((WindowID, CGPoint, String) -> Void)?
    var finishDrag: ((CGPoint) -> Void)?
    let titles = TabTitles()

    var isInteracting: Bool { panels.values.contains { ($0.contentView as? TabBarView)?.hasGesture == true } }

    func contains(_ id: WindowID) -> Bool {
        panels.values.contains { UInt32($0.windowNumber) == id }
            || shells.values.contains { UInt32($0.windowNumber) == id }
    }

    func update(_ layouts: [(space: UInt64, layout: Layout)], model: WindowModel) {
        var wanted: Set<Key> = []
        let identities = Set(layouts.flatMap { $0.layout.tabGroups.flatMap(\.tabs) }.compactMap { model.windows[$0]?.identity })
        titles.keep(identities)
        for (space, layout) in layouts {
            for group in layout.tabGroups {
                let key = Key(space: space, members: group.windows.sorted())
                wanted.insert(key)
                let panel = panels[key] ?? layoutPanel(TabBarView(frame: .zero), ignoresMouse: false)
                panel.acceptsMouseMovedEvents = true
                let view = panel.contentView as! TabBarView
                if groups[key] != group || panels[key] == nil {
                    view.configure(group: group, titles: group.tabs.map { id in
                        model.windows[id].map { titles.title(for: $0) } ?? "Window"
                    }, icons: group.tabs.map { id in
                        model.windows[id].flatMap { NSRunningApplication(processIdentifier: $0.pid)?.icon }
                    }, cornerRadius: CGFloat(model.windows[group.selected]?.cornerRadius ?? 10))
                    let shell = shells[key] ?? layoutPanel(TabShellView(frame: .zero), ignoresMouse: true)
                    shells[key] = shell
                    let shellFrame = (shell.contentView as! TabShellView).configure(
                        groupFrame: group.frame, cornerRadius: CGFloat(model.windows[group.selected]?.cornerRadius ?? 10))
                    placeLayoutPanel(shell, frame: shellFrame, space: space, above: group.selected, order: .below)
                    shell.contentView?.needsDisplay = true
                    view.select = { [weak self] id in self?.select?(id) }
                    view.close = { [weak self] id in self?.close?(id) }
                    view.reorder = { [weak self] id, index, members in self?.reorder?(id, index, members) }
                    view.drag = { [weak self] id, point, title in self?.drag?(id, point, title) }
                    view.finishDrag = { [weak self] point in self?.finishDrag?(point) }
                    placeLayoutPanel(panel, frame: group.barFrame, space: space, above: group.selected)
                }
                groups[key] = group
                panels[key] = panel
            }
        }
        for key in Array(panels.keys) where !wanted.contains(key) {
            panels.removeValue(forKey: key)?.close()
            groups[key] = nil
            shells.removeValue(forKey: key)?.close()
        }
    }

    func invalidateTitles(_ id: WindowID? = nil) {
        if let id { titles.invalidate(id) }
        groups.removeAll()
    }

    func cancelGesture() {
        panels.values.forEach { ($0.contentView as? TabBarView)?.cancelGesture() }
    }

    func hide() {
        panels.values.forEach { $0.close() }
        panels.removeAll()
        shells.values.forEach { $0.close() }
        shells.removeAll()
        groups.removeAll()
        titles.keep([])
    }
}

final class TabBarView: NSView {
    private var tabs: [WindowID] = []
    private var selected: WindowID?
    private var titles: [String] = []
    private var gesture: TabGesture?
    private var members: [WindowID] = []
    private var cornerRadius: CGFloat = 10
    private let control = TabSegmentControl(frame: .zero)
    private let scroll = TabScrollView(frame: .zero)
    private let document = NSView(frame: .zero)
    private let previous = NSButton(image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Scroll tabs left")!, target: nil, action: nil)
    private let next = NSButton(image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Scroll tabs right")!, target: nil, action: nil)
    private let insertion = TabInsertionView(frame: .zero)
    private var revealSelected = true
    private var lastWidth: CGFloat = 0
    private var dragCursor = false
    private var gestureStartY: CGFloat = 0
    private(set) var tabFrames: [CGRect] = []
    private var closeButtons: [TabCloseButton] = []
    private var hoverIndex: Int?
    private var area: NSTrackingArea?
    var select: ((WindowID) -> Void)?
    var close: ((WindowID) -> Void)?
    var reorder: ((WindowID, Int, [WindowID]) -> Void)?
    var drag: ((WindowID, CGPoint, String) -> Void)?
    var finishDrag: ((CGPoint) -> Void)?

    var hasGesture: Bool { gesture != nil }

    func configure(group: TabGroup, titles: [String], icons: [NSImage?] = [], cornerRadius: CGFloat = 10) {
        if group.tabs != tabs || Set(group.windows) != Set(members) { cancelGesture() }
        revealSelected = revealSelected || selected != group.selected || tabs != group.tabs
        tabs = group.tabs
        selected = group.selected
        self.titles = titles
        self.cornerRadius = cornerRadius
        members = group.windows
        control.segmentCount = tabs.count
        for i in tabs.indices {
            control.setLabel(titles[i], forSegment: i)
            let icon = icons.indices.contains(i) ? icons[i]?.copy() as? NSImage : nil
            icon?.size = NSSize(width: 16, height: 16)
            control.setImage(icon, forSegment: i)
            control.setImageScaling(.scaleProportionallyDown, forSegment: i)
            control.setToolTip(titles[i], forSegment: i)
        }
        control.selectedSegment = tabs.firstIndex { $0 == selected } ?? -1
        while closeButtons.count > tabs.count { closeButtons.removeLast().removeFromSuperview() }
        while closeButtons.count < tabs.count {
            let image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close tab")!
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 9, weight: .medium))!
            let button = TabCloseButton(image: image, target: self, action: #selector(closeTab(_:)))
            button.isBordered = false
            button.controlSize = .small
            button.contentTintColor = .secondaryLabelColor
            button.setButtonType(.momentaryChange)
            button.focusRingType = .none
            document.addSubview(button)
            closeButtons.append(button)
        }
        for i in tabs.indices {
            closeButtons[i].windowID = tabs[i]
            closeButtons[i].toolTip = "Close \(titles[i])"
            closeButtons[i].setAccessibilityLabel("Close \(titles[i])")
        }
        needsLayout = true
        updateCloseVisibility()
        needsDisplay = true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        control.segmentStyle = .automatic
        if #available(macOS 27.0, *), control.responds(to: NSSelectorFromString("setRole:")) {
            // Public NSSegmentedControl.Role.tabs (raw value 1). KVC also lets older SDKs compile this file.
            control.setValue(NSNumber(value: 1), forKey: "role")
        } else { control.segmentStyle = .capsule }
        control.trackingMode = .selectOne
        control.segmentDistribution = .fit
        control.controlSize = .regular
        control.font = .systemFont(ofSize: 13)
        control.focusRingType = .none
        control.target = self
        control.action = #selector(selectSegment(_:))
        document.addSubview(control)
        scroll.documentView = document
        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.horizontalScrollElasticity = .none
        scroll.verticalScrollElasticity = .none
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        addSubview(scroll)
        for button in [previous, next] {
            button.isBordered = false
            button.controlSize = .small
            button.contentTintColor = .secondaryLabelColor
            button.target = self
            button.action = #selector(scrollTabs(_:))
            addSubview(button)
        }
        previous.setAccessibilityLabel("Scroll tabs left")
        next.setAccessibilityLabel("Scroll tabs right")
        addSubview(insertion)
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func selectSegment(_ sender: NSSegmentedControl) {
        guard tabs.indices.contains(sender.selectedSegment) else { return }
        select?(tabs[sender.selectedSegment])
    }

    @objc private func closeTab(_ sender: TabCloseButton) {
        let id = sender.pressedWindowID ?? sender.windowID
        guard tabs.contains(id) else { return }
        cancelGesture()
        close?(id)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func layout() {
        super.layout()
        guard !tabs.isEmpty else { return }
        let crowded = CGFloat(tabs.count) * TabStripSizing.minimumWidth > max(0, bounds.width - 6)
        let inset: CGFloat = crowded ? 25 : 3
        scroll.frame = CGRect(x: inset, y: 1, width: max(0, bounds.width - 2 * inset), height: max(0, bounds.height - 2))
        previous.frame = CGRect(x: 2, y: 2, width: 21, height: max(0, bounds.height - 4))
        next.frame = CGRect(x: bounds.maxX - 23, y: 2, width: 21, height: max(0, bounds.height - 4))
        previous.isHidden = !crowded
        next.isHidden = !crowded
        let font = control.font ?? .systemFont(ofSize: 13)
        let preferred = titles.map { ($0 as NSString).size(withAttributes: [.font: font]).width + 56 }
        let widths = TabStripSizing.widths(preferred: preferred, available: scroll.bounds.width)
        let size = CGSize(width: widths.reduce(0, +), height: scroll.bounds.height)
        document.frame = CGRect(origin: .zero, size: size)
        control.frame = document.bounds
        var x: CGFloat = 0
        tabFrames = widths.map { width in
            defer { x += width }
            return CGRect(x: x, y: 0, width: width, height: size.height)
        }
        (control.cell as? TabSegmentCell)?.frames = tabFrames
        for i in tabs.indices {
            control.setWidth(widths[i], forSegment: i)
            closeButtons[i].frame = CGRect(x: tabFrames[i].minX + 5, y: size.height / 2 - 8, width: 16, height: 16)
        }
        if revealSelected || lastWidth != bounds.width, let i = tabs.firstIndex(where: { $0 == selected }) {
            let frame = tabFrames[i], visible = scroll.contentView.bounds
            let offset = frame.minX < visible.minX ? frame.minX : max(visible.minX, frame.maxX - visible.width)
            scrollTo(offset)
        } else { scrollTo(scroll.contentView.bounds.minX) }
        revealSelected = false
        lastWidth = bounds.width
        insertion.frame = bounds
    }

    @objc private func scrolled() {
        hoverIndex = nil
        updateCloseVisibility()
        previous.isEnabled = scroll.contentView.bounds.minX > 0.5
        next.isEnabled = scroll.contentView.bounds.maxX < document.bounds.maxX - 0.5
    }

    @objc private func scrollTabs(_ sender: NSButton) {
        let step = scroll.bounds.width * 0.75 * (sender === previous ? -1 : 1)
        scrollTo(scroll.contentView.bounds.minX + step)
    }

    private func scrollTo(_ x: CGFloat) {
        let offset = min(max(0, x), max(0, document.bounds.width - scroll.bounds.width))
        scroll.contentView.scroll(to: CGPoint(x: offset, y: 0))
        scroll.reflectScrolledClipView(scroll.contentView)
        scrolled()
    }

    override func scrollWheel(with event: NSEvent) {
        guard document.bounds.width > scroll.bounds.width else { return super.scrollWheel(with: event) }
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
        scrollTo(scroll.contentView.bounds.minX - delta * (event.hasPreciseScrollingDeltas ? 1 : 16))
    }

    private func index(at point: CGPoint) -> Int? {
        guard scroll.frame.contains(point) else { return nil }
        let local = document.convert(point, from: self)
        return tabFrames.firstIndex { $0.contains(local) }
    }

    private var globalTabFrames: [CGRect] {
        guard let window else { return [] }
        return tabFrames.map { frame in
            let rect = window.convertToScreen(document.convert(frame, to: nil))
            return CGRect(x: rect.minX, y: (NSScreen.screens.first?.frame.maxY ?? 0) - rect.maxY, width: rect.width, height: rect.height)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let next = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(next)
        area = next
    }

    override func mouseMoved(with event: NSEvent) {
        guard !tabs.isEmpty, bounds.width > 0 else { return }
        let point = convert(event.locationInWindow, from: nil)
        hoverIndex = index(at: point)
        updateCloseVisibility()
    }

    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
    override func mouseExited(with event: NSEvent) { hoverIndex = nil; updateCloseVisibility() }

    private func updateCloseVisibility() {
        for i in closeButtons.indices { closeButtons[i].alphaValue = hoverIndex == i && gesture == nil ? 1 : 0 }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func globalPoint(_ event: NSEvent) -> CGPoint {
        let point = window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
        return CGPoint(x: point.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - point.y)
    }

    func cancelGesture() {
        gesture = nil
        insertion.marker = nil
        if dragCursor { NSCursor.pop(); dragCursor = false }
        updateCloseVisibility()
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        cancelGesture()
        guard !tabs.isEmpty, bounds.width > 0, let window else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard let index = index(at: point) else { return }
        let frame = window.frame
        let strip = CGRect(x: frame.minX, y: (NSScreen.screens.first?.frame.maxY ?? 0) - frame.maxY,
                           width: frame.width, height: frame.height)
        gestureStartY = globalPoint(event).y
        gesture = TabGesture(source: tabs[index], members: members, start: globalPoint(event), strip: strip, count: tabs.count)
    }

    override func mouseDragged(with event: NSEvent) {
        guard var gesture else { return }
        let point = globalPoint(event)
        let local = convert(event.locationInWindow, from: nil)
        if abs(point.y - gestureStartY) <= 18 {
            if local.x < scroll.frame.minX + 16 { scrollTo(scroll.contentView.bounds.minX - 16) }
            else if local.x > scroll.frame.maxX - 16 { scrollTo(scroll.contentView.bounds.minX + 16) }
        }
        let action = gesture.update(at: point, tabFrames: globalTabFrames)
        if action != nil, !dragCursor { NSCursor.closedHand.push(); dragCursor = true }
        self.gesture = gesture
        updateCloseVisibility()
        switch action {
        case .detach:
            insertion.marker = nil
            let title = tabs.firstIndex(of: gesture.source).map { titles[$0] } ?? "Window"
            drag?(gesture.source, point, title)
        case .reorder(let index):
            if let from = tabs.firstIndex(of: gesture.source), from != index {
                let frame = document.convert(tabFrames[index], to: self)
                let x = index > from ? frame.maxX : frame.minX
                insertion.marker = min(scroll.frame.maxX - 2, max(scroll.frame.minX + 2, x))
            } else { insertion.marker = nil }
        default: break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard var gesture else { return }
        let point = globalPoint(event)
        let action = gesture.finish(at: point, tabFrames: globalTabFrames)
        cancelGesture()
        switch action {
        case .click: select?(gesture.source)
        case .reorder(let index): reorder?(gesture.source, index, gesture.members)
        case .detach:
            // A quick release can arrive without an intermediate mouseDragged event.
            let title = tabs.firstIndex(of: gesture.source).map { titles[$0] } ?? "Window"
            drag?(gesture.source, point, title)
            finishDrag?(point)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        let background = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        background.appendRect(CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height / 2))
        background.fill()

    }
}

/// Public AppKit styling; pointer input is handled by the strip so tab detach/reorder still works.
private final class TabCloseButton: NSButton {
    var windowID: WindowID = 0
    private(set) var pressedWindowID: WindowID?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        pressedWindowID = windowID
        defer { pressedWindowID = nil }
        super.mouseDown(with: event)
    }
}

final class TabSegmentCell: NSSegmentedCell {
    var frames: [CGRect] = []
    override func drawSegment(_ segment: Int, inFrame frame: NSRect, with controlView: NSView) {
        guard segmentCount > 0 else { return }
        // Native artwork can extend beyond a segment's allocation. Use the same
        // allocations as the strip's buttons, keeping their reserved slots clear.
        let width = controlView.bounds.width / CGFloat(segmentCount)
        let allocation = frames.indices.contains(segment) ? frames[segment]
            : CGRect(x: controlView.bounds.minX + CGFloat(segment) * width, y: frame.minY, width: width, height: frame.height)
        let content = NSRect(x: allocation.minX + 24, y: frame.minY,
                             width: max(0, allocation.width - 32), height: frame.height)
        guard !content.isEmpty else { return }
        // Clip each segment independently so it cannot cover a close button or neighbouring tab.
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(rect: content).addClip()
        super.drawSegment(segment, inFrame: content, with: controlView)
    }
}

private final class TabSegmentControl: NSSegmentedControl {
    override class var cellClass: AnyClass? {
        get { TabSegmentCell.self }
        set {}
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Keep pointer gestures on the strip while native buttons retain their own input handling.
private final class TabScrollView: NSScrollView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit is NSButton ? hit : superview
    }
}

private final class TabInsertionView: NSView {
    var marker: CGFloat? { didSet { needsDisplay = true } }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        guard let x = marker else { return }
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: CGRect(x: x - 1.5, y: 3, width: 3, height: max(0, bounds.height - 6)), xRadius: 1.5, yRadius: 1.5).fill()
        for y in [CGFloat(3), bounds.height - 3] {
            NSBezierPath(ovalIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)).fill()
        }
    }
}

/// WinMuxX's group-shell principle with Dinky's system background and existing focus border.
/// The content cutout stays transparent and never intercepts mouse input.
final class TabShellView: NSView {
    private var groupHeight: CGFloat = 0
    var cornerRadius: CGFloat = 10
    override var isFlipped: Bool { true }

    /// Only the strip and the active window's top corners need background pixels.
    /// A full-group transparent panel would still allocate a full-size backing surface.
    func configure(groupFrame: CGRect, cornerRadius: CGFloat) -> CGRect {
        groupHeight = groupFrame.height
        self.cornerRadius = cornerRadius
        var frame = groupFrame
        frame.size.height = min(groupFrame.height, TabGroup.barHeight + max(0, cornerRadius))
        return frame
    }

    override func draw(_ dirtyRect: NSRect) {
        let group = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: max(bounds.height, groupHeight))
        let shell = NSBezierPath(roundedRect: group, xRadius: cornerRadius, yRadius: cornerRadius)
        let height = min(TabGroup.barHeight, group.height)
        let content = CGRect(x: group.minX, y: group.minY + height,
                             width: group.width, height: max(0, group.height - height))
        if !content.isEmpty { shell.append(NSBezierPath(roundedRect: content, xRadius: cornerRadius, yRadius: cornerRadius)) }
        shell.windingRule = .evenOdd
        NSColor.windowBackgroundColor.setFill()
        shell.fill()
    }
}
