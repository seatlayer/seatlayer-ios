// GENERATED — do not edit.
//
// Source: Design/tokens.json
// Regenerate: node Scripts/generate-picker-tokens.mjs
//
// Opacities that carry a meaning of their own.
import Foundation

/// Opacities that carry a meaning of their own.
/// 
/// Not decoration: each one is a state the buyer is being told about,
/// and it is the same number on every platform.
public enum SeatLayerPickerOpacityTokens {
    /// `0.45`
    public static let removing: Double = 0.45
    /// `0.42`
    public static let mapControlDisabled: Double = 0.42
    /// `0.1`
    public static let noteToneWash: Double = 0.1
    /// `0.06`
    public static let noteNeutralWash: Double = 0.06
    /// `0.6`
    public static let noteHairline: Double = 0.6
    /// `0.75`
    public static let noteBodyInk: Double = 0.75
    /// `0.18`
    public static let warnPillWash: Double = 0.18
    /// `0.38`
    public static let confirmScrim: Double = 0.38
    /// `0.5`
    public static let confirmScrimFlat: Double = 0.5

    /// Every value in this group, keyed by its token name.
    public static let all: [String: Double] = [
        "removing": removing,
        "mapControlDisabled": mapControlDisabled,
        "noteToneWash": noteToneWash,
        "noteNeutralWash": noteNeutralWash,
        "noteHairline": noteHairline,
        "noteBodyInk": noteBodyInk,
        "warnPillWash": warnPillWash,
        "confirmScrim": confirmScrim,
        "confirmScrimFlat": confirmScrimFlat,
    ]
}
