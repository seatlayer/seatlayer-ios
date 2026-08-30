import Foundation

/// How long an unused renderer host remains transferable by default.
public let seatLayerPickerPrewarmDefaultTTL: TimeInterval = 30

public enum SeatLayerPickerPrewarmStatus: String, Sendable, Equatable, CaseIterable {
    case idle
    case loading
    case ready
}

/// Pure ownership ledger used by the UIKit pool. It deliberately stores only
/// the immutable page URL and lifecycle metadata—never event configuration,
/// buyer access, selection, or hold state.
struct SeatLayerPickerPrewarmLedger: Sendable, Equatable {
    struct Entry: Sendable, Equatable {
        let generation: Int
        let pageURL: URL
        let expiresAt: TimeInterval
    }

    enum StartDecision: Sendable, Equatable {
        case reuse(generation: Int)
        case replace(previousGeneration: Int?, entry: Entry)
    }

    private(set) var entry: Entry?
    private var nextGeneration = 1

    mutating func start(
        pageURL: URL,
        now: TimeInterval,
        ttl: TimeInterval
    ) -> StartDecision {
        let previous = expire(now: now)
        if let entry, entry.pageURL == pageURL {
            return .reuse(generation: entry.generation)
        }
        let replacement = Entry(
            generation: nextGeneration,
            pageURL: pageURL,
            expiresAt: now + ttl
        )
        nextGeneration += 1
        let previousGeneration = entry?.generation ?? previous
        entry = replacement
        return .replace(previousGeneration: previousGeneration, entry: replacement)
    }

    mutating func consume(pageURL: URL, now: TimeInterval) -> Int? {
        _ = expire(now: now)
        guard let entry, entry.pageURL == pageURL else { return nil }
        self.entry = nil
        return entry.generation
    }

    @discardableResult
    mutating func cancel() -> Int? {
        defer { entry = nil }
        return entry?.generation
    }

    @discardableResult
    mutating func expire(now: TimeInterval) -> Int? {
        guard let entry, now >= entry.expiresAt else { return nil }
        self.entry = nil
        return entry.generation
    }
}
