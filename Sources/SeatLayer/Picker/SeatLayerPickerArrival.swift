import Foundation

/// When one row of an arriving set starts, and how long it takes.
///
/// Best-available drops several seats into the cart at once, and opening the
/// accessibility sheet puts a whole vocabulary on screen at once. Landing them
/// together reads as a page redraw; landing them one after the next reads as
/// rows being found. The whole set is bounded by `motion.duration.fly`, so a
/// long list never turns its own arrival into a wait.
public struct SeatLayerPickerArrival: Sendable, Equatable {
    /// How long this row waits before it begins, in milliseconds.
    public let delayMilliseconds: Int
    /// How long it then takes, in milliseconds.
    public let durationMilliseconds: Int

    public init(delayMilliseconds: Int, durationMilliseconds: Int) {
        self.delayMilliseconds = delayMilliseconds
        self.durationMilliseconds = durationMilliseconds
    }

    /// The whole thing, start to rest.
    public var totalMilliseconds: Int { delayMilliseconds + durationMilliseconds }

    public var delay: TimeInterval { Double(delayMilliseconds) / 1_000 }
    public var duration: TimeInterval { Double(durationMilliseconds) / 1_000 }
}

/// How far into the run a row may still be waiting. A row that has spent its
/// whole budget queueing appears rather than arrives, which is not the point.
let seatLayerPickerArrivalLatestStart: Double = 0.9

/// The arrival for the row at `index` of a set, or nil for a row that is not
/// arriving at all.
///
/// Deterministic by construction — the answer is the index and nothing else,
/// so the same list arriving twice arrives the same way, and a still of it can
/// be compared against a golden.
public func seatLayerPickerArrival(index: Int) -> SeatLayerPickerArrival? {
    guard index >= 0 else { return nil }
    let durations = SeatLayerPickerMotionDurationTokens.self
    let queued = durations.stagger * index
    let total = min(durations.pop + queued, durations.fly)
    let delay = min(queued, Int(Double(total) * seatLayerPickerArrivalLatestStart))
    return SeatLayerPickerArrival(
        delayMilliseconds: delay,
        durationMilliseconds: total - delay
    )
}

/// The arrival order of a freshly measured list.
///
/// A row already on screen is not arriving; the rows that were not there
/// before are, in the order the list carries them. The result is addressed by
/// the row's own key so a later removal does not renumber a row mid-flight.
public func seatLayerPickerArrivals(
    keys: [String],
    seen: Set<String>
) -> [String: Int] {
    var arrivals: [String: Int] = [:]
    var index = 0
    for key in keys where !seen.contains(key) {
        arrivals[key] = index
        index += 1
    }
    return arrivals
}

#if canImport(SwiftUI)
import SwiftUI

/// A newly arrived row settling in, one after the next.
///
/// Skipped rather than shortened when the viewer has asked for less movement —
/// a stagger has no reduced form — and skipped under the golden harness, where
/// the point of the surface is that it holds still.
struct SeatLayerPickerArrivalPop: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    func body(content: Content) -> some View {
        if let arrival = plan {
            content
                .opacity(landed ? 1 : 0)
                .scaleEffect(landed ? 1 : 0.94, anchor: .leading)
                .onAppear {
                    withAnimation(
                        .timingCurve(
                            SeatLayerPickerCurveTokens.easeEnter.x1,
                            SeatLayerPickerCurveTokens.easeEnter.y1,
                            SeatLayerPickerCurveTokens.easeEnter.x2,
                            SeatLayerPickerCurveTokens.easeEnter.y2,
                            duration: arrival.duration
                        ).delay(arrival.delay)
                    ) {
                        landed = true
                    }
                }
        } else {
            content
        }
    }

    private var plan: SeatLayerPickerArrival? {
        guard !reduceMotion, !SeatLayerPickerMotion.capturing else { return nil }
        return seatLayerPickerArrival(index: index)
    }
}

extension View {
    /// Lands this row as the `index`-th of an arriving set. A negative index
    /// is a row that was already there.
    func seatLayerPickerArrivalPop(index: Int) -> some View {
        modifier(SeatLayerPickerArrivalPop(index: index))
    }
}
#endif
