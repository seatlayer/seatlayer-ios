// GENERATED — do not edit.
//
// Source: Design/tokens.json
// Regenerate: node Scripts/generate-picker-tokens.mjs
//
// The type ramp and the per-surface Dynamic Type clamps.
import Foundation

/// One role in the picker's type ramp.
public struct SeatLayerPickerTypeToken: Sendable, Equatable {
    /// Point size before the platform's text-size setting is applied.
    public let size: Double
    /// Numeric weight, on the 100–950 scale the design sources use.
    public let weight: Double

    public init(size: Double, weight: Double) {
        self.size = size
        self.weight = weight
    }
}

/// The picker's type ramp: one point size and weight per role.
public enum SeatLayerPickerTypeTokens {
    /// `size 16, weight 800`
    public static let headerTitle = SeatLayerPickerTypeToken(
        size: 16,
        weight: 800
    )
    /// `size 14, weight 800`
    public static let dockSection = SeatLayerPickerTypeToken(
        size: 14,
        weight: 800
    )
    /// `size 13, weight 600`
    public static let dockCount = SeatLayerPickerTypeToken(
        size: 13,
        weight: 600
    )
    /// `size 14, weight 800`
    public static let confirmIdentity = SeatLayerPickerTypeToken(
        size: 14,
        weight: 800
    )
    /// `size 14, weight 800`
    public static let confirmAction = SeatLayerPickerTypeToken(
        size: 14,
        weight: 800
    )
    /// `size 13, weight 600`
    public static let footTotalLabel = SeatLayerPickerTypeToken(
        size: 13,
        weight: 600
    )
    /// `size 17, weight 700`
    public static let footTotalAmount = SeatLayerPickerTypeToken(
        size: 17,
        weight: 700
    )
    /// `size 15, weight 700`
    public static let cartCardName = SeatLayerPickerTypeToken(
        size: 15,
        weight: 700
    )
    /// `size 13, weight 600`
    public static let cartCardPosition = SeatLayerPickerTypeToken(
        size: 13,
        weight: 600
    )
    /// `size 15, weight 800`
    public static let cartCardAmount = SeatLayerPickerTypeToken(
        size: 15,
        weight: 800
    )
    /// `size 10, weight 800`
    public static let cartNoteTitle = SeatLayerPickerTypeToken(
        size: 10,
        weight: 800
    )
    /// `size 10, weight 600`
    public static let cartNoteText = SeatLayerPickerTypeToken(
        size: 10,
        weight: 600
    )
    /// `size 12, weight 700`
    public static let peekSummary = SeatLayerPickerTypeToken(
        size: 12,
        weight: 700
    )
    /// `size 19, weight 850`
    public static let peekFromPrice = SeatLayerPickerTypeToken(
        size: 19,
        weight: 850
    )
    /// `size 14, weight 700`
    public static let peekSummaryOpen = SeatLayerPickerTypeToken(
        size: 14,
        weight: 700
    )
    /// `size 16, weight 800`
    public static let peekPill = SeatLayerPickerTypeToken(
        size: 16,
        weight: 800
    )
    /// `size 16, weight 800`
    public static let findPill = SeatLayerPickerTypeToken(
        size: 16,
        weight: 800
    )
    /// `size 12.5, weight 700`
    public static let bestSeatsSelect = SeatLayerPickerTypeToken(
        size: 12.5,
        weight: 700
    )
    /// `size 12.5, weight 800`
    public static let bestSeatsGo = SeatLayerPickerTypeToken(
        size: 12.5,
        weight: 800
    )
    /// `size 11, weight 600`
    public static let attribution = SeatLayerPickerTypeToken(
        size: 11,
        weight: 600
    )
    /// `size 14, weight 800`
    public static let bookButton = SeatLayerPickerTypeToken(
        size: 14,
        weight: 800
    )
    /// `size 11, weight 800`
    public static let legendChip = SeatLayerPickerTypeToken(
        size: 11,
        weight: 800
    )
    /// `size 12.5, weight 800`
    public static let noteTitle = SeatLayerPickerTypeToken(
        size: 12.5,
        weight: 800
    )
    /// `size 11, weight 400`
    public static let noteBody = SeatLayerPickerTypeToken(
        size: 11,
        weight: 400
    )
    /// `size 11.5, weight 750`
    public static let noteTitleCompact = SeatLayerPickerTypeToken(
        size: 11.5,
        weight: 750
    )
    /// `size 10.5, weight 400`
    public static let noteBodyCompact = SeatLayerPickerTypeToken(
        size: 10.5,
        weight: 400
    )
    /// `size 12, weight 800`
    public static let pill = SeatLayerPickerTypeToken(
        size: 12,
        weight: 800
    )
    /// `size 11, weight 800`
    public static let accessStep = SeatLayerPickerTypeToken(
        size: 11,
        weight: 800
    )

    /// Every role, keyed by its token name.
    public static let all: [String: SeatLayerPickerTypeToken] = [
        "headerTitle": headerTitle,
        "dockSection": dockSection,
        "dockCount": dockCount,
        "confirmIdentity": confirmIdentity,
        "confirmAction": confirmAction,
        "footTotalLabel": footTotalLabel,
        "footTotalAmount": footTotalAmount,
        "cartCardName": cartCardName,
        "cartCardPosition": cartCardPosition,
        "cartCardAmount": cartCardAmount,
        "cartNoteTitle": cartNoteTitle,
        "cartNoteText": cartNoteText,
        "peekSummary": peekSummary,
        "peekFromPrice": peekFromPrice,
        "peekSummaryOpen": peekSummaryOpen,
        "peekPill": peekPill,
        "findPill": findPill,
        "bestSeatsSelect": bestSeatsSelect,
        "bestSeatsGo": bestSeatsGo,
        "attribution": attribution,
        "bookButton": bookButton,
        "legendChip": legendChip,
        "noteTitle": noteTitle,
        "noteBody": noteBody,
        "noteTitleCompact": noteTitleCompact,
        "noteBodyCompact": noteBodyCompact,
        "pill": pill,
        "accessStep": accessStep,
    ]
}

/// How far each surface lets the platform grow its type.
/// 
/// A clamp is a promise about a layout, not a preference: past it the
/// surface would clip or overflow rather than read larger. Surfaces that
/// own the screen are absent on purpose.
public enum SeatLayerPickerTypeScaleTokens {
    /// `1.3`
    public static let rail: Double = 1.3
    /// `1.3`
    public static let dock: Double = 1.3
    /// `1.3`
    public static let peek: Double = 1.3
    /// `1.3`
    public static let card: Double = 1.3
    /// `1.6`
    public static let sheet: Double = 1.6
    /// `1.6`
    public static let state: Double = 1.6

    /// Every clamp, keyed by its surface name.
    public static let all: [String: Double] = [
        "rail": rail,
        "dock": dock,
        "peek": peek,
        "card": card,
        "sheet": sheet,
        "state": state,
    ]
}
