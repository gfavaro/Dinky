import CoreGraphics

/// Tab-strip input, following WinMux's 4-point drag and 18-point vertical escape thresholds.
/// The app owns the gesture; this type only decides between click, reorder and detach.
public struct TabGesture {
    public enum Action: Equatable {
        case click, reorder(Int), detach
    }
    public let source: WindowID
    public let members: [WindowID]
    private let start: CGPoint
    private let strip: CGRect
    private let count: Int
    private var moved = false
    public private(set) var detached = false

    public init(source: WindowID, members: [WindowID], start: CGPoint, strip: CGRect, count: Int) {
        self.source = source
        self.members = members
        self.start = start
        self.strip = strip
        self.count = count
    }

    public mutating func update(at point: CGPoint) -> Action? {
        let dx = point.x - start.x, dy = point.y - start.y
        if !moved, hypot(dx, dy) < 4 { return nil }
        moved = true
        if abs(dy) > 18 { detached = true }
        if detached { return .detach }
        guard count > 0, strip.width > 0 else { return nil }
        let index = min(count - 1, max(0, Int((point.x - strip.minX) / (strip.width / CGFloat(count)))))
        return .reorder(index)
    }

    public mutating func finish(at point: CGPoint) -> Action {
        update(at: point) ?? .click
    }
}

extension Workspace {
    /// Reorder one tab (possibly a subtree), keeping each child's saved tile ratio with it.
    @discardableResult
    public mutating func reorderTab(_ id: WindowID, to index: Int, members: [WindowID]) -> Bool {
        guard let path = root.path(of: id), let depth = path.indices.last(where: {
            let c = root.container(at: Array(path.prefix($0)))
            return c.mode == .tabs && Set(c.children.flatMap(\.windows)) == Set(members)
        }) else { return false }
        let parent = Array(path.prefix(depth)), from = path[depth]
        guard root.container(at: parent).children.indices.contains(index), from != index else { return false }
        root.modify(at: parent) { $0.reorder(from: from, to: index) }
        focus(id)
        return true
    }
}
