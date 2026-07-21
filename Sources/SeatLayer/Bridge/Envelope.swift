import Foundation

/// Envelope kind.
///
/// `unknown` exists because a bundle newer than this app may introduce a kind
/// this build has never heard of. Decoding must yield a value, never throw —
/// the router then ignores what it cannot act on.
public enum EnvelopeKind: Sendable, Hashable {
    /// web→native: handshake opener.
    case hello
    /// native→web: handshake reply.
    case initialize
    /// native→web: a correlated command.
    case cmd
    /// web→native: the success reply to one `cmd`.
    case res
    /// web→native: the failure reply to one `cmd`.
    case err
    /// web→native: an unsolicited event carrying a monotonic sequence.
    case evt
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "hello": self = .hello
        case "init": self = .initialize
        case "cmd": self = .cmd
        case "res": self = .res
        case "err": self = .err
        case "evt": self = .evt
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .hello: return "hello"
        case .initialize: return "init"
        case .cmd: return "cmd"
        case .res: return "res"
        case .err: return "err"
        case .evt: return "evt"
        case .unknown(let raw): return raw
        }
    }
}

/// One bridge frame: `{ sl, k, id, n, t, p }`.
public struct Envelope: Sendable, Equatable {
    /// Envelope marker + envelope version. Always 1 for this protocol.
    public static let marker = 1

    public var kind: EnvelopeKind
    /// Correlation id — set on `cmd`, echoed on the matching `res`/`err`.
    public var id: String?
    /// Monotonic sequence — set on `evt` only.
    public var sequence: Int?
    /// Command or event name.
    public var type: String
    public var payload: JSONValue?

    public init(
        kind: EnvelopeKind,
        type: String,
        id: String? = nil,
        sequence: Int? = nil,
        payload: JSONValue? = nil
    ) {
        self.kind = kind
        self.type = type
        self.id = id
        self.sequence = sequence
        self.payload = payload
    }
}

// MARK: - Decoding

public extension Envelope {
    /// Parse + validate an inbound frame, mirroring the web side's `decode()`.
    ///
    /// Returns `nil` for anything that is not a well-formed envelope. The bridge
    /// ignores those silently rather than throwing, because a WebView can
    /// receive messages it does not own.
    ///
    /// One deliberate divergence from the web implementation: the web side
    /// rejects a frame whose `k` is not in its known set, because a page may
    /// receive unrelated `postMessage` traffic it must filter out. On iOS the
    /// only writer to our `WKScriptMessageHandler` is our own bundle, so an
    /// unknown `k` means a NEWER bundle rather than foreign traffic. We decode
    /// it as `.unknown` and let the router drop it, which keeps an old app
    /// forward-compatible instead of treating new frames as malformed.
    static func decode(_ value: JSONValue) -> Envelope? {
        guard case .object(let fields) = value else { return nil }
        guard fields["sl"]?.intValue == Envelope.marker else { return nil }
        guard let kindRaw = fields["k"]?.stringValue else { return nil }
        guard let type = fields["t"]?.stringValue, !type.isEmpty else { return nil }

        // `id` and `n`, when present, must be the right primitive — a frame that
        // gets these wrong is malformed, not merely unfamiliar.
        var id: String?
        if let raw = fields["id"], !raw.isNull {
            guard let value = raw.stringValue else { return nil }
            id = value
        }

        var sequence: Int?
        if let raw = fields["n"], !raw.isNull {
            // JavaScript has one number type, so `n: 1` reaches us as an
            // NSNumber holding a DOUBLE. Matching the web side's `isFiniteInt`
            // means accepting any finite, integral number — demanding a strict
            // integer here silently rejects every `evt`, `sys.ready` included.
            guard let number = raw.doubleValue,
                  number.isFinite,
                  number.rounded() == number
            else { return nil }
            sequence = Int(number)
        }

        return Envelope(
            kind: EnvelopeKind(rawValue: kindRaw),
            type: type,
            id: id,
            sequence: sequence,
            payload: fields["p"]
        )
    }

    /// Parse from the `Any` graph handed over by `WKScriptMessage.body`.
    static func decode(foundation value: Any) -> Envelope? {
        decode(JSONValue(foundation: value))
    }

    /// Parse from a JSON string (the shape the string-based native shims use).
    static func decode(json: String) -> Envelope? {
        guard let data = json.data(using: .utf8),
              let value = try? JSONDecoder().decode(JSONValue.self, from: data)
        else { return nil }
        return decode(value)
    }
}

// MARK: - Encoding

public extension Envelope {
    /// Lower to the wire object, omitting fields the web side treats as absent.
    func encoded() -> JSONValue {
        var fields: [String: JSONValue] = [
            "sl": .int(Envelope.marker),
            "k": .string(kind.rawValue),
            "t": .string(type),
        ]
        if let id { fields["id"] = .string(id) }
        if let sequence { fields["n"] = .int(sequence) }
        if let payload { fields["p"] = payload }
        return .object(fields)
    }

    /// The `Any` graph to hand to `callAsyncJavaScript` as an argument.
    func toFoundation() -> Any { encoded().toFoundation() }

    func jsonString() -> String? {
        guard let data = try? JSONEncoder().encode(encoded()) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
