import Foundation

// Every enum here carries an `unknown(String)` case and decodes via
// `init(from:)` that CANNOT throw on an unfamiliar value. The web bundle is
// updated independently of the app: an app compiled today must keep working
// when a bundle a year from now introduces a new seat status, object type or
// transport name. Structs likewise ignore fields they do not know, which
// `Codable` gives us for free.

/// A string-backed enum that never fails to decode.
public protocol OpenEnum: RawRepresentable, Codable, Sendable, Hashable where RawValue == String {
    init(unknown: String)
}

public extension OpenEnum {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self(unknown: raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// True when this value came from a bundle newer than the app.
    var isUnknown: Bool { Self(rawValue: rawValue) == nil }
}

// MARK: - Open enums

/// Whether the SERVED event books real inventory.
///
/// A test event looks and behaves exactly like a live one but books nothing, so
/// an app that cannot tell them apart can ship a build that appears to work and
/// sells no tickets. Always badge `.test` in the UI.
public enum EventMode: OpenEnum {
    case live
    case test
    case unknown(String)

    public init?(rawValue: String) {
        switch rawValue {
        case "live": self = .live
        case "test": self = .test
        default: return nil
        }
    }

    public init(unknown: String) { self = .unknown(unknown) }

    public var rawValue: String {
        switch self {
        case .live: return "live"
        case .test: return "test"
        case .unknown(let raw): return raw
        }
    }
}

/// Which web→native shim the bundle selected. `.ios` is the expected value in
/// this SDK; anything else means the bundle fell back to another channel.
public enum TransportName: OpenEnum {
    case ios, android, flutter, reactNative, frame, none
    case unknown(String)

    public init?(rawValue: String) {
        switch rawValue {
        case "ios": self = .ios
        case "android": self = .android
        case "flutter": self = .flutter
        case "rn": self = .reactNative
        case "frame": self = .frame
        case "none": self = .none
        default: return nil
        }
    }

    public init(unknown: String) { self = .unknown(unknown) }

    public var rawValue: String {
        switch self {
        case .ios: return "ios"
        case .android: return "android"
        case .flutter: return "flutter"
        case .reactNative: return "rn"
        case .frame: return "frame"
        case .none: return "none"
        case .unknown(let raw): return raw
        }
    }
}

/// What kind of sellable object a hold line item covers.
public enum ObjectType: OpenEnum {
    case seat, booth, ga
    case unknown(String)

    public init?(rawValue: String) {
        switch rawValue {
        case "seat": self = .seat
        case "booth": self = .booth
        case "ga": self = .ga
        default: return nil
        }
    }

    public init(unknown: String) { self = .unknown(unknown) }

    public var rawValue: String {
        switch self {
        case .seat: return "seat"
        case .booth: return "booth"
        case .ga: return "ga"
        case .unknown(let raw): return raw
        }
    }
}

/// Live status of a seat. The server's status vocabulary grows over time.
public enum SeatStatus: OpenEnum {
    case free, held, booked, blocked
    case unknown(String)

    public init?(rawValue: String) {
        switch rawValue {
        case "free": self = .free
        case "held": self = .held
        case "booked": self = .booked
        case "blocked": self = .blocked
        default: return nil
        }
    }

    public init(unknown: String) { self = .unknown(unknown) }

    public var rawValue: String {
        switch self {
        case .free: return "free"
        case .held: return "held"
        case .booked: return "booked"
        case .blocked: return "blocked"
        case .unknown(let raw): return raw
        }
    }
}

/// Canvas projection used by the shared buyer renderer.
public enum SeatLayerViewMode: OpenEnum {
    case flat, iso, perspective
    case unknown(String)

    public init?(rawValue: String) {
        switch rawValue {
        case "flat": self = .flat
        case "iso": self = .iso
        case "perspective": self = .perspective
        default: return nil
        }
    }

    public init(unknown: String) { self = .unknown(unknown) }

    public var rawValue: String {
        switch self {
        case .flat: return "flat"
        case .iso: return "iso"
        case .perspective: return "perspective"
        case .unknown(let raw): return raw
        }
    }
}

/// Why the picker is asking the host app for a fresh buyer-access bearer.
public enum BuyerAccessRefreshReason: OpenEnum {
    case initial, expiring, expired, unauthorized, reconnect, manual
    case unknown(String)

