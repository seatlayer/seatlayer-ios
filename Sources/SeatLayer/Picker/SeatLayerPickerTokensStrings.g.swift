// GENERATED — do not edit.
//
// Source: Design/tokens.json
// Regenerate: node Scripts/generate-picker-tokens.mjs
//
// The English default for every buyer-facing chrome string, and the
// typed key each one is addressed by.
import Foundation

/// Every buyer-facing string the native picker chrome can render.
///
/// The raw value is the cross-platform token name. `localeKey` is the
/// name the runtime's own translated dictionaries use, which differs for
/// plural forms (`ticketCountOne` is `ticketCount.one` there).
public enum SeatLayerPickerStringKey: String, CaseIterable, Sendable {
    /// Close seat selection
    case close
    /// Choose your seats
    case chooseSeats
    /// Venue
    case overview
    /// All floors
    case allFloors
    /// Previous section
    case previousSection
    /// Next section
    case nextSection
    /// Back to venue
    case backToVenue
    /// Cancel
    case cancel
    /// Select
    case select
    /// Add seat
    case addSeat
    /// Added
    case added
    /// Section
    case sectionWord
    /// Row
    case rowWord
    /// Seat
    case seatWord
    /// Place
    case placeWord
    /// View from here
    case viewFromHere
    /// ≈ {m} m to stage
    case sightline
    /// Passport
    case passport
    /// 3D
    case venue3D
    /// See it in 3D
    case seeItIn3D
    /// View from this seat
    case viewFromThisSeat
    /// Open venue 360°
    case openVenue360
    /// Previous seat
    case previousSeat
    /// Next seat
    case nextSeat
    /// Recentre the view
    case recentre
    /// view from your seat
    case viewFromYourSeat
    /// Choose tickets
    case chooseTickets
    /// Tap a seat on the map, or let us pick the best available for you.
    case emptyTrayHint
    /// Any ticket type
    case anyTicketType
    /// Any venue zone
    case anyVenueZone
    /// All prices
    case allPrices
    /// Ticket type
    case ticketType
    /// Premium seat
    case premiumSeat
    /// Not available
    case notAvailable
    /// VIEW
    case viewGroupTitle
    /// Organizer note
    case organizerNote
    /// Empty wheelchair space
    case emptyWheelchairSpace
    /// Accessible physical seat
    case accessiblePhysicalSeat
    /// Restricted view
    case restrictedView
    /// Obstructed view
    case obstructedView
    /// Venue zone
    case venueZone
    /// Fewer tickets
    case fewerTickets
    /// More tickets
    case moreTickets
    /// Best seats
    case bestSeats
    /// Find seats together
    case findSeatsTogether
    /// Finding the best seats…
    case findingBestSeats
    /// Find seats
    case findSeats
    /// Show less
    case showLess
    /// Undo
    case undo
    /// Hold seats & checkout
    case holdAndCheckout
    /// Continue to checkout
    case continueToCheckout
    /// Secure {count} more & checkout
    case secureMoreAndCheckout
    /// Secure more
    case secureMore
    /// No seats selected
    case noSeatsSelected
    /// Find best seats
    case findBestSeatsCta
    /// Select seats
    case selectSeats
    /// Pick your seats
    case pickYourSeats
    /// Sales are closed
    case salesClosedPill
    /// ✓ {count} secured · {total} — you won't be charged yet
    case peekSecured
    /// Seats secured. Opening checkout…
    case seatsSecuredOpeningCheckout
    /// Sales closed
    case salesClosedCta
    /// Confirm or cancel this seat
    case confirmOrCancelSeat
    /// Confirm your tickets
    case confirmYourTickets
    /// Securing your seats…
    case securingSeats
    /// Opening secure checkout…
    case openingCheckout
    /// Adjust your selection
    case adjustSelection
    /// Powered by SeatLayer
    case poweredBy
    /// Test mode
    case testMode
    /// Test mode · books nothing
    case testModeLong
    /// Bookings here are not real and no card is charged
    case testModeExplained
    /// Accessibility and view filters
    case accessibility
    /// Display options
    case displayOptions
    /// {count} free
    case accessFreeCount
    /// {index} of {total}
    case accessibleStep
    /// {count} sections
    case accessibleSections
    /// Jump to the first section
    case accessJumpFirstSection
    /// Jump to the next section
    case accessJumpNextSection
    /// Companion places beside them stay selectable
    case companionSeatsNote
    /// Fit venue
    case fitVenue
    /// Show whole venue
    case fitWholeVenue
    /// Zoom in
    case zoomIn
    /// Zoom out
    case zoomOut
    /// Map
    case mapView
    /// Flat 2D map
    case flat2dMap
    /// Interactive 3D venue view
    case interactive3dVenueView
    /// Venue view
    case venueView
    /// Ticket removed
    case seatRemoved
    /// Loading seat map…
    case loading
    /// The seat map could not be loaded.
    case errorMessage
    /// Try again
    case retry
    /// Accessibility and view
    case accessibilityTitle
    /// Hide limited-view seats
    case hideLimitedView
    /// Colourblind-friendly colours
    case colorblindSafe
    /// Wheelchair
    case accessWheelchair
    /// Companion
    case accessCompanion
    /// Semi-ambulatory
    case accessSemiAmbulatory
    /// Aisle seat
    case accessDesignatedAisle
    /// Step-free
    case accessStepFree
    /// Hearing support
    case accessHearing
    /// Mobility cart
    case accessCart
    /// Sign language view
    case accessSignLanguage
    /// Low vision
    case accessLowVision
    /// Sensory-friendly
    case accessSensoryFriendly
    /// Plus-size seat
    case accessPlusSize
    /// Lift armrest
    case accessLiftArmrest
    /// {need} · {count}
    case accessNeedWithCount
    /// Your seats were released.
    case holdLapsedTitle
    /// They were held for {n} minutes.
    case holdLapsedBody
    /// Select it again
    case reselectSeatsOne
    /// Select them again
    case reselectSeatsOther
    /// {n} could not be recovered
    case seatsNotRecovered
    /// Your seats are already in checkout
    case holdInCheckoutTitle
    /// Finish checkout to keep them. To pick different seats, release these first — they go back on sale.
    case holdInCheckoutBody
    /// Release and change seats
    case releaseAndChangeSeats
    /// Your seats are already held
    case holdAlreadyHeldTitle
    /// Continue to checkout to keep them.
    case holdAlreadyHeldBody
    /// Remove seat
    case removeSeat
    /// Open ticket panel
    case expandCart
    /// Collapse ticket panel
    case collapseCart
    /// Rotate venue
    case orbitMode
    /// Move venue
    case panMode
    /// General admission
    case generalAdmission
    /// Choose the number of guests for this table
    case chooseTableGuests
    /// Confirm table
    case confirmTable
    /// Add tickets
    case addTickets
    /// +{count} min
    case addMinutes
    /// Refresh
    case accessRefresh
    /// Select a ticket type
    case selectTicketTier
    /// Requires the adjacent wheelchair place.
    case tierCompanionGuidance
    /// {count} places currently available
    case placesAvailable
    /// Continue · {money}
    case continueWithTotal
    /// Continue
    case continueWord
    /// From {price}
    case fromPrice
    /// Find {count} best seats
    case findBestSeats
    /// Find {count} best seat
    case findBestSeatsOne
    /// Find {count} best seats
    case findBestSeatsOther
    /// {clock}
    case heldFor
    /// +{count} more
    case moreCount
    /// Drag to move venue
    case moveVenue
    /// Place {place}
    case placeNumberIdentity
    /// Select them again
    case reselectSeats
    /// {parts}
    case seatIdentity
    /// {count} seats
    case seatsFree
    /// {count} seat
    case seatsFreeOne
    /// {count} seats
    case seatsFreeOther
    /// {count} left
    case seatsLeft
    /// {count} seat left
    case seatsLeftInSectionOne
    /// {count} seats left
    case seatsLeftInSectionOther
    /// Only {count} left
    case onlyLeft
    /// Choose {count} more
    case chooseMore
    /// Remove {count} tickets
    case removeTickets
    /// Remove {count} ticket
    case removeTicketsOne
    /// Remove {count} tickets
    case removeTicketsOther
    /// {count} tickets
    case ticketCount
    /// {count} ticket
    case ticketCountOne
    /// {count} tickets
    case ticketCountOther
    /// Row {row}
    case rowIdentity
    /// Drag to rotate venue
    case rotateVenue
    /// Seat {seat}
    case seatNumberIdentity
    /// Sales are closed
    case salesClosed
    /// Ticket sales for this event have ended.
    case salesClosedCopy
    /// Sales are closed for this event.
    case salesClosedToast
    /// This event
    case soldOutEyebrow
    /// Sold out
    case soldOutTitle
    /// No reserved seats are currently available for this event.
    case soldOutCopy
    /// Your hold expired — the seats were released. Pick again.
    case holdExpired
    /// Your hold ended while you were away. That seat is still free.
    case holdLapsedStillFreeOne
    /// Your hold ended while you were away. Those seats are still free.
    case holdLapsedStillFreeOther
    /// Your hold ended while you were away, and {count} of those seats has been taken. The rest are still free.
    case holdLapsedSomeTakenOne
    /// Your hold ended while you were away, and {count} of those seats have been taken. The rest are still free.
    case holdLapsedSomeTakenOther
    /// Your hold ended while you were away, and that seat has been taken.
    case holdLapsedAllTakenOne
    /// Your hold ended while you were away, and those seats have been taken.
    case holdLapsedAllTakenOther
    /// Your seats are held for {time}. Need more time?
    case seatsHeldForNeedMoreTime
    /// Add time
    case addTime
    /// Adding…
    case addingEllipsis
    /// More time added — your seats are still held.
    case moreTimeAdded
    /// Couldn't add more time — please head to checkout now.
    case couldNotAddMoreTime
    /// Seat {label} was just taken by another buyer.
    case seatJustTakenByAnother
    /// One or more seats were just taken. Please pick again.
    case seatsJustTaken
    /// You're all set
    case allSetTitle
    /// confirmed. A confirmation is on its way.
    case confirmedAndOnWay
    /// Back to map
    case backToMap
    /// The seat map didn't load
    case mapDidNotLoad
    /// Check your connection and try again.
    case checkConnection
    /// These seats are on hold right now
    case accessPausedTitle
    /// The organizer has paused this selection. Try again in a few minutes.
    case accessPausedCopy
    /// This access link is no longer active
    case accessRevokedTitle
    /// Ask whoever sent you here for a new link to keep booking these seats.
    case accessRevokedCopy
    /// Your seat session has expired
    case accessExpiredTitle
    /// Reload the seat map to continue. Seats already in your cart stay held until the timer ends.
    case accessExpiredCopy
    /// We couldn't verify your access
    case accessUnverifiedTitle
    /// You can still book anything shown as available. Contact whoever sent you here for access to the rest.
    case accessUnverifiedCopy
    /// Reload seat map
    case reloadSeatMap
    /// No selectable seats are currently available.
    case noSelectableSeats
    /// Number of guests
    case numberOfGuests
    /// Choose how many guests will sit together. This table is held exclusively for your party.
    case chooseGuestsCopy
    /// Fewer guests
    case fewerGuests
    /// More guests
    case moreGuests
    /// Choose between {min} and {max} guests.
    case chooseMinMaxGuests
    /// Select table
    case selectTable
    /// Update table
    case updateTable
    /// Remove
    case removeWord
    /// {venue} seat map
    case venueMap
    /// Seats are picked with the controls around the map: the price rail above it, the section controls below it, and the ticket panel at the foot.
    case venueMapHint
    /// {count} minute left
    case holdMinutesLeftOne
    /// {count} minutes left
    case holdMinutesLeftOther
    /// {count} second left
    case holdSecondsLeftOne
    /// {count} seconds left
    case holdSecondsLeftOther
    /// About finding seats together
    case aboutBestSeats
    /// Closest available group, chosen instantly.
    case closestGroupChosenInstantly

