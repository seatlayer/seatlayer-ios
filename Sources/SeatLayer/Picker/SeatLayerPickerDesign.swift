import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

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

    public static func duration(
        _ effect: SeatLayerPickerMotionEffect
    ) -> Int {
        switch effect {
        case .enter: return enterMilliseconds
        case .exit: return exitMilliseconds
        case .dock: return dockMilliseconds
        case .sheet: return sheetMilliseconds
        case .fly: return flyMilliseconds
        case .pop: return popMilliseconds
        case .stagger: return staggerMilliseconds
        case .crossfade: return crossfadeMilliseconds
        case .toast: return toastMilliseconds
        case .immersive: return immersiveMilliseconds
        }
    }

    public static var allDurations: [SeatLayerPickerMotionEffect: Int] {
        Dictionary(uniqueKeysWithValues: SeatLayerPickerMotionEffect.allCases.map {
            ($0, duration($0))
        })
    }
}

public enum SeatLayerPickerMotionEffect: String, Sendable, Equatable, CaseIterable {
    case enter
    case exit
    case dock
    case sheet
    case fly
    case pop
    case stagger
    case crossfade
    case toast
    case immersive
}

public enum SeatLayerPickerMotionCurve: String, Sendable, Equatable, CaseIterable {
    case easeEnter
    case easeExit
    case spring
}

public struct SeatLayerPickerCubicBezier: Sendable, Equatable {
    public let x1: Double
    public let y1: Double
    public let x2: Double
    public let y2: Double

    public init(x1: Double, y1: Double, x2: Double, y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
}

public struct SeatLayerPickerResolvedMotion: Sendable, Equatable {
    public let effect: SeatLayerPickerMotionEffect
    public let durationMilliseconds: Int
    public let curve: SeatLayerPickerCubicBezier
    /// Effects with no meaningful reduced form are omitted rather than played
    /// instantly when Reduce Motion is enabled.
    public let skipped: Bool

    public init(
        effect: SeatLayerPickerMotionEffect,
        durationMilliseconds: Int,
        curve: SeatLayerPickerCubicBezier,
        skipped: Bool
    ) {
        self.effect = effect
        self.durationMilliseconds = durationMilliseconds
        self.curve = curve
        self.skipped = skipped
    }
}

public enum SeatLayerPickerMotion {
    public static func curve(
        _ curve: SeatLayerPickerMotionCurve
    ) -> SeatLayerPickerCubicBezier {
        switch curve {
        case .easeEnter:
            return .init(x1: 0.215, y1: 0.61, x2: 0.355, y2: 1)
        case .easeExit:
            return .init(x1: 0.55, y1: 0.055, x2: 0.675, y2: 0.19)
        case .spring:
            return .init(x1: 0.34, y1: 1.56, x2: 0.64, y2: 1)
        }
    }

    public static func resolve(
        _ effect: SeatLayerPickerMotionEffect,
        reduceMotion: Bool,
        curve curveName: SeatLayerPickerMotionCurve = .easeEnter
    ) -> SeatLayerPickerResolvedMotion {
        let skipped = reduceMotion && [.fly, .stagger].contains(effect)
        return .init(
            effect: effect,
            durationMilliseconds: reduceMotion
                ? 0
                : SeatLayerPickerMotionTokens.duration(effect),
            curve: curve(curveName),
            skipped: skipped
        )
    }
}

public enum SeatLayerPickerHapticTokens {
    public static let selectionAdded = SeatLayerPickerHapticStrength.selection
    public static let sectionFocused = SeatLayerPickerHapticStrength.light
    public static let holdCreated = SeatLayerPickerHapticStrength.medium
    public static let holdExpired = SeatLayerPickerHapticStrength.heavy

