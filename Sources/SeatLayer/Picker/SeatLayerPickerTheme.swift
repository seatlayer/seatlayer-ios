import Foundation

/// Appearance mode shared by the native chrome and the headless chart.
public enum SeatLayerPickerThemeMode: String, Sendable, Equatable, CaseIterable {
    case auto
    case light
    case dark
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
