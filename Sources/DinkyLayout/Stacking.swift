import CoreGraphics

extension Layout {
    /// Windows to raise, back to front, so overlapping windows (accordion, fullscreen) stack as `order` says
    /// wherever that shows. `current` is the on-screen order, front to back. Empty when it already agrees;
    /// plain tiles never overlap.
    ///
    /// Each raise briefly puts that window on top, and makes it its app's key window, before the ones meant to
    /// be in front of it are raised again: a visible flash. So raising is kept to the fewest windows from the
    /// front, only the order of two windows whose overlap shows somewhere counts (where windows above both
    /// cover it, either may be on top), and once the front window is on top nothing is raised just to fix
    /// which background window peeks out at an edge. A focus change puts the new front window on top, so
    /// switching windows in an accordion normally raises nothing.
    public func raises(current: [WindowID]) -> [WindowID] {
        let stack = order.filter { id in
            frames.contains { other, rect in other != id && !rect.intersection(frames[id]!).isEmpty }
        }
        if let front = stack.first, current.first(where: stack.contains) == front { return [] }
        let position = Dictionary(current.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        // Raising the first `n` of the stack, back to front, puts them on top in order; the rest keep their
        // current order, which must already be right. With n = stack.count there is no rest, so one n fits.
        let n = (0...stack.count).first { n in
            let rest = n..<stack.count
            return rest.allSatisfy { i in
                rest.allSatisfy { j in
                    guard i < j, showsOrder(stack, i, j) else { return true }
                    guard let above = position[stack[i]], let below = position[stack[j]] else { return false }
                    return above < below
                }
            }
        }!
        return Array(stack.prefix(n).reversed())
    }

    /// Whether it shows which of `stack[i]` and `stack[j]` (i < j) is on top: part of their overlap is not
    /// covered by the windows meant to be above both.
    private func showsOrder(_ stack: [WindowID], _ i: Int, _ j: Int) -> Bool {
        let shared = frames[stack[i]]!.intersection(frames[stack[j]]!)
        guard !shared.isEmpty else { return false }
        let above = stack[..<i].map { frames[$0]! }
        return !above.reduce([shared]) { rest, cover in rest.flatMap { $0.subtracting(cover) } }.isEmpty
    }
}

extension CGRect {
    /// The parts of this rect outside `other`, as up to four rects.
    func subtracting(_ other: CGRect) -> [CGRect] {
        let cut = intersection(other)
        guard !cut.isEmpty else { return [self] }
        var parts: [CGRect] = []
        if cut.minY > minY { parts.append(CGRect(x: minX, y: minY, width: width, height: cut.minY - minY)) }
        if cut.maxY < maxY { parts.append(CGRect(x: minX, y: cut.maxY, width: width, height: maxY - cut.maxY)) }
        if cut.minX > minX { parts.append(CGRect(x: minX, y: cut.minY, width: cut.minX - minX, height: cut.height)) }
        if cut.maxX < maxX { parts.append(CGRect(x: cut.maxX, y: cut.minY, width: maxX - cut.maxX, height: cut.height)) }
        return parts
    }
}
