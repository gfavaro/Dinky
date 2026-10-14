import AppKit
import Testing
@testable import dinky

struct WindowKindTests {
    @Test func `Document eligibility survives visibility changes`() {
        var window = Window(identity: .init(id: 1, pid: 1, firstSeen: .distantPast), appName: "Test", bundleID: "test")
        window.isDocument = true
        window.isOrderedIn = true
        window.isVisible = true
        #expect(window.isNormal)
        window.isOrderedIn = false
        #expect(window.isTileableKind)
        #expect(!window.isNormal)
        window.isVisible = false
        #expect(window.isTileableKind)
        window.isDocument = false
        #expect(!window.isTileableKind)
        window.isDocument = true
        window.level = 3
        #expect(!window.isTileableKind)
    }
}

@MainActor
struct WindowTrackingTests {
    @Test func `An ineligible tracked window releases classification state`() {
        let coordinator = Coordinator(displays: DisplayModel(), config: .default)
        let id: UInt32 = 1
        coordinator.placements[id] = Placement(floating: false, space: nil)
        coordinator.attempts[id] = 2
        coordinator.adopting.insert(id)
        coordinator.adoptTargets[id] = "test display"
        coordinator.notTabs.insert(id)
        let panel = Window(identity: .init(id: id, pid: 1, firstSeen: .distantPast), appName: "Test", bundleID: "test")
        coordinator.track(panel)
        #expect(coordinator.placements[id] == nil)
        #expect(coordinator.attempts[id] == nil)
        #expect(!coordinator.adopting.contains(id))
        #expect(coordinator.adoptTargets[id] == nil)
        #expect(!coordinator.notTabs.contains(id))
    }

    @Test func `A hidden document retains its classification`() {
        let coordinator = Coordinator(displays: DisplayModel(), config: .default)
        var window = Window(identity: .init(id: 1, pid: 1, firstSeen: .distantPast), appName: "Test", bundleID: "test")
        window.isDocument = true
        coordinator.placements[window.id] = Placement(floating: false, space: nil)
        coordinator.track(window)
        #expect(coordinator.placements[window.id] != nil)
    }
}
