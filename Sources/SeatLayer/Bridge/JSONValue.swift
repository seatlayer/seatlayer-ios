import Foundation

/// A loss-tolerant representation of any JSON value crossing the bridge.
///
/// The bridge payload (`p`) is schema-free by design: the web bundle may add
/// fields at any time and this SDK must carry them across unchanged rather than
/// fail to decode. Typed accessors in `Payloads.swift` project a `JSONValue`
/// into a Swift struct; anything they do not know about survives here.
public enum JSONValue: Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - Codable

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "unrepresentable JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

// MARK: - Equatable

/// Numeric cases compare by value, so `1` and `1.0` — which JSON does not
/// distinguish — are equal.
extension JSONValue: Equatable {
    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.bool(let l), .bool(let r)): return l == r
        case (.string(let l), .string(let r)): return l == r
        case (.array(let l), .array(let r)): return l == r
        case (.object(let l), .object(let r)): return l == r
        case (.int(let l), .int(let r)): return l == r
        case (.double(let l), .double(let r)): return l == r
        case (.int(let l), .double(let r)): return Double(l) == r
        case (.double(let l), .int(let r)): return l == Double(r)
        default: return false
        }
    }
}

// MARK: - Accessors

public extension JSONValue {
    subscript(key: String) -> JSONValue? {
        guard case .object(let dict) = self else { return nil }
        return dict[key]
    }

    subscript(index: Int) -> JSONValue? {
        guard case .array(let items) = self, items.indices.contains(index) else { return nil }
        return items[index]
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let value): return value
        case .double(let value) where value.isFinite: return Int(value)
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .int(let value): return Double(value)
        case .double(let value): return value
        default: return nil
        }
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    /// Project this value onto a `Decodable` type. Unknown fields are ignored by
    /// `Codable`, which is exactly the tolerance the bridge requires.
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Foundation interop

public extension JSONValue {
    /// Build from the `Any` graph that `WKScriptMessage.body` hands over.
    ///
    /// `WKScriptMessage` bridges JS values to `NSDictionary` / `NSArray` /
    /// `NSNumber` / `NSString` / `NSNull`, so this is the web→native entry.
    init(foundation value: Any) {
        switch value {
        case is NSNull:
            self = .null
        case let number as NSNumber:
            // `NSNumber` erases Bool into a number; recover it via the ObjC type
            // encoding, otherwise `true` would cross the bridge as `1`.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else if let type = String(cString: number.objCType, encoding: .ascii),
                      ["f", "d"].contains(type) {
                self = .double(number.doubleValue)
            } else {
                self = .int(number.intValue)
            }
        case let string as String:
            self = .string(string)
        case let array as [Any]:
            self = .array(array.map(JSONValue.init(foundation:)))
        case let dict as [String: Any]:
            self = .object(dict.mapValues(JSONValue.init(foundation:)))
        default:
            self = .null
        }
    }

    /// Lower to the JSON-serialisable `Any` graph that
    /// `WKWebView.callAsyncJavaScript(_:arguments:)` accepts as an argument.
    ///
    /// Passing this as an ARGUMENT (rather than interpolating JSON into script
    /// source) is what keeps payload content from ever being parsed as code.
    func toFoundation() -> Any {
        switch self {
        case .null: return NSNull()
        case .bool(let value): return NSNumber(value: value)
        case .int(let value): return NSNumber(value: value)
        case .double(let value): return NSNumber(value: value)
        case .string(let value): return value
        case .array(let value): return value.map { $0.toFoundation() }
        case .object(let value): return value.mapValues { $0.toFoundation() }
        }
    }
}

// MARK: - Literals

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}

public extension JSONValue {
    /// Build an object, dropping keys whose value is `nil`. Mirrors how the web
    /// side omits absent optionals rather than sending explicit `null`.
    static func object(compacting pairs: [String: JSONValue?]) -> JSONValue {
        .object(pairs.compactMapValues { $0 })
    }
}
