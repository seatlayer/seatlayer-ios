import Foundation

/// Everything needed to boot a seat map.
///
/// Field names mirror the web `SeatingChart` options so the two SDKs read as
/// one product.
public struct SeatLayerConfiguration: Sendable {
    /// Event key, e.g. `ev_xxx`. Required.
    public var event: String
    /// API origin. Defaults to `https://api.seatlayer.io`.
    public var apiBase: String?
    /// Optional public rendering key.
    public var publicKey: String?
    /// Max seats selectable at once (web default 10).
    public var maxSelection: Int?
    /// BCP-47 language for the widget UI — `de`, `es-MX`, … The native picker
    /// ships the same 37-locale catalog as Flutter and React Native and falls
    /// back through language then English. Defaults to the device language.
    public var locale: String?
    /// Per-key string overrides layered over the active locale.
    public var messages: [String: String]?
    /// ISO 4217 currency for on-map prices (web default USD).
    public var currency: String?
    /// Colorblind-safe rendering: category hues switch to an Okabe-Ito palette
    /// and booked seats render hollow, so state never relies on hue alone.
    public var colorblindSafe: Bool?
    /// Initial canvas projection. Defaults to `.flat`.
    public var initialView: SeatLayerViewMode?
    /// Whether the WEB side draws its in-canvas seat tooltip. Leave `false` when
    /// the app presents its own seat sheet natively — the default here, because
    /// a hover tooltip is a pointer affordance that does not belong on touch.
    public var showsWebSeatTooltip: Bool = false
    /// One-shot private-inventory bearer. Prefer `buyerAccessTokenProvider` so
    /// the picker can renew without rebuilding the view.
    public var buyerAccessToken: BuyerAccessToken?
    /// Called in memory whenever private buyer access needs a fresh bearer.
    /// Bearers are never put in URLs, logs, events, or persistent storage.
    public var buyerAccessTokenProvider: BuyerAccessTokenProvider?
    /// Objects selected as soon as the chart is ready (id or public label).
    public var selectedObjects: [String]?
    /// Restrict buyer selection to these objects. `nil` means unrestricted.
    public var selectableObjects: [String]?
    /// Exact guest count required before the selection is valid.
    public var numberOfPlacesToSelect: Int?
    /// Additional data-only selection rules enforced by the shared picker.
    public var selectionValidators: [SelectionValidator]?

    /// Native-side deadline for a single command before it fails `sl_timeout`.
    public var commandTimeout: TimeInterval = BridgeClient.defaultTimeout
    /// How long to wait for `sys.ready` before failing the load.
    public var handshakeTimeout: TimeInterval = 30
    /// Free-form host identification sent in `init.host`, for server-side and
    /// bundle-side diagnostics.
    public var hostInfo: [String: String] = [:]

    /// Override the page the WebView loads. Production defaults to the immutable
    /// hosted mobile page. Demos may supply a self-contained local fixture.
    public var pageURL: URL?

    public init(
        event: String,
        apiBase: String? = nil,
        publicKey: String? = nil,
        maxSelection: Int? = nil,
        locale: String? = nil,
        messages: [String: String]? = nil,
        currency: String? = nil,
        colorblindSafe: Bool? = nil,
        initialView: SeatLayerViewMode? = nil,
        showsWebSeatTooltip: Bool = false,
        buyerAccessToken: BuyerAccessToken? = nil,
        buyerAccessTokenProvider: BuyerAccessTokenProvider? = nil,
        selectedObjects: [String]? = nil,
        selectableObjects: [String]? = nil,
        numberOfPlacesToSelect: Int? = nil,
        selectionValidators: [SelectionValidator]? = nil
    ) {
        self.event = event
        self.apiBase = apiBase
        self.publicKey = publicKey
        self.maxSelection = maxSelection
        self.locale = locale
        self.messages = messages
        self.currency = currency
        self.colorblindSafe = colorblindSafe
        self.initialView = initialView
        self.showsWebSeatTooltip = showsWebSeatTooltip
        self.buyerAccessToken = buyerAccessToken
        self.buyerAccessTokenProvider = buyerAccessTokenProvider
        self.selectedObjects = selectedObjects
        self.selectableObjects = selectableObjects
        self.numberOfPlacesToSelect = numberOfPlacesToSelect
        self.selectionValidators = selectionValidators
    }

    /// The `init` payload: `{ protocol, host, chrome, config }`.
    func initPayload(protocolRange: ProtocolRange = .native) -> JSONValue {
        var host: [String: JSONValue] = [
            "platform": .string("ios"),
            "sdk": .string(SeatLayer.sdkVersion),
        ]
        for (key, value) in hostInfo { host[key] = .string(value) }

        var config: [String: JSONValue] = ["event": .string(event)]
        if let apiBase { config["apiBase"] = .string(apiBase) }
        if let publicKey { config["publicKey"] = .string(publicKey) }
        if let maxSelection { config["maxSelection"] = .int(maxSelection) }
        if let locale { config["locale"] = .string(locale) }
        if let currency { config["currency"] = .string(currency) }
        if let colorblindSafe { config["colorblindSafe"] = .bool(colorblindSafe) }
        if let initialView { config["initialView"] = .string(initialView.rawValue) }
        if let messages {
            config["messages"] = .object(messages.mapValues { JSONValue.string($0) })
        }
        if let buyerAccessToken { config["buyerAccessToken"] = buyerAccessToken.jsonValue() }
        if buyerAccessTokenProvider != nil { config["nativeAccessProvider"] = .bool(true) }
        if let selectedObjects {
            config["selectedObjects"] = .array(selectedObjects.map(JSONValue.string))
        }
        if let selectableObjects {
            config["selectableObjects"] = .array(selectableObjects.map(JSONValue.string))
        }
        if let numberOfPlacesToSelect {
            config["numberOfPlacesToSelect"] = .int(numberOfPlacesToSelect)
        }
        if let selectionValidators {
            config["selectionValidators"] = .array(selectionValidators.map { $0.jsonValue() })
        }

        return [
            "protocol": protocolRange.json,
            "host": .object(host),
            "chrome": ["seatTooltip": .bool(showsWebSeatTooltip)],
            "config": .object(config),
        ]
    }

    var usesPrivateAccess: Bool {
        buyerAccessToken != nil || buyerAccessTokenProvider != nil
    }

    var usesSelectionPolicy: Bool {
        selectedObjects != nil || selectableObjects != nil
            || numberOfPlacesToSelect != nil || selectionValidators != nil
    }
}

public enum SeatLayer {
    /// This SDK's version.
    public static let sdkVersion = "0.3.0"
    /// Immutable hosted runtime loaded by production views.
    public static let hostedWebVersion = "0.71.5"
    /// Runtime retained only for explicit offline demo/test fixtures.
    public static let legacyFixtureWebVersion = "0.59.0"
    @available(*, deprecated, renamed: "hostedWebVersion")
    public static let bundledWebVersion = hostedWebVersion
    public static let mobileOrigin = "https://cdn.seatlayer.io"
    public static let mobilePageURL = URL(
        string: "https://cdn.seatlayer.io/seatlayer-js@\(hostedWebVersion)/mobile.html"
    )!
}
