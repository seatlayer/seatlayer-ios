// GENERATED — do not edit.
//
// Source: Design/tokens.json
// Regenerate: node Scripts/generate-picker-tokens.mjs
//
// Which platform haptic each cue fires.
import Foundation

/// Which platform haptic each buyer-facing cue fires.
public enum SeatLayerPickerHapticNameTokens {
    /// `selection`
    public static let selectionAdded = "selection"
    /// `selection`
    public static let sectionFocused = "selection"
    /// `light`
    public static let ticketRemoved = "light"
    /// `warning`
    public static let holdEnding = "warning"
    /// `medium`
    public static let holdCreated = "medium"
    /// `heavy`
    public static let holdExpired = "heavy"
    /// `light`
    public static let cardArrived = "light"
    /// `medium`
    public static let seatConfirmed = "medium"
    /// `selection`
    public static let cardCancelled = "selection"

    /// Every cue, keyed by its token name.
    public static let all: [String: String] = [
        "selectionAdded": selectionAdded,
        "sectionFocused": sectionFocused,
        "ticketRemoved": ticketRemoved,
        "holdEnding": holdEnding,
        "holdCreated": holdCreated,
        "holdExpired": holdExpired,
        "cardArrived": cardArrived,
        "seatConfirmed": seatConfirmed,
        "cardCancelled": cardCancelled,
    ]

    /// The first snapshot of a session never fires a cue.
    public static let firstSnapshotPolicy = "The first snapshot of a session never fires a cue: a resumed focus or hold is not something the buyer just did."
}
