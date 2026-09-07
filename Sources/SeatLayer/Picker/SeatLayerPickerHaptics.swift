import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Native feedback moments shared by the ready-made and custom picker paths.
///
/// Four of the nine are DEDUCED from the snapshot stream by the policy below —
/// selection, focus and hold are only known to agree with each other inside a
/// snapshot. The rest are announced by the surface that owns the moment: the
/// seat card knows exactly when it landed and which of its two answers was
/// pressed, and nothing here has to guess at that.
public enum SeatLayerPickerHapticCue: String, Sendable, Equatable, CaseIterable {
    /// A seat joined the selection. The lightest cue there is: picking seats
    /// is a repeated action and anything heavier is noise by the fourth tap.
    case selectionAdded
    /// The map moved into a different section — a change of place, not of
    /// inventory, so it takes the tick a picker wheel gives passing a stop.
    case sectionFocused
    /// A ticket left the cart — the ×, a swipe, or the card's Remove answer.
    /// Light: something the buyer did on purpose and can undo.
    case ticketRemoved
    /// The hold has a minute left. The one warning in the set, and the only
    /// cue that is not an answer to a touch, so it is a buzz rather than an
    /// impact — it has to be recognisable through a pocket.
    case holdEnding
    /// Seats are now actually held: the one irreversible-feeling moment.
    case holdCreated
    /// The hold ran out and the seats went back. The heaviest cue, and the
    /// only one for something the buyer did not do.
    case holdExpired
    /// The seat card arrived over the map. Light, because the buyer's finger
    /// is still on the glass: this is the surface answering the tap.
    case cardArrived
    /// The buyer pressed `Add seat` — the one tap that changes what they pay.
    case seatConfirmed
    /// The card was dismissed: the button, a tap outside, or a swipe down.
    /// Nothing happened that the buyer has to notice.
    case cardCancelled
}

/// Platform-neutral strengths generated from the shared picker tokens.
public enum SeatLayerPickerHapticStrength: String, Sendable, Equatable, CaseIterable {
    case selection
    case light
    case medium
    case heavy
    /// Deliberately not an impact. A warning has to be told apart from the
    /// taps the buyer has been feeling all along, and duration is the one
    /// dimension the impact generators do not use.
    case warning
}

/// Optional seam for apps that own a broader feedback vocabulary.
@MainActor
public protocol SeatLayerPickerHapticAdapter: AnyObject {
    func play(_ strength: SeatLayerPickerHapticStrength)
}

/// Default UIKit implementation. The operating system remains free to make
/// feedback silent when the device or buyer preference requires it.
#if canImport(UIKit)
@MainActor
public final class SeatLayerPickerUIKitHapticAdapter: SeatLayerPickerHapticAdapter {
    private let selection = UISelectionFeedbackGenerator()
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notice = UINotificationFeedbackGenerator()

    public init() {}

    public func play(_ strength: SeatLayerPickerHapticStrength) {
        switch strength {
        case .selection:
            selection.prepare()
            selection.selectionChanged()
        case .light:
            light.prepare()
            light.impactOccurred()
        case .medium:
            medium.prepare()
            medium.impactOccurred()
        case .heavy:
            heavy.prepare()
            heavy.impactOccurred()
        case .warning:
            // The platform's own warning pattern, which is a rhythm rather
            // than a single knock — the token's whole point.
            notice.prepare()
            notice.notificationOccurred(.warning)
        }
    }
}
#endif

public struct SeatLayerPickerHapticSnapshot: Sendable, Equatable {
    public let selectionCount: Int
    public let focusedSectionId: String?
    public let hasHold: Bool

    public init(
        selectionCount: Int = 0,
        focusedSectionId: String? = nil,
        hasHold: Bool = false
    ) {
        self.selectionCount = max(0, selectionCount)
        self.focusedSectionId = focusedSectionId
        self.hasHold = hasHold
    }

    public init(_ snapshot: SeatLayerPickerSnapshot) {
        self.init(
            selectionCount: snapshot.selection.count,
            focusedSectionId: snapshot.map.focusedSectionId,
            hasHold: snapshot.hold.active
        )
    }
}

public struct SeatLayerPickerHapticPolicyState: Sendable, Equatable {
    public enum HoldLifecycle: String, Sendable, Equatable {
        case inactive
        case active
        case expiredAwaitingInactive
        case reportedInactive
    }

    public let seeded: Bool
    public let selectionCount: Int
    public let focusedSectionId: String?
    public let hasHold: Bool
    public let holdLifecycle: HoldLifecycle

    public init(
        seeded: Bool = false,
        selectionCount: Int = 0,
        focusedSectionId: String? = nil,
        hasHold: Bool = false,
        holdLifecycle: HoldLifecycle = .inactive
    ) {
        self.seeded = seeded
        self.selectionCount = max(0, selectionCount)
        self.focusedSectionId = focusedSectionId
        self.hasHold = hasHold
        self.holdLifecycle = holdLifecycle
    }
}

