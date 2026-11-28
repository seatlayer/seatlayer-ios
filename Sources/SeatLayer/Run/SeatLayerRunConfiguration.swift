import Foundation

/// Everything needed to open the run page: a few performances of one run,
/// chosen by one buyer.
///
/// The page draws the run. The app draws its bar (brand, name, hold clock,
/// close) and takes the buyer to its own checkout.
public struct SeatLayerRunConfiguration: Sendable {
    /// Run key, e.g. `pg_xxx`. Required.
    public var run: String
    /// API origin. Defaults to `https://api.seatlayer.io`.
    public var apiBase: String?
    /// The same seat at every performance, or seats chosen per performance.
    public var selectionMode: SeatLayerRunSelectionMode?
    /// Whether the buyer may switch between the two.
    public var allowSelectionModeSwitch: Bool?
    /// How many places the buyer takes. Required with per-performance
    /// selection or the switch.
    public var numberOfPlacesToSelect: Int?
    /// Most seats selectable at once.
    public var maxSelection: Int?
    /// One-shot private-inventory bearer. Prefer `buyerAccessTokenProvider`.
    public var buyerAccessToken: BuyerAccessToken?
    /// Called in memory whenever private buyer access needs a fresh bearer.
    public var buyerAccessTokenProvider: BuyerAccessTokenProvider?
    /// Takes up a hold this buyer already has. Comes with `initialOperationId`.
    public var initialHoldId: String?
    /// The operation of `initialHoldId`.
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
    /// Override the page. Production loads the hosted run page.
    public var pageURL: URL?

    /// The hosted run page at the pinned map.
    public static let defaultPageURL = URL(
        string: "\(SeatLayer.mobileOrigin)/seatlayer-js@\(SeatLayer.hostedWebVersion)/group.html"
    )!

    public init(
        run: String,
        apiBase: String? = nil,
        selectionMode: SeatLayerRunSelectionMode? = nil,
        allowSelectionModeSwitch: Bool? = nil,
        numberOfPlacesToSelect: Int? = nil,
        maxSelection: Int? = nil,
        buyerAccessToken: BuyerAccessToken? = nil,
        buyerAccessTokenProvider: BuyerAccessTokenProvider? = nil,
        initialHoldId: String? = nil,
        initialOperationId: String? = nil,
        locale: String? = nil,
        colorblindSafe: Bool? = nil,
        enable3D: Bool? = nil
    ) {
        self.run = run
        self.apiBase = apiBase
        self.selectionMode = selectionMode
        self.allowSelectionModeSwitch = allowSelectionModeSwitch
        self.numberOfPlacesToSelect = numberOfPlacesToSelect
        self.maxSelection = maxSelection
        self.buyerAccessToken = buyerAccessToken
        self.buyerAccessTokenProvider = buyerAccessTokenProvider
        self.initialHoldId = initialHoldId
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
        if run.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw refuse("SeatLayer run must not be empty.")
        }
        if let maxSelection, maxSelection < 1 {
            throw refuse("SeatLayer maxSelection must be a positive integer.")
        }
        if let numberOfPlacesToSelect, numberOfPlacesToSelect < 1 {
            throw refuse("SeatLayer numberOfPlacesToSelect must be a positive integer.")
        }
        if (selectionMode == .perPerformance || allowSelectionModeSwitch == true),
           numberOfPlacesToSelect == nil {
            throw refuse("SeatLayer numberOfPlacesToSelect is required with per-performance selection or the switch.")
        }
        if (initialHoldId == nil) != (initialOperationId == nil) {
            throw refuse("SeatLayer initialHoldId and initialOperationId come both or neither.")
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
            "performanceGroup": .string(run),
            "apiBase": apiBase.map(JSONValue.string),
            "selectionMode": selectionMode.map { .string($0.rawValue) },
            "allowSelectionModeSwitch": allowSelectionModeSwitch.map(JSONValue.bool),
            "numberOfPlacesToSelect": numberOfPlacesToSelect.map(JSONValue.int),
            "maxSelection": maxSelection.map(JSONValue.int),
            "buyerAccessToken": buyerAccessToken?.jsonValue(),
            "nativeAccessProvider": buyerAccessTokenProvider == nil ? nil : .bool(true),
            "initialHoldId": initialHoldId.map(JSONValue.string),
            "initialOperationId": initialOperationId.map(JSONValue.string),
            "locale": locale.map(JSONValue.string),
            "colorblindSafe": colorblindSafe.map(JSONValue.bool),
            "enable3D": enable3D.map(JSONValue.bool),
            // The app's bar is the only one, with the name, the clock and the
            // close button; checkout is the app's.
            "header": .bool(false),
            "appBar": .bool(true),
            "checkout": .string("handoff"),
        ])
        return [
            "protocol": protocolRange.json,
            "host": .object(host),
            "config": config,
        ]
    }
}

extension SeatLayerRunConfiguration: SeatLayerSurfaceLoading {
    var resolvedPageURL: URL { pageURL ?? Self.defaultPageURL }
    /// The run page takes buyer access from its own config, asking for tokens
    /// as the event page does, and checks its own selection rules: it needs
    /// neither of the event page's features for them.
    func compatibilityProblem(with bundle: BundleInfo) -> String? { nil }
}
