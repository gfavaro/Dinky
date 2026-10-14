import CoreGraphics
import Testing
@testable import DinkyLayout

struct TabGroupTests {
    @Test func `Tab selection changes hit targets without moving members`() {
        var ws = workspace(3, algorithm: .dwindle(.tabs))
        let frames = ws.layout().frames
        #expect(ws.layout().visibleWindows == [3])
        #expect(ws.layout().tabGroups[0].barFrame == rect(0, 0, 1000, 28))
        ws.focus(1)
        #expect(ws.layout().frames == frames)
        #expect(ws.layout().visibleWindows == [1])
        #expect(ws.layout().tabGroups[0].selected == 1)
    }

    @Test func `Returning to tiles restores manual ratios and orientation`() {
        var ws = workspace(3)
        ws.resize(by: 60, along: .vertical)
        let before = ws.root, frames = ws.layout().frames
        ws.setMode(.tabs)
        #expect(ws.layout().tabGroups.count == 1)
        ws.setMode(.tiles)
        #expect(ws.root == before)
        #expect(ws.layout().frames == frames)
    }

    @Test func `Inactive subtrees do not show nested strips`() {
        var ws = workspace(4)
        ws.drop(DropIntent(source: 1, target: 2, zone: .tabs))
        let child = ws.root
        ws.root = Container(.horizontal, .tabs, [.container(child), .window(5)])
        ws.focus(5)
        #expect(ws.layout().tabGroups.count == 1)
        #expect(ws.layout().visibleWindows == [5])
        ws.focus(1)
        #expect(ws.layout().tabGroups.count == 2)
        #expect(ws.layout().visibleWindows.contains(1))
        #expect(!ws.layout().visibleWindows.contains(2))
        #expect(!ws.layout().visibleWindows.contains(5))
    }

    @Test func `Minimums include the tallest member plus one tab bar`() {
        let node = Node.container(Container(.horizontal, .tabs, [.window(1), .window(2)]))
        let sizes = [WindowID(1): CGSize(width: 200, height: 400), 2: CGSize(width: 500, height: 150)]
        #expect(node.minimumExtent(.horizontal, gap: 8, padding: 30, sizes) == 500)
        #expect(node.minimumExtent(.vertical, gap: 8, padding: 30, sizes) == 428)
    }

    @Test func `Resizing a member resizes the group without changing internal ratios`() {
        var ws = workspace(3)
        ws.setMode(.tabs)
        let ratios = ws.container(of: 3)!.ratios
        ws.resize(3, to: CGSize(width: 600, height: 572), moving: [.left])
        #expect(ws.layout().frames[3] == ws.layout().frames[2])
        #expect(ws.layout().frames[3]!.width == 600)
        #expect(ws.container(of: 3)!.ratios == ratios)
    }

    @Test func `Native app tab replacement retains its Dinky tab allocation`() {
        var ws = workspace(3, algorithm: .dwindle(.tabs))
        ws.focus(2)
        let frames = ws.layout().frames
        ws.replace(2, with: 20)
        #expect(ws.focused == 20)
        #expect(ws.layout().frames[20] == frames[2])
        #expect(ws.layout().tabGroups[0].selected == 20)
        #expect(ws.layout().tabGroups[0].tabs == [1, 20, 3])
    }

    @Test func `Closing the active member chooses a survivor and collapses the last group`() {
        var ws = workspace(3, algorithm: .dwindle(.tabs))
        ws.remove(3)
        #expect(ws.focused == 2)
        #expect(ws.layout().visibleWindows == [2])
        ws.remove(2)
        #expect(ws.layout().tabGroups.isEmpty)
        #expect(ws.layout().frames[1] == ws.bounds)
    }

    @Test func `Fullscreen hides tab strips and restores them on exit`() {
        var ws = workspace(2, algorithm: .dwindle(.tabs))
        ws.toggleFullscreen()
        #expect(ws.layout().tabGroups.isEmpty)
        #expect(ws.layout().visibleWindows == [2])
        ws.toggleFullscreen()
        #expect(ws.layout().tabGroups.count == 1)
    }

    @Test func `Parked scrolling windows never become drag destinations`() {
        var ws = workspace(8, algorithm: .scrolling)
        ws.walls = [.left, .right]
        ws.focus(8)
        let layout = ws.layout()
        for id in ws.windows where !ws.isInView(id) {
            #expect(!layout.visibleWindows.contains(id))
        }
        #expect(layout.visibleWindows.contains(8))
    }

    @Test func `One border encloses the strip and selected window`() {
        var ws = workspace(3, algorithm: .dwindle(.tabs))
        #expect(ws.layout().tabBorderFrames == [3: ws.bounds])
        #expect(ws.layout().suppressedTabBorders == [1, 2])
        ws.focus(1)
        #expect(ws.layout().tabBorderFrames == [1: ws.bounds])
        #expect(ws.layout().suppressedTabBorders == [2, 3])
        ws.remove(2)
        ws.remove(3)
        #expect(ws.layout().tabBorderFrames.isEmpty)
        #expect(ws.layout().suppressedTabBorders.isEmpty)
    }

    @Test func `Nested tabs do not draw a second outline inside the outer group`() {
        var ws = workspace(3)
        ws.setMode(.tabs)
        let child = ws.root
        ws.root = Container(.horizontal, .tabs, [.container(child), .window(4)])
        ws.focus(3)
        #expect(ws.layout().tabGroups.count == 2)
        #expect(ws.layout().tabBorderFrames == [3: ws.bounds])
        #expect(ws.layout().suppressedTabBorders == [1, 2, 4])
        ws.toggleFullscreen()
        #expect(ws.layout().tabBorderFrames.isEmpty)
    }

    @Test func `Legacy accordion spelling is an alias for tabs`() {
        #expect(LayoutMode.accordion == .tabs)
        #expect(FixedExpansion.accordion == .tabs)
        var ws = workspace(2, algorithm: .dwindle(.accordion), padding: 90)
        #expect(ws.layout().frames[1] == rect(0, 28, 1000, 572))
        ws.accordionPadding = 5
        #expect(ws.layout().frames[1] == rect(0, 28, 1000, 572))
    }
}
