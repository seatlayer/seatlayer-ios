import Foundation

/// The heights the ticket sheet rests at, in points of sheet BODY — the part
/// below the head strip, which is the only part that changes size.
///
/// Peek is zero by construction: the head and the foot are always drawn, so
/// collapsing the sheet is collapsing its body to nothing. `mini` is the
/// step-down the sheet takes while a seat card is asking a question; its body
/// is zero too, and the surface itself slides down by `surfaceDrop` so the
/// card is never argued with by a sheet standing at its full height.
public struct SeatLayerPickerSheetDetents: Sendable, Equatable {
    /// Two heights are the same rest when they differ by less than this.
    public static let epsilon: Double = 0.5

    /// The sheet at its own content height, under the picker's ceiling.
    public let content: Double
    /// The tallest a finger can drag it. Equal to `content` unless the content
    /// overflows the ceiling.
    public let full: Double
    /// How far the whole surface slides off the bottom at `mini`.
    public let surfaceDrop: Double

    /// Creates a rest table. `full` is clamped up to `content`: a sheet whose
    /// content fits under the ceiling has nothing to open further onto.
    public init(content: Double, full: Double, surfaceDrop: Double = 0) {
        let floor = max(0, content)
        self.content = floor
        self.full = max(floor, full)
        self.surfaceDrop = max(0, surfaceDrop)
    }

    /// Whether the finger-only ceiling is a place of its own.
    public var offersFull: Bool { full > content + Self.epsilon }

    /// The highest body height on offer.
    public var top: Double { offersFull ? full : content }

    /// The body height `detent` rests at.
    public func height(of detent: SeatLayerPickerSheetDetent) -> Double {
        switch detent {
        case .mini, .peek: return 0
        case .open: return content
        }
    }

    /// How far the surface itself is pushed down at `detent`.
    public func surfaceOffset(of detent: SeatLayerPickerSheetDetent) -> Double {
        detent == .mini ? surfaceDrop : 0
    }

    /// Every rest on offer, from the shortest up. `mini` is never settled onto
    /// by a finger — the picker steps down to it when a card opens.
    public var offered: [SeatLayerPickerSheetDetent] { [.peek, .open] }

    /// Where a body `height` settles when the finger simply lets go.
    public func nearest(_ height: Double) -> SeatLayerPickerSheetDetent {
        var best = SeatLayerPickerSheetDetent.peek
        var bestGap = Double.infinity
        for detent in offered {
            let gap = abs(self.height(of: detent) - height)
            if gap < bestGap {
                bestGap = gap
                best = detent
            }
        }
        return best
    }

    /// Where a body `height` settles when the finger was still moving at
    /// `velocity` — points of body height per second, positive while opening.
    ///
    /// A fling is an instruction, not a measurement: past
    /// `sheetFlingVelocity` the sheet goes to the next rest in the direction
    /// thrown even when it is nowhere near it.
    public func settle(height: Double, velocity: Double) -> SeatLayerPickerSheetDetent {
        guard abs(velocity) >= SeatLayerPickerPhysicsTokens.sheetFlingVelocity else {
            return nearest(height)
        }
        if velocity > 0 {
            for detent in offered where self.height(of: detent) > height + Self.epsilon {
                return detent
            }
            return offered[offered.count - 1]
        }
        for detent in offered.reversed() where self.height(of: detent) < height - Self.epsilon {
            return detent
        }
        return offered[0]
    }
}

/// A short deliberate drag still answers: when the settled rest is the one the
/// drag started from and the finger travelled at least this far, the sheet
/// steps one rest in the direction of travel.
public let seatLayerPickerSheetDragThreshold: Double = 18

/// The rest one rung along from `detent` in the direction of `travel`.
public func seatLayerPickerSheetStep(
    from detent: SeatLayerPickerSheetDetent,
    travel: Double,
    in detents: SeatLayerPickerSheetDetents
) -> SeatLayerPickerSheetDetent {
    let order = detents.offered
    guard let index = order.firstIndex(of: detent) else { return detent }
    if travel > 0 { return order[min(order.count - 1, index + 1)] }
    if travel < 0 { return order[max(0, index - 1)] }
    return detent
}

