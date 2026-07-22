import Foundation

/// Every failure this SDK surfaces.
public enum SeatLayerError: Error, Sendable, Equatable {
    /// The web side answered a command with `err`, or emitted `sys.error`.
    /// `code` is an OPEN set: bridge codes (`bad_payload`, `not_ready`, …) and
    /// API codes (`sold_out`, …) both arrive here unchanged.
    case bridge(BridgeErrorPayload)

    /// No `res`/`err` arrived for a command within the timeout. Reported with
    /// `BridgeErrorCode.timeout`.
    case timeout(command: String, seconds: TimeInterval)

    /// The two protocol ranges do not intersect — there is no revision both
    /// sides understand. The correct remedy is a version change, not a retry,
    /// so this is typed separately rather than folded into `.bridge`.
    case incompatible(native: ProtocolRange, web: ProtocolRange, reason: String)

    /// The handshake did not complete within the configured window.
    case handshakeTimeout(seconds: TimeInterval)

    /// The view was torn down, or `destroy()` was called, before the command
    /// could complete.
    case destroyed

    /// The WebView could not be driven (script evaluation failed, no web view).
    case transport(String)

    /// A reply arrived but did not match the expected shape.
    case decoding(String)

    /// The bundled web asset is missing from the package resources.
    case missingResource(String)
}

extension SeatLayerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .bridge(let payload):
            return "SeatLayer bridge error [\(payload.code)]: \(payload.message)"
        case .timeout(let command, let seconds):
            return "SeatLayer command `\(command)` timed out after \(seconds)s (\(BridgeErrorCode.timeout))"
        case .incompatible(let native, let web, let reason):
            return """
            SeatLayer is out of date and cannot run this seat map. \
            This app speaks protocol \(native.min)–\(native.max); the seat map bundle speaks \
            \(web.min)–\(web.max). Please update the app. (\(reason))
            """
        case .handshakeTimeout(let seconds):
            return "SeatLayer seat map did not start within \(seconds)s"
        case .destroyed:
            return "SeatLayer view has been destroyed"
        case .transport(let detail):
            return "SeatLayer transport failure: \(detail)"
        case .decoding(let detail):
            return "SeatLayer could not decode a bridge reply: \(detail)"
        case .missingResource(let name):
            return "SeatLayer package resource `\(name)` is missing from the bundle"
        }
    }

    /// The wire code, for callers that branch on the open code set.
    public var code: String {
        switch self {
        case .bridge(let payload): return payload.code
        case .timeout: return BridgeErrorCode.timeout
        case .incompatible: return "sl_incompatible"
        case .handshakeTimeout: return "sl_handshake_timeout"
        case .destroyed: return BridgeErrorCode.destroyed
        case .transport: return "sl_transport"
        case .decoding: return "sl_decoding"
        case .missingResource: return "sl_missing_resource"
        }
    }

    /// True when the user needs a new build of the app — the one failure that no
    /// amount of retrying will fix.
    public var requiresAppUpdate: Bool {
        if case .incompatible = self { return true }
        return false
    }

    /// The seats an availability failure reported as already taken, when the
    /// error carries them (a `bestAvailable` / `hold` / `holdGA` 409). `nil` for
    /// every other failure. Lets a caller show "A-1, A-2 were just taken"
    /// straight from the thrown error, without reaching into `details`.
    public var conflicts: [HoldConflict]? {
        if case .bridge(let payload) = self { return payload.conflicts }
        return nil
    }
}
