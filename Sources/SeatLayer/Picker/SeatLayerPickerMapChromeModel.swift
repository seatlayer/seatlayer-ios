import Foundation

// Everything the chrome standing on the map decides before it draws anything.
//
// The views in this area are iOS-only and never compile under `swift test`, so
// every rule they follow — which chips the price rail carries, which discs the
// control column mounts, which of the ink candidates the test chip can
// actually be read in — lives here instead, where the macOS suite exercises
// it.

// MARK: - Colour arithmetic

/// An opaque colour, in the picker's own token form.
///
/// Deliberately not `UIColor`: the rules below are decided in the unit suite,
/// which never links UIKit.
public struct SeatLayerPickerRGB: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(1, max(0, red))
        self.green = min(1, max(0, green))
        self.blue = min(1, max(0, blue))
    }

    /// Parses `#RRGGBB` and the picker's canonical `#AARRGGBB`.
    ///
    /// Alpha is kept separately rather than being folded in: a token carrying
    /// one is a colour to be laid over something, and what it is laid over is
    /// the caller's business.
    public init?(hex value: String) {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard raw.count == 6 || raw.count == 8, let number = UInt64(raw, radix: 16) else {
            return nil
        }
        let shifted = raw.count == 8 ? number & 0x00ff_ffff : number
        self.init(
            red: Double((shifted >> 16) & 0xff) / 255,
            green: Double((shifted >> 8) & 0xff) / 255,
            blue: Double(shifted & 0xff) / 255
        )
    }

    /// `#RRGGBB`, so a view can hand it straight to `UIColor(slHex:)`.
    public var hex: String {
        String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    /// `self` at `alpha` laid over `base`.
    public func blended(over base: SeatLayerPickerRGB, alpha: Double) -> SeatLayerPickerRGB {
        let weight = min(1, max(0, alpha))
        return SeatLayerPickerRGB(
            red: red * weight + base.red * (1 - weight),
            green: green * weight + base.green * (1 - weight),
            blue: blue * weight + base.blue * (1 - weight)
        )
    }

    /// `self` walked `weight` of the way toward `other`.
    public func mixed(toward other: SeatLayerPickerRGB, weight: Double) -> SeatLayerPickerRGB {
        other.blended(over: self, alpha: weight)
    }

    /// WCAG relative luminance.
    public var luminance: Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// WCAG relative contrast against another opaque colour.
    public func contrast(against other: SeatLayerPickerRGB) -> Double {
        let first = luminance + 0.05
        let second = other.luminance + 0.05
        return first > second ? first / second : second / first
    }
}

/// The two inks the picker sets the rest of its sentences in.
///
/// Neither is pure black or pure white, mirroring `highestContrastInk` in the
/// web runtime.
enum SeatLayerPickerNeutralInk {
    static let dark = SeatLayerPickerRGB(hex: "#172033")!
    static let light = SeatLayerPickerRGB(hex: "#EEF1F8")!
}

/// The better of the two picker inks on `background`, by contrast.
public func seatLayerPickerHighestContrastInk(
    on background: SeatLayerPickerRGB
) -> SeatLayerPickerRGB {
    SeatLayerPickerNeutralInk.dark.contrast(against: background)
        >= SeatLayerPickerNeutralInk.light.contrast(against: background)
        ? SeatLayerPickerNeutralInk.dark
        : SeatLayerPickerNeutralInk.light
}

/// The contrast floor every readable label on the map clears.
public let seatLayerPickerTextContrastFloor = 4.5

/// Readable ink for the test chip, measured against its REAL ground.
///
/// The chip is not painted on `surface`. It is painted on a
/// `opacity.warnPillWash` wash of `warning` over it, which is a different and
/// always-warmer colour — so the surface is the ground to mix, not the ground
/// to measure. Three steps, in order of how much of the brand hue they keep:
/// the hue itself, the hue walked toward `text` in 0.05 steps from 0.15, and a
/// neutral ink chosen by contrast when the hue cannot get there at all.
///
/// Step three is the one a fixed blend has no answer for. On a mid-tone ground
/// no mix of a mid-tone gold and a mid-tone ink clears 4.5:1, and a walk with
/// no fallback returns the ground's own ink — which is how a live buyer got a
/// 2.3:1 chip on a light host theme over a chart saved dark.
public func seatLayerPickerWarnPillInk(
    warning: SeatLayerPickerRGB,
    text: SeatLayerPickerRGB,
    surface: SeatLayerPickerRGB
) -> SeatLayerPickerRGB {
    let ground = seatLayerPickerWarnPillGround(warning: warning, surface: surface)
    if warning.contrast(against: ground) >= seatLayerPickerTextContrastFloor { return warning }
    var weight = 0.15
    while weight <= 1.0 {
        let candidate = warning.mixed(toward: text, weight: weight)
        if candidate.contrast(against: ground) >= seatLayerPickerTextContrastFloor {
            return candidate
        }
        weight += 0.05
    }
    return seatLayerPickerHighestContrastInk(on: ground)
}

