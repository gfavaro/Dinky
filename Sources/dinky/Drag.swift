import AppKit
import DinkyLayout

struct DragSession {
    let identity: Window.Identity
    let space: UInt64
    let layout: Layout
    var fromTabStrip = false
    var intent: DropIntent?
    var targetIdentity: Window.Identity?
}

extension Coordinator {
    func startDragEvents() {
        dragEvents.onEvent = { [weak self] type, pointer, keyCode in
            guard let self else { return }
            self.dragPointer = pointer
            if type == .keyDown, keyCode == 53 { self.tabBars.cancelGesture(); self.cancelDrag(); return }
            if type == .leftMouseUp { self.finishDrag(); return }
            if type == .leftMouseDragged { self.showPlaceholders() }
        }
        dragEvents.start()
    }

    func dragTab(_ id: WindowID, at point: CGPoint, title: String) {
        guard enabled, !MissionControl.shared.active, dragEvents.available, !dragEvents.suppressed,
              let key = placements[id]?.space, isVisible(key), let window = model.windows[id],
              let workspace = workspaces[key], workspace.fullscreen == nil else { return }
        if dragSession == nil {
            dragging = id
            dragSession = DragSession(identity: window.identity, space: key, layout: workspace.layout(), fromTabStrip: true)
        }
        guard dragSession?.identity == window.identity, dragSession?.fromTabStrip == true else { return }
        dragPointer = point
        showPlaceholders()
        tabDragProxy.show(title: title, at: point, space: key, above: dropOverlay.windowID ?? id)
    }

    func finishTabDrag(at point: CGPoint) {
        guard dragSession?.fromTabStrip == true else { return }
        dragPointer = point
        finishDrag()
    }

    func noteFrameChange(of id: WindowID) {
        if dragging == id { return showPlaceholders() }
        guard enabled, !MissionControl.shared.active, dragging == nil, !tabBars.isInteracting, dragEvents.available,
              !dragEvents.suppressed, mouseButtonDown, !isAnimating(id),
              let key = placements[id]?.space, isVisible(key), let window = model.windows[id],
              let layout = workspaces[key]?.layout(), let home = layout.frames[id],
              !window.frame.isClose(to: home, within: 2) else { return }
        dragging = id
        dragSession = DragSession(identity: window.identity, space: key, layout: layout)
        dragPointer = CGEvent(source: nil)?.location
        showPlaceholders()
    }

    func cancelDrag() {
        guard let session = dragSession else { return }
        dragging = nil
        dragSession = nil
        tabBars.cancelGesture()
        tabDragProxy.hide()
        placeholders.hide(release: true)
        dropOverlay.hide(release: true)
        dragEvents.suppressUntilRelease()
        cancelledDragSpace = session.space
        dirty.insert(session.space)
        flush()
    }

    private func finishDrag() {
        if let space = cancelledDragSpace {
            cancelledDragSpace = nil
            dirty.insert(space)
            flush()
        }
        guard let session = dragSession else { return }
        // Resolve the final pointer before clearing the drag. WindowServer events can lag mouse-up.
        showPlaceholders(frame: liveFrame(session.identity.id))
        guard let final = dragSession else { return }
        dragging = nil
        dragSession = nil
        tabBars.cancelGesture()
        tabDragProxy.hide()
        placeholders.hide(release: true)
        dropOverlay.hide(release: true)
        guard enabled, model.windows[session.identity.id]?.identity == session.identity,
              placements[session.identity.id]?.space == session.space, isVisible(session.space),
              let window = model.windows[session.identity.id], let expected = session.layout.frames[window.id] else { return }
        let frame = liveFrame(window.id) ?? window.frame
        if session.fromTabStrip {
            if commitDrop(final) { focus(window.id) }
        } else if !frame.isClose(to: expected, within: 2) {
            if let edges = movedEdges(from: expected, to: frame) {
                edit(session.space) { $0.resize(window.id, to: frame.size, moving: edges) }
            } else { _ = commitDrop(final) }
        }
        dirty.insert(session.space)
        flush()
    }

    private func commitDrop(_ session: DragSession) -> Bool {
        guard let intent = session.intent, let identity = session.targetIdentity,
              model.windows[intent.target]?.identity == identity, placements[intent.target]?.space == session.space else { return false }
        if config.drag.dropTargets { return edit(session.space) { $0.drop(intent) } == true }
        return edit(session.space) { $0.swap(intent.source, intent.target) } == true
    }

    private func showPlaceholders(frame: CGRect? = nil) {
        guard var session = dragSession, let id = dragging, let window = model.windows[id],
              window.identity == session.identity, placements[id]?.space == session.space, isVisible(session.space),
              workspaces[session.space]?.fullscreen == nil else { return cancelDrag() }
        session.intent = nil
        session.targetIdentity = nil
        let home = session.layout.frames[id]!
        let currentFrame = frame ?? window.frame
        guard session.fromTabStrip || (!currentFrame.isClose(to: home, within: 2) && movedEdges(from: home, to: currentFrame) == nil),
              let pointer = dragPointer else {
            dragSession = session
            placeholders.hide()
            dropOverlay.hide()
            return
        }
        // Dragging the selected tab must expose its remaining group as a destination too.
        let remainingTab = session.layout.tabGroups.first { $0.selected == id }?.tabs.first { $0 != id }
        let target = session.layout.order.first { other in
            guard other != id, session.layout.visibleWindows.contains(other) || remainingTab == other,
                  placements[other]?.space == session.space, model.windows[other] != nil else { return false }
            return destinationFrame(other, in: session.layout)?.contains(pointer) == true
        }
        let targetFrame = target.flatMap { destinationFrame($0, in: session.layout) }
        if let target, let targetFrame {
            session.intent = config.drag.dropTargets
                ? DropZones.resolve(source: id, target: target, pointer: pointer, frame: targetFrame)
                : DropIntent(source: id, target: target, zone: .swap)
            session.targetIdentity = model.windows[target]?.identity
        }
        dragSession = session
        if config.drag.placeholders {
            placeholders.show(dragged: id, home: home, target: config.drag.dropTargets ? nil : targetFrame,
                              cornerRadius: CGFloat(window.cornerRadius))
        } else { placeholders.hide() }
        if config.drag.dropTargets, let intent = session.intent, let targetFrame {
            dropOverlay.show(frame: targetFrame, zone: intent.zone, above: intent.target, below: id)
        } else { dropOverlay.hide() }
    }

    private func destinationFrame(_ id: WindowID, in layout: Layout) -> CGRect? {
        layout.tabGroups.first { $0.windows.contains(id) }?.frame ?? layout.frames[id]
    }

    private func liveFrame(_ id: WindowID) -> CGRect? {
        let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]]
        guard let bounds = info?.first?[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: bounds as CFDictionary)
    }

    private func movedEdges(from tile: CGRect, to frame: CGRect) -> Set<Direction>? {
        let axes = [((Direction.left, tile.minX, frame.minX), (Direction.right, tile.maxX, frame.maxX)),
                    ((Direction.up, tile.minY, frame.minY), (Direction.down, tile.maxY, frame.maxY))]
        var edges: Set<Direction> = []
        for (lead, trail) in axes {
            let moved = [lead, trail].filter { abs($0.2 - $0.1) > 2 }.map(\.0)
            if moved.count == 2 { return nil }
            edges.formUnion(moved)
        }
        return edges.isEmpty ? nil : edges
    }

    private var mouseButtonDown: Bool { CGEventSource.buttonState(.combinedSessionState, button: .left) }
}
