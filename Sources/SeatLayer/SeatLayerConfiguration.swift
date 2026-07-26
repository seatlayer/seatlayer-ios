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
    /// Reserved for future authenticated rendering.
    public var publicKey: String?
    /// Max seats selectable at once (web default 10).
    public var maxSelection: Int?
    /// BCP 47 language for the widget UI — `de`, `es-MX`, … Built-in: en, es,
    /// de, fr. Defaults to the device language.
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

    /// Native-side deadline for a single command before it fails `sl_timeout`.
    public var commandTimeout: TimeInterval = BridgeClient.defaultTimeout
    /// How long to wait for `sys.ready` before failing the load.
    public var handshakeTimeout: TimeInterval = 30
    /// Free-form host identification sent in `init.host`, for server-side and
    /// bundle-side diagnostics.
    public var hostInfo: [String: String] = [:]

    /// Override the page the WebView loads. Defaults to the bundled
    /// `index.html`. Used by the demo app to load a self-contained fixture page.
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
        showsWebSeatTooltip: Bool = false
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

        return [
            "protocol": protocolRange.json,
            "host": .object(host),
            "chrome": ["seatTooltip": .bool(showsWebSeatTooltip)],
            "config": .object(config),
        ]
    }
}

public enum SeatLayer {
    /// This SDK's version.
    public static let sdkVersion = "0.1.0"
    /// The web bundle vendored into this package.
    public static let bundledWebVersion = "0.29.0"
}
