import AppKit
import DinkyLayout
import Testing
@testable import dinky

@Suite(.serialized)
@MainActor
struct TabBarTests {
    private func strip(width: CGFloat = 840, nativeTabs: Bool = true) -> (TabBarView, NSPanel) {
        _ = NSApplication.shared
        var workspace = Workspace(bounds: CGRect(x: 0, y: 0, width: width, height: 560), algorithm: .dwindle(.tabs))
        for id: UInt32 in 1...3 { workspace.insert(id) }
        let view = TabBarView(frame: CGRect(x: 0, y: 0, width: width, height: 28))
        let panel = layoutPanel(view, ignoresMouse: false)
        panel.setFrame(CGRect(x: 0, y: 0, width: width, height: 28), display: false)
        let control = view.subviews.compactMap { $0 as? NSSegmentedControl }.first!
        if !nativeTabs {
            if #available(macOS 27.0, *) { control.setValue(NSNumber(value: 0), forKey: "role") }
            control.segmentStyle = .capsule
        }
        let icon = NSImage(systemSymbolName: "app.fill", accessibilityDescription: "Test app")!
        let originalSize = icon.size
        view.configure(group: workspace.layout().tabGroups[0], titles: ["First", "Second", String(repeating: "Long title ", count: 30)], icons: [icon, icon, icon])
        #expect(icon.size == originalSize, "Do not resize a shared application icon")
        view.layoutSubtreeIfNeeded()
        return (view, panel)
    }

    private func event(_ type: NSEvent.EventType, x: CGFloat, y: CGFloat, panel: NSPanel) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: CGPoint(x: x, y: y), modifierFlags: [], timestamp: 0,
                          windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    @Test func `Click reorder detach and cancellation stay distinct`() {
        let (view, panel) = strip()
        defer { panel.close() }
        var selected: WindowID?, reordered: Int?, finished = 0
        view.select = { selected = $0 }
        view.reorder = { _, index, _ in reordered = index }
        view.finishDrag = { _ in finished += 1 }
        view.mouseDown(with: event(.leftMouseDown, x: 420, y: 14, panel: panel))
        #expect(selected == nil)
        view.mouseUp(with: event(.leftMouseUp, x: 420, y: 14, panel: panel))
        #expect(selected == 2)
        view.mouseDown(with: event(.leftMouseDown, x: 420, y: 14, panel: panel))
        view.mouseDragged(with: event(.leftMouseDragged, x: 750, y: 14, panel: panel))
        view.mouseUp(with: event(.leftMouseUp, x: 750, y: 14, panel: panel))
        #expect(reordered == 2)
        view.mouseDown(with: event(.leftMouseDown, x: 420, y: 14, panel: panel))
        view.mouseUp(with: event(.leftMouseUp, x: 420, y: -30, panel: panel))
        #expect(finished == 1, "A quick release still completes a detach")
        view.mouseDown(with: event(.leftMouseDown, x: 420, y: 14, panel: panel))
        view.mouseDragged(with: event(.leftMouseDragged, x: 420, y: -30, panel: panel))
        view.cancelGesture()
        view.mouseUp(with: event(.leftMouseUp, x: 420, y: -30, panel: panel))
        #expect(finished == 1)
    }

    @Test(arguments: [true, false], [NSAppearance.Name.aqua, .darkAqua])
    func `Native and fallback controls retain icons and close the requested tab`(_ nativeTabs: Bool, _ appearance: NSAppearance.Name) {
        let (view, panel) = strip(width: 360, nativeTabs: nativeTabs)
        view.appearance = NSAppearance(named: appearance)
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        defer { panel.close() }
        let control = view.subviews.compactMap { $0 as? NSSegmentedControl }.first!
        #expect(control.hitTest(.zero) == nil)
        for i in 0..<3 {
            #expect(control.image(forSegment: i)?.size == NSSize(width: 16, height: 16))
            #expect(abs(control.width(forSegment: i) - control.bounds.width / 3) < 0.01)
        }
        var closed: WindowID?
        view.close = { closed = $0 }
        let buttons = view.subviews.compactMap { $0 as? NSButton }
        buttons[0].performClick(nil)
        #expect(closed == 1, "Do not close the selected third tab")
        view.mouseMoved(with: event(.mouseMoved, x: 180, y: 14, panel: panel))
        #expect(buttons[1].alphaValue == 1)
        #expect(buttons[0].alphaValue == 0)
    }

    @Test func `Long titles cannot paint into a neighbouring close slot`() {
        let (_, panel) = strip(width: 360)
        defer { panel.close() }
        let cell = TabSegmentCell()
        cell.segmentCount = 2
        cell.setLabel(String(repeating: "Very long window title ", count: 30), forSegment: 0)
        cell.setImage(NSImage(systemSymbolName: "app.fill", accessibilityDescription: "Test app"), forSegment: 0)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 180, pixelsHigh: 28,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        // AppKit's artwork frame can start before the first tab's own allocation.
        let drawingView = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 28))
        cell.drawSegment(0, inFrame: NSRect(x: -7, y: 0, width: 100, height: 28), with: drawingView)
        NSGraphicsContext.restoreGraphicsState()
        var painted = false
        for y in 0..<28 {
            for x in 0..<180 {
                let alpha = bitmap.colorAt(x: x, y: y)!.alphaComponent
                if x < 24 || x >= 82 { #expect(alpha == 0) }
                else if alpha > 0 { painted = true }
            }
        }
        #expect(painted)
    }

    @Test func `The group shell leaves window content transparent`() {
        let view = TabShellView(frame: CGRect(x: 0, y: 0, width: 840, height: 560))
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        #expect(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.alphaComponent == 0)
        #expect(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: 8)!.alphaComponent > 0)
    }

    @Test func `Creating and closing tab panels does not retain windows`() {
        _ = NSApplication.shared
        let before = NSApp.windows.count
        for _ in 0..<100 {
            autoreleasepool {
                let (_, panel) = strip()
                panel.close()
            }
        }
        #expect(NSApp.windows.count == before)
    }
}
