import CoreGraphics
import Testing
@testable import DinkyLayout

struct TabGestureTests {
    func gesture() -> TabGesture {
        TabGesture(source: 2, members: [1, 2, 3], start: CGPoint(x: 250, y: -100),
                   strip: CGRect(x: -200, y: -114, width: 900, height: 28), count: 3)
    }

    @Test func `Small movements remain a click`() {
        var gesture = gesture()
        let action = gesture.update(at: CGPoint(x: 252, y: -99))
        #expect(action == nil)
        let finish = gesture.finish(at: CGPoint(x: 252, y: -99))
        #expect(finish == .click)
    }

    @Test func `Horizontal dragging reorders and clamps to the strip`() {
        var gesture = gesture()
        let last = gesture.update(at: CGPoint(x: 650, y: -100))
        #expect(last == .reorder(2))
        let first = gesture.update(at: CGPoint(x: -1000, y: -100))
        #expect(first == .reorder(0))
        #expect(!gesture.detached)
    }

    @Test(arguments: [CGFloat(-19), 19])
    func `Leaving the strip detaches in either vertical direction`(_ dy: CGFloat) {
        var gesture = gesture()
        let action = gesture.update(at: CGPoint(x: 250, y: -100 + dy))
        #expect(action == .detach)
        #expect(gesture.detached)
        let returned = gesture.finish(at: CGPoint(x: 250, y: -100))
        #expect(returned == .detach)
    }

    @Test func `The escape threshold does not detach early`() {
        var gesture = gesture()
        let action = gesture.update(at: CGPoint(x: 450, y: -82))
        #expect(action == .reorder(2))
        #expect(!gesture.detached)
    }

    @Test func `Tab reorder carries saved ratios and selects the dragged member`() {
        var ws = workspace(3)
        ws.resize(by: 80, along: .vertical)
        ws.setMode(.tabs)
        let before = ws.container(of: 3)!.ratios
        let members = [WindowID(2), 3]
        let changed = ws.reorderTab(3, to: 0, members: members)
        #expect(changed)
        #expect(ws.layout().tabGroups[0].tabs == [3, 2])
        #expect(ws.container(of: 3)!.ratios == [before[1], before[0]])
        #expect(ws.focused == 3)
        ws.setMode(.tiles)
        #expect(ws.layout().frames[3]!.height > ws.layout().frames[2]!.height)
    }

    @Test func `Stale membership and bad indexes do not change the layout`() {
        var ws = workspace(3, algorithm: .dwindle(.tabs))
        let before = ws
        let stale = ws.reorderTab(3, to: 0, members: [1, 3])
        let badIndex = ws.reorderTab(3, to: 9, members: [1, 2, 3])
        #expect(!stale)
        #expect(!badIndex)
        #expect(ws == before)
    }

    @Test func `Fixed cells and scrolling widths survive tab reorder`() {
        for algorithm in [TilingAlgorithm.fixed(rows: 1, columns: 1, expand: .tabs), .scrolling] {
            var ws = workspace(3, algorithm: algorithm)
            if ws.isScrolling {
                ws.drop(DropIntent(source: 1, target: 2, zone: .tabs))
                ws.drop(DropIntent(source: 3, target: 2, zone: .tabs))
                ws.setWidth(ofColumn: 0, 0.7)
            }
            let widths = ws.columnWidths
            let changed = ws.reorderTab(3, to: 0, members: [1, 2, 3])
            #expect(changed)
            #expect(ws.columnWidths == widths)
            if case .fixed = algorithm { #expect(ws.isFixedTree) }
        }
    }
}

struct VariableTabGestureTests {
    @Test func `Reorder uses the visible variable-width tab allocations`() {
        var gesture = TabGesture(source: 2, members: [1, 2, 3], start: CGPoint(x: 90, y: 14),
                                 strip: CGRect(x: 0, y: 0, width: 600, height: 28), count: 3)
        let frames = [CGRect(x: -50, y: 0, width: 120, height: 28),
                      CGRect(x: 70, y: 0, width: 300, height: 28),
                      CGRect(x: 370, y: 0, width: 180, height: 28)]
        #expect(gesture.update(at: CGPoint(x: 360, y: 14), tabFrames: frames) == .reorder(1))
        #expect(gesture.finish(at: CGPoint(x: 390, y: 14), tabFrames: frames) == .reorder(2))
    }
}