    public static func strength(
        for cue: SeatLayerPickerHapticCue
    ) -> SeatLayerPickerHapticStrength {
        switch cue {
        case .selectionAdded: return selectionAdded
        case .sectionFocused: return sectionFocused
        case .holdCreated: return holdCreated
        case .holdExpired: return holdExpired
        }
    }
}

#if canImport(SwiftUI)
func seatLayerPickerAnimation(
    _ effect: SeatLayerPickerMotionEffect,
    reduceMotion: Bool,
    curve: SeatLayerPickerMotionCurve = .easeEnter
) -> Animation? {
    let resolved = SeatLayerPickerMotion.resolve(
        effect,
        reduceMotion: reduceMotion,
        curve: curve
    )
    guard !resolved.skipped, resolved.durationMilliseconds > 0 else { return nil }
    return .timingCurve(
        resolved.curve.x1,
        resolved.curve.y1,
        resolved.curve.x2,
        resolved.curve.y2,
        duration: Double(resolved.durationMilliseconds) / 1_000
    )
}

/// Scales explicit design-token point sizes with the buyer's Dynamic Type
/// setting while retaining the picker typography weights and rounded numerals.
/// A shared modifier keeps custom component implementations from silently
/// falling back to fixed-size text.
struct SeatLayerPickerScaledFontModifier: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 17
    let weight: Font.Weight
    let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight, design: design))
    }
}

extension View {
    func seatLayerPickerFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(SeatLayerPickerScaledFontModifier(
            size: size,
            weight: weight,
            design: design
        ))
    }
}
#endif

public enum SeatLayerPickerElevationTokens {
    public static let header = 0.0
    public static let dockBar = 8.0
    public static let sheet = 12.0
    public static let confirmCard = 18.0
    public static let pill = 0.0
}

public enum SeatLayerPickerStringKey: String, CaseIterable, Sendable {
    case accessCart
    case accessCompanion
    case accessDesignatedAisle
    case accessHearing
    case accessLiftArmrest
    case accessLowVision
    case accessNeedWithCount
    case accessPlusSize
    case accessSemiAmbulatory
    case accessSensoryFriendly
    case accessSignLanguage
    case accessStepFree
    case accessWheelchair
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
    case moveVenue
    case nextSeat
    case nextSection
    case orbitMode
    case overview
    case panMode
    case poweredBy
    case previousSeat
    case previousSection
    case recentre
    case removeSeat
    case removeTable
    case recoverSeats
    case retry
    case select
    case selectTicketTier
    case seatsLeft
    case showLess
    case row
    case salesClosed
    case seat
    case seatRemoved
    case section
    case testMode
    case testModeDescription
    case ticket
    case noTicketsAvailable
    case place
    case placesAvailable
    case confirmTable
    case ticketCount
    case tierCompanionGuidance
    case ticketType
    case undo
    case venue3D
    case viewFromHere
    case viewFromYourSeat
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

    var resolvedLocale: Locale {
        Locale(identifier: requestedLocaleIdentifier)
    }

    var usesRightToLeftLayout: Bool {
        let language = requestedLocaleIdentifier.split(separator: "-").first
            .map { String($0).lowercased() } ?? "en"
        return ["ar", "fa", "he", "ku"].contains(language)
    }

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

