import Foundation

/// Counts the pages the system ended, so a page that cannot stay up ends in the
/// error view with its Retry and not in a reload that never stops.
///
/// Two pages ended inside `window` are replaced; a third is not.
struct SeatLayerPickerPageRecovery: Sendable {
    static let window: TimeInterval = 60
    static let limit = 2

    private var recent: [TimeInterval] = []

    /// Answers whether this loss may be answered with a reload.
    mutating func lost(at now: TimeInterval) -> Bool {
        recent = recent.filter { now - $0 < Self.window }
        recent.append(now)
        return recent.count <= Self.limit
    }

    mutating func reset() {
        recent.removeAll(keepingCapacity: false)
    }
}
