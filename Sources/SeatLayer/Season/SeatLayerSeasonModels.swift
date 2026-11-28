import Foundation

/// What the Season page is doing, as its status line says. Open: a newer page
/// may name another kind.
public struct SeatLayerSeasonStatusKind: RawRepresentable, Sendable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let loading = SeatLayerSeasonStatusKind(rawValue: "loading")
    public static let ready = SeatLayerSeasonStatusKind(rawValue: "ready")
    public static let pending = SeatLayerSeasonStatusKind(rawValue: "pending")
    public static let held = SeatLayerSeasonStatusKind(rawValue: "held")
    public static let booked = SeatLayerSeasonStatusKind(rawValue: "booked")
    public static let released = SeatLayerSeasonStatusKind(rawValue: "released")
    public static let renewalIntent = SeatLayerSeasonStatusKind(rawValue: "renewal_intent")
    public static let partialTerminal = SeatLayerSeasonStatusKind(rawValue: "partial_terminal")
    public static let failed = SeatLayerSeasonStatusKind(rawValue: "failed")
}

/// One date of the Season's package, in its order.
public struct SeatLayerSeasonDate: Sendable, Equatable {
    public let position: Int
    public let eventKey: String
    public let name: String
    /// Nil while the date has no start yet.
    public let startsAt: Date?
    /// The start as the page writes it, in the Season's zone and the page's
    /// language.
    public let startsAtLabel: String?
    /// No longer part of what a new hold takes.
    public let past: Bool
    /// Taken off sale.
    public let cancelled: Bool

    init?(_ value: JSONValue?) {
        guard let position = value?["position"]?.intValue,
              let eventKey = value?["eventKey"]?.stringValue,
              let name = value?["name"]?.stringValue else { return nil }
        self.position = position
        self.eventKey = eventKey
        self.name = name
        startsAt = seatLayerRunDate(value?["startsAt"])
        startsAtLabel = value?["startsAtLabel"]?.stringValue
        past = value?["past"]?.boolValue ?? false
        cancelled = value?["cancelled"]?.boolValue ?? false
    }
}

/// The page's status line: a kind to decide on, and the sentence the buyer
/// sees and hears. Decide on `kind`, never on `message`.
public struct SeatLayerSeasonStatus: Sendable, Equatable {
    public let kind: SeatLayerSeasonStatusKind
    public let message: String
    public let operationId: String?
    /// On `.ready` only: the package's dates.
    public let dates: [SeatLayerSeasonDate]?
    /// Once the Season is read: its name, for the app's bar.
    public let seasonName: String?
    /// Once the Season is read: the club's brand.
    public let branding: SeatLayerPickerBranding?

    init?(_ value: JSONValue?) {
        guard let kind = value?["kind"]?.stringValue else { return nil }
        self.kind = SeatLayerSeasonStatusKind(rawValue: kind)
        message = value?["message"]?.stringValue ?? ""
        operationId = value?["operationId"]?.stringValue
        dates = value?["dates"]?.arrayValue.map { $0.compactMap(SeatLayerSeasonDate.init) }
        seasonName = value?["season"]?["name"]?.stringValue
        branding = value?["branding"]?.objectValue == nil ? nil : decodeBranding(value?["branding"])
    }
}

/// A Season hold, handed to your checkout. Your server books it by
/// `operationId` and charges at its own prices.
public struct SeatLayerSeasonHandoff: Sendable, Equatable {
    public let seasonKey: String
    public let planActivationId: String
    /// The caller-stable `sop_` id the hold was made under. Book by it, and
    /// de-duplicate a second continue by it.
    public let operationId: String
    public let holdId: String
    public let expiresAt: Date
    /// The whole handoff as the page sent it (allocations, seats and their
    /// price types, policy), to forward to your server unchanged.
    public let json: JSONValue

    init?(_ value: JSONValue?) {
        guard let value, value.objectValue != nil,
              let seasonKey = value["seasonKey"]?.stringValue,
              let planActivationId = value["planActivationId"]?.stringValue,
              let operationId = value["operationId"]?.stringValue,
              let holdId = value["holdId"]?.stringValue,
              let expiresAt = seatLayerRunDate(value["expiresAt"]) else { return nil }
        self.seasonKey = seasonKey
        self.planActivationId = planActivationId
        self.operationId = operationId
        self.holdId = holdId
        self.expiresAt = expiresAt
        json = value
    }
}

/// The held order as the page prices it.
public struct SeatLayerSeasonHeldOrder: Sendable, Equatable {
    public let operationId: String
    public let expiresAt: Date
    public let currency: String
    /// Each held seat as the page sent it.
    public let seats: [JSONValue]
    /// The total in minor units, or nil when the page cannot price it.
    public let totalMinor: Int?

    init?(_ value: JSONValue?) {
        guard let operationId = value?["operationId"]?.stringValue,
              let expiresAt = seatLayerRunDate(value?["expiresAt"]),
              let currency = value?["currency"]?.stringValue else { return nil }
        self.operationId = operationId
        self.expiresAt = expiresAt
        self.currency = currency
        seats = value?["seats"]?.arrayValue ?? []
        totalMinor = value?["totalMinor"]?.intValue
    }
}

/// How a close the app asked for ended. Open.
public struct SeatLayerSeasonCloseOutcome: RawRepresentable, Sendable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    /// Nothing was held: close the screen.
    public static let closed = SeatLayerSeasonCloseOutcome(rawValue: "closed")
    /// The buyer released the seats: close the screen.
    public static let released = SeatLayerSeasonCloseOutcome(rawValue: "released")
    /// The buyer kept the seats: they stay held until the hold runs out.
    public static let kept = SeatLayerSeasonCloseOutcome(rawValue: "kept")
    /// Asked again while the question was up: stay.
    public static let stayed = SeatLayerSeasonCloseOutcome(rawValue: "stayed")
    /// The buyer chose release, but the server had booked the hold: close as
    /// after a purchase.
    public static let booked = SeatLayerSeasonCloseOutcome(rawValue: "booked")

    /// Whether the screen closes on this outcome.
    public var closes: Bool { self != .stayed }
}

/// How a close ended, and the hold it was about (kept: reopen on it with
/// `initialOperationId`).
public struct SeatLayerSeasonClose: Sendable, Equatable {
    public let outcome: SeatLayerSeasonCloseOutcome
    public let operationId: String?

    public init(outcome: SeatLayerSeasonCloseOutcome, operationId: String? = nil) {
        self.outcome = outcome
        self.operationId = operationId
    }
}

/// What `markBooked` found. Open.
public struct SeatLayerSeasonBookedStatus: RawRepresentable, Sendable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    /// Booked now.
    public static let booked = SeatLayerSeasonBookedStatus(rawValue: "booked")
    /// This page saw it booked before.
    public static let alreadyBooked = SeatLayerSeasonBookedStatus(rawValue: "already_booked")
    /// Held here but not booked on the server yet: send again once it is.
    public static let pending = SeatLayerSeasonBookedStatus(rawValue: "pending")
    /// Nothing is held here, and the server has not booked the named operation.
    public static let nothingHeld = SeatLayerSeasonBookedStatus(rawValue: "nothing_held")
    /// The page holds another operation, and the server has not booked the
    /// named one.
    public static let differentHold = SeatLayerSeasonBookedStatus(rawValue: "different_hold")
}