    /// The key this string carries in the translated dictionaries.
    public var localeKey: String {
        switch self {
        case .reselectSeatsOne: return "reselectSeats.one"
        case .reselectSeatsOther: return "reselectSeats.other"
        case .findBestSeatsOne: return "findBestSeats.one"
        case .findBestSeatsOther: return "findBestSeats.other"
        case .seatsFreeOne: return "seatsFree.one"
        case .seatsFreeOther: return "seatsFree.other"
        case .seatsLeftInSectionOne: return "seatsLeftInSection.one"
        case .seatsLeftInSectionOther: return "seatsLeftInSection.other"
        case .removeTicketsOne: return "removeTickets.one"
        case .removeTicketsOther: return "removeTickets.other"
        case .ticketCountOne: return "ticketCount.one"
        case .ticketCountOther: return "ticketCount.other"
        case .holdLapsedStillFreeOne: return "holdLapsedStillFree.one"
        case .holdLapsedStillFreeOther: return "holdLapsedStillFree.other"
        case .holdLapsedSomeTakenOne: return "holdLapsedSomeTaken.one"
        case .holdLapsedSomeTakenOther: return "holdLapsedSomeTaken.other"
        case .holdLapsedAllTakenOne: return "holdLapsedAllTaken.one"
        case .holdLapsedAllTakenOther: return "holdLapsedAllTaken.other"
        case .holdMinutesLeftOne: return "holdMinutesLeft.one"
        case .holdMinutesLeftOther: return "holdMinutesLeft.other"
        case .holdSecondsLeftOne: return "holdSecondsLeft.one"
        case .holdSecondsLeftOther: return "holdSecondsLeft.other"
        default: return rawValue
        }
    }

