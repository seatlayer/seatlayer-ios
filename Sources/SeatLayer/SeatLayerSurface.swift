import Foundation

/// What a view needs to load one hosted surface: the event picker's page or
/// the run page.
protocol SeatLayerSurfaceLoading: Sendable {
    /// The page the view loads.
    var resolvedPageURL: URL { get }
    var commandTimeout: TimeInterval { get }
    var handshakeTimeout: TimeInterval { get }
    var buyerAccessTokenProvider: BuyerAccessTokenProvider? { get }
    func initPayload(protocolRange: ProtocolRange) -> JSONValue
    /// Why the loaded page cannot serve this configuration, or nil.
    func compatibilityProblem(with bundle: BundleInfo) -> String?
}

extension SeatLayerConfiguration: SeatLayerSurfaceLoading {
    var resolvedPageURL: URL { pageURL ?? SeatLayer.mobilePageURL }

    func compatibilityProblem(with bundle: BundleInfo) -> String? {
        if usesPrivateAccess, !bundle.supports(capability: "native-access-provider") {
            return "the bundle does not support private buyer access"
        }
        if usesSelectionPolicy,
           !bundle.supports(capability: "selection-controls")
            || !bundle.supports(capability: "selection-validity") {
            return "the bundle does not support the configured selection policy"
        }
        return nil
    }
}

/// The native side of one hosted surface. The view drives the handshake and
/// hands every step and every event of its own page to the session.
@MainActor
protocol SeatLayerSurfaceSession: AnyObject {
    func sessionBeginLoading(owner: UUID?)
    func sessionConnect(
        transport: any SeatLayerPickerCommandTransport,
        bundleInfo: BundleInfo,
        owner: UUID?
    )
    func sessionReady(_ info: ReadyInfo, payload: JSONValue?, owner: UUID?)
    func sessionFailed(_ error: SeatLayerError, owner: UUID?)
    func sessionConnection(_ payload: JSONValue?, owner: UUID?)
    func sessionDestroyed(owner: UUID?)
    /// An event of the surface the view does not handle itself.
    func sessionEvent(_ name: String, payload: JSONValue?, owner: UUID?)
}

extension SeatLayerPickerController: SeatLayerSurfaceSession {
    func sessionBeginLoading(owner: UUID?) { beginLoading(owner: owner) }

    func sessionConnect(
        transport: any SeatLayerPickerCommandTransport,
        bundleInfo: BundleInfo,
        owner: UUID?
    ) {
        connect(transport: transport, bundleInfo: bundleInfo, owner: owner)
    }

    func sessionReady(_ info: ReadyInfo, payload: JSONValue?, owner: UUID?) {
        markReady(info, payload: payload, owner: owner)
    }

    func sessionFailed(_ error: SeatLayerError, owner: UUID?) { fail(error, owner: owner) }

    func sessionConnection(_ payload: JSONValue?, owner: UUID?) {
        accept(connection: payload, owner: owner)
    }

    func sessionDestroyed(owner: UUID?) { markDestroyed(owner: owner) }

    /// The picker's own events are read by the view.
    func sessionEvent(_ name: String, payload: JSONValue?, owner: UUID?) {}
}
