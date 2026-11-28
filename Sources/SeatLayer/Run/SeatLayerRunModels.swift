import Foundation

/// How the buyer chooses seats across the run's performances. Open: a newer
/// page may name another mode.
public struct SeatLayerRunSelectionMode: RawRepresentable, Sendable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    /// The same seat at every performance.
    public static let sameSeat = SeatLayerRunSelectionMode(rawValue: "same_seat")
    /// Seats chosen performance by performance.
    public static let perPerformance = SeatLayerRunSelectionMode(rawValue: "per_performance")
}

/// One performance of the run.
public struct SeatLayerRunPerformance: Sendable, Equatable {
    public let position: Int
    public let eventKey: String
    public let name: String
    public let startsAt: Date?
    /// The date as the page writes it, in its own language and time zone.
    public let startsAtLabel: String?
    public let salesState: String?

    init?(_ value: JSONValue?) {
        guard let position = value?["position"]?.intValue,
              let eventKey = value?["eventKey"]?.stringValue,
              let name = value?["name"]?.stringValue else { return nil }
        self.position = position
        self.eventKey = eventKey
        self.name = name
        startsAt = seatLayerRunDate(value?["startsAt"])
        startsAtLabel = value?["startsAtLabel"]?.stringValue
        salesState = value?["salesState"]?.stringValue
    }
}

/// The run the page opened.
public struct SeatLayerRunDescriptor: Sendable, Equatable {
    public let key: String
    public let name: String
    public let performances: [SeatLayerRunPerformance]
    public let state: String?
    /// `test` or `live`.
    public let mode: String?
    public let currency: String?
    public let venue: String?
    /// The page's whole description, for fields this build predates.
    public let json: JSONValue

    init?(_ value: JSONValue?) {
        guard let value, value.objectValue != nil,
              let key = value["key"]?.stringValue,
              let name = value["name"]?.stringValue else { return nil }
        self.key = key
        self.name = name
        performances = (value["performances"]?.arrayValue ?? []).compactMap(SeatLayerRunPerformance.init)
        state = value["state"]?.stringValue
        mode = value["mode"]?.stringValue
        currency = value["currency"]?.stringValue
        venue = value["venue"]?.stringValue
        json = value
    }
}

/// What the run page is showing in place of seats. Open.
public struct SeatLayerRunStatusKind: RawRepresentable, Sendable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let idle = SeatLayerRunStatusKind(rawValue: "idle")
    public static let pending = SeatLayerRunStatusKind(rawValue: "pending")
    public static let recoveryFailed = SeatLayerRunStatusKind(rawValue: "recovery_failed")
    public static let salesClosed = SeatLayerRunStatusKind(rawValue: "sales_closed")
    public static let revisionChanged = SeatLayerRunStatusKind(rawValue: "revision_changed")
    public static let sessionEnded = SeatLayerRunStatusKind(rawValue: "session_ended")
}

public struct SeatLayerRunStatus: Sendable, Equatable {
    public let kind: SeatLayerRunStatusKind
    /// The page's own words for it.
    public let message: String
    public let reference: String?
    public let branding: SeatLayerPickerBranding?

    init?(_ value: JSONValue?) {
        guard let kind = value?["kind"]?.stringValue else { return nil }
        self.kind = SeatLayerRunStatusKind(rawValue: kind)
        message = value?["message"]?.stringValue ?? ""
        reference = value?["reference"]?.stringValue
        branding = value?["branding"]?.objectValue == nil ? nil : decodeBranding(value?["branding"])
    }
}

/// A hold the buyer made across the run's performances.
public struct SeatLayerRunHandoff: Sendable, Equatable {
    public let operationId: String
    public let holdId: String
    public let expiresAt: Date
    public let performanceKeys: [String]
    public let seatLabels: [String]
    public let selectionMode: SeatLayerRunSelectionMode?
    /// Whether the page reports it booked.
    public let booked: Bool
    /// The page's whole handoff, for your server.
    public let json: JSONValue

    init?(_ value: JSONValue?) {
        guard let value, value.objectValue != nil,
              let operationId = value["operationId"]?.stringValue,
              let holdId = value["holdId"]?.stringValue,
              let expiresAt = seatLayerRunDate(value["expiresAt"]) else { return nil }
        self.operationId = operationId
        self.holdId = holdId
        self.expiresAt = expiresAt
        performanceKeys = (value["performanceKeys"]?.arrayValue ?? []).compactMap(\.stringValue)
        seatLabels = (value["seatLabels"]?.arrayValue ?? []).compactMap(\.stringValue)
        selectionMode = value["selectionMode"]?.stringValue.map(SeatLayerRunSelectionMode.init(rawValue:))
        booked = value["bookingState"]?.stringValue == "booked"
        json = value
    }
}

/// What `markBooked` found. Open.
public struct SeatLayerRunBookedStatus: RawRepresentable, Sendable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    /// The server has not booked it yet.
    public static let pending = SeatLayerRunBookedStatus(rawValue: "pending")
    public static let booked = SeatLayerRunBookedStatus(rawValue: "booked")
}

/// Epoch milliseconds, as the page sends dates.
func seatLayerRunDate(_ value: JSONValue?) -> Date? {
    guard let ms = value?.doubleValue, ms.isFinite else { return nil }
    return Date(timeIntervalSince1970: ms.rounded() / 1000)
}