    /// The English default.
    public var englishDefault: String {
        SeatLayerPickerStringTokens.english[self] ?? rawValue
    }
}

/// A string that has one wording for a count of one and another
/// for every other count.
public struct SeatLayerPickerPluralKey: Sendable, Equatable {
    public let one: SeatLayerPickerStringKey
    public let other: SeatLayerPickerStringKey

    /// The form that names `count`.
    public func form(_ count: Int) -> SeatLayerPickerStringKey {
        count == 1 ? one : other
    }
}

/// Every string that has singular and plural wordings.
public enum SeatLayerPickerPluralKeys {
    /// `reselectSeats`
    public static let reselectSeats = SeatLayerPickerPluralKey(
        one: .reselectSeatsOne,
        other: .reselectSeatsOther
    )
    /// `findBestSeats`
    public static let findBestSeats = SeatLayerPickerPluralKey(
        one: .findBestSeatsOne,
        other: .findBestSeatsOther
    )
    /// `seatsFree`
    public static let seatsFree = SeatLayerPickerPluralKey(
        one: .seatsFreeOne,
        other: .seatsFreeOther
    )
    /// `seatsLeftInSection`
    public static let seatsLeftInSection = SeatLayerPickerPluralKey(
        one: .seatsLeftInSectionOne,
        other: .seatsLeftInSectionOther
    )
    /// `removeTickets`
    public static let removeTickets = SeatLayerPickerPluralKey(
        one: .removeTicketsOne,
        other: .removeTicketsOther
    )
    /// `ticketCount`
    public static let ticketCount = SeatLayerPickerPluralKey(
        one: .ticketCountOne,
        other: .ticketCountOther
    )
    /// `holdLapsedStillFree`
    public static let holdLapsedStillFree = SeatLayerPickerPluralKey(
        one: .holdLapsedStillFreeOne,
        other: .holdLapsedStillFreeOther
    )
    /// `holdLapsedSomeTaken`
    public static let holdLapsedSomeTaken = SeatLayerPickerPluralKey(
        one: .holdLapsedSomeTakenOne,
        other: .holdLapsedSomeTakenOther
    )
    /// `holdLapsedAllTaken`
    public static let holdLapsedAllTaken = SeatLayerPickerPluralKey(
        one: .holdLapsedAllTakenOne,
        other: .holdLapsedAllTakenOther
    )
    /// `holdMinutesLeft`
    public static let holdMinutesLeft = SeatLayerPickerPluralKey(
        one: .holdMinutesLeftOne,
        other: .holdMinutesLeftOther
    )
    /// `holdSecondsLeft`
    public static let holdSecondsLeft = SeatLayerPickerPluralKey(
        one: .holdSecondsLeftOne,
        other: .holdSecondsLeftOther
    )
}

