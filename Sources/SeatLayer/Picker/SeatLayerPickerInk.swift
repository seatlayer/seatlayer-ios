import Foundation

/// Per-colour ink decisions, and the one measurement they all rest on.
///
/// The picker paints on colours nobody chose for legibility: a category band is
/// the organizer's own hex, and a note band is a wash mixed out of the surface
/// underneath it. Choosing ink by "is the theme dark" gets both of those
/// wrong, so the choice is MEASURED — and measured against the ground actually
/// painted, not against the surface a translucent wash was mixed from, which
/// is how a 1.8:1 amber shipped.
///
/// The arithmetic is deliberately platform-free so the contrast gate is a unit
/// test rather than a screenshot: a wash that fails the bar has to fail the
/// build, on every machine, without a simulator.

/// An opaque colour, in the sRGB the token document is authored in.
public struct SeatLayerPickerInkColor: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    /// Kept so a wash can be composited; every measurement is taken after
    /// compositing, never on a translucent value.
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = min(1, max(0, red))
        self.green = min(1, max(0, green))
        self.blue = min(1, max(0, blue))
        self.alpha = min(1, max(0, alpha))
    }

    /// A `#rrggbb` or `#aarrggbb` token value, or nil for anything else.
    public init?(hex raw: String) {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6 || value.count == 8,
              let parsed = UInt32(value, radix: 16) else { return nil }
        let bits = value.count == 6 ? 0xFF00_0000 | parsed : parsed
        self.init(
            red: Double((bits >> 16) & 0xFF) / 255,
            green: Double((bits >> 8) & 0xFF) / 255,
            blue: Double(bits & 0xFF) / 255,
            alpha: Double((bits >> 24) & 0xFF) / 255
        )
    }

    /// The widget's darkest ink — near-black, not pure black. One true black
    /// on an otherwise navy-inked card reads as a printing error.
    public static let bandDarkInk = SeatLayerPickerInkColor(
        red: 0x0B / 255, green: 0x0F / 255, blue: 0x19 / 255
    )

    public static let white = SeatLayerPickerInkColor(red: 1, green: 1, blue: 1)
}

/// The picker's own ink arithmetic.
public enum SeatLayerPickerInk {
    /// Composite `overlay` at `opacity` over the opaque `base`.
    ///
    /// The picker's washes are drawn, not blended by the reader's eye, so any
    /// contrast figure taken against the base alone is a figure for a colour
    /// that is never on screen. `overlay`'s own alpha multiplies `opacity`.
    public static func blend(
        _ overlay: SeatLayerPickerInkColor,
        _ opacity: Double,
        over base: SeatLayerPickerInkColor
    ) -> SeatLayerPickerInkColor {
        let alpha = min(1, max(0, opacity)) * overlay.alpha
        return SeatLayerPickerInkColor(
            red: overlay.red * alpha + base.red * (1 - alpha),
            green: overlay.green * alpha + base.green * (1 - alpha),
            blue: overlay.blue * alpha + base.blue * (1 - alpha)
        )
    }

    /// `from` walked `amount` of the way toward `to`.
    public static func lerp(
        _ from: SeatLayerPickerInkColor,
        _ to: SeatLayerPickerInkColor,
        _ amount: Double
    ) -> SeatLayerPickerInkColor {
        let t = min(1, max(0, amount))
        return SeatLayerPickerInkColor(
            red: from.red + (to.red - from.red) * t,
            green: from.green + (to.green - from.green) * t,
            blue: from.blue + (to.blue - from.blue) * t
        )
    }

    /// The WCAG relative luminance of an opaque colour.
    public static func relativeLuminance(
        _ color: SeatLayerPickerInkColor
    ) -> Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.red)
            + 0.7152 * channel(color.green)
            + 0.0722 * channel(color.blue)
    }

    /// The WCAG contrast ratio between two opaque colours, 1 to 21.
    public static func contrastRatio(
        _ a: SeatLayerPickerInkColor,
        _ b: SeatLayerPickerInkColor
    ) -> Double {
        let first = relativeLuminance(a)
        let second = relativeLuminance(b)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    /// The ink a full-bleed category band takes.
    ///
    /// White wherever white clears 3:1 on the band, and the widget's near-black
    /// otherwise — so a pale yellow category keeps its name and a deep blue one
    /// does not lose it.
    public static func bandInk(
        _ band: SeatLayerPickerInkColor
    ) -> SeatLayerPickerInkColor {
        contrastRatio(.white, band) >= 3 ? .white : .bandDarkInk
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

extension SeatLayerPickerInkColor {
    /// A resolved SwiftUI colour as ink arithmetic sees it.
    ///
    /// Resolved against no trait deliberately: every caller has already picked
    /// its palette for the appearance it is drawing in, so a second appearance
    /// resolution would undo that choice.
    init(_ color: Color) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            self.init(red: 0, green: 0, blue: 0)
            return
        }
        self.init(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
    }

    var color: Color {
        Color(red: red, green: green, blue: blue).opacity(alpha)
    }
}

func seatLayerPickerBlend(
    _ overlay: Color,
    _ opacity: Double,
    over base: Color
) -> Color {
    SeatLayerPickerInk.blend(
        SeatLayerPickerInkColor(overlay),
        opacity,
        over: SeatLayerPickerInkColor(base)
    ).color
}

func seatLayerPickerLerp(_ from: Color, _ to: Color, _ amount: Double) -> Color {
    SeatLayerPickerInk.lerp(
        SeatLayerPickerInkColor(from),
        SeatLayerPickerInkColor(to),
        amount
    ).color
}

func seatLayerPickerContrastRatio(_ a: Color, _ b: Color) -> Double {
    SeatLayerPickerInk.contrastRatio(
        SeatLayerPickerInkColor(a),
        SeatLayerPickerInkColor(b)
    )
}

/// The ink a full-bleed category band takes; see `SeatLayerPickerInk.bandInk`.
func seatLayerPickerBandInk(_ band: Color) -> Color {
    SeatLayerPickerInk.bandInk(SeatLayerPickerInkColor(band)).color
}
#endif
