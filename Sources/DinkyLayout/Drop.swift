import CoreGraphics

public enum DropZone: CaseIterable, Equatable, Sendable {
    case tabs, left, right, above, below, swap

    var direction: Direction? {
        switch self {
        case .left: return .left
        case .right: return .right
        case .above: return .up
        case .below: return .down
        case .tabs, .swap: return nil
        }
    }
}

public struct DropIntent: Equatable, Sendable {
    public let source: WindowID
    public let target: WindowID
    public let zone: DropZone

    public init(source: WindowID, target: WindowID, zone: DropZone) {
        self.source = source
        self.target = target
        self.zone = zone
    }
}

/// WinMux's six-zone interaction, adapted for CGRect. See THIRD_PARTY_NOTICES.md.
public enum DropZones {
    public static func frames(in frame: CGRect) -> [(zone: DropZone, frame: CGRect)] {
        guard frame.width > 0, frame.height > 0 else { return [] }
        let tabHeight = min(max(frame.height * 0.18, 32), frame.height / 3)
        let body = CGRect(x: frame.minX, y: frame.minY + tabHeight,
                          width: frame.width, height: frame.height - tabHeight)
        let w = body.width / 3, h = body.height / 3
        return [
            (.tabs, CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: tabHeight)),
            (.left, CGRect(x: body.minX, y: body.minY, width: w, height: body.height)),
            (.right, CGRect(x: body.maxX - w, y: body.minY, width: w, height: body.height)),
            (.above, CGRect(x: body.minX + w, y: body.minY, width: w, height: h)),
            (.swap, CGRect(x: body.minX + w, y: body.minY + h, width: w, height: h)),
            (.below, CGRect(x: body.minX + w, y: body.maxY - h, width: w, height: h)),
        ]
    }

    public static func resolve(source: WindowID, target: WindowID, pointer: CGPoint, frame: CGRect) -> DropIntent? {
        guard source != target, frame.contains(pointer),
              let zone = frames(in: frame).reversed().first(where: { $0.frame.contains(pointer) })?.zone else { return nil }
        return DropIntent(source: source, target: target, zone: zone)
    }
}

extension Workspace {
    /// Commit a drop atomically. No layout state changes for an invalid or stale intent.
    @discardableResult
    public mutating func drop(_ intent: DropIntent) -> Bool {
        guard intent.source != intent.target, fullscreen == nil,
              contains(intent.source), contains(intent.target) else { return false }
        var next = self
        if intent.zone == .tabs, let sourcePath = root.path(of: intent.source), let targetPath = root.path(of: intent.target) {
            let parent = Array(sourcePath.dropLast())
            if root.container(at: parent).mode == .tabs, targetPath.starts(with: parent) {
                focus(intent.source)
                return true
            }
        }
        if intent.zone == .swap {
            guard next.swap(intent.source, intent.target) else { return false }
        } else {
            let targetShare = isScrolling ? width(ofColumn: root.path(of: intent.target)![0]) : columnWidth
            next.remove(intent.source)
            guard var path = next.root.path(of: intent.target) else { return false }
            // Treat an existing tabbed group as one destination allocation.
            if let depth = path.indices.first(where: { next.root.container(at: Array(path.prefix($0))).mode == .tabs }) {
                path = Array(path.prefix(depth))
            }
            if isScrolling, let direction = intent.zone.direction, direction.orientation == .horizontal {
                let column = next.root.path(of: intent.target)![0]
                next.root.insert(.window(intent.source), at: column + (direction.isForward ? 1 : 0))
                next.columnWidths[intent.source] = targetShare
            } else if intent.zone == .tabs, next.isTabContainer(at: path) {
                next.root.modify(at: path) { $0.insert(.window(intent.source), at: $0.children.count) }
            } else {
                let target: Node = path.isEmpty ? .container(next.root) : next.root.node(at: path)
                let direction = intent.zone.direction
                let children: [Node] = direction?.isForward == false ? [.window(intent.source), target] : [target, .window(intent.source)]
                let group = Container(direction.map { ContainerOrientation($0.orientation) } ?? .horizontal,
                                      intent.zone == .tabs ? .tabs : .tiles, children)
                if path.isEmpty { next.root = group }
                else { next.root.modify(at: Array(path.dropLast())) { $0.replace(at: path.last!, with: .container(group)) } }
            }
            next.normalize()
            if isScrolling, let column = next.root.path(of: intent.source)?.first {
                next.setWidth(ofColumn: column, targetShare)
            }
        }
        next.focus(intent.source)
        self = next
        return true
    }

    private func isTabContainer(at path: [Int]) -> Bool {
        if path.isEmpty { return root.mode == .tabs }
        if case .container(let c) = root.node(at: path) { return c.mode == .tabs }
        return false
    }
}
