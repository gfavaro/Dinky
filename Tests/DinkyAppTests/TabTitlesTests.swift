import AppKit
import Testing
@testable import dinky

private final class TitleReads {
    private let lock = NSLock()
    private var reads = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return reads }
    func record() { lock.lock(); defer { lock.unlock() }; reads += 1 }
}

@MainActor
struct TabTitlesTests {
    private func window(id: UInt32 = 1, firstSeen: Date = .distantPast) -> Window {
        Window(identity: .init(id: id, pid: 1, firstSeen: firstSeen), appName: "Test app", bundleID: "test")
    }

    private func load(_ titles: TabTitles, window: Window) async {
        await withCheckedContinuation { continuation in
            titles.changed = { continuation.resume() }
            #expect(titles.title(for: window) == "Test app")
            _ = titles.title(for: window) // Duplicate requests must share the same read.
        }
        titles.changed = nil
    }

    @Test func `Titles deduplicate reads and refresh after invalidation`() async {
        let reads = TitleReads()
        let titles = TabTitles(readTitle: { _ in reads.record(); return "  Document  \n" })
        let window = window()
        titles.keep([window.identity])
        await load(titles, window: window)
        #expect(titles.title(for: window) == "Document")
        #expect(reads.count == 1)
        titles.invalidate(window.id)
        await load(titles, window: window)
        #expect(titles.title(for: window) == "Document")
        #expect(reads.count == 2)
        titles.keep([])
        #expect(titles.title(for: window) == "Test app")
    }

    @Test func `Missing titles are cached and reused IDs have distinct identities`() async {
        let reads = TitleReads()
        let titles = TabTitles(readTitle: { _ in reads.record(); return nil })
        let original = window()
        titles.keep([original.identity])
        await load(titles, window: original)
        #expect(titles.title(for: original) == "Test app")
        #expect(titles.title(for: original) == "Test app")
        #expect(reads.count == 1)
        let replacement = window(firstSeen: .distantFuture)
        titles.keep([replacement.identity])
        #expect(original.identity != replacement.identity)
        await load(titles, window: replacement)
        #expect(titles.title(for: replacement) == "Test app")
        #expect(reads.count == 2)
    }

    @Test func `Invalidation discards a read that was already queued`() async {
        let reads = TitleReads()
        let titles = TabTitles(readTitle: { _ in
            reads.record()
            return reads.count == 1 ? "Old title" : "Current title"
        })
        let window = window()
        titles.keep([window.identity])
        // Both requests are scheduled on the main actor before either result can be applied.
        _ = titles.title(for: window)
        titles.invalidate(window.id)
        await load(titles, window: window)
        #expect(titles.title(for: window) == "Current title")
        #expect(reads.count == 2)
    }

}