public struct SeatLayerPickerHapticPolicyResult: Sendable, Equatable {
    public let state: SeatLayerPickerHapticPolicyState
    public let cues: [SeatLayerPickerHapticCue]

    public init(
        state: SeatLayerPickerHapticPolicyState,
        cues: [SeatLayerPickerHapticCue]
    ) {
        self.state = state
        self.cues = cues
    }
}

/// Pure transition policy. Snapshot adoption never depends on feedback, and
/// the first snapshot seeds state silently so resumed holds do not buzz.
public enum SeatLayerPickerHaptics {
    public static let initialState = SeatLayerPickerHapticPolicyState()

    public static func strength(
        for cue: SeatLayerPickerHapticCue
    ) -> SeatLayerPickerHapticStrength {
        SeatLayerPickerHapticTokens.strength(for: cue)
    }

    public static func reduce(
        _ state: SeatLayerPickerHapticPolicyState,
        snapshot: SeatLayerPickerHapticSnapshot
    ) -> SeatLayerPickerHapticPolicyResult {
        let snapshotHasHold = snapshot.hasHold
        if !state.seeded {
            let lifecycle: SeatLayerPickerHapticPolicyState.HoldLifecycle
            switch (state.holdLifecycle, snapshotHasHold) {
            case (.expiredAwaitingInactive, true): lifecycle = .expiredAwaitingInactive
            case (.expiredAwaitingInactive, false): lifecycle = .reportedInactive
            case (_, true): lifecycle = .active
            default: lifecycle = state.holdLifecycle
            }
            return .init(
                state: stateFrom(snapshot, lifecycle: lifecycle),
                cues: []
            )
        }

        let lifecycle: SeatLayerPickerHapticPolicyState.HoldLifecycle
        if snapshotHasHold {
            lifecycle = state.holdLifecycle == .expiredAwaitingInactive
                ? .expiredAwaitingInactive
                : .active
        } else if state.holdLifecycle == .expiredAwaitingInactive {
            lifecycle = .reportedInactive
        } else if state.holdLifecycle == .reportedInactive {
            lifecycle = .reportedInactive
        } else {
            lifecycle = .inactive
        }
        let next = stateFrom(snapshot, lifecycle: lifecycle)
        var cues: [SeatLayerPickerHapticCue] = []
        if next.selectionCount > state.selectionCount { cues.append(.selectionAdded) }
        if let focused = next.focusedSectionId,
           focused != state.focusedSectionId { cues.append(.sectionFocused) }
        if [.inactive, .reportedInactive].contains(state.holdLifecycle),
           next.holdLifecycle == .active { cues.append(.holdCreated) }
        return .init(state: next, cues: cues)
    }

    /// Explicit expiry is distinct from a deliberate release and fires once
    /// until an inactive snapshot and a genuinely new active hold re-arm it.
    public static func signalHoldExpired(
        _ state: SeatLayerPickerHapticPolicyState
    ) -> SeatLayerPickerHapticPolicyResult {
        guard state.holdLifecycle != .expiredAwaitingInactive,
              state.holdLifecycle != .reportedInactive else {
            return .init(state: state, cues: [])
        }
        return .init(
            state: .init(
                seeded: state.seeded,
                selectionCount: state.selectionCount,
                focusedSectionId: state.focusedSectionId,
                hasHold: false,
                holdLifecycle: state.seeded && state.holdLifecycle == .inactive
                    ? .reportedInactive
                    : .expiredAwaitingInactive
            ),
            cues: [.holdExpired]
        )
    }

    /// Whether `cue` is one the snapshot policy can deduce.
    ///
    /// Named so a caller can tell the two families apart without reading this
    /// file: everything else is announced by the surface that owns the moment.
    public static let deducedFromSnapshots: Set<SeatLayerPickerHapticCue> = [
        .selectionAdded, .sectionFocused, .holdCreated, .holdExpired,
    ]

    private static func stateFrom(
        _ snapshot: SeatLayerPickerHapticSnapshot,
        lifecycle: SeatLayerPickerHapticPolicyState.HoldLifecycle
    ) -> SeatLayerPickerHapticPolicyState {
        .init(
            seeded: true,
            selectionCount: snapshot.selectionCount,
            focusedSectionId: snapshot.focusedSectionId,
            hasHold: lifecycle == .active,
            holdLifecycle: lifecycle
        )
    }
}

@MainActor
extension SeatLayerPickerController {
    /// Fire one cue the surfaces know about directly.
    ///
    /// The card's four moments — it arrived, the seat was confirmed, the card
    /// was cancelled, the ticket was removed — are not deducible from a
    /// snapshot: the runtime's `selection` is the same before and after a
    /// buyer answers a card. So the surface that owns the moment says so, and
    /// the seeding rule that governs the deduced cues does not apply: nothing
    /// here can fire on a session's first snapshot, because nothing here fires
    /// without a buyer having pressed something.
    ///
    /// Silent when the host did not configure feedback, exactly as the
    /// snapshot-driven cues are.
    public func emitHaptic(_ cue: SeatLayerPickerHapticCue) {
        play([cue])
    }
}
