import Foundation

/// Appearance mode shared by the native chrome and the headless chart.
public enum SeatLayerPickerThemeMode: String, Sendable, Equatable, CaseIterable {
    case auto
    case light
    case dark
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
