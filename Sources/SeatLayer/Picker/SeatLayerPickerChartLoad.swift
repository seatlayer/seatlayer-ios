import Foundation

/// Open runtime-owned chart-load trace. Unknown JSON fields remain in `raw`.
/// The SDK does not log or transmit this value.
public struct SeatLayerChartLoadTrace: Sendable, Equatable {
    public let raw: [String: JSONValue]
    public let event: String?
    public let scope: String?
    public let surface: String?
    public let outcome: String?
    public let stage: String?
    public let ms: Int?
    public let api: Int?
    public let scene: Int?
    public let panel: Int?
    public let paint: Int?
    public let normalize: Int?
    public let renderer: Int?
    public let availabilityMs: Int?
    public let seats: Int?
    public let floors: Int?
    public let view: String?
    public let load: String?
    public let transport: String?
    public let chartBytes: Int?
    public let chartCache: String?
    public let server: Int?
    public let r2Head: Int?
    public let cacheLookup: Int?
    public let r2Get: Int?
    public let transform: Int?
    public let host: String?
    public let platform: String?
    public let bundle: String?
    public let protocolRevision: Int?
    public let chromeOwner: String?
    public let bootMs: Int?
    public let documentMs: Int?
    public let handshakeMs: Int?

    public var succeeded: Bool { outcome == nil || outcome == "success" }
}

/// Runtime and native halves of one render attempt.
public struct SeatLayerChartLoad: Sendable, Equatable {
    public let trace: SeatLayerChartLoadTrace
    public let tapToReadyMs: Int?
    public let ready: ReadyInfo?

    public init(
        trace: SeatLayerChartLoadTrace,
        tapToReadyMs: Int? = nil,
        ready: ReadyInfo? = nil
    ) {
        self.trace = trace
        self.tapToReadyMs = tapToReadyMs
        self.ready = ready
    }

    public var hostMs: Int? {
        guard let tapToReadyMs, let bootMs = trace.bootMs else { return nil }
        return max(0, tapToReadyMs - bootMs)
    }
}

/// Decodes only the `trace` nested in a `telemetry.chartLoad` event.
public func decodeSeatLayerChartLoadEvent(
    _ payload: JSONValue?
) -> SeatLayerChartLoadTrace? {
    decodeSeatLayerChartLoadTrace(payload?["trace"])
}

/// Decodes an additive trace without treating unknown fields as failure.
public func decodeSeatLayerChartLoadTrace(
    _ value: JSONValue?
) -> SeatLayerChartLoadTrace? {
    guard let raw = value?.objectValue else { return nil }
    func string(_ key: String) -> String? { raw[key]?.stringValue }
    func integer(_ key: String) -> Int? {
        guard let number = raw[key]?.doubleValue,
              number.isFinite,
              number >= 0,
              number.rounded() == number,
              number <= Double(Int.max) else { return nil }
        return Int(number)
    }
    return SeatLayerChartLoadTrace(
        raw: raw,
        event: string("event"),
        scope: string("scope"),
        surface: string("surface"),
        outcome: string("outcome"),
        stage: string("stage"),
        ms: integer("ms"),
        api: integer("api"),
        scene: integer("scene"),
        panel: integer("panel"),
        paint: integer("paint"),
        normalize: integer("normalize"),
        renderer: integer("renderer"),
        availabilityMs: integer("availabilityMs"),
        seats: integer("seats"),
        floors: integer("floors"),
        view: string("view"),
        load: string("load"),
        transport: string("transport"),
        chartBytes: integer("chartBytes"),
        chartCache: string("chartCache"),
        server: integer("server"),
        r2Head: integer("r2Head"),
        cacheLookup: integer("cacheLookup"),
        r2Get: integer("r2Get"),
        transform: integer("transform"),
        host: string("host"),
        platform: string("platform"),
        bundle: string("bundle"),
        protocolRevision: integer("protocol"),
        chromeOwner: string("chromeOwner"),
        bootMs: integer("bootMs"),
        documentMs: integer("documentMs"),
        handshakeMs: integer("handshakeMs")
    )
}
