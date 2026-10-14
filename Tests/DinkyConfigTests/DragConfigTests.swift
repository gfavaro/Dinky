import Testing
import DinkyConfig

struct DragConfigTests {
    @Test func `Drop targets are opt-in and independent of placeholders`() throws {
        #expect(!Config.default.drag.dropTargets)
        let config = try Config.parse("[drag]\ndrop-targets = true\nplaceholders = false\n")
        #expect(config.drag.dropTargets)
        #expect(!config.drag.placeholders)
    }

    @Test func `Tabs can be selected for workspaces and fixed overflow`() throws {
        let config = try Config.parse("default-layout = 'tabs'\n[workspace.2]\nlayout = 'fixed'\nexpand = 'tabs'\n")
        #expect(config.defaultLayout == .tabs)
        #expect(config.settings(forWorkspace: 2).expand == .tabs)
    }

    @Test func `Legacy accordion options still parse`() throws {
        let config = try Config.parse("default-layout = 'accordion'\n[accordion]\npadding = 40\norientation = 'auto'\n[focus-follows-mouse]\naccordion-edges = false\n")
        #expect(config.defaultLayout == .accordion)
        #expect(config.accordion.padding == 40)
    }
}