    public init?(rawValue: String) {
        switch rawValue {
        case "initial": self = .initial
        case "expiring": self = .expiring
        case "expired": self = .expired
        case "unauthorized": self = .unauthorized
        case "reconnect": self = .reconnect
        case "manual": self = .manual
        default: return nil
        }
    }

    public init(unknown: String) { self = .unknown(unknown) }

    public var rawValue: String {
        switch self {
        case .initial: return "initial"
        case .expiring: return "expiring"
        case .expired: return "expired"
        case .unauthorized: return "unauthorized"
        case .reconnect: return "reconnect"
        case .manual: return "manual"
        case .unknown(let raw): return raw
        }
    }
}

/// Why private inventory cannot currently be shown to this buyer.
public enum BuyerAccessUnavailableReason: OpenEnum {
    case revoked, paused, invalid, originMismatch, eventMismatch, groupMismatch
    case modeMismatch, channelDenied, invalidScope, providerFailed, noToken
    case unknown(String)

    public init?(rawValue: String) {
        switch rawValue {
        case "revoked": self = .revoked
        case "paused": self = .paused
        case "invalid": self = .invalid
        case "origin_mismatch": self = .originMismatch
        case "event_mismatch": self = .eventMismatch
        case "group_mismatch": self = .groupMismatch
        case "mode_mismatch": self = .modeMismatch
        case "channel_denied": self = .channelDenied
        case "invalid_scope": self = .invalidScope
        case "provider_failed": self = .providerFailed
        case "no_token": self = .noToken
        default: return nil
        }
    }

    public init(unknown: String) { self = .unknown(unknown) }

    public var rawValue: String {
        switch self {
        case .revoked: return "revoked"
        case .paused: return "paused"
        case .invalid: return "invalid"
        case .originMismatch: return "origin_mismatch"
        case .eventMismatch: return "event_mismatch"
        case .groupMismatch: return "group_mismatch"
        case .modeMismatch: return "mode_mismatch"
        case .channelDenied: return "channel_denied"
        case .invalidScope: return "invalid_scope"
        case .providerFailed: return "provider_failed"
        case .noToken: return "no_token"
        case .unknown(let raw): return raw
        }
    }
}

public enum SelectedObjectUnavailableReason: OpenEnum {
    case ineligible, taken, exhausted
    case unknown(String)

    public init?(rawValue: String) {
        switch rawValue {
        case "ineligible": self = .ineligible
        case "taken": self = .taken
        case "exhausted": self = .exhausted
        default: return nil
        }
    }

    public init(unknown: String) { self = .unknown(unknown) }

    public var rawValue: String {
        switch self {
        case .ineligible: return "ineligible"
        case .taken: return "taken"
        case .exhausted: return "exhausted"
        case .unknown(let raw): return raw
        }
    }
}

public enum SelectionViolation: OpenEnum {
    case numberOfPlacesToSelect, minimumSelectedPlaces, consecutiveSeats, noOrphanSeats
    case unknown(String)

    public init?(rawValue: String) {
        switch rawValue {
        case "numberOfPlacesToSelect": self = .numberOfPlacesToSelect
        case "minimumSelectedPlaces": self = .minimumSelectedPlaces
        case "consecutiveSeats": self = .consecutiveSeats
        case "noOrphanSeats": self = .noOrphanSeats
        default: return nil
        }
    }

    public init(unknown: String) { self = .unknown(unknown) }

    public var rawValue: String {
        switch self {
        case .numberOfPlacesToSelect: return "numberOfPlacesToSelect"
        case .minimumSelectedPlaces: return "minimumSelectedPlaces"
        case .consecutiveSeats: return "consecutiveSeats"
        case .noOrphanSeats: return "noOrphanSeats"
        case .unknown(let raw): return raw
        }
    }
}

// MARK: - Value types

/// An opaque, short-lived buyer-access bearer minted by the host's backend.
public struct BuyerAccessToken: Sendable, Equatable {
    public var token: String
    /// Epoch milliseconds. When absent, refresh happens reactively.
    public var expiresAt: Double?

    public init(token: String, expiresAt: Double? = nil) {
        self.token = token
        self.expiresAt = expiresAt
    }

