import Foundation

/// Hash of the canonical cross-platform picker token input used to generate
/// this file. Flutter and React Native publish the same hash.
public let seatLayerPickerTokenSourceSHA256 =
    "0667fdddab037b3f63eaf18b4ba099f477cb630edc93f9ea90f90862609e492f"

/// Hash of the canonical locale input used by the native picker strings.
public let seatLayerPickerLocaleSourceSHA256 =
    "9401509eb3704d0ec1d61d9ec8a6a4126b0d76ad8f0c3c204c890f24d9a55048"

/// Hash of the platform-neutral picker component catalogue.
public let seatLayerPickerComponentSourceSHA256 =
    "c091ace21b09f484dc516748d660f5d24ef4554826f8037ee30231addaa8e190"

public enum SeatLayerPickerSizeTokens {
    public static let phoneBreakpoint = 640.0
    public static let wideBreakpoint = 840.0
    public static let headerHeight = 56.0
    public static let headerLogoSize = 28.0
    public static let dockBarHeight = 52.0
    public static let peekHeight = 44.0
    public static let sheetMaxHeightFraction = 0.6
    public static let emptyTrayMaxHeight = 150.0
    public static let denseLineHeight = 40.0
    public static let denseVisibleLines = 5
    public static let confirmCardGutter = 16.0
    public static let confirmCardMaxWidth = 360.0
    public static let confirmIdentityHeight = 44.0
    public static let confirmPhotoHeight = 64.0
    public static let confirmActionHeight = 40.0
    public static let selectorHeight = 40.0
    public static let accessibilityControlSize = 44.0
    public static let mapControlSize = 36.0
    public static let attributionHeight = 18.0
    public static let legendChipFontSize = 11.0
    public static let minimumHitTarget = 44.0
}

public enum SeatLayerPickerRadiusTokens {
    public static let base = 14.0
    public static let card = 18.0
    public static let sheet = 14.0
    public static let button = 8.0
    public static let chip = 999.0
    public static let pill = 999.0
}

public enum SeatLayerPickerMotionTokens {
    public static let budgetMilliseconds = 420
    public static let enterMilliseconds = 260
    public static let exitMilliseconds = 180
    public static let dockMilliseconds = 240
    public static let sheetMilliseconds = 300
    public static let flyMilliseconds = 420
    public static let popMilliseconds = 180
    public static let staggerMilliseconds = 60
    public static let crossfadeMilliseconds = 120
    public static let toastMilliseconds = 200
    public static let immersiveMilliseconds = 300
    public static let undoWindowMilliseconds = 4_000
}

public enum SeatLayerPickerElevationTokens {
    public static let header = 0.0
    public static let dockBar = 8.0
    public static let sheet = 12.0
    public static let confirmCard = 18.0
    public static let pill = 0.0
}

public enum SeatLayerPickerStringKey: String, CaseIterable, Sendable {
    case accessiblePlace
    case accessibility
    case accessibilityTitle
    case addTickets
    case allFloors
    case anyTicketType
    case anyVenueZone
    case applyFilters
    case backToVenue
    case bestSeats
    case cancel
    case chooseSeats
    case chooseTickets
    case chooseGuests
    case close
    case collapseCart
    case colorblindSafe
    case continueWithTotal
    case continueWord
    case emptyTrayHint
    case errorMessage
    case dismiss
    case expandCart
    case fitVenue
    case fromPrice
    case generalAdmission
    case holdExpired
    case heldFor
    case hideLimitedView
    case holdAndCheckout
    case limitedViewNotice
    case loading
    case mapView
    case moreTickets
    case nextSection
    case overview
    case poweredBy
    case previousSection
    case removeSeat
    case removeTable
    case recoverSeats
    case retry
    case select
    case selectTicketTier
    case seatsLeft
    case row
    case seat
    case section
    case testMode
    case testModeDescription
    case ticket
    case noTicketsAvailable
    case place
    case placesAvailable
    case confirmTable
    case ticketCount
    case ticketType
    case venue3D
    case viewFromHere
    case viewInformation
    case wheelchairAccessibleSeating
    case wheelchairSpaceNoFixedChair
    case zoomIn
    case zoomOut
}

/// Buyer-facing wording for the native chrome. Host overrides use the same
/// stable keys as Flutter and React Native and may replace one string without
/// forking a component.
public struct SeatLayerPickerStrings: Sendable, Equatable {
    public var overrides: [String: String]
    /// BCP-47 locale. Nil follows the buyer's first preferred language.
    public var localeIdentifier: String?

    public init(
        overrides: [String: String] = [:],
        localeIdentifier: String? = nil
    ) {
        self.overrides = overrides
        self.localeIdentifier = localeIdentifier
    }

    public static var supportedLocales: [String] { generatedLocales.keys.sorted() }

