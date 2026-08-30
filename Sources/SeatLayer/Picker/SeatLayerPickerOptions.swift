import Foundation

public enum SeatLayerPickerLayoutMode: String, Sendable, Equatable, CaseIterable {
    case adaptive
    case phone
    case wide
}

/// Visibility choices for the ready-made composition. Every part remains
/// public and can also be used independently inside `SeatLayerPickerScope`.
public struct SeatLayerPickerChromeOptions: Sendable, Equatable {
    public var header: Bool
    public var priceLegend: Bool
    public var floorSelector: Bool
    public var floorStrip: Bool
    public var mapControls: Bool
    public var overview: Bool
    public var zoom: Bool
    public var colorblind: Bool
    public var fit: Bool
    public var map3D: Bool
    public var accessibility: Bool
    public var cartSheet: Bool
    public var dock: Bool
    public var confirmCard: Bool
    public var holdPill: Bool
    public var attribution: Bool

    public init(
        header: Bool = true,
        priceLegend: Bool = true,
        floorSelector: Bool = true,
        floorStrip: Bool = true,
        mapControls: Bool = true,
        overview: Bool = true,
        zoom: Bool = true,
        colorblind: Bool = true,
        fit: Bool = true,
        map3D: Bool = true,
        accessibility: Bool = true,
        cartSheet: Bool = true,
        dock: Bool = true,
        confirmCard: Bool = true,
        holdPill: Bool = true,
        attribution: Bool = true
    ) {
        self.header = header
        self.priceLegend = priceLegend
        self.floorSelector = floorSelector
        self.floorStrip = floorStrip
        self.mapControls = mapControls
        self.overview = overview
        self.zoom = zoom
        self.colorblind = colorblind
        self.fit = fit
        self.map3D = map3D
        self.accessibility = accessibility
        self.cartSheet = cartSheet
        self.dock = dock
        self.confirmCard = confirmCard
        self.holdPill = holdPill
        self.attribution = attribution
    }
}

/// Runtime behaviour shared by the ready-made and headless picker surfaces.
public struct SeatLayerPickerOptions: Sendable, Equatable {
    public var layout: SeatLayerPickerLayoutMode
    public var chrome: SeatLayerPickerChromeOptions
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
    public var refreshOnResume: Bool
    public var announceHoldLapse: Bool
    public var haptics: Bool
    public var languages: [String]

    public init(
        layout: SeatLayerPickerLayoutMode = .adaptive,
        chrome: SeatLayerPickerChromeOptions = .init(),
        readOnly: Bool = false,
        confirmSelection: Bool = true,
        enableBestAvailable: Bool = true,
        enable3D: Bool = true,
        enableSeatView: Bool = true,
        holdTtlMs: Int? = nil,
        initialHoldId: String? = nil,
        max3DSeats: Int? = nil,
        hideEventDetails: Bool = false,
        panelInitiallyCollapsed: Bool = true,
        refreshOnResume: Bool = true,
        announceHoldLapse: Bool = true,
        haptics: Bool = true,
        languages: [String] = []
    ) {
        self.layout = layout
        self.chrome = chrome
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
        self.refreshOnResume = refreshOnResume
        self.announceHoldLapse = announceHoldLapse
        self.haptics = haptics
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
