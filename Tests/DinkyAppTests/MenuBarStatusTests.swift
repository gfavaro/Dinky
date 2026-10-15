import DinkyConfig
import Testing
@testable import dinky

struct MenuBarStatusTests {
    @Test func `Main stays compact and other modes use their first uppercase character`() {
        #expect(MenuBarStatus(workspace: 3, mode: "main", warning: false, enabled: true).title == "3")
        #expect(MenuBarStatus(workspace: 3, mode: "service", warning: false, enabled: true).title == "(S) 3")
        #expect(MenuBarStatus(workspace: 12, mode: "resize", warning: false, enabled: true).title == "(R) 12")
        #expect(MenuBarStatus(workspace: 3, mode: "écran", warning: false, enabled: true).title == "(É) 3")
        #expect(MenuBarStatus(workspace: 3, mode: "👩‍💻work", warning: false, enabled: true).title == "(👩‍💻) 3")
    }

    @Test func `Unknown spaces warnings and disabled state retain their meaning`() {
        let label = MenuBarStatus(workspace: nil, mode: "service", warning: true, enabled: false)
        #expect(label.title == "(S) ?!")
        #expect(label.description.contains("mode service"))
        #expect(label.description.contains("disabled"))
        #expect(label.description.contains("warning"))
        #expect(MenuBarStatus(workspace: 3, mode: "main", warning: true, enabled: true).title == "3!")
    }

    @Test func `Full names distinguish modes with the same initial`() {
        let service = MenuBarStatus(workspace: 3, mode: "service", warning: false, enabled: true)
        let select = MenuBarStatus(workspace: 3, mode: "select", warning: false, enabled: true)
        #expect(service.title == select.title)
        #expect(service.description != select.description)
    }

    @Test func `Hooks and label observers share one change event without duplicates`() {
        let engine = HotkeyEngine(onCommands: { _ in })
        engine.load(modes: Config.default.modes, sides: ModifierSides())
        var hooks: [String] = [], labels: [String] = []
        engine.observeModeChange { mode, previous in hooks.append("\(previous)>\(mode)") }
        engine.observeModeChange { mode, previous in labels.append("\(previous)>\(mode)") }
        engine.setMode("service")
        engine.setMode("service")
        engine.setMode("missing")
        #expect(engine.currentMode == "service")
        engine.load(modes: Config.default.modes, sides: ModifierSides())
        #expect(engine.currentMode == "main")
        #expect(hooks == ["main>service", "service>main"])
        #expect(labels == hooks)
    }
}
