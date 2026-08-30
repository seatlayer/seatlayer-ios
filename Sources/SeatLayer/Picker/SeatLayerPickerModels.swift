import Foundation

/// Protocol-2 picker snapshot schema understood by this SDK.
public let seatLayerPickerSnapshotSchema = "seatlayer.picker.snapshot/1"

/// Runtime floor sentinel meaning that every floor is visible.
public let seatLayerAllFloors = "all"

public struct SeatLayerPickerEventDetails: Sendable, Equatable {
    public let key: String
    public let name: String
    public let mode: EventMode
    public let currency: String
    public let venue: String?
    public let startsAt: Double?
    public let timezone: String?
    public let locale: String?
    public let posterURL: String?
    public let salesClosed: Bool
}

public struct SeatLayerPickerBranding: Sendable, Equatable {
    public let brandName: String?
    public let logoURL: String?
    public let attributionRequired: Bool
    public let accent: String?
    public let accentInk: String?
    public let background: String?
    public let surface: String?
    public let text: String?
    public let muted: String?
    public let line: String?
    public let fontFamily: String?
    public let radius: Double?
}

public struct SeatLayerPickerCategory: Sendable, Equatable {
    public let key: String
    public let label: String
    public let color: String
    public let priceMin: Double
    public let priceMax: Double
    public let available: Int
    public let notForSale: Bool
    public let tiers: [CategoryTier]
}

public struct SeatLayerPickerZone: Sendable, Equatable {
    public let id: String
    public let label: String
    public let color: String?
}

public struct SeatLayerPickerSectionSummary: Sendable, Equatable {
    public let id: String
    public let label: String
    public let displayLabel: String?
    public let zoneId: String?
    public let zoneLabel: String?
    public let entrance: String?
    public let color: String?
    public let dominantCategoryKey: String?
    public let seatsLeft: Int?
    public let priceMin: Double?
    public let priceMax: Double?
}

public struct SeatLayerPickerCartLine: Sendable, Equatable {
    public let lineKey: String
    public let label: String
    public let displayLabel: String?
    public let displayType: String?
    public let objectId: String
    public let objectType: String
    public let categoryKey: String
    public let tierId: String?
    public let unitPrice: Double
    public let currency: String
    public let quantity: Int
    public let seatId: String?
    public let sectionLabel: String?
    public let rowLabel: String?
    public let seatNumber: String?

    public var total: Double { unitPrice * Double(quantity) }
}

/// Opaque checkout capability transferred to the host application.
///
/// The hold id is deliberately absent from ordinary picker snapshots and
/// appears only in this handoff.
public struct SeatLayerPickerCheckoutHandoff: Sendable, Equatable {
    public let holdId: String
    public let expiresAt: Double
    public let currency: String
    public let lineItems: [SeatLayerPickerCartLine]
    public let total: Double
}

public struct SeatLayerPickerHold: Sendable, Equatable {
    public let active: Bool
    public let expiresAt: Double?
    /// `picker`, `host`, or a future additive value.
    public let owner: String?
}

public struct SeatLayerPickerViewportInsets: Sendable, Equatable {
    public let top: Double
    public let right: Double
    public let bottom: Double
    public let left: Double

    public init(
        top: Double = 0,
        right: Double = 0,
        bottom: Double = 0,
        left: Double = 0
    ) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    public static let zero = SeatLayerPickerViewportInsets(
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
    )
}

public struct SeatLayerPickerFloorInfo: Sendable, Equatable {
    public let id: String
    public let name: String
    public let level: Int?
}

public struct SeatLayerPickerAccessNeed: Sendable, Equatable {
    public let key: String
    public let count: Int
}

public struct SeatLayerPickerMapState: Sendable, Equatable {
    public let rung: String
    public let viewMode: String
    public let buyerView: String
    public let view3DNavigationMode: String
    public let view3DTargetSeatId: String?
    public let activeFloorId: String?
    public let focusedSectionId: String?
    public let focusedSection: SeatLayerPickerSectionSummary?
    public let colorblindSafe: Bool
    public let hideLimitedView: Bool
    public let canZoomIn: Bool
    public let canZoomOut: Bool
    public let categoryFilter: [String]
    public let accessibilityFilter: [String]
    public let accessNeeds: [SeatLayerPickerAccessNeed]
    public let floors: [SeatLayerPickerFloorInfo]
    public let floorMode: String?
    public let floorLabelStyle: String?
    public let viewportInsets: SeatLayerPickerViewportInsets?

    public var isVenue3D: Bool { buyerView == "venue3d" }
    public var showsAllFloors: Bool { floorMode == "all" }
}

/// One immutable, revision-ordered native picker state.
public struct SeatLayerPickerSnapshot: Sendable, Equatable {
    public let schema: String
    public let sessionId: String
    public let revision: Int
    public let event: SeatLayerPickerEventDetails
    public let branding: SeatLayerPickerBranding
    public let categories: [SeatLayerPickerCategory]
    public let zones: [SeatLayerPickerZone]
    public let sections: [SeatLayerPickerSectionSummary]
    public let generalAdmissionAreas: [GAArea]
    public let bestAvailableZones: [SeatLayerPickerZone]
    public let map: SeatLayerPickerMapState
    public let selection: [SelectedSeat]
    public let selectionValidity: SelectionValidity?
    public let maxSelection: Int
    public let ticketCount: Int
    public let cartLines: [SeatLayerPickerCartLine]
    public let cartTotal: Double
    public let currency: String
    public let hold: SeatLayerPickerHold
    public let accessConfigured: Bool
    public let accessStatus: String
    public let accessReason: String?
    public let capabilities: Set<String>
    /// The complete additive payload for diagnostics and future projections.
    public let raw: JSONValue
}

public struct SeatLayerSeatView: Sendable, Equatable {
    public let seatId: String?
    public let title: String?
    public let caption: String?
    public let badge: String?
    public let real: Bool
    public let generated: Bool
    public let dragHint: String?
}
