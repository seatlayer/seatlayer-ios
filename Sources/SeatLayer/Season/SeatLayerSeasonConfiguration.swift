import Foundation

/// Everything needed to open a Season: a package of dates, sold as the same
/// seat for every date, with your app's own checkout.
///
/// The page draws the package, the dates, the map and the cart. The app draws
/// its bar (brand, the Season's name, hold clock, close).
public struct SeatLayerSeasonConfiguration: Sendable {
    /// Season key, e.g. `sea_xxx`. Required.
    public var season: String
    /// API origin. Defaults to `https://api.seatlayer.io`.
    public var apiBase: String?
    /// Publishable `pk_` key for a public Season. For a members-only Season
    /// use `buyerAccessTokenProvider` instead.
    public var publicKey: String?
    /// The package to open on, by its key. Without it, or for a key not on
    /// sale, the Season opens on its first package. Ignored with a buyer
    /// access token, which is bound to one package.
    public var package: String?
    /// The price types the buyer may choose per seat (`adult`, `child`, …),
    /// for a package priced by type. Nil or `["adult"]`: every seat is adult.
    public var priceTypes: [String]?
    /// Your checkout emails a ticket for every date, so the first step says so.
    public var ticketsByEmail: Bool?
    /// Most seats the buyer may hold at once.
    public var maxSelection: Int?
    /// One-shot private buyer bearer. Prefer `buyerAccessTokenProvider`.
    public var buyerAccessToken: BuyerAccessToken?
    /// Called in memory whenever private buyer access needs a fresh bearer.
    public var buyerAccessTokenProvider: BuyerAccessTokenProvider?
    /// A hold your app already has, by its `sop_` operation id: the page opens
    /// on it instead of starting a new one. Only the buyer who placed it gets
    /// it back, so pass that buyer's token too.
    public var initialOperationId: String?
    /// BCP-47 language for the page. Defaults to the device language.
    public var locale: String?
    /// Colorblind-safe rendering.
    public var colorblindSafe: Bool?
    /// Whether the page offers its 3D view.
    public var enable3D: Bool?
    /// Native-side deadline for a single command.
    public var commandTimeout: TimeInterval = BridgeClient.defaultTimeout
    /// How long to wait for the page to be ready.
    public var handshakeTimeout: TimeInterval = 45
    /// Free-form host identification sent in `init.host`.
    public var hostInfo: [String: String] = [:]
    /// Override the page. Production loads the hosted Season page.
    public var pageURL: URL?

    /// The hosted Season page at the pinned map.
    public static let defaultPageURL = URL(
        string: "\(SeatLayer.mobileOrigin)/seatlayer-js@\(SeatLayer.hostedWebVersion)/season.html"
    )!

    public init(
        season: String,
        apiBase: String? = nil,
        publicKey: String? = nil,
        package: String? = nil,
        priceTypes: [String]? = nil,
        ticketsByEmail: Bool? = nil,
        maxSelection: Int? = nil,
        buyerAccessToken: BuyerAccessToken? = nil,
        buyerAccessTokenProvider: BuyerAccessTokenProvider? = nil,
        initialOperationId: String? = nil,
        locale: String? = nil,
        colorblindSafe: Bool? = nil,
        enable3D: Bool? = nil
    ) {
        self.season = season
        self.apiBase = apiBase
        self.publicKey = publicKey
        self.package = package
        self.priceTypes = priceTypes
        self.ticketsByEmail = ticketsByEmail
        self.maxSelection = maxSelection
        self.buyerAccessToken = buyerAccessToken
        self.buyerAccessTokenProvider = buyerAccessTokenProvider
        self.initialOperationId = initialOperationId
        self.locale = locale
        self.colorblindSafe = colorblindSafe
        self.enable3D = enable3D
    }

    /// Throws `bad_payload` for what the page would refuse, mounting nothing.
    public func validate() throws {
        func refuse(_ message: String) -> SeatLayerError {
            .bridge(.init(code: BridgeErrorCode.badPayload, message: message))
        }
        if season.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw refuse("SeatLayer season must not be empty.")
        }
        if let maxSelection, maxSelection < 1 {
            throw refuse("SeatLayer maxSelection must be a positive integer.")
        }
        if let buyerAccessToken,
           buyerAccessToken.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || buyerAccessToken.expiresAt.map({ !$0.isFinite }) == true {
            throw refuse("SeatLayer buyerAccessToken is invalid.")
        }
    }

    /// The `init` payload: `{ protocol, host, config }`.
    func initPayload(protocolRange: ProtocolRange = ProtocolRange(min: 2, max: 2)) -> JSONValue {
        var host: [String: JSONValue] = [
            "platform": .string("ios"),
            "sdk": .string(SeatLayer.sdkVersion),
        ]
        for (key, value) in hostInfo { host[key] = .string(value) }

        let config = JSONValue.object(compacting: [
            "season": .string(season),
            "apiBase": apiBase.map(JSONValue.string),
            "publicKey": publicKey.map(JSONValue.string),
            "package": package.map(JSONValue.string),
            "priceTypes": priceTypes.map { .array($0.map(JSONValue.string)) },
            "ticketsByEmail": ticketsByEmail.map(JSONValue.bool),
            "maxSelection": maxSelection.map(JSONValue.int),
            "buyerAccessToken": buyerAccessToken?.jsonValue(),
            "nativeAccessProvider": buyerAccessTokenProvider == nil ? nil : .bool(true),
            "initialOperationId": initialOperationId.map(JSONValue.string),
            "locale": locale.map(JSONValue.string),
            "colorblindSafe": colorblindSafe.map(JSONValue.bool),
            "enable3D": enable3D.map(JSONValue.bool),
            // The app's bar is the only one, with the name, the clock and the
            // close button.
            "appBar": .bool(true),
        ])
        return [
            "protocol": protocolRange.json,
            "host": .object(host),
            "config": config,
        ]
    }
}

extension SeatLayerSeasonConfiguration: SeatLayerSurfaceLoading {
    var resolvedPageURL: URL { pageURL ?? Self.defaultPageURL }
    /// The Season page takes buyer access from its own config, asking for
    /// tokens as the event page does: it needs none of the event page's
    /// features.
    func compatibilityProblem(with bundle: BundleInfo) -> String? { nil }
}
