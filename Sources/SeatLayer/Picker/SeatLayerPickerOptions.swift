import Foundation

/// Renders one authoritative runtime amount in native picker chrome.
/// A throwing or blank result falls back to the SDK's locale-aware formatter.
public typealias SeatLayerPickerMoneyFormatter = @Sendable (
    _ amount: Double,
    _ currency: String
) throws -> String

/// The page's word for taking the app's prices: in `init.config.pricing` at
/// load, and through `picker.setPricing` while it is open.
let seatLayerHostPricingCapability = "host-pricing-v1"

/// One category's price, or a price for each of its ticket types.
public struct SeatLayerCategoryPricing: Sendable, Equatable {
    /// The price without ticket types, and of a type `tiers` leaves out.
    public var base: Double?
    /// Price by ticket type id.
    public var tiers: [String: Double]

    public init(base: Double? = nil, tiers: [String: Double] = [:]) {
        self.base = base
        self.tiers = tiers
    }

    /// The page's shape: a bare number for one price, else `{ base, tiers }`;
    /// nil when nothing here is a price.
    var bridgeValue: JSONValue? {
        let base = seatLayerHostPrice(base)
        guard let tiers = seatLayerHostPrices(tiers) else { return base.map(JSONValue.double) }
        return .object(compacting: ["base": base.map(JSONValue.double), "tiers": tiers])
    }
}

/// One seat's or table's price, or a price for each ticket type. A seat has no
/// base price.
public struct SeatLayerSeatPricing: Sendable, Equatable {
    /// The seat's price whatever the ticket type.
    public var price: Double?
    /// Price by ticket type id; empty when `price` is set.
    public var tiers: [String: Double]

    /// One price for this seat.
    public init(_ price: Double) {
        self.init(price: price, tiers: [:])
    }

    /// One price for each ticket type of this seat.
    public static func tiers(_ tiers: [String: Double]) -> Self {
        Self(price: nil, tiers: tiers)
    }

    private init(price: Double?, tiers: [String: Double]) {
        self.price = price
        self.tiers = tiers
    }

    /// The page's shape: a bare number, else `{ tiers }`; nil when nothing
    /// here is a price.
    var bridgeValue: JSONValue? {
        if let price = seatLayerHostPrice(price) { return .double(price) }
        return seatLayerHostPrices(tiers).map { .object(["tiers": $0]) }
    }
}

/// The app's own prices and money writing, both for display: the hold is
/// still priced by the server.
///
/// `categories` are the prices the buyer is shown — on the price rail, the
/// seat card, the cart and the checkout handoff — in place of the chart's own;
/// a category left out keeps the chart's price. `objects` price single seats
/// and tables by their `label`, the booking identity, and win over their
/// category's price. A page without `host-pricing-v1` keeps the chart's
/// prices. Change them on the open map with
/// `SeatLayerPickerController.setPricing(_:)`.
public struct SeatLayerPickerPricing: Sendable, Equatable {
    /// Prices by category key.
    public var categories: [String: SeatLayerCategoryPricing]
    /// Prices of single seats and tables, by their `label`.
    public var objects: [String: SeatLayerSeatPricing]
    /// How every amount in the native chrome is written.
    public var formatter: SeatLayerPickerMoneyFormatter? {
        didSet { formatterIdentity = formatter == nil ? nil : UUID() }
    }

    private var formatterIdentity: UUID?

    public init(
        categories: [String: SeatLayerCategoryPricing] = [:],
        objects: [String: SeatLayerSeatPricing] = [:],
        formatter: SeatLayerPickerMoneyFormatter? = nil
    ) {
        self.categories = categories
        self.objects = objects
        self.formatter = formatter
        formatterIdentity = formatter == nil ? nil : UUID()
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.formatterIdentity == rhs.formatterIdentity
            && lhs.categories == rhs.categories
            && lhs.objects == rhs.objects
    }

    /// The page's `pricing` value: `{ prices, objects }`, each only where it
    /// holds a price, or nil when nothing sets one. Anything that is not a
    /// price — negative, not finite, or under an empty key — is left out.
    var bridgeValue: JSONValue? {
        let prices = seatLayerHostEntries(categories.mapValues(\.bridgeValue))
        let seats = seatLayerHostEntries(objects.mapValues(\.bridgeValue))
        guard prices != nil || seats != nil else { return nil }
        return .object(compacting: ["prices": prices, "objects": seats])
    }
}

/// A price the page can use: finite and not negative.
private func seatLayerHostPrice(_ value: Double?) -> Double? {
    guard let value, value.isFinite, value >= 0 else { return nil }
    return value
}

/// Usable prices by id, or nil when none is usable.
private func seatLayerHostPrices(_ values: [String: Double]) -> JSONValue? {
    seatLayerHostEntries(values.mapValues { seatLayerHostPrice($0).map(JSONValue.double) })
}

/// The entries with a key and a value, or nil when none has both.
private func seatLayerHostEntries(_ values: [String: JSONValue?]) -> JSONValue? {
    var kept: [String: JSONValue] = [:]
    for (key, value) in values where !key.isEmpty {
        if let value { kept[key] = value }
    }
    return kept.isEmpty ? nil : .object(kept)
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

/// How fingers move the 3D venue.
public enum SeatLayer3DTouchNavigation: String, Sendable, Equatable {
    /// One finger moves the view, a pinch zooms, a two-finger twist turns the
    /// venue and a two-finger drag tilts it. The map's default.
    case map
    /// The earlier gestures, with the Rotate / Move control they need.
    case classic
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
    /// Whether the 3D venue draws its standing crowd.
    public var enable3DCrowd: Bool
    /// How fingers move the 3D venue. `nil` takes the map's default, `.map`.
    /// `.classic` keeps the earlier gestures and draws the Rotate / Move
    /// control they need.
    public var touchNavigation3D: SeatLayer3DTouchNavigation?
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
        enable3DCrowd: Bool = true,
        touchNavigation3D: SeatLayer3DTouchNavigation? = nil,
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
        self.enable3DCrowd = enable3DCrowd
        self.touchNavigation3D = touchNavigation3D
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
        if !enable3DCrowd { config["enable3DCrowd"] = .bool(false) }
        if let touchNavigation3D { config["touchNavigation3D"] = .string(touchNavigation3D.rawValue) }
        if !normalizedLanguages.isEmpty {
            config["languages"] = .array(normalizedLanguages.map(JSONValue.string))
        }
        if let pricing = pricing?.bridgeValue { config["pricing"] = pricing }
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