/// The wash the test chip actually stands on.
public func seatLayerPickerWarnPillGround(
    warning: SeatLayerPickerRGB,
    surface: SeatLayerPickerRGB
) -> SeatLayerPickerRGB {
    warning.blended(over: surface, alpha: SeatLayerPickerOpacityTokens.warnPillWash)
}

// MARK: - Price rail

/// One drawn member of the price rail.
public struct SeatLayerPickerLegendChip: Sendable, Equatable {
    /// The category key, or nil for `All prices`.
    public let categoryKey: String?
    /// What the chip prints.
    public let label: String
    /// The full sentence a screen reader hears.
    public let accessibilityLabel: String
    /// The category's colour, or nil for a chip that names no category.
    public let colorHex: String?
    /// Whether this chip is the map's current answer.
    public let selected: Bool
    /// Whether the runtime positively reported that nothing is left.
    public let soldOut: Bool
}

/// What the price rail draws, decided before anything is measured.
public enum SeatLayerPickerLegendModel {
    /// The chips, `All prices` first and pinned.
    ///
    /// `compact` is the phone, which carries the prices alone: a category name
    /// beside every amount is a rail nobody can read at a glance, and the
    /// not-available key that closes the wide rail would end the phone's row
    /// half off the screen.
    public static func chips(
        snapshot: SeatLayerPickerSnapshot?,
        compact: Bool,
        currency: String,
        allPricesLabel: String,
        amount: (Double) -> String,
        soldOutSuffix: String
    ) -> [SeatLayerPickerLegendChip] {
        let categories = snapshot?.categories.filter { !$0.notForSale } ?? []
        guard !categories.isEmpty else { return [] }
        let filter = snapshot?.map.categoryFilter ?? []
        var chips: [SeatLayerPickerLegendChip] = [
            SeatLayerPickerLegendChip(
                categoryKey: nil,
                label: allPricesLabel,
                accessibilityLabel: allPricesLabel,
                colorHex: nil,
                selected: filter.isEmpty,
                soldOut: false
            ),
        ]
        for category in categories {
            let printed = amountText(category, amount: amount)
            let soldOut = isSoldOut(category)
            let spoken = [
                printed.map { "\(category.label) — \($0)" } ?? category.label,
                soldOut ? soldOutSuffix : "",
            ].filter { !$0.isEmpty }.joined(separator: ", ")
            chips.append(SeatLayerPickerLegendChip(
                categoryKey: category.key,
                label: printed.map { compact ? $0 : "\(category.label) · \($0)" }
                    ?? category.label,
                accessibilityLabel: spoken,
                colorHex: category.color,
                selected: filter.contains(category.key),
                soldOut: soldOut
            ))
        }
        return chips
    }

    /// Whether the not-available key closes the rail. The phone carries the
    /// prices alone; the wide rail has the room and keeps the key.
    public static func showsUnavailableKey(compact: Bool) -> Bool { !compact }

    /// A single price prints itself, an equal minimum and maximum print once,
    /// and a spread prints `{min}+`. A category with no configured price has
    /// no amount at all and wears its name instead.
    public static func amountText(
        _ category: SeatLayerPickerCategory,
        amount: (Double) -> String
    ) -> String? {
        guard category.priceMin > 0 || category.priceMax > 0 else { return nil }
        if category.priceMin == category.priceMax { return amount(category.priceMin) }
        return "\(amount(category.priceMin))+"
    }

    /// Sold out only on positive evidence.
    ///
    /// An absent availability figure means *unknown*, never zero: a rail that
    /// struck a category through because nobody counted it would rewrite the
    /// price ladder the buyer is reading.
    public static func isSoldOut(_ category: SeatLayerPickerCategory) -> Bool {
        category.availabilityReported && category.available == 0
    }
}

// MARK: - The map's control column

/// One disc of the map's control column, in the order it is drawn.
public enum SeatLayerPickerMapControl: String, Sendable, Equatable {
    /// The accessibility filter sheet; heads the column on both layouts.
    case accessibility
    /// Steps the camera in one rung.
    case zoomIn
    /// Walks one rung back out. Wide only.
    case zoomOut
    /// The whole venue from any depth, via `picker.overview`. Phone only.
    case wholeVenue
    /// Map | 3D. Wide only; the phone layout owns the top-trailing corner.
    case viewMode
    /// Colourblind-safe palette.
    case colorblind
}

/// What the control column mounts and which of its discs are live.
public struct SeatLayerPickerControlColumnPlan: Sendable, Equatable {
    /// The discs, top to bottom.
    public let controls: [SeatLayerPickerMapControl]
    /// Discs that keep their slot but cannot be pressed.
    public let retired: Set<SeatLayerPickerMapControl>
    /// Whether the back-to-venue disc stands in the top-leading corner.
    public let showsBackToVenue: Bool

    public func isRetired(_ control: SeatLayerPickerMapControl) -> Bool {
        retired.contains(control)
    }
}