/// `raw`, held inside `low...high` by a band that gives rather than stops.
///
/// A hard clamp tells the buyer their finger has stopped working. A rubber
/// band tells them they have reached the end and are still holding the sheet.
public func seatLayerPickerRubberBand(_ raw: Double, _ low: Double, _ high: Double) -> Double {
    let give = SeatLayerPickerPhysicsTokens.rubberBand
    if raw > high { return high + (raw - high) * give }
    if raw < low { return low - (low - raw) * give }
    return raw
}

/// The ceilings the open sheet is capped at, before the head, foot and bottom
/// safe inset are added back.
///
/// A cart with tickets in it may take more of the screen than an empty tray,
/// which has only a form on it and no reason to loom.
public func seatLayerPickerSheetCeiling(
    screenHeight: Double,
    hasTickets: Bool
) -> Double {
    let size = SeatLayerPickerSizeTokens.self
    return hasTickets
        ? min(screenHeight * size.sheetMaxHeightFraction, size.sheetMaxHeight)
        : min(screenHeight * size.emptyTrayMaxHeightFraction, size.emptyTrayMaxHeight)
}

/// The finger-only ceiling: how tall the buyer may drag the sheet to read the
/// rest of a long order.
public func seatLayerPickerSheetFingerCeiling(screenHeight: Double) -> Double {
    screenHeight * SeatLayerPickerSizeTokens.sheetFullHeightFraction
}

/// The rest table for one measured sheet.
///
/// - Parameters:
///   - screenHeight: the height the sheet is laid out in.
///   - chrome: the head strip, the measured foot and the bottom safe inset —
///     everything the sheet draws in every state.
///   - contentHeight: how tall the cart region wants to be.
///   - hasTickets: whether the cart has anything in it.
public func seatLayerPickerSheetDetents(
    screenHeight: Double,
    chrome: Double,
    contentHeight: Double,
    hasTickets: Bool
) -> SeatLayerPickerSheetDetents {
    let ceiling = seatLayerPickerSheetCeiling(screenHeight: screenHeight, hasTickets: hasTickets)
    let body = max(0, ceiling - chrome)
    let wanted = max(0, contentHeight)
    let fingerBody = max(0, seatLayerPickerSheetFingerCeiling(screenHeight: screenHeight) - chrome)
    return SeatLayerPickerSheetDetents(
        content: min(wanted, body),
        full: min(wanted, fingerBody),
        surfaceDrop: SeatLayerPickerSizeTokens.sheetHandleOverhang
            + SeatLayerPickerSizeTokens.sheetHeadHeight
    )
}

/// Whether the sheet must give the map back.
///
/// The sheet never opens itself, and there are exactly two ways it closes
/// without being touched: a seat card opens over the map — the tap the runtime
/// reports to native chrome, which is how a tap on the map reaches an expanded
/// sheet at all — or the camera steps back out of the seats. Both are the
/// buyer saying they are looking at the map again.
public func seatLayerPickerSheetShouldCollapse(
    detent: SeatLayerPickerSheetDetent,
    cardIsUp: Bool,
    previousRung: String?,
    rung: String?
) -> Bool {
    guard detent == .open else { return false }
    if cardIsUp { return true }
    guard let previousRung, let rung, previousRung != rung else { return false }
    return previousRung == "seats" && rung != "seats"
}

#if canImport(UIKit)
import UIKit

/// The height the sheet's ceilings are a fraction of.
///
/// Read from the window scene rather than measured: the sheet is laid out at
/// the bottom of the picker and never sees the whole screen, and a ceiling
/// derived from its own box would shrink every time it collapsed.
@MainActor
public func seatLayerPickerScreenHeight() -> Double {
    let scenes = UIApplication.shared.connectedScenes
    let window = scenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first { $0.isKeyWindow }
    if let height = window?.bounds.height, height > 0 { return Double(height) }
    return Double(UIScreen.main.bounds.height)
}
#endif
