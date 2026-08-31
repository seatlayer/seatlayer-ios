#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

struct SeatLayerPickerStyleEnvironment: Equatable {
    var mode: SeatLayerPickerThemeMode = .auto
    var theme = SeatLayerPickerTheme()
    var strings = SeatLayerPickerStrings()
    var options = SeatLayerPickerOptions()
}

private struct SeatLayerPickerStyleKey: EnvironmentKey {
    static let defaultValue = SeatLayerPickerStyleEnvironment()
}

extension EnvironmentValues {
    var seatLayerPickerStyle: SeatLayerPickerStyleEnvironment {
        get { self[SeatLayerPickerStyleKey.self] }
        set { self[SeatLayerPickerStyleKey.self] = newValue }
    }
}

struct SeatLayerPickerPalette {
    let background: Color
    let surface: Color
    let text: Color
    let mutedText: Color
    let divider: Color
    let error: Color
    let warning: Color
    let accent: Color
    let onAccent: Color
    let mapBackground: Color
    let mapRowLabel: Color
    let mapText: Color
    let mapSelection: Color
    let mapTheme: SeatLayerPickerMapTheme
    let dark: Bool
}

func resolveSeatLayerPickerPalette(
    style: SeatLayerPickerStyleEnvironment,
    colorScheme: ColorScheme,
    snapshot: SeatLayerPickerSnapshot?
) -> SeatLayerPickerPalette {
    let dark = style.mode == .dark || (style.mode == .auto && colorScheme == .dark)
    let defaults = dark ? PickerHex.dark : PickerHex.light
    let brand = snapshot?.branding

    func role(_ explicit: String?, _ fallback: String) -> String {
        guard let explicit, UIColor(slHex: explicit) != nil else { return fallback }
        return explicit
    }

    func brandRole(_ explicit: String?, _ branded: String?, _ fallback: String) -> String {
        if let explicit, UIColor(slHex: explicit) != nil { return explicit }
        if let branded, UIColor(slHex: branded) != nil { return branded }
        return fallback
    }

    // Ground belongs to the selected mode. Organizer branding is deliberately
    // below that preset, matching Flutter: a light-only organizer text token
    // must never make dark native chrome unreadable. Hosts can still override
    // every role explicitly. Branding continues to own the accent pair.
    let background = role(style.theme.background, defaults.background)
    let surface = role(style.theme.surface, defaults.surface)
    let text = role(style.theme.text, defaults.text)
    let muted = role(style.theme.mutedText, defaults.muted)
    let divider = role(style.theme.divider, defaults.divider)
    let accent = brandRole(style.theme.accent, brand?.accent, defaults.accent)
    let onAccent = brandRole(style.theme.onAccent, brand?.accentInk, defaults.onAccent)
    let error = role(style.theme.error, defaults.error)
    let warning = role(style.theme.warning, defaults.warning)
    let mapBackground = role(style.theme.map.background, defaults.mapBackground)
    let mapRow = role(style.theme.map.rowLabelColor, defaults.mapRowLabel)
    let mapText = role(style.theme.map.textColor, defaults.mapText)
    let mapSelection = brandRole(
        style.theme.map.selectionColor,
        brand?.accent,
        defaults.mapSelection
    )

    return SeatLayerPickerPalette(
        background: Color(uiColor: UIColor(slHex: background) ?? .systemBackground),
        surface: Color(uiColor: UIColor(slHex: surface) ?? .secondarySystemBackground),
        text: Color(uiColor: UIColor(slHex: text) ?? .label),
        mutedText: Color(uiColor: UIColor(slHex: muted) ?? .secondaryLabel),
        divider: Color(uiColor: UIColor(slHex: divider) ?? .separator),
        error: Color(uiColor: UIColor(slHex: error) ?? .systemRed),
        warning: Color(uiColor: UIColor(slHex: warning) ?? .systemOrange),
        accent: Color(uiColor: UIColor(slHex: accent) ?? .systemIndigo),
        onAccent: Color(uiColor: UIColor(slHex: onAccent) ?? .white),
        mapBackground: Color(uiColor: UIColor(slHex: mapBackground) ?? .systemBackground),
        mapRowLabel: Color(uiColor: UIColor(slHex: mapRow) ?? .label),
        mapText: Color(uiColor: UIColor(slHex: mapText) ?? .label),
        mapSelection: Color(uiColor: UIColor(slHex: mapSelection) ?? .systemIndigo),
        mapTheme: SeatLayerPickerMapTheme(
            background: mapBackground,
            rowLabelColor: mapRow,
            textColor: mapText,
            selectionColor: mapSelection
        ),
        dark: dark
    )
}

func seatLayerMoney(_ amount: Double, currency: String, locale: Locale = .current) -> String {
    formatSeatLayerPickerMoney(amount, currency: currency, locale: locale, pricing: nil)
}

func seatLayerPickerMoney(
    _ amount: Double,
    currency: String,
    style: SeatLayerPickerStyleEnvironment
) -> String {
    formatSeatLayerPickerMoney(
        amount,
        currency: currency,
        locale: style.strings.resolvedLocale,
        pricing: style.options.pricing
    )
}

extension UIColor {
    convenience init?(slHex value: String) {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard raw.count == 6 || raw.count == 8,
              let number = UInt64(raw, radix: 16) else { return nil }

        let alpha: CGFloat
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        if raw.count == 8 {
            // Canonical picker input uses Flutter's #AARRGGBB form.
            alpha = CGFloat((number >> 24) & 0xff) / 255
            red = CGFloat((number >> 16) & 0xff) / 255
            green = CGFloat((number >> 8) & 0xff) / 255
            blue = CGFloat(number & 0xff) / 255
        } else {
            alpha = 1
            red = CGFloat((number >> 16) & 0xff) / 255
            green = CGFloat((number >> 8) & 0xff) / 255
            blue = CGFloat(number & 0xff) / 255
        }
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

private enum PickerHex {
    struct Values {
        let background: String
        let surface: String
        let text: String
        let muted: String
        let divider: String
        let error: String
        let warning: String
        let accent: String
        let onAccent: String
        let mapBackground: String
        let mapRowLabel: String
        let mapText: String
        let mapSelection: String
    }

    static let light = Values(
        background: "#F6F7FB", surface: "#FFFFFF", text: "#172033",
        muted: "#667085", divider: "#29172033", error: "#B42318",
        warning: "#F4B740", accent: "#5B4B8A", onAccent: "#FFFFFF",
        mapBackground: "#E9EDF4", mapRowLabel: "#334155",
        mapText: "#172033", mapSelection: "#5B4B8A"
    )

    static let dark = Values(
        background: "#0F1522", surface: "#1A2234", text: "#EEF1F8",
        muted: "#A5AEC2", divider: "#3DA5AEC2", error: "#FF6B6B",
        warning: "#F4B740", accent: "#9B8AFB", onAccent: "#110D20",
        mapBackground: "#0F1522", mapRowLabel: "#D7DEEA",
        mapText: "#F4F7FB", mapSelection: "#9B8AFB"
    )
}
#endif