    func jsonValue() -> JSONValue {
        .object(compacting: [
            "token": .string(token),
            "expiresAt": expiresAt.map(JSONValue.double),
        ])
    }
}

public struct BuyerAccessRequestContext: Sendable, Equatable {
    public var reason: BuyerAccessRefreshReason

    public init(reason: BuyerAccessRefreshReason) { self.reason = reason }
}

public typealias BuyerAccessTokenProvider = @Sendable (BuyerAccessRequestContext) async throws -> BuyerAccessToken

/// Selection rules supported by the shared buyer picker.
public enum SelectionValidator: Sendable, Equatable {
    case minimumSelectedPlaces(Int)
    case consecutiveSeats
    case noOrphanSeats

    func jsonValue() -> JSONValue {
        switch self {
        case .minimumSelectedPlaces(let minimum):
            return ["type": "minimumSelectedPlaces", "minimum": .int(minimum)]
        case .consecutiveSeats:
            return ["type": "consecutiveSeats"]
        case .noOrphanSeats:
            return ["type": "noOrphanSeats"]
        }
    }
}

/// A ticket tier a category offers (Adult / Child / …).
public struct CategoryTier: Codable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var price: Double
    /// Currency for this tier when it differs from the event/cart fallback.
    public var currency: String?
    /// Additive buyer rule such as `companion`.
    public var restriction: String?
    /// Runtime-authored guidance shown beside the tier choice.
    public var buyerMessage: String?

    public init(
        id: String,
        name: String,
        price: Double,
        currency: String? = nil,
        restriction: String? = nil,
        buyerMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.currency = currency
        self.restriction = restriction
        self.buyerMessage = buyerMessage
    }
}

/// Commercial selling/view attributes resolved for a seat.
public struct SeatCommercialAttributes: Codable, Sendable, Equatable {
    public var restrictedView: Bool?
    public var obstructedView: Bool?
    public var premium: Bool?
    public var note: String?
}

/// One selected seat.
public struct SelectedSeat: Codable, Sendable, Equatable {
    public var id: String
    public var label: String
    /// Buyer-facing label (row `displayLabel` applied). Falls back to `label`.
    /// NEVER use for booking — `label` is the inventory identity.
    public var displayLabel: String?
    public var categoryKey: String?
    /// Price for the chosen tier when the category has tiers, else base price.
    public var price: Double?
    public var tiers: [CategoryTier]?
    /// The chosen tier's id; absent when the category has no tiers.
    public var tierId: String?
    public var commercial: SeatCommercialAttributes?
    /// Parent chart-object identity when the runtime exposes one.
    public var objectId: String?
    public var objectType: ObjectType?
    /// `variable` for a table whose guest count is chosen after tapping.
    public var bookingMode: String?
    public var quantity: Int?
    public var minOccupancy: Int?
    public var maxOccupancy: Int?
    public var capacity: Int?
    public var currency: String?
    public var sectionLabel: String?
    public var rowLabel: String?
    public var seatNumber: String?
    public var displayType: String?
    public var rowType: String?
    public var accessibility: [String]?
    public var wheelchairSpaceType: String?

    /// What to show the buyer. Booking still uses `label`.
    public var buyerFacingLabel: String { displayLabel ?? label }
}

/// Current exact-count and validator state for the buyer's selection.
public struct SelectionValidity: Codable, Sendable, Equatable {
    public var isValid: Bool
    public var count: Int
    public var required: Int
    public var remaining: Int
    public var seats: [SelectedSeat]
    public var violations: [SelectionViolation]
}

public struct BuyerAccessExpiredEvent: Codable, Sendable, Equatable {
    public var reason: BuyerAccessRefreshReason
    public var code: String?
    public var refreshed: Bool
}

public struct BuyerAccessUnavailableEvent: Codable, Sendable, Equatable {
    public var reason: BuyerAccessUnavailableReason
    public var code: String?
    public var status: Int?
    public var retryable: Bool
}

public struct SelectedObjectUnavailableEvent: Codable, Sendable, Equatable {
    public var labels: [String]
    public var reason: SelectedObjectUnavailableReason
    public var code: String?
}

