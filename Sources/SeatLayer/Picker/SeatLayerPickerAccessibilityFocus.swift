import Foundation

/// Pure state for the accessibility sheet's bound and for the accessible
/// section tour the sheet's count chip starts.
///
/// Nothing here touches SwiftUI, so the bound, the tour's lifecycle and the
/// stepper's four states are all exercised on macOS by `swift test`.

/// The height the accessibility sheet takes on a screen of `screenHeight`.
///
/// Bounded so the map the buyer is filtering stays visible behind it: a
/// fraction of the screen, floored at a minimum, and never taller than the
/// screen itself. The row list scrolls inside the bound rather than the sheet
/// growing to hold it.
public func seatLayerAccessSheetHeight(screenHeight: Double) -> Double {
    guard screenHeight.isFinite, screenHeight > 0 else {
        return SeatLayerPickerSizeTokens.accessSheetMinHeight
    }
    let preferred = screenHeight * SeatLayerPickerSizeTokens.accessSheetMaxHeightFraction
    return min(max(preferred, SeatLayerPickerSizeTokens.accessSheetMinHeight), screenHeight)
}

/// What the accessible-section stepper draws right now.
public enum SeatLayerPickerAccessibleTourState: Sendable, Equatable {
    /// Walking: `index` of `total`, both one-based for the buyer.
    case step(index: Int, total: Int)
    /// Before the first step, with the sections counted.
    case counted(sections: Int)
    /// Before the first step, where the runtime does not count sections.
    case uncounted
    /// Nothing matches, or nothing is filtered: the pill is not drawn.
    case absent
}

/// The accessible-section tour: which provisions it walks and where it is.
///
/// The runtime owns the camera; this only remembers the walk so the pill can
/// name it, and forgets the walk whenever the filter changes underneath it —
/// a tour of the seats the buyer no longer asked for is worse than no tour.
public struct SeatLayerPickerAccessibilityTour: Sendable, Equatable {
    /// The provisions the walk was begun with, in the order they were sent.
    public private(set) var types: [String]
    /// The last step the runtime answered with, if any.
    public private(set) var step: SeatLayerPickerAccessibleStep?
    /// Set once the runtime answers a walk with no next section.
    public private(set) var exhausted: Bool

    public init(
        types: [String] = [],
        step: SeatLayerPickerAccessibleStep? = nil,
        exhausted: Bool = false
    ) {
        self.types = types
        self.step = step
        self.exhausted = exhausted
    }

    public var isWalking: Bool { step != nil }

    /// Begins (or restarts) a walk over `types`.
    public mutating func begin(_ types: [String]) {
        self.types = types
        step = nil
        exhausted = false
    }

    /// Records what the runtime answered a `focusNextAccessibleSection` with.
    ///
    /// A nil step is an answer, not a failure: nothing matches, and the pill
    /// goes rather than drawing "0 of 0".
    public mutating func advance(to next: SeatLayerPickerAccessibleStep?) {
        guard let next, next.total > 0 else {
            step = nil
            exhausted = true
            return
        }
        step = next
        exhausted = false
    }

    /// Abandons the walk when the active filter is no longer what it began on.
    ///
    /// Returns whether anything was abandoned, so a caller can redraw once.
    @discardableResult
    public mutating func reconcile(activeTypes: [String]) -> Bool {
        guard Set(activeTypes) != Set(types) else { return false }
        begin(activeTypes)
        return true
    }

    /// What the stepper draws, given what the runtime supports.
    ///
    /// `sectionsWithMatches` is counted from `sections[].accessibleFree` and is
    /// nil where `section-access-counts-v1` is absent — a missing count means
    /// "not counted", never zero.
    public func state(
        supportsFocus: Bool,
        sectionsWithMatches: Int?
    ) -> SeatLayerPickerAccessibleTourState {
        guard supportsFocus, !types.isEmpty, !exhausted else { return .absent }
        if let step, step.total > 0 {
            return .step(index: step.index + 1, total: step.total)
        }
        guard let sectionsWithMatches else { return .uncounted }
        return sectionsWithMatches > 0 ? .counted(sections: sectionsWithMatches) : .absent
    }
}

/// How many sections hold a free space matching one of `types`.
///
/// Returns nil where the runtime does not report section access counts at all,
/// so the caller can tell "not counted" from "counted, and none".
public func seatLayerAccessibleSectionCount(
    snapshot: SeatLayerPickerSnapshot?,
    types: [String],
    supportsCounts: Bool
) -> Int? {
    guard supportsCounts, let snapshot, !types.isEmpty else { return nil }
    var counted = false
    var total = 0
    for section in snapshot.sections {
        // A missing entry is "not counted", never zero: a section the runtime
        // says nothing about must not be reported as holding nothing.
        guard let free = section.accessibleFree else { continue }
        counted = true
        if free > 0 { total += 1 }
    }
    return counted ? total : nil
}