public enum SeatLayerPickerMapControlModel {
    /// Whether a back-out control still has somewhere to take the buyer.
    ///
    /// Inside a framed section there is always a rung left. Otherwise the fit
    /// pose itself is the one camera with nothing to offer, and where the
    /// runtime does not report a pose, `canZoomOut` is the older and coarser
    /// reading it falls back to.
    ///
    /// An unreported pose is not a reported "no": a runtime that says nothing
    /// about where its camera is falls back to `canZoomOut`, and only a
    /// runtime that says it is already fitted rests the control.
    public static func canStepBack(_ map: SeatLayerPickerMapState?) -> Bool {
        guard let map else { return false }
        if map.focusedSectionId != nil { return true }
        if map.atVenueFit == true { return false }
        return map.canZoomOut
    }

    /// `+` retires among the seats or at the zoom ceiling.
    ///
    /// Retired, not removed: the column is anchored at its foot, so a disc
    /// that left the tree would move the accessibility disc under the thumb
    /// already reaching for it.
    public static func zoomInRetires(_ map: SeatLayerPickerMapState?) -> Bool {
        guard let map else { return true }
        return map.rung == "seats" || map.canZoomIn == false
    }

    /// The column for one layout.
    ///
    /// `onMap` is false inside the immersive scene, which owns its own corner:
    /// the whole column, the colourblind disc and the back-to-venue disc are
    /// unmounted there and only the way back stays.
    public static func plan(
        map: SeatLayerPickerMapState?,
        chrome: SeatLayerPickerChromeOptions,
        wide: Bool,
        onMap: Bool,
        offersVenue3D: Bool,
        offersColorblind: Bool,
        offersAccessibility: Bool
    ) -> SeatLayerPickerControlColumnPlan {
        var controls: [SeatLayerPickerMapControl] = []
        var retired: Set<SeatLayerPickerMapControl> = []
        if onMap, chrome.accessibility, offersAccessibility {
            controls.append(.accessibility)
        }
        if onMap, chrome.zoom {
            controls.append(.zoomIn)
            if zoomInRetires(map) { retired.insert(.zoomIn) }
            if wide {
                controls.append(.zoomOut)
                // Live only among the seats: at a section's own frame the only
                // step back is the whole venue, and two discs for one move
                // read as a puzzle.
                if !canStepBack(map) || map?.rung != "seats" { retired.insert(.zoomOut) }
            }
        }
        // The whole-venue disc is the phone's foot of the ladder, and it is
        // ALWAYS live: snapshot camera facts are stale after a pinch, and
        // dimming it on a stale reading strands a buyer with nowhere to press.
        // The wide rail draws no fit control of its own at all.
        if onMap, !wide, chrome.fit { controls.append(.wholeVenue) }
        if wide, chrome.map3D, offersVenue3D { controls.append(.viewMode) }
        if onMap, chrome.showsColorblind(wide: wide), offersColorblind {
            controls.append(.colorblind)
        }
        return SeatLayerPickerControlColumnPlan(
            controls: controls,
            retired: retired,
            showsBackToVenue: onMap
                && chrome.showsOverview(wide: wide)
                && map?.focusedSectionId != nil
        )
    }
}

// MARK: - Section dock

/// How much of the seats-left sentence the dock has room for.
public enum SeatLayerPickerDockCountStep: Sendable, Equatable {
    case full
    case short
    case hidden
}

public enum SeatLayerPickerDockModel {
    /// The matching-spaces suffix, or nil.
    ///
    /// A section with no entry was not counted and says nothing: absent is not
    /// zero, and a bar that drew `♿ 0` would tell a buyer the section is full
    /// when the truth is that nobody counted it.
    public static func accessibleSuffix(
        section: SeatLayerPickerSectionSummary?,
        filter: [String],
        supportsCounts: Bool
    ) -> String? {
        guard supportsCounts, !filter.isEmpty, let free = section?.accessibleFree else {
            return nil
        }
        return "· ♿ \(free)"
    }

    /// The count sentence at each rung of the fit ladder.
    public static func countText(
        step: SeatLayerPickerDockCountStep,
        seatsLeft: Int?,
        sectionLabel: String,
        inSection: (Int, String) -> String,
        plain: (Int) -> String
    ) -> String? {
        guard let seatsLeft else { return nil }
        switch step {
        case .full: return inSection(seatsLeft, sectionLabel)
        case .short: return plain(seatsLeft)
        case .hidden: return nil
        }
    }

    /// The widest rung of the ladder that fits, measured rather than guessed.
    ///
    /// Candidates arrive widest first with the width their text actually
    /// measured; the count may never be clipped, so a budget that fits none of
    /// them hides the count rather than truncating it.
    public static func fit(
        _ candidates: [(step: SeatLayerPickerDockCountStep, width: Double)],
        budget: Double
    ) -> SeatLayerPickerDockCountStep {
        candidates.first { $0.width <= budget }?.step ?? .hidden
    }

    /// The next rung down when the measured text does not fit.
    public static func degrade(_ step: SeatLayerPickerDockCountStep) -> SeatLayerPickerDockCountStep {
        switch step {
        case .full: return .short
        case .short, .hidden: return .hidden
        }
    }
}
