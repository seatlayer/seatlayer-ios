import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Native feedback moments shared by the ready-made and custom picker paths.
public enum SeatLayerPickerHapticCue: String, Sendable, Equatable, CaseIterable {
    case selectionAdded
    case sectionFocused
    case holdCreated
    case holdExpired
}

/// Platform-neutral strengths generated from the shared picker tokens.
public enum SeatLayerPickerHapticStrength: String, Sendable, Equatable, CaseIterable {
    case selection
    case light
    case medium
    case heavy
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
