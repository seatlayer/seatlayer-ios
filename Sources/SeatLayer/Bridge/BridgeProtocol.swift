import Foundation

/// Oldest protocol revision this SDK can speak.
public let seatLayerProtocolMin = 1
/// Newest protocol revision this SDK can speak.
public let seatLayerProtocolMax = 1

/// Protocol range as advertised by either side of the handshake.
public struct ProtocolRange: Sendable, Equatable, Codable {
    public var min: Int
    public var max: Int

    public init(min: Int, max: Int) {
        self.min = min
        self.max = max
    }

    /// This SDK's own range.
    public static let native = ProtocolRange(min: seatLayerProtocolMin, max: seatLayerProtocolMax)

    /// Normalise a `protocol` field that may be a bare number OR a `{min,max}`.
    public static func from(_ value: JSONValue?) -> ProtocolRange? {
        guard let value else { return nil }
        if case .int(let revision) = value { return ProtocolRange(min: revision, max: revision) }
        guard case .object(let fields) = value,
              case .int(let min)? = fields["min"],
              case .int(let max)? = fields["max"],
              min <= max
        else { return nil }
        return ProtocolRange(min: min, max: max)
    }

    var json: JSONValue { ["min": .int(min), "max": .int(max)] }
}

/// Result of intersecting the two sides' protocol ranges.
public enum Negotiation: Sendable, Equatable {
    case agreed(Int)
    case incompatible(reason: String)
}

/// Version negotiation by RANGE INTERSECTION.
///
/// The agreed revision is the highest both sides can speak — `min(aMax, bMax)`.
/// If that falls below EITHER side's minimum the ranges do not overlap and
/// there is no revision both understand, so the bridge refuses to render rather
/// than half-speaking a protocol.
///
/// Both upgrade directions are therefore safe:
///   - old app (max 1) + new bundle (1...3) → agreed 1, the bundle speaks down.
///   - new app (2...4) + old bundle (max 1) → agreed 1 < appMin 2 → incompatible.
public func negotiate(
    native: ProtocolRange = .native,
    web: ProtocolRange
) -> Negotiation {
    let agreed = Swift.min(native.max, web.max)
    guard agreed >= native.min, agreed >= web.min else {
        return .incompatible(
            reason: "no shared protocol revision (native \(native.min)..\(native.max), web \(web.min)..\(web.max))"
        )
    }
    return .agreed(agreed)
}

/// Bridge-level error codes.
///
/// Anything the underlying API returns (`sold_out`, …) passes through
/// unchanged, so this is an OPEN string set: only special-case the codes below.
public enum BridgeErrorCode {
    /// `t` is not in the bundle's command table.
    public static let unsupportedCommand = "unsupported_command"
    /// `p` failed the command's argument validation.
    public static let badPayload = "bad_payload"
    /// A command arrived before `sys.ready`.
    public static let notReady = "not_ready"
    /// A command arrived after the `destroy` command.
    public static let destroyed = "destroyed"
    /// Native-only: no reply arrived within the command timeout. This code has
    /// no web-side counterpart — the web bridge answers every `cmd`, so a
    /// missing reply means the WebView itself stalled or was torn down.
    public static let timeout = "sl_timeout"
}

/// One seat the server reported as no longer holdable — the `conflicts` an
/// availability failure (a 409) carries. Decoded leniently: the server's
/// vocabulary grows, and a missing or unfamiliar field must never turn a real
/// conflict into a decode failure.
public struct HoldConflict: Codable, Sendable, Equatable {
    /// The inventory label of the seat that conflicted (e.g. `A-1`).
    public var label: String?
    /// Why it conflicted, as the server named it (`booked`, `held`, …).
    public var status: String?

    public init(label: String? = nil, status: String? = nil) {
        self.label = label
        self.status = status
    }
}

/// Payload of an `err` envelope, and of the `sys.error` / `error` event.
public struct BridgeErrorPayload: Sendable, Equatable {
    public var code: String
    public var message: String
    public var details: JSONValue?

    public init(code: String, message: String, details: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }

    public init(_ value: JSONValue?) {
        self.code = value?["code"]?.stringValue ?? "unknown_error"
        self.message = value?["message"]?.stringValue ?? ""
        self.details = value?["details"]
    }

    /// The seats an availability failure (`sold_out`, `not_enough_together`, a
    /// hold 409) reported as already gone, or `nil` when the error carries none.
    ///
    /// The API nests these under `details.conflicts`; a decode is best-effort so
    /// one malformed entry never masks the rest.
    public var conflicts: [HoldConflict]? {
        guard let raw = details?["conflicts"]?.arrayValue, !raw.isEmpty else { return nil }
        let decoded = raw.compactMap { try? $0.decode(HoldConflict.self) }
        return decoded.isEmpty ? nil : decoded
    }
}
