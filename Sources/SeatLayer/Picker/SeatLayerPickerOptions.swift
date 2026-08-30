import Foundation

/// Runtime behaviour shared by the ready-made and headless picker surfaces.
public struct SeatLayerPickerOptions: Sendable, Equatable {
    public var readOnly: Bool
    public var confirmSelection: Bool
    public var enableBestAvailable: Bool
    public var enable3D: Bool
    public var enableSeatView: Bool
    public var holdTtlMs: Int?
    public var initialHoldId: String?
    public var max3DSeats: Int?
    public var hideEventDetails: Bool
    public var panelInitiallyCollapsed: Bool
    public var languages: [String]

    public init(
        readOnly: Bool = false,
        confirmSelection: Bool = false,
        enableBestAvailable: Bool = true,
        enable3D: Bool = true,
        enableSeatView: Bool = true,
        holdTtlMs: Int? = nil,
        initialHoldId: String? = nil,
        max3DSeats: Int? = nil,
        hideEventDetails: Bool = false,
        panelInitiallyCollapsed: Bool = false,
        languages: [String] = []
    ) {
        self.readOnly = readOnly
        self.confirmSelection = confirmSelection
        self.enableBestAvailable = enableBestAvailable
        self.enable3D = enable3D
        self.enableSeatView = enableSeatView
        self.holdTtlMs = holdTtlMs
        self.initialHoldId = initialHoldId
        self.max3DSeats = max3DSeats
        self.hideEventDetails = hideEventDetails
        self.panelInitiallyCollapsed = panelInitiallyCollapsed
        self.languages = languages
    }

    var bridgeConfig: [String: JSONValue] {
        var config: [String: JSONValue] = [
            "readOnly": .bool(readOnly),
            "confirmSelection": .bool(confirmSelection),
            "enableBestAvailable": .bool(enableBestAvailable),
            "enable3D": .bool(enable3D),
            "enableSeatView": .bool(enableSeatView),
            "hideEventDetails": .bool(hideEventDetails),
            "panelCollapsed": .bool(panelInitiallyCollapsed),
        ]
        if let holdTtlMs { config["holdTtlMs"] = .int(holdTtlMs) }
        if let initialHoldId { config["initialHoldId"] = .string(initialHoldId) }
        if let max3DSeats { config["max3DSeats"] = .int(max3DSeats) }
        if !languages.isEmpty {
            config["languages"] = .array(languages.map(JSONValue.string))
        }
        return config
    }
}
