import CoreGraphics

/// Readable tab widths without changing the height of a crowded strip.
public enum TabStripSizing {
    public static let minimumWidth: CGFloat = 112
    public static let maximumWidth: CGFloat = 320

    public static func widths(preferred: [CGFloat], available: CGFloat) -> [CGFloat] {
        guard !preferred.isEmpty else { return [] }
        let desired = preferred.map { min(maximumWidth, max(minimumWidth, $0)) }
        let minimum = minimumWidth * CGFloat(desired.count)
        if available <= minimum { return Array(repeating: minimumWidth, count: desired.count) }
        let extra = available - minimum
        let demand = desired.map { $0 - minimumWidth }
        let total = demand.reduce(0, +)
        if extra < total {
            return demand.map { minimumWidth + extra * $0 / total }
        }
        var result = desired
        var remainder = available - desired.reduce(0, +)
        while remainder > 0.5 {
            let growing = result.indices.filter { result[$0] < maximumWidth }
            guard !growing.isEmpty else { break }
            let share = remainder / CGFloat(growing.count)
            var used: CGFloat = 0
            for i in growing {
                let add = min(share, maximumWidth - result[i])
                result[i] += add
                used += add
            }
            remainder -= used
        }
        return result
    }
}
