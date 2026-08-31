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
    /// Whether the runtime actually reported `available`. A missing future or
    /// legacy field must not be mistaken for positive sold-out evidence.
    public let availabilityReported: Bool
    public let notForSale: Bool
    public let tiers: [CategoryTier]

    init(
        key: String,
        label: String,
        color: String,
        priceMin: Double,
        priceMax: Double,
        available: Int,
        availabilityReported: Bool = true,
        notForSale: Bool,
        tiers: [CategoryTier]
    ) {
        self.key = key
        self.label = label
        self.color = color
        self.priceMin = priceMin
        self.priceMax = priceMax
        self.available = available
        self.availabilityReported = availabilityReported
        self.notForSale = notForSale
        self.tiers = tiers
    }
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
    /// Runtime-authored ticket tier name, resolved from the authoritative
    /// category catalog when an older protocol payload omits it.
    public let tierName: String?
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

/// How much of an expired hold can be selected again.
public enum SeatLayerPickerRecovery: String, Sendable, Equatable, CaseIterable {
    case all
    case partial
    case none
}

/// Authoritative result of a live availability reconciliation.
public struct SeatLayerPickerAvailabilityOutcome: Sendable, Equatable {
    public let refreshed: Bool
    public let lostLabels: [String]
    public let holdLapsed: Bool
    public let lapsedLabels: [String]
    public let recoverableLabels: [String]
    public let revision: Int?
    public let heldForMs: Int?

    public init(
        refreshed: Bool,
        lostLabels: [String] = [],
        holdLapsed: Bool = false,
        lapsedLabels: [String] = [],
        recoverableLabels: [String] = [],
        revision: Int? = nil,
        heldForMs: Int? = nil
    ) {
        self.refreshed = refreshed
        self.lostLabels = lostLabels
        self.holdLapsed = holdLapsed
        self.lapsedLabels = holdLapsed ? lapsedLabels : []
        self.recoverableLabels = holdLapsed
            ? recoverableLabels.filter(Set(lapsedLabels).contains)
            : []
        self.revision = revision
        self.heldForMs = heldForMs
    }

    public static let unsupported = SeatLayerPickerAvailabilityOutcome(refreshed: false)

    public var isQuiet: Bool { lostLabels.isEmpty && !holdLapsed }

    public var recovery: SeatLayerPickerRecovery {
        guard !recoverableLabels.isEmpty else { return .none }
        return recoverableLabels.count >= lapsedLabels.count ? .all : .partial
    }
}

/// One expired hold retained until native chrome tells the buyer what happened.
public struct SeatLayerPickerHoldLapse: Sendable, Equatable {
    public let lapsedLabels: [String]
    public let recoverableLabels: [String]
    public let heldForMs: Int?

    public init(
        lapsedLabels: [String],
        recoverableLabels: [String],
        heldForMs: Int? = nil
    ) {
        self.lapsedLabels = lapsedLabels
        self.recoverableLabels = recoverableLabels.filter(Set(lapsedLabels).contains)
        self.heldForMs = heldForMs
    }

    public var recovery: SeatLayerPickerRecovery {
        guard !recoverableLabels.isEmpty else { return .none }
        return recoverableLabels.count >= lapsedLabels.count ? .all : .partial
    }

    public var unrecoverableCount: Int {
        max(0, lapsedLabels.count - recoverableLabels.count)
    }
}

/// Typed result of a lifecycle or explicit availability command.
public struct SeatLayerPickerLifecycleResult: Sendable, Equatable {
    public let snapshot: SeatLayerPickerSnapshot?
    public let outcome: SeatLayerPickerAvailabilityOutcome?

    public init(
        snapshot: SeatLayerPickerSnapshot? = nil,
        outcome: SeatLayerPickerAvailabilityOutcome? = nil
    ) {
        self.snapshot = snapshot
        self.outcome = outcome
    }
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
    /// Buyer-display identity under the 3D camera, selected or not.
    public let view3DTargetSeat: SelectedSeat?
    /// Same-row neighbours in authored inventory order.
    public let view3DPreviousSeatId: String?
    public let view3DNextSeatId: String?
    /// Section framed by the 3D scene, independent of 2D map focus.
    public let view3DFocusedSectionId: String?
    /// Whether the runtime emitted the additive 3D position contract.
    ///
    /// A reported null neighbour is a real row boundary. `false` means an
    /// older runtime omitted the contract and permits the bounded selection
    /// fallback used during rollout.
    public let reportsView3DPosition: Bool
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

/// The runtime branding entitlement is the only authority for whether native
/// picker chrome renders the SeatLayer attribution. Before the first snapshot
/// arrives there is no branding decision to present.
func seatLayerPickerAttributionVisible(
    in snapshot: SeatLayerPickerSnapshot?
) -> Bool {
    snapshot?.branding.attributionRequired == true
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