/// One line of a hold.
public struct HoldLineItem: Codable, Sendable, Equatable {
    public var label: String
    public var objectId: String?
    public var objectType: ObjectType?
    public var categoryKey: String?
    public var tierId: String?
    /// Price in major currency units (45 means $45.00).
    public var unitPrice: Double?
    public var currency: String?
    public var quantity: Int?
}

/// An open hold.
public struct HoldResult: Codable, Sendable, Equatable {
    public var holdId: String
    /// Server expiry, in milliseconds since the epoch.
    public var expiresAt: Double
    public var seats: [SelectedSeat]?
    public var items: [HoldLineItem]?

    public var expiryDate: Date { Date(timeIntervalSince1970: expiresAt / 1000) }
    public var timeRemaining: TimeInterval { Swift.max(0, expiryDate.timeIntervalSinceNow) }
}

/// Best-available response — the server-picked seats plus the hold.
public struct BestAvailableResult: Codable, Sendable, Equatable {
    public var holdId: String
    public var expiresAt: Double
    public var labels: [String]
    public var seats: [SelectedSeat]?
    public var items: [HoldLineItem]?

    public var expiryDate: Date { Date(timeIntervalSince1970: expiresAt / 1000) }
}

/// A general-admission area and its live availability.
public struct GAArea: Codable, Sendable, Equatable {
    public var id: String
    public var label: String?
    public var capacity: Int?
    public var available: Int?
    public var categoryKey: String?
    public var price: Double?
    public var currency: String?
    public var tiers: [CategoryTier]?
}

/// One floor of a multi-floor venue.
public struct FloorInfo: Codable, Sendable, Equatable {
    public var id: String
    public var name: String
}

/// Rich hover payload — everything a seat popover needs.
public struct SeatHoverDetails: Codable, Sendable, Equatable {
    public var id: String?
    public var label: String?
    public var displayLabel: String?
    public var categoryKey: String?
    public var categoryLabel: String?
    public var categoryColor: String?
    public var status: SeatStatus?
    public var price: Double?
    public var currency: String?
    public var sectionLabel: String?
    public var rowLabel: String?
    public var seatNumber: String?
    /// Buyer-facing type word for the row/table; absent means "Row".
    public var rowType: String?
    public var tiers: [CategoryTier]?
    public var tierId: String?
    public var commercial: SeatCommercialAttributes?
}

/// What `sys.ready` reports once the chart exists.
public struct ReadyInfo: Sendable, Equatable {
    /// The negotiated protocol revision.
    public var protocolRevision: Int
    /// Whether the served event books real inventory.
    public var mode: EventMode
    /// Which shim the bundle actually selected — confirm this is `.ios`.
    public var transport: TransportName
    /// The event key the chart was built for.
    public var eventKey: String?

    public init(_ payload: JSONValue?) {
        self.protocolRevision = payload?["protocol"]?.intValue ?? seatLayerProtocolMin
        self.mode = payload?["mode"]?.stringValue.map { EventMode(rawValue: $0) ?? .unknown($0) } ?? .live
        self.transport = payload?["transport"]?.stringValue.map { TransportName(rawValue: $0) ?? .unknown($0) } ?? .unknown("")
        self.eventKey = payload?["chart"]?["event"]?.stringValue
    }
}

/// What the bundle advertises in `hello`.
public struct BundleInfo: Sendable, Equatable {
    public var bundle: String
    public var protocolRange: ProtocolRange
    public var capabilities: [String]
    public var events: [String]
    public var commands: [String]

    public init(_ payload: JSONValue?) {
        self.bundle = payload?["bundle"]?.stringValue ?? "unknown"
        self.protocolRange = ProtocolRange.from(payload?["protocol"]) ?? .native
        self.capabilities = payload?["capabilities"]?.arrayValue?.compactMap(\.stringValue) ?? []
        self.events = payload?["events"]?.arrayValue?.compactMap(\.stringValue) ?? []
        self.commands = payload?["commands"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    /// Whether the bundle accepts a command, so the app can hide UI for
    /// capabilities an older bundle lacks instead of discovering
    /// `unsupported_command` at tap time.
    public func supports(command: String) -> Bool { commands.contains(command) }
    public func supports(capability: String) -> Bool { capabilities.contains(capability) }
}
