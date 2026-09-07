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
    let warnText: Color
    let premium: Color
    let premiumText: Color
    let chrome: Color
    let chromeLine: Color
    let accent: Color
    let onAccent: Color
    let mapBackground: Color
    let mapRowLabel: Color
    let mapText: Color
    let mapSelection: Color
    let mapTheme: SeatLayerPickerMapTheme
    let dark: Bool

    /// Immersive chrome floats over a rendered venue and is dark in both
    /// appearances, so its glass reads from the dark palette either way.
    static let immersiveGlass = pickerColor(SeatLayerPickerDarkColorTokens.immersiveGlass)
    static let immersiveGlassBorder =
        pickerColor(SeatLayerPickerDarkColorTokens.immersiveGlassBorder)
    static let immersiveGlassInk =
        pickerColor(SeatLayerPickerDarkColorTokens.immersiveGlassInk)
    static let immersiveCaption =
        pickerColor(SeatLayerPickerDarkColorTokens.immersiveCaption)
    static let immersiveCaptionBorder =
        pickerColor(SeatLayerPickerDarkColorTokens.immersiveCaptionBorder)
    static let immersiveCaptionInk =
        pickerColor(SeatLayerPickerDarkColorTokens.immersiveCaptionInk)
}

/// One canonical token hex as a SwiftUI colour.
func pickerColor(_ hex: String) -> Color {
    Color(uiColor: UIColor(slHex: hex) ?? .clear)
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
    let warnText = defaults.warnText
    let premium = defaults.premium
    let premiumText = defaults.premiumText
    let chrome = defaults.chrome
    let chromeLine = defaults.chromeLine
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
        warnText: pickerColor(warnText),
        premium: pickerColor(premium),
        premiumText: pickerColor(premiumText),
        chrome: pickerColor(chrome),
        chromeLine: pickerColor(chromeLine),
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

/// The default palettes, read straight from the generated design tokens.
private enum PickerHex {
    struct Values {
        let mode: [String: String]

        subscript(role: String) -> String { mode[role] ?? "#000000" }

        var background: String { self["background"] }
        var surface: String { self["surface"] }
        var text: String { self["text"] }
        var muted: String { self["mutedText"] }
        var divider: String { self["divider"] }
        var error: String { self["error"] }
        var warning: String { self["warning"] }
        var warnText: String { self["warnText"] }
        var premium: String { self["premium"] }
        var premiumText: String { self["premiumText"] }
        var chrome: String { self["chrome"] }
        var chromeLine: String { self["chromeLine"] }
        var accent: String { self["accent"] }
        var onAccent: String { self["onAccent"] }
        var mapBackground: String { self["mapBackground"] }
        var mapRowLabel: String { self["mapRowLabel"] }
        var mapText: String { self["mapText"] }
        var mapSelection: String { self["mapSelection"] }
    }

    static let light = Values(mode: SeatLayerPickerLightColorTokens.all)
    static let dark = Values(mode: SeatLayerPickerDarkColorTokens.all)
}

#endif