    public func findBestSeats(_ count: Int) -> String {
        let pluralKey = count == 1 ? "findBestSeats.one" : "findBestSeats.other"
        let template = overrides[pluralKey]
            ?? localized[pluralKey]
            ?? (count == 1 ? "Find {count} best seat" : "Find {count} best seats")
        return template.replacingOccurrences(of: "{count}", with: String(count))
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

    public func accessNeed(_ key: String, count: Int? = nil) -> String {
        let canonicalKey = key.lowercased().replacingOccurrences(of: "_", with: "-")
        let known: [String: SeatLayerPickerStringKey] = [
            "wheelchair": .accessWheelchair,
            "companion": .accessCompanion,
            "semi-ambulatory": .accessSemiAmbulatory,
            "designated-aisle": .accessDesignatedAisle,
            "step-free": .accessStepFree,
            "hearing": .accessHearing,
            "cart": .accessCart,
            "sign-language": .accessSignLanguage,
            "low-vision": .accessLowVision,
            "sensory-friendly": .accessSensoryFriendly,
            "plus-size": .accessPlusSize,
            "lift-armrest": .accessLiftArmrest,
        ]
        let words = key
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = words.isEmpty
            ? key
            : String(words.prefix(1)).uppercased(with: resolvedLocale) + words.dropFirst()
        let label = overrides["accessNeeds.\(key)"]
            ?? overrides["accessNeeds.\(canonicalKey)"]
            ?? known[canonicalKey].map { text($0) }
            ?? fallback
        guard let count else { return label }
        return text(
            .accessNeedWithCount,
            replacing: ["need": label, "count": String(max(0, count))]
        )
    }

    private var localized: [String: String] {
        let requested = requestedLocaleIdentifier
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

    private var requestedLocaleIdentifier: String {
        let candidate = (localeIdentifier ?? Locale.preferredLanguages.first ?? "en")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
        return candidate.isEmpty ? "en" : candidate
    }

    private static let english: [SeatLayerPickerStringKey: String] = [
        .accessCart: "Mobility cart",
        .accessCompanion: "Companion",
        .accessDesignatedAisle: "Aisle seat",
        .accessHearing: "Hearing support",
        .accessLiftArmrest: "Lift armrest",
        .accessLowVision: "Low vision",
        .accessNeedWithCount: "{need} · {count}",
        .accessPlusSize: "Plus-size seat",
        .accessSemiAmbulatory: "Semi-ambulatory",
        .accessSensoryFriendly: "Sensory-friendly",
        .accessSignLanguage: "Sign language view",
        .accessStepFree: "Step-free",
        .accessWheelchair: "Wheelchair",
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
        .moveVenue: "Drag to move venue",
        .nextSeat: "Next seat",
        .nextSection: "Next section",
        .orbitMode: "Rotate venue",
        .overview: "Venue",
        .panMode: "Move venue",
        .poweredBy: "Powered by SeatLayer",
        .previousSeat: "Previous seat",
        .previousSection: "Previous section",
        .recentre: "Recentre on this seat",
        .removeSeat: "Remove ticket",
        .removeTable: "Remove table",
        .recoverSeats: "Recover seats",
        .retry: "Try again",
        .select: "Select",
        .selectTicketTier: "Select a ticket type",
        .seatsLeft: "{count} left",
        .showLess: "Show less",
        .row: "Row",
        .salesClosed: "Ticket sales for this event have ended.",
        .seat: "Seat",
        .seatRemoved: "Ticket removed.",
        .section: "Section",
        .testMode: "TEST MODE",
        .testModeDescription: "Test event. No real booking will be made.",
        .ticket: "Ticket",
        .noTicketsAvailable: "No tickets are currently available.",
        .place: "Place",
        .placesAvailable: "{count} places currently available",
        .confirmTable: "Confirm table",
        .ticketCount: "{count} tickets",
        .tierCompanionGuidance: "Requires the adjacent wheelchair place.",
        .ticketType: "Ticket type",
        .undo: "Undo",
        .venue3D: "3D",
        .viewFromHere: "View from here",
        .viewFromYourSeat: "view from your seat",
        .viewInformation: "View information",
        .wheelchairAccessibleSeating: "Wheelchair-accessible seating.",
        .wheelchairSpaceNoFixedChair: "Wheelchair space without a fixed chair.",
        .zoomIn: "Zoom in",
        .zoomOut: "Zoom out",
    ]
}

/// Deliberately derives buyer copy from stable error classification, never
/// from a bridge or host-provided description that could contain private
/// checkout state. Integrators still receive the complete typed error through
/// callbacks for their own diagnostics.
func seatLayerPickerBuyerErrorText(
    _ error: SeatLayerError,
    strings: SeatLayerPickerStrings
) -> String {
    let unavailableCodes: Set<String> = [
        "sold_out",
        "not_enough_together",
        "hold_unavailable",
        "event_closed",
        "sales_closed",
        "no_inventory",
    ]
    if unavailableCodes.contains(error.code) {
        return strings.text(.noTicketsAvailable)
    }
    return error.isRetryable ? strings.text(.retry) : strings.text(.errorMessage)
}
