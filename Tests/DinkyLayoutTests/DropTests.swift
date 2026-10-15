import CoreGraphics
import Testing
@testable import DinkyLayout

struct DropTests {
    private func group(of id: WindowID, in ws: Workspace) -> Container? {
        guard let path = ws.root.path(of: id), let depth = path.indices.first(where: {
            ws.root.container(at: Array(path.prefix($0))).mode == .accordion
        }) else { return nil }
        return ws.root.container(at: Array(path.prefix(depth)))
    }

    @Test(arguments: DropZone.allCases)
    func `Each zone resolves at its center`(_ zone: DropZone) {
        let frame = rect(-1200, -400, 900, 600)
        let target = DropZones.frames(in: frame).first { $0.zone == zone }!.frame
        let intent = DropZones.resolve(source: 1, target: 2, pointer: CGPoint(x: target.midX, y: target.midY), frame: frame)
        #expect(intent == DropIntent(source: 1, target: 2, zone: zone))
    }

    @Test func `Zones cover the destination exactly once away from boundaries`() {
        let frame = rect(30, 50, 300, 240)
        let zones = DropZones.frames(in: frame)
        #expect(zones.reduce(CGFloat(0)) { $0 + $1.frame.width * $1.frame.height } == frame.width * frame.height)
        for x in stride(from: 31, to: 330, by: 7) {
            for y in stride(from: 51, to: 290, by: 7) {
                #expect(DropZones.resolve(source: 1, target: 2, pointer: CGPoint(x: x, y: y), frame: frame) != nil)
            }
        }
        #expect(DropZones.resolve(source: 1, target: 1, pointer: CGPoint(x: 50, y: 60), frame: frame) == nil)
        #expect(DropZones.resolve(source: 1, target: 2, pointer: .zero, frame: frame) == nil)
        #expect(DropZones.frames(in: .zero).isEmpty)
    }

    @Test(arguments: DropZone.allCases)
    func `Dwindle drops keep every window exactly once`(_ zone: DropZone) {
        var ws = workspace(5)
        #expect(ws.drop(DropIntent(source: 1, target: 5, zone: zone)) == true)
        #expect(ws.windows.count == 5)
        #expect(Set(ws.windows) == Set(1...5))
        #expect(ws.focused == 1)
        #expect(ws.layout().frames.count == 5)
        if zone == .accordion {
            #expect(ws.layout().frames[1] != ws.layout().frames[5])
            #expect(group(of: 1, in: ws)?.mode == .accordion)
        }
    }

    @Test(arguments: [DropZone.left, .right, .above, .below])
    func `Directional drops split the destination allocation equally`(_ zone: DropZone) {
        var ws = workspace(2, gaps: Gaps(all: 8))
        #expect(ws.drop(DropIntent(source: 1, target: 2, zone: zone)) == true)
        let frames = ws.layout().frames, source = frames[1]!, target = frames[2]!
        if zone == .left || zone == .right {
            #expect(source.width == target.width)
            #expect((source.minX < target.minX) == (zone == .left))
        } else {
            #expect(source.height == target.height)
            #expect((source.minY < target.minY) == (zone == .above))
        }
    }

    @Test(arguments: DropZone.allCases)
    func `Fixed drops preserve reserved cells and later insertion`(_ zone: DropZone) {
        var ws = workspace(4, algorithm: .fixed(rows: 2, columns: 2, expand: .columns))
        let untouched = ws.layout().frames[3]
        #expect(ws.drop(DropIntent(source: 1, target: 4, zone: zone)) == true)
        #expect(ws.isFixedTree)
        #expect(ws.root.children.count == 2)
        #expect(ws.root.container(at: [0]).children.count == 2)
        #expect(ws.layout().frames[3] == untouched)
        ws.insert(5)
        #expect(ws.isFixedTree)
        #expect(Set(ws.windows) == Set(1...5))
        if zone != .swap {
            #expect(ws.root.node(at: [0, 0]) == .window(5))
            #expect(Set(ws.root.node(at: [1, 1]).windows) == [1, 4])
        }
    }

    @Test(arguments: DropZone.allCases)
    func `Scrolling drops preserve destination widths`(_ zone: DropZone) {
        var ws = workspace(3, algorithm: .scrolling)
        ws.setWidth(ofColumn: 0, 0.25)
        ws.setWidth(ofColumn: 1, 0.65)
        #expect(ws.drop(DropIntent(source: 1, target: 2, zone: zone)) == true)
        let column = ws.root.path(of: 1)!.first!
        #expect(abs(ws.width(ofColumn: column) - 0.65) < 1e-9)
        #expect(ws.columnWidths[1] == 0.65)
        #expect(Set(ws.windows) == [1, 2, 3])
        if zone == .accordion || zone == .above || zone == .below {
            #expect(ws.root.path(of: 1)![0] == ws.root.path(of: 2)![0])
        }
    }

    @Test func `Invalid and fullscreen drops leave the entire workspace unchanged`() {
        var ws = workspace(3)
        let before = ws
        #expect(ws.drop(DropIntent(source: 1, target: 99, zone: .accordion)) == false)
        #expect(ws.drop(DropIntent(source: 99, target: 1, zone: .left)) == false)
        #expect(ws.drop(DropIntent(source: 1, target: 1, zone: .accordion)) == false)
        #expect(ws == before)
        ws.toggleFullscreen()
        let fullscreen = ws
        #expect(ws.drop(DropIntent(source: 1, target: 2, zone: .swap)) == false)
        #expect(ws == fullscreen)
    }

