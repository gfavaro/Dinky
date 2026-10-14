import CoreGraphics
import Testing
@testable import DinkyLayout

/// `auto` orientation, `setOrientation` and tabs preserving orientation.
struct OrientationTests {
    /// h[1 v[2 3]] in 1000x600: the column on the right is 500x600, taller than wide. 3 is focused.
    func column(autoOrientAccordions: Bool = true) -> Workspace {
        var ws = workspace(3)
        ws.autoOrientAccordions = autoOrientAccordions
        return ws
    }

    @Test func `Auto resolves along the longer side`() {
        let c = Container(.auto)
        #expect(c.axis(in: rect(0, 0, 800, 600)) == .horizontal)
        #expect(c.axis(in: rect(0, 0, 600, 800)) == .vertical)
        #expect(c.axis(in: rect(0, 0, 600, 600)) == .horizontal)
    }

    @Test func `Auto tiles follow the workspace shape`() {
        var ws = workspace(2)
        ws.setOrientation(.auto)
        #expect(shape(ws.root) == "*[1 2]")
        #expect(ws.layout().frames[2] == rect(500, 0, 500, 600))
        ws.bounds = rect(0, 0, 600, 1000)
        #expect(ws.layout().frames[2] == rect(0, 500, 600, 500))
        #expect(ws.containerAxis(of: 2) == .vertical)
    }

    @Test func `Legacy auto orientation does not rotate tab groups`() {
        let tall = rect(0, 0, 600, 1000)
        var ws = Workspace(bounds: tall, autoOrientAccordions: true, algorithm: .dwindle(.tabs))
        ws.insert(1)
        ws.insert(2)
        #expect(shape(ws.root) == "th[1 2]")
        #expect(ws.containerAxis(of: 2) == .horizontal)
        #expect(ws.layout().frames[2] == rect(0, 28, 600, 972))
        var kept = Workspace(bounds: tall, autoOrientAccordions: false, algorithm: .dwindle(.tabs))
        kept.insert(1)
        #expect(shape(kept.root) == "th[1]", "without auto orientation the root stays horizontal")
        #expect(shape(Workspace(bounds: tall, autoOrientAccordions: true).root) == "h[]", "tiles are unchanged")
    }

    @Test func `Tabs preserve a tall columns orientation`() {
        var ws = column()
        ws.setMode(.tabs)
        #expect(shape(ws.root) == "h[1 tv[2 3]]")
        #expect(ws.layout().frames[2] == rect(500, 28, 500, 572))
        #expect(ws.layout().frames[3] == rect(500, 28, 500, 572))
    }

    @Test func `Resizing tabs preserves the containers orientation`() {
        var ws = column()
        ws.setMode(.tabs)
        #expect(ws.resize(by: 200) == true)
        #expect(ws.containerAxis(of: 3) == .vertical)
        #expect(ws.layout().frames[3] == rect(300, 28, 700, 572))
    }

    @Test func `Auto follows the laid out rect when a minimum holds the column back`() {
        var ws = column()
        ws.setMode(.tabs)
        ws.minimumSizes = [1: CGSize(width: 450, height: 0)]
        #expect(ws.resize(by: 200) == true)
        #expect(ws.containerAxis(of: 3) == .vertical)
        #expect(ws.layout().frames[3] == rect(450, 28, 550, 572))
    }

    /// h[1 *[2 3]] with 1 held at 450: the column is laid out 550x600, though its ratio alone would make it 700x600.
    @Test func `Every command sees a held back auto column as vertical`() {
        var ws = column()
        #expect(ws.resize(by: 200, along: .horizontal) == true)
        ws.setOrientation(.auto)
        ws.minimumSizes = [1: CGSize(width: 450, height: 0)]
        #expect(shape(ws.root) == "h[1 *[2 3]]")
        #expect(ws.containerAxis(of: 3) == .vertical)
        #expect(ws.edgeWindow(.up) == 2)
        #expect(ws.resize(by: 50, along: .vertical) == true)
        #expect(ws.layout().frames[3] == rect(450, 250, 550, 350))
        ws.insert(4)
        #expect(shape(ws.root) == "h[1 *[2 h[3 4]]]", "3 is 550x350, so it splits side by side")
    }

    @Test func `Explicit orientation is not changed by layout`() {
        var ws = column(autoOrientAccordions: false)
        ws.setMode(.tabs)
        #expect(shape(ws.root) == "h[1 tv[2 3]]")
        ws.resize(by: 200)
        #expect(ws.containerAxis(of: 3) == .vertical)
        #expect(ws.layout().frames[3] == rect(300, 28, 700, 572))
    }

    @Test func `An orientation chosen by command survives the switch to tabs`() {
        var ws = column()
        ws.setOrientation(.vertical)
        ws.setMode(.tabs)
        #expect(shape(ws.root) == "h[1 tv[2 3]]")
    }

    @Test func `Mode and orientation together do not merge halfway`() {
        var ws = column()
        ws.setLayout(.tabs, .horizontal)
        #expect(shape(ws.root) == "h[1 th[2 3]]")
    }

    @Test func `Setting the parents orientation merges into it`() {
        var ws = column()
        ws.setOrientation(.horizontal)
        #expect(shape(ws.root) == "h[1 2 3]")
    }

    @Test func `Neighbours follow the resolved axis`() {
        var ws = column()
        ws.setOrientation(.auto)
        ws.focus(2)
        #expect(ws.neighbor(of: 2, .down) == 3)
        #expect(ws.resize(by: 200, along: .horizontal) == true)
        #expect(ws.neighbor(of: 2, .right) == 3)
        #expect(ws.neighbor(of: 2, .down) == nil)
    }
}
