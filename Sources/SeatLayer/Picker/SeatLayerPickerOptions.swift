import Foundation

/// Renders one authoritative runtime amount in native picker chrome.
/// A throwing or blank result falls back to the SDK's locale-aware formatter.
public typealias SeatLayerPickerMoneyFormatter = @Sendable (
    _ amount: Double,
    _ currency: String
) throws -> String

/// Native-chrome money presentation. Inventory prices and totals remain
/// runtime-authored; this changes formatting only.
public struct SeatLayerPickerPricing: Sendable, Equatable {
    public var formatter: SeatLayerPickerMoneyFormatter? {
        didSet { formatterIdentity = formatter == nil ? nil : UUID() }
    }

    private var formatterIdentity: UUID?

    public init(formatter: SeatLayerPickerMoneyFormatter? = nil) {
        self.formatter = formatter
        formatterIdentity = formatter == nil ? nil : UUID()
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.formatterIdentity == rhs.formatterIdentity
    }
}

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
    /// Off by default at every width: the ticket panel already names the
    /// section the buyer is in, and a second bar under the map takes height
    /// the map needs more.
    public var dock: Bool
    public var confirmCard: Bool
    public var holdPill: Bool
    /// Retained for source compatibility. Runtime `branding.attributionRequired`
    /// is authoritative and cannot be overridden by host chrome options.
    public var attribution: Bool
    public var venue3D: Bool
    public var seatViewChrome: Bool
    public var systemBars: Bool
    /// Whether the map behind an open seat card is put behind blurred glass
    /// with a clear hole around the seat.
    public var seatCardGlass: Bool
    /// Whether a hold running down offers the buyer more time.
    ///
    /// Off on the phone: the countdown itself is the prompt there, and a
    /// second surface over a map the buyer is working in is one interruption
    /// too many. Set `phoneExtendHoldPrompt` to show it anyway.
    public var extendHoldPrompt: Bool
    public var phoneExtendHoldPrompt: Bool
    /// Dense phone chrome keeps these controls in their native sheets by
    /// default. Set the corresponding flag to expose the enabled control on
    /// the map as well; the original `overview`, `zoom`, and `colorblind`
    /// switches remain source-compatible master gates.
    public var phoneOverview: Bool
    public var phoneColorblind: Bool

    /// Retired. The phone's control column now carries `+` and the whole-venue
    /// disc for every buyer, so there is nothing left for this to reveal.
    ///
    /// Still stored and still read by `showsZoom(wide:)` for a host composing
    /// its own controls; the ready-made picker no longer consults it.
    @available(*, deprecated, message: "The phone column always carries the zoom controls.")
    public var phoneZoom: Bool {
        get { storedPhoneZoom }
        set { storedPhoneZoom = newValue }
    }

    /// Retired for the same reason as `phoneZoom`: the whole-venue disc is
    /// part of the phone column rather than an opt-in.
    @available(*, deprecated, message: "The phone column always carries the whole-venue control.")
    public var phoneFit: Bool {
        get { storedPhoneFit }
        set { storedPhoneFit = newValue }
    }

    private var storedPhoneZoom: Bool
    private var storedPhoneFit: Bool

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
        dock: Bool = false,
        confirmCard: Bool = true,
        holdPill: Bool = true,
        attribution: Bool = true,
        seatCardGlass: Bool = true,
        extendHoldPrompt: Bool = true,
        phoneExtendHoldPrompt: Bool = false,
        venue3D: Bool = true,
        seatViewChrome: Bool = true,
        systemBars: Bool = true,
        phoneOverview: Bool = false,
        phoneZoom: Bool = false,
        phoneColorblind: Bool = false,
        phoneFit: Bool = false
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
        self.seatCardGlass = seatCardGlass
        self.extendHoldPrompt = extendHoldPrompt
        self.phoneExtendHoldPrompt = phoneExtendHoldPrompt
        self.venue3D = venue3D
        self.seatViewChrome = seatViewChrome
        self.systemBars = systemBars
        self.phoneOverview = phoneOverview
        self.storedPhoneZoom = phoneZoom
        self.phoneColorblind = phoneColorblind
        self.storedPhoneFit = phoneFit
    }

    public func showsOverview(wide: Bool) -> Bool { overview && (wide || phoneOverview) }
    public func showsZoom(wide: Bool) -> Bool { zoom && (wide || storedPhoneZoom) }
    public func showsColorblind(wide: Bool) -> Bool { colorblind && (wide || phoneColorblind) }
    public func showsFit(wide: Bool) -> Bool { fit && (wide || storedPhoneFit) }
    public func showsExtendHoldPrompt(wide: Bool) -> Bool {
        extendHoldPrompt && (wide || phoneExtendHoldPrompt)
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
    /// The event's name, for chrome that has nothing else to print while the
    /// first snapshot is still on its way.
    public var eventName: String?
    /// Whether a seat someone else has already booked is drawn as booked
    /// rather than simply absent.
    public var showBookedOverlay: Bool
    /// Whether the buyer's colourblind-safe choice is remembered between
    /// sessions rather than asked for again each time.
    public var persistColorblindPreference: Bool
    public var panelInitiallyCollapsed: Bool
    public var refreshOnResume: Bool
    public var announceHoldLapse: Bool
    public var haptics: Bool
    public var languages: [String]
    public var pricing: SeatLayerPickerPricing?

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
        eventName: String? = nil,
        showBookedOverlay: Bool = true,
        persistColorblindPreference: Bool = true,
        panelInitiallyCollapsed: Bool = true,
        refreshOnResume: Bool = true,
        announceHoldLapse: Bool = true,
        haptics: Bool = true,
        languages: [String] = [],
        pricing: SeatLayerPickerPricing? = nil
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
        self.eventName = eventName
        self.showBookedOverlay = showBookedOverlay
        self.persistColorblindPreference = persistColorblindPreference
        self.panelInitiallyCollapsed = panelInitiallyCollapsed
        self.refreshOnResume = refreshOnResume
        self.announceHoldLapse = announceHoldLapse
        self.haptics = haptics
        self.languages = languages
        self.pricing = pricing
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
        if let normalizedHoldTtlMs { config["holdTtlMs"] = .int(normalizedHoldTtlMs) }
        if let normalizedInitialHoldId { config["initialHoldId"] = .string(normalizedInitialHoldId) }
        if let normalizedMax3DSeats { config["max3DSeats"] = .int(normalizedMax3DSeats) }
        if !normalizedLanguages.isEmpty {
            config["languages"] = .array(normalizedLanguages.map(JSONValue.string))
        }
        return config
    }

    var normalizedHoldTtlMs: Int? {
        holdTtlMs.flatMap { $0 > 0 ? $0 : nil }
    }

    private var normalizedInitialHoldId: String? {
        guard let initialHoldId else { return nil }
        let normalized = initialHoldId.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private var normalizedMax3DSeats: Int? {
        max3DSeats.flatMap { $0 > 0 ? $0 : nil }
    }

    private var normalizedLanguages: [String] {
        guard languages.count <= 64 else { return [] }
        var seen: Set<String> = []
        return languages.compactMap { language in
            let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: "-")
            let key = normalized.lowercased()
            guard !normalized.isEmpty, normalized.count <= 128, seen.insert(key).inserted else {
                return nil
            }
            return normalized
        }
    }
}