    @Test func `Existing accordion join without losing width when old members close`() {
        var ws = workspace(3, algorithm: .scrolling)
        ws.setWidth(ofColumn: 1, 0.7)
        #expect(ws.drop(DropIntent(source: 1, target: 2, zone: .accordion)) == true)
        #expect(ws.drop(DropIntent(source: 3, target: 2, zone: .accordion)) == true)
        #expect(Set(group(of: 3, in: ws)!.children.flatMap(\.windows)) == [1, 2, 3])
        ws.remove(2)
        ws.remove(1)
        #expect(ws.columnWidths[3] == 0.7)
        #expect(group(of: 3, in: ws) == nil)
    }

    @Test func `Dropping within the same accordion group preserves manual ratios`() {
        var ws = workspace(3)
        ws.setMode(.accordion)
        let before = ws.root
        #expect(ws.drop(DropIntent(source: 3, target: 2, zone: .accordion)) == true)
        #expect(ws.root == before)
    }

    @Test(arguments: [DropZone.left, .right, .above, .below])
    func `Dragging an accordion member out splits beside its remaining group`(_ zone: DropZone) {
        var ws = workspace(3, algorithm: .dwindle(.accordion))
        #expect(ws.drop(DropIntent(source: 3, target: 1, zone: zone)) == true)
        #expect(Set(group(of: 1, in: ws)!.children.flatMap(\.windows)) == [1, 2])
        #expect(!ws.layout().frames[3]!.intersects(ws.layout().frames[1]!))
    }

    @Test func `Drop out of accordion collapses the old group`() {
        var ws = workspace(3)
        #expect(ws.drop(DropIntent(source: 1, target: 2, zone: .accordion)) == true)
        #expect(ws.drop(DropIntent(source: 1, target: 3, zone: .left)) == true)
        #expect(group(of: 3, in: ws) == nil)
        #expect(Set(ws.windows) == [1, 2, 3])
    }

    @Test func `Directional drop treats an accordion group as one tile`() {
        var ws = workspace(3)
        #expect(ws.drop(DropIntent(source: 1, target: 2, zone: .accordion)) == true)
        #expect(ws.drop(DropIntent(source: 3, target: 2, zone: .above)) == true)
        #expect(ws.layout().frames[1] != ws.layout().frames[2])
        #expect(ws.layout().frames[3]!.maxY <= min(ws.layout().frames[1]!.minY, ws.layout().frames[2]!.minY))
    }

    @Test func `Fixed nested splits survive removal without losing reserved holes`() {
        var ws = workspace(4, algorithm: .fixed(rows: 2, columns: 2, expand: .accordion))
        ws.drop(DropIntent(source: 1, target: 4, zone: .above))
        ws.drop(DropIntent(source: 2, target: 4, zone: .accordion))
        ws.remove(4)
        #expect(ws.isFixedTree)
        #expect(Set(ws.windows) == [1, 2, 3])
        ws.remove(2)
        #expect(ws.isFixedTree)
        ws.remove(1)
        #expect(ws.root.node(at: [1, 1]).windows.isEmpty)
        ws.insert(5)
        #expect(ws.root.node(at: [0, 0]) == .window(5))
    }

    @Test func `Swap keeps manual frames and ratios`() {
        var ws = workspace(3)
        ws.focus(1)
        ws.resize(by: 100, along: .horizontal)
        let before = ws.layout().frames, ratios = ws.root.ratios
        ws.drop(DropIntent(source: 1, target: 3, zone: .swap))
        #expect(ws.layout().frames[3] == before[1])
        #expect(ws.layout().frames[1] == before[3])
        #expect(ws.root.ratios == ratios)
    }

    @Test func `Repeated cross-layout drops keep ratios finite and identities unique`() {
        for algorithm in [TilingAlgorithm.dwindle(.tiles), .fixed(rows: 2, columns: 3, expand: .accordion), .scrolling] {
            var ws = workspace(6, algorithm: algorithm)
            for step in 0..<240 {
                let source = WindowID(step % 6 + 1), target = WindowID((step + 2) % 6 + 1)
                #expect(ws.drop(DropIntent(source: source, target: target, zone: DropZone.allCases[step % 6])) == true)
                #expect(ws.windows.count == 6)
                #expect(Set(ws.windows) == Set(1...6))
                #expect(ws.layout().frames.values.allSatisfy { $0.width.isFinite && $0.height.isFinite && $0.width >= 0 && $0.height >= 0 })
            }
        }
    }
    @Test func `Accordion drop previews cover the group including peeking edges`() {
        var ws = workspace(3)
        ws.drop(DropIntent(source: 1, target: 2, zone: .accordion))
        let layout = ws.layout()
        let first = ws.dropFrame(for: 1, in: layout), second = ws.dropFrame(for: 2, in: layout)
        #expect(first == second)
        #expect(first!.contains(layout.frames[1]!))
        #expect(first!.contains(layout.frames[2]!))
        #expect(ws.dropFrame(for: 3, in: layout) == layout.frames[3])
        #expect(ws.dropFrame(for: 99, in: layout) == nil)
    }

}
