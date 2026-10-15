import AppKit
import Testing
@testable import dinky

@Suite(.serialized)
@MainActor
struct DisplayAreaTests {
    private func display(area: CGRect) -> Display {
        Display(uuid: "test-display", id: 1, frame: CGRect(x: 0, y: 0, width: 1710, height: 1112),
                visibleArea: area, isMain: true, spaces: [3], userSpaces: [3], currentSpaceID: 3)
    }

    @Test func `Dock changes publish new usable bounds without a display or Space change`() {
        let dockShown = CGRect(x: 0, y: 38, width: 1631, height: 1074)
        let dockHidden = CGRect(x: 0, y: 38, width: 1710, height: 1074)
        var fresh = [display(area: dockShown)]
        let model = DisplayModel(read: { fresh })
        model.reconcile()
        var changes: [CGRect] = []
        model.observe { changes.append($0.displays[0].visibleArea) }
        fresh = [display(area: dockHidden)]
        model.reconcile()
        model.reconcile()
        fresh = [display(area: dockShown)]
        model.reconcile()
        #expect(changes == [dockHidden, dockShown])
        #expect(model.displays[0].currentSpaceID == 3)
    }

    @Test func `Dock sides and menu bar bounds convert without losing their offsets`() {
        #expect(usableDisplayFrame(CGRect(x: 0, y: 0, width: 1631, height: 1074), primaryHeight: 1112)
                == CGRect(x: 0, y: 38, width: 1631, height: 1074))
        #expect(usableDisplayFrame(CGRect(x: 79, y: 0, width: 1631, height: 1074), primaryHeight: 1112)
                == CGRect(x: 79, y: 38, width: 1631, height: 1074))
        #expect(usableDisplayFrame(CGRect(x: 0, y: 79, width: 1710, height: 995), primaryHeight: 1112)
                == CGRect(x: 0, y: 38, width: 1710, height: 995))
        #expect(usableDisplayFrame(CGRect(x: -908, y: 1112, width: 3440, height: 1440), primaryHeight: 1112)
                == CGRect(x: -908, y: -1440, width: 3440, height: 1440))
    }
}
