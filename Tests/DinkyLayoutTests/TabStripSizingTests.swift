import CoreGraphics
import Testing
@testable import DinkyLayout

struct TabStripSizingTests {
    @Test func `Long titles receive more room than short titles`() {
        let widths = TabStripSizing.widths(preferred: [120, 300], available: 420)
        #expect(widths[1] > widths[0])
        #expect(abs(widths.reduce(0, +) - 420) < 0.01)
    }

    @Test func `A wide display does not stretch two tabs indefinitely`() {
        #expect(TabStripSizing.widths(preferred: [120, 200], available: 3400) == [320, 320])
    }

    @Test func `Crowded strips keep a readable minimum and scroll instead`() {
        #expect(TabStripSizing.widths(preferred: Array(repeating: 300, count: 20), available: 800) == Array(repeating: 112, count: 20))
    }

    @Test(arguments: [CGFloat(0), 240, 450, 900, 3400])
    func `Widths remain bounded and use the available space when possible`(_ available: CGFloat) {
        let widths = TabStripSizing.widths(preferred: [0, 180, 500], available: available)
        #expect(widths.allSatisfy { $0 >= 112 && $0 <= 320 })
        let sum = widths.reduce(0, +)
        #expect(abs(sum - min(960, max(336, available))) < 0.5)
        #expect(TabStripSizing.widths(preferred: [], available: available).isEmpty)
    }
}