/// The English default for every buyer-facing chrome string.
public enum SeatLayerPickerStringTokens {
    /// The English default for every key.
    public static let english: [SeatLayerPickerStringKey: String] = [
        .close: "Close seat selection",
        .chooseSeats: "Choose your seats",
        .overview: "Venue",
        .allFloors: "All floors",
        .previousSection: "Previous section",
        .nextSection: "Next section",
        .backToVenue: "Back to venue",
        .cancel: "Cancel",
        .select: "Select",
        .addSeat: "Add seat",
        .added: "Added",
        .sectionWord: "Section",
        .rowWord: "Row",
        .seatWord: "Seat",
        .placeWord: "Place",
        .viewFromHere: "View from here",
        .sightline: "≈ {m} m to stage",
        .passport: "Passport",
        .venue3D: "3D",
        .seeItIn3D: "See it in 3D",
        .viewFromThisSeat: "View from this seat",
        .openVenue360: "Open venue 360°",
        .previousSeat: "Previous seat",
        .nextSeat: "Next seat",
        .recentre: "Recentre the view",
        .viewFromYourSeat: "view from your seat",
        .chooseTickets: "Choose tickets",
        .emptyTrayHint: "Tap a seat on the map, or let us pick the best available for you.",
        .anyTicketType: "Any ticket type",
        .anyVenueZone: "Any venue zone",
        .allPrices: "All prices",
        .ticketType: "Ticket type",
        .premiumSeat: "Premium seat",
        .notAvailable: "Not available",
        .viewGroupTitle: "VIEW",
        .organizerNote: "Organizer note",
        .emptyWheelchairSpace: "Empty wheelchair space",
        .accessiblePhysicalSeat: "Accessible physical seat",
        .restrictedView: "Restricted view",
        .obstructedView: "Obstructed view",
        .venueZone: "Venue zone",
        .fewerTickets: "Fewer tickets",
        .moreTickets: "More tickets",
        .bestSeats: "Best seats",
        .findSeatsTogether: "Find seats together",
        .findingBestSeats: "Finding the best seats…",
        .findSeats: "Find seats",
        .showLess: "Show less",
        .undo: "Undo",
        .holdAndCheckout: "Hold seats & checkout",
        .continueToCheckout: "Continue to checkout",
        .secureMoreAndCheckout: "Secure {count} more & checkout",
        .secureMore: "Secure more",
        .noSeatsSelected: "No seats selected",
        .findBestSeatsCta: "Find best seats",
        .selectSeats: "Select seats",
        .pickYourSeats: "Pick your seats",
        .salesClosedPill: "Sales are closed",
        .peekSecured: "✓ {count} secured · {total} — you won't be charged yet",
        .seatsSecuredOpeningCheckout: "Seats secured. Opening checkout…",
        .salesClosedCta: "Sales closed",
        .confirmOrCancelSeat: "Confirm or cancel this seat",
        .confirmYourTickets: "Confirm your tickets",
        .securingSeats: "Securing your seats…",
        .openingCheckout: "Opening secure checkout…",
        .adjustSelection: "Adjust your selection",
        .poweredBy: "Powered by SeatLayer",
        .testMode: "Test mode",
        .testModeLong: "Test mode · books nothing",
        .testModeExplained: "Bookings here are not real and no card is charged",
        .accessibility: "Accessibility and view filters",
        .displayOptions: "Display options",
        .accessFreeCount: "{count} free",
        .accessibleStep: "{index} of {total}",
        .accessibleSections: "{count} sections",
        .accessJumpFirstSection: "Jump to the first section",
        .accessJumpNextSection: "Jump to the next section",
        .companionSeatsNote: "Companion places beside them stay selectable",
        .fitVenue: "Fit venue",
        .fitWholeVenue: "Show whole venue",
        .zoomIn: "Zoom in",
        .zoomOut: "Zoom out",
        .mapView: "Map",
        .flat2dMap: "Flat 2D map",
        .interactive3dVenueView: "Interactive 3D venue view",
        .venueView: "Venue view",
        .seatRemoved: "Ticket removed",
        .loading: "Loading seat map…",
        .errorMessage: "The seat map could not be loaded.",
        .retry: "Try again",
        .accessibilityTitle: "Accessibility and view",
        .hideLimitedView: "Hide limited-view seats",
        .colorblindSafe: "Colourblind-friendly colours",
        .accessWheelchair: "Wheelchair",
        .accessCompanion: "Companion",
        .accessSemiAmbulatory: "Semi-ambulatory",
        .accessDesignatedAisle: "Aisle seat",
        .accessStepFree: "Step-free",
        .accessHearing: "Hearing support",
        .accessCart: "Mobility cart",
        .accessSignLanguage: "Sign language view",
        .accessLowVision: "Low vision",
        .accessSensoryFriendly: "Sensory-friendly",
        .accessPlusSize: "Plus-size seat",
        .accessLiftArmrest: "Lift armrest",
        .accessNeedWithCount: "{need} · {count}",
        .holdLapsedTitle: "Your seats were released.",
        .holdLapsedBody: "They were held for {n} minutes.",
        .reselectSeatsOne: "Select it again",
        .reselectSeatsOther: "Select them again",
        .seatsNotRecovered: "{n} could not be recovered",
        .holdInCheckoutTitle: "Your seats are already in checkout",
        .holdInCheckoutBody: "Finish checkout to keep them. To pick different seats, release these first — they go back on sale.",
        .releaseAndChangeSeats: "Release and change seats",
        .holdAlreadyHeldTitle: "Your seats are already held",
        .holdAlreadyHeldBody: "Continue to checkout to keep them.",
        .removeSeat: "Remove seat",
        .expandCart: "Open ticket panel",
        .collapseCart: "Collapse ticket panel",
        .orbitMode: "Rotate venue",
        .panMode: "Move venue",
        .generalAdmission: "General admission",
        .chooseTableGuests: "Choose the number of guests for this table",
        .confirmTable: "Confirm table",
        .addTickets: "Add tickets",
        .addMinutes: "+{count} min",
        .accessRefresh: "Refresh",
        .selectTicketTier: "Select a ticket type",
        .tierCompanionGuidance: "Requires the adjacent wheelchair place.",
        .placesAvailable: "{count} places currently available",
        .continueWithTotal: "Continue · {money}",
        .continueWord: "Continue",
        .fromPrice: "From {price}",
        .findBestSeats: "Find {count} best seats",
        .findBestSeatsOne: "Find {count} best seat",
        .findBestSeatsOther: "Find {count} best seats",
        .heldFor: "{clock}",
        .moreCount: "+{count} more",
        .moveVenue: "Drag to move venue",
        .placeNumberIdentity: "Place {place}",
        .reselectSeats: "Select them again",
        .seatIdentity: "{parts}",
        .seatsFree: "{count} seats",
        .seatsFreeOne: "{count} seat",
        .seatsFreeOther: "{count} seats",
        .seatsLeft: "{count} left",
        .seatsLeftInSectionOne: "{count} seat left",
        .seatsLeftInSectionOther: "{count} seats left",
        .onlyLeft: "Only {count} left",
        .chooseMore: "Choose {count} more",
        .removeTickets: "Remove {count} tickets",
        .removeTicketsOne: "Remove {count} ticket",
        .removeTicketsOther: "Remove {count} tickets",
        .ticketCount: "{count} tickets",
        .ticketCountOne: "{count} ticket",
        .ticketCountOther: "{count} tickets",
        .rowIdentity: "Row {row}",
        .rotateVenue: "Drag to rotate venue",
        .seatNumberIdentity: "Seat {seat}",
        .salesClosed: "Sales are closed",
        .salesClosedCopy: "Ticket sales for this event have ended.",
        .salesClosedToast: "Sales are closed for this event.",
        .soldOutEyebrow: "This event",
        .soldOutTitle: "Sold out",
        .soldOutCopy: "No reserved seats are currently available for this event.",
        .holdExpired: "Your hold expired — the seats were released. Pick again.",
        .holdLapsedStillFreeOne: "Your hold ended while you were away. That seat is still free.",
        .holdLapsedStillFreeOther: "Your hold ended while you were away. Those seats are still free.",
        .holdLapsedSomeTakenOne: "Your hold ended while you were away, and {count} of those seats has been taken. The rest are still free.",
        .holdLapsedSomeTakenOther: "Your hold ended while you were away, and {count} of those seats have been taken. The rest are still free.",
        .holdLapsedAllTakenOne: "Your hold ended while you were away, and that seat has been taken.",
        .holdLapsedAllTakenOther: "Your hold ended while you were away, and those seats have been taken.",
        .seatsHeldForNeedMoreTime: "Your seats are held for {time}. Need more time?",
        .addTime: "Add time",
        .addingEllipsis: "Adding…",
        .moreTimeAdded: "More time added — your seats are still held.",
        .couldNotAddMoreTime: "Couldn't add more time — please head to checkout now.",
        .seatJustTakenByAnother: "Seat {label} was just taken by another buyer.",
        .seatsJustTaken: "One or more seats were just taken. Please pick again.",
        .allSetTitle: "You're all set",
        .confirmedAndOnWay: "confirmed. A confirmation is on its way.",
        .backToMap: "Back to map",
        .mapDidNotLoad: "The seat map didn't load",
        .checkConnection: "Check your connection and try again.",
        .accessPausedTitle: "These seats are on hold right now",
        .accessPausedCopy: "The organizer has paused this selection. Try again in a few minutes.",
        .accessRevokedTitle: "This access link is no longer active",
        .accessRevokedCopy: "Ask whoever sent you here for a new link to keep booking these seats.",
        .accessExpiredTitle: "Your seat session has expired",
        .accessExpiredCopy: "Reload the seat map to continue. Seats already in your cart stay held until the timer ends.",
        .accessUnverifiedTitle: "We couldn't verify your access",
        .accessUnverifiedCopy: "You can still book anything shown as available. Contact whoever sent you here for access to the rest.",
        .reloadSeatMap: "Reload seat map",
        .noSelectableSeats: "No selectable seats are currently available.",
        .numberOfGuests: "Number of guests",
        .chooseGuestsCopy: "Choose how many guests will sit together. This table is held exclusively for your party.",
        .fewerGuests: "Fewer guests",
        .moreGuests: "More guests",
        .chooseMinMaxGuests: "Choose between {min} and {max} guests.",
        .selectTable: "Select table",
        .updateTable: "Update table",
        .removeWord: "Remove",
        .venueMap: "{venue} seat map",
        .venueMapHint: "Seats are picked with the controls around the map: the price rail above it, the section controls below it, and the ticket panel at the foot.",
        .holdMinutesLeftOne: "{count} minute left",
        .holdMinutesLeftOther: "{count} minutes left",
        .holdSecondsLeftOne: "{count} second left",
        .holdSecondsLeftOther: "{count} seconds left",
        .aboutBestSeats: "About finding seats together",
        .closestGroupChosenInstantly: "Closest available group, chosen instantly.",
    ]
}
