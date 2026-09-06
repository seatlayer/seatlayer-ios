import Foundation

/// One resolved reading of the checkout call to action.
///
/// The picker draws that one button in two places — the sheet's foot, which a
/// phone shows collapsed as well as open, and the wide layout's checkout bar.
/// Both used to go grey while keeping a label that told the buyer nothing
/// about why. This is the single rule they share.
public struct SeatLayerPickerCheckoutCta: Sendable, Equatable {
    /// The words on the button.
    public let label: String
    /// Whether the buyer may press it.
    public let enabled: Bool
    /// Whether the button carries a spinner beside `label`. Only ever true
    /// while something the buyer already asked for is in flight.
    public let busy: Bool
    /// Whether `label` is a reason the button cannot be pressed, rather than
    /// the caller's own label.
    public let statesReason: Bool
    /// Whether a press opens the best-seats form rather than a checkout.
    public let findsBestSeats: Bool

    public init(
        label: String,
        enabled: Bool,
        busy: Bool = false,
        statesReason: Bool = false,
        findsBestSeats: Bool = false
    ) {
        self.label = label
        self.enabled = enabled
        self.busy = busy
        self.statesReason = statesReason
        self.findsBestSeats = findsBestSeats
    }
}

/// Everything the ladder reads, passed in so the rule stays pure.
public struct SeatLayerPickerCheckoutCtaInput: Sendable, Equatable {
    /// The caller's own wording for the ordinary case.
    public var label: String
    /// The composite permission: ready, not busy, not read-only, has tickets.
    public var canCheckout: Bool
    /// Whether the event has stopped selling.
    public var salesClosed: Bool
    /// Whether a general-admission or table prompt is unanswered.
    public var promptOpen: Bool
    /// Whether a seat's confirm card is still unanswered.
    public var seatCardOpen: Bool
    /// Whether the hold the press would create is already being made.
    public var creatingHold: Bool
    /// Whether the host's own checkout callback is still running.
    public var handoffInFlight: Bool
    /// How many tickets the confirmed cart holds. Nil where the caller has no
    /// count to offer, which withholds the count-shaped rungs.
    public var ticketCount: Int?
    /// Seats picked since the hold was made.
    public var pendingCount: Int
    /// Whether a hold is already standing.
    public var holdActive: Bool
    /// Whether the empty cart's door into the finder may be offered.
    public var canOfferFind: Bool
    /// The runtime's own verdict on the selection.
    public var validity: SelectionValidity?

    public init(
        label: String,
        canCheckout: Bool,
        salesClosed: Bool = false,
        promptOpen: Bool = false,
        seatCardOpen: Bool = false,
        creatingHold: Bool = false,
        handoffInFlight: Bool = false,
        ticketCount: Int? = nil,
        pendingCount: Int = 0,
        holdActive: Bool = false,
        canOfferFind: Bool = false,
        validity: SelectionValidity? = nil
    ) {
        self.label = label
        self.canCheckout = canCheckout
        self.salesClosed = salesClosed
        self.promptOpen = promptOpen
        self.seatCardOpen = seatCardOpen
        self.creatingHold = creatingHold
        self.handoffInFlight = handoffInFlight
        self.ticketCount = ticketCount
        self.pendingCount = pendingCount
        self.holdActive = holdActive
        self.canOfferFind = canOfferFind
        self.validity = validity
    }
}

/// Resolve the checkout call to action.
///
/// The order is the web picker's, and it matters: sales closing outranks an
/// open prompt, an open prompt outranks the hold a press behind it would
/// create, and a selection the event's rules reject is only worth mentioning
/// once nothing is in flight.
public func seatLayerCheckoutCtaState(
    _ input: SeatLayerPickerCheckoutCtaInput,
    strings: SeatLayerPickerStrings
) -> SeatLayerPickerCheckoutCta {
    func reason(_ words: String, busy: Bool = false) -> SeatLayerPickerCheckoutCta {
        SeatLayerPickerCheckoutCta(
            label: words,
            enabled: false,
            busy: busy,
            statesReason: true
        )
    }

    // 1. Nothing else is worth saying about an event that has stopped selling.
    if input.salesClosed { return reason(strings.text(.salesClosedCta)) }

    // 2. A prompt the buyer has not answered. The places under it are already
    //    in the runtime's selection, so without this the button reads as live.
    if input.promptOpen { return reason(strings.text(.confirmYourTickets)) }

    // The card standing over the map is the answer to this one: the footer
    // keeps the label it had so the buyer's cart still reads as their cart
    // underneath it, but nothing on the sheet is pressable — not even the
    // finder.
    if input.seatCardOpen {
        var under = input
        under.seatCardOpen = false
        let resolved = seatLayerCheckoutCtaState(under, strings: strings)
        return SeatLayerPickerCheckoutCta(
            label: resolved.label,
            enabled: false,
            busy: resolved.busy,
            statesReason: resolved.statesReason,
            findsBestSeats: false
        )
    }

    // 3. and 4. Work the buyer has already asked for. The hold comes first
    //    because the handoff cannot exist until it succeeds.
    if input.creatingHold { return reason(strings.text(.securingSeats), busy: true) }
    if input.handoffInFlight { return reason(strings.text(.openingCheckout), busy: true) }

    // 5. A selection the event's own rules reject. Say what would fix it where
    //    the runtime gave a number to say it with. `required` is 0 for a rule
    //    about the SHAPE of a selection rather than its size, and "Remove 1
    //    ticket" would be a wrong instruction there.
    if let validity = input.validity, !validity.isValid {
        if validity.remaining > 0 {
            return reason(strings.text(.chooseMore, replacing: [
                "count": String(validity.remaining),
            ]))
        }
        if validity.required > 0, validity.count > validity.required {
            return reason(strings.text(
                SeatLayerPickerPluralKeys.removeTickets,
                count: validity.count - validity.required
            ))
        }
        return reason(strings.text(.adjustSelection))
    }

    guard let count = input.ticketCount else {
        return SeatLayerPickerCheckoutCta(label: input.label, enabled: input.canCheckout)
    }

    // 6. The empty phone cart has a door, not a dead button. Gated exactly as
    //    the tray's own card is: an existing hold means no card would render,
    //    and a door into an empty room is worse than none.
    if count == 0, input.canOfferFind, !input.holdActive {
        return SeatLayerPickerCheckoutCta(
            label: strings.text(.findBestSeatsCta),
            enabled: true,
            findsBestSeats: true
        )
    }

    // 7. A hold that already exists changes what the button is offering: the
    //    seats are secured, so it offers the till — or offers to take the
    //    seats picked since into the same hold first.
    if input.holdActive {
        return SeatLayerPickerCheckoutCta(
            label: input.pendingCount > 0
                ? strings.text(.secureMoreAndCheckout, replacing: [
                    "count": String(input.pendingCount),
                ])
                : strings.text(.continueToCheckout),
            enabled: input.canCheckout
        )
    }

    // 8. An empty cart. Not a reason the button failed — there is simply
    //    nothing in it yet — but it is still the one thing left to do.
    if count == 0 {
        return SeatLayerPickerCheckoutCta(
            label: strings.text(.selectSeats),
            enabled: false,
            statesReason: true
        )
    }

    // 9. Nothing in the way: the caller's own label.
    return SeatLayerPickerCheckoutCta(label: input.label, enabled: input.canCheckout)
}