    public func text(
        _ key: SeatLayerPickerStringKey,
        replacing values: [String: String] = [:]
    ) -> String {
        let template = overrides[key.rawValue]
            ?? localized[key.rawValue]
            ?? Self.english[key]
            ?? key.rawValue
        return values.reduce(template) { result, entry in
            result.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
        }
    }

    public func ticketCount(_ count: Int) -> String {
        let pluralKey = count == 1 ? "ticketCount.one" : "ticketCount.other"
        if let exact = overrides[pluralKey] ?? localized[pluralKey] {
            return exact.replacingOccurrences(of: "{count}", with: String(count))
        }
        return count == 1 ? "1 ticket" : "\(count) tickets"
    }

    public func seatsLeft(_ count: Int) -> String {
        text(.seatsLeft, replacing: ["count": String(count)])
    }

    public func fromPrice(_ price: String) -> String {
        text(.fromPrice, replacing: ["price": price])
    }

    public func continueWithTotal(_ money: String) -> String {
        text(.continueWithTotal, replacing: ["money": money])
    }

    private var localized: [String: String] {
        let requested = (localeIdentifier ?? Locale.preferredLanguages.first ?? "en")
            .replacingOccurrences(of: "_", with: "-")
        if let exact = Self.generatedLocales.first(where: {
            $0.key.caseInsensitiveCompare(requested) == .orderedSame
        })?.value { return exact }
        let language = requested.split(separator: "-").first.map(String.init) ?? "en"
        if language.caseInsensitiveCompare("zh") == .orderedSame {
            let traditional = requested.localizedCaseInsensitiveContains("Hant")
                || requested.localizedCaseInsensitiveContains("TW")
                || requested.localizedCaseInsensitiveContains("HK")
            return Self.generatedLocales[traditional ? "zh-Hant" : "zh-Hans"] ?? [:]
        }
        return Self.generatedLocales.first(where: {
            $0.key.caseInsensitiveCompare(language) == .orderedSame
        })?.value ?? Self.generatedLocales["en"] ?? [:]
    }

    private static let english: [SeatLayerPickerStringKey: String] = [
        .accessiblePlace: "Accessible place",
        .accessibility: "Accessibility and view filters",
        .accessibilityTitle: "Accessibility and view",
        .addTickets: "Add tickets",
        .allFloors: "All floors",
        .anyTicketType: "Any ticket type",
        .anyVenueZone: "Any venue zone",
        .applyFilters: "Apply filters",
        .backToVenue: "Back to venue",
        .bestSeats: "Best seats",
        .cancel: "Cancel",
        .chooseSeats: "Choose your seats",
        .chooseTickets: "Choose tickets",
        .chooseGuests: "Choose the number of guests for this table",
        .close: "Close seat selection",
        .collapseCart: "Collapse cart",
        .colorblindSafe: "Colourblind-friendly colours",
        .continueWithTotal: "Continue · {money}",
        .continueWord: "Continue",
        .emptyTrayHint: "Tap a seat on the map, or let us pick the best available for you.",
        .errorMessage: "The seat map could not be loaded.",
        .dismiss: "Dismiss",
        .expandCart: "Expand cart",
        .fitVenue: "Fit venue",
        .fromPrice: "From {price}",
        .generalAdmission: "General admission",
        .holdExpired: "Your seat hold expired",
        .heldFor: "{clock}",
        .hideLimitedView: "Hide limited-view seats",
        .holdAndCheckout: "Hold seats & checkout",
        .limitedViewNotice: "This seat may have a limited or obstructed view.",
        .loading: "Loading seat map…",
        .mapView: "Seat map",
        .moreTickets: "More tickets",
        .nextSection: "Next section",
        .overview: "Venue",
        .poweredBy: "Powered by SeatLayer",
        .previousSection: "Previous section",
        .removeSeat: "Remove ticket",
        .removeTable: "Remove table",
        .recoverSeats: "Recover seats",
        .retry: "Try again",
        .select: "Select",
        .selectTicketTier: "Select a ticket type",
        .seatsLeft: "{count} left",
        .row: "Row",
        .seat: "Seat",
        .section: "Section",
        .testMode: "TEST MODE",
        .testModeDescription: "Test event. No real booking will be made.",
        .ticket: "Ticket",
        .noTicketsAvailable: "No tickets are currently available.",
        .place: "Place",
        .placesAvailable: "{count} places currently available",
        .confirmTable: "Confirm table",
        .ticketCount: "{count} tickets",
        .ticketType: "Ticket type",
        .venue3D: "3D",
        .viewFromHere: "View from here",
        .viewInformation: "View information",
        .wheelchairAccessibleSeating: "Wheelchair-accessible seating.",
        .wheelchairSpaceNoFixedChair: "Wheelchair space without a fixed chair.",
        .zoomIn: "Zoom in",
        .zoomOut: "Zoom out",
    ]
}
