import Foundation

/// Appearance mode shared by the native chrome and the headless chart.
public enum SeatLayerPickerThemeMode: String, Sendable, Equatable, CaseIterable {
    case auto
    case light
    case dark
}

/// The organizer's own logo, for the header slot.
///
/// Data only: an asset name resolved against a bundle, or a URL the host has
/// already vetted. The SDK never fetches an image a snapshot named.
public struct SeatLayerPickerBrandLogo: Sendable, Equatable {
    /// An image asset name, resolved in `bundleIdentifier` or the main bundle.
    public var imageName: String?
    /// Where `imageName` lives, when it is not the app's own bundle.
    public var bundleIdentifier: String?
    /// A location the host has vetted itself.
    public var url: URL?
    /// The bytes, when the host already holds them.
    public var data: Data?

    public init(
        imageName: String? = nil,
        bundleIdentifier: String? = nil,
        url: URL? = nil,
        data: Data? = nil
    ) {
        self.imageName = imageName
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.data = data
    }
}

/// Per-token layout overrides, resolved against the generated size tokens.
///
/// Keys are the canonical token names in `Design/tokens.json`, which is what
/// `SeatLayerPickerSizeTokens.all` is keyed by; an unknown key is inert rather
/// than an error, so a host pinned to an older SDK keeps building. Overriding
/// a measurement is a promise about a layout, so prefer changing none.
public struct SeatLayerPickerLayout: Sendable, Equatable {
    public var overrides: [String: Double]

    public init(overrides: [String: Double] = [:]) {
        self.overrides = overrides
    }

    /// The override for `token`, or the canonical value.
    public func value(_ token: String) -> Double? {
        overrides[token] ?? SeatLayerPickerSizeTokens.all[token]
    }

    public subscript(token: String) -> Double? {
        get { value(token) }
        set { overrides[token] = newValue }
    }
}

/// Native picker color roles. Six-digit hexadecimal values keep the public
/// theme portable between SwiftUI, UIKit, and the map renderer.
public struct SeatLayerPickerTheme: Sendable, Equatable {
    public var background: String?
    public var surface: String?
    public var text: String?
    public var mutedText: String?
    public var divider: String?
    public var error: String?
    public var warning: String?
    public var accent: String?
    public var onAccent: String?
    /// A font family the chrome uses in place of the system face.
    public var fontFamily: String?
    /// The organizer's logo, for the header slot.
    public var logo: SeatLayerPickerBrandLogo?
    /// The base corner radius, in points. Nil keeps the token.
    public var radius: Double?
    /// The corner radius of buttons and other controls.
    public var buttonRadius: Double?
    /// Per-token layout overrides.
    public var layout: SeatLayerPickerLayout?
    public var map: SeatLayerPickerMapTheme

    public init(
        background: String? = nil,
        surface: String? = nil,
        text: String? = nil,
        mutedText: String? = nil,
        divider: String? = nil,
        error: String? = nil,
        warning: String? = nil,
        accent: String? = nil,
        onAccent: String? = nil,
        fontFamily: String? = nil,
        logo: SeatLayerPickerBrandLogo? = nil,
        radius: Double? = nil,
        buttonRadius: Double? = nil,
        layout: SeatLayerPickerLayout? = nil,
        map: SeatLayerPickerMapTheme = .init()
    ) {
        self.background = background
        self.surface = surface
        self.text = text
        self.mutedText = mutedText
        self.divider = divider
        self.error = error
        self.warning = warning
        self.accent = accent
        self.onAccent = onAccent
        self.fontFamily = fontFamily
        self.logo = logo
        self.radius = radius.map { max(0, $0) }
        self.buttonRadius = buttonRadius.map { max(0, $0) }
        self.layout = layout
        self.map = map
    }
}

/// The four canvas roles a native host is allowed to override.
///
/// Colors use six-digit hexadecimal notation (`#RRGGBB`). Keeping this surface
/// deliberately small lets SwiftUI/UIKit chrome and the renderer agree on the
/// same contrast pairings without exposing web-only styling options.
public struct SeatLayerPickerMapTheme: Sendable, Equatable {
    public var background: String?
    public var rowLabelColor: String?
    public var textColor: String?
    public var selectionColor: String?

    public init(
        background: String? = nil,
        rowLabelColor: String? = nil,
        textColor: String? = nil,
        selectionColor: String? = nil
    ) {
        self.background = background
        self.rowLabelColor = rowLabelColor
        self.textColor = textColor
        self.selectionColor = selectionColor
    }

    var jsonValue: JSONValue {
        .object(compacting: [
            "background": background.map(JSONValue.string),
            "rowLabelColor": rowLabelColor.map(JSONValue.string),
            "textColor": textColor.map(JSONValue.string),
            "selectionColor": selectionColor.map(JSONValue.string),
        ])
    }

    var colors: [String] {
        [background, rowLabelColor, textColor, selectionColor].compactMap { $0 }
    }
}
