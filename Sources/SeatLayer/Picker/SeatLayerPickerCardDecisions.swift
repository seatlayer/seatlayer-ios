import Foundation

/// The seat card's judgements, with nothing drawn.
///
/// Which seats may be asked about at all, which word the primary answer
/// offers, how a row prints once its section has already been named, and how
/// far the card follows a thumb before it goes stiff. Every one of them is a
/// rule a screenshot cannot check, so they live here and the views only read
/// them.

/// The two questions the one card asks.
///
/// `add` is the original: a seat the buyer has tapped but not yet taken.
/// `remove` is the same card about a seat already in their cart, raised by a
/// SECOND tap on it — which used to drop the seat in silence, with no card and
/// nothing to undo it with. Same layout, same identity, same price; only the
/// primary answer changes, and Cancel keeps the seat rather than dropping it.
///
/// Deliberately not a separate card: a buyer taps a seat and expects the thing
/// that seat's tap always produces, and two surfaces for one gesture is a
/// second thing to learn for no gain.
public enum SeatLayerPickerCardQuestion: String, Sendable, Equatable, CaseIterable {
    case add
    case remove
}

/// Whether a card may be raised over `seat` at all.
///
/// A seat the buyer cannot take is INERT. The engine stopped reporting taps on
/// one, and this is the same rule on this side of the bridge for the case where
/// an older runtime still reports the tap: a card asking "add this seat?" over
/// a seat that is sold, blocked or in someone else's hold is a question with no
/// true answer, and the buyer would be told a reason they can do nothing about
/// instead of being left on the map.
///
/// `held` is the one status that depends on WHOSE hold it is. The picker's own
/// hold makes the buyer's seats held, and those seats keep their card — it is
/// the card that offers them back. With no hold of the picker's own, a held
/// seat belongs to someone else.
///
/// A status this build does not know is not a reason to swallow a seat the
/// runtime put in the selection.
public func seatLayerPickerMayAskAboutSeat(
    _ seat: SelectedSeat,
    holdActive: Bool
) -> Bool {
    switch seat.status {
    case nil: return true
    case .booked, .blocked: return false
    case .held: return holdActive
    default: return true
    }
}

/// Whether the seat's category is one a buyer may choose from.
///
/// "Not for sale" is a property of the CATEGORY, not of the seat: an organizer
/// marks a whole price band unsellable and every seat in it goes inert
/// together. A seat whose category this snapshot does not carry is left alone.
public func seatLayerPickerCategoryIsSelectable(
    _ seat: SelectedSeat,
    in snapshot: SeatLayerPickerSnapshot?
) -> Bool {
    guard let key = seat.categoryKey,
          let category = snapshot?.categories.first(where: { $0.key == key })
    else { return true }
    return !category.notForSale
}

/// The word the card's primary answer offers.
///
/// A booth, a table or a general-admission area is not a seat, and the button
/// must not call it one.
public func seatLayerPickerCardPrimaryKey(
    _ seat: SelectedSeat,
    question: SeatLayerPickerCardQuestion
) -> SeatLayerPickerStringKey {
    if question == .remove { return .removeSeat }
    let type = seat.objectType?.rawValue
    return type == nil || type == "seat" ? .addSeat : .select
}

/// What the chart calls a row, where it called it anything.
///
/// A chart that named its rows "Tier" or "Bank" said so on purpose, and the
/// card prints the organizer's word rather than correcting it to "Row".
public func seatLayerPickerRowWord(
    _ seat: SelectedSeat,
    strings: SeatLayerPickerStrings
) -> String {
    let display = seat.displayType?.trimmingCharacters(in: .whitespaces) ?? ""
    if !display.isEmpty { return display }
    let rowType = seat.rowType?.trimmingCharacters(in: .whitespaces) ?? ""
    if !rowType.isEmpty { return rowType }
    return strings.text(.rowWord)
}

/// What the chart calls the thing in the row. A booth holds a place, not a
/// seat.
public func seatLayerPickerSeatWord(
    _ seat: SelectedSeat,
    strings: SeatLayerPickerStrings
) -> String {
    strings.text(seat.objectType?.rawValue == "booth" ? .placeWord : .seatWord)
}

/// The row's own label, with the section's name taken off the front of it.
///
/// A chart authored with `id: GALL, label: Gallery` names its rows `GALL-H`,
/// and the card has already printed `Gallery` in the cell beside it. Printing
/// `GALL-H` there says the section twice and leaves the buyer reading a code
/// instead of a row.
///
/// `sectionCode` is the section's own id where the snapshot carries one, which
/// strips exactly that token without leaning on the abbreviation rule below.
public func seatLayerPickerRowLabel(
    _ rowLabel: String?,
    section sectionLabel: String?,
    sectionCode: String? = nil
) -> String {
    let row = rowLabel?.trimmingCharacters(in: .whitespaces) ?? ""
    let section = sectionLabel?.trimmingCharacters(in: .whitespaces) ?? ""
    guard !row.isEmpty else { return row }

    if !section.isEmpty, row.lowercased().hasPrefix(section.lowercased()) {
        let rest = seatLayerPickerWithoutLeadingSeparator(String(row.dropFirst(section.count)))
        if !rest.isEmpty { return rest }
    }

    guard let separator = row.firstIndex(where: {
        seatLayerPickerRowPrefixSeparators.contains($0)
    }) else { return row }
    let head = String(row[row.startIndex..<separator])
    let rest = seatLayerPickerWithoutLeadingSeparator(String(row[separator...]))
    guard !rest.isEmpty else { return row }
    return seatLayerPickerNamesSection(head, section: section, code: sectionCode) ? rest : row
}

/// The code the snapshot gave the section named `sectionLabel`, if any.
public func seatLayerPickerSectionCode(
    _ snapshot: SeatLayerPickerSnapshot?,
    sectionLabel: String?
) -> String? {
    let label = sectionLabel?.trimmingCharacters(in: .whitespaces).lowercased()
    guard let label, !label.isEmpty else { return nil }
    return snapshot?.sections.first {
        $0.label.trimmingCharacters(in: .whitespaces).lowercased() == label
            || $0.displayLabel?.trimmingCharacters(in: .whitespaces).lowercased() == label
    }?.id
}

/// The characters a chart puts between a section's name and a row's.
let seatLayerPickerRowPrefixSeparators: Set<Character> = ["-", "–", "—", "_", " ", "·", "/"]

func seatLayerPickerWithoutLeadingSeparator(_ value: String) -> String {
    var rest = value.trimmingCharacters(in: .whitespaces)
    while let first = rest.first, seatLayerPickerRowPrefixSeparators.contains(first) {
        rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
    }
    return rest
}

/// Whether `head` is the section saying its own name again.
func seatLayerPickerNamesSection(
    _ head: String,
    section: String,
    code: String?
) -> Bool {
    guard !head.isEmpty else { return false }
    let upper = head.uppercased()
    let trimmedCode = code?.trimmingCharacters(in: .whitespaces) ?? ""
    if !trimmedCode.isEmpty, upper == trimmedCode.uppercased() { return true }
    guard !section.isEmpty else { return false }
    if upper == section.uppercased() { return true }
    // An abbreviation, and only an abbreviation: a mixed-case token is a place
    // name in its own right, and one letter is a row group far more often than
    // it is a section code.
    guard head == upper, head.count >= 2 else { return false }
    guard head.rangeOfCharacter(from: CharacterSet(charactersIn: "A"..."Z")) != nil else {
        return false
    }
    return section.uppercased()
        .replacingOccurrences(of: " ", with: "")
        .hasPrefix(upper)
}

// MARK: - The push down

/// How far the card has to be pushed before letting go cancels.
///
/// Far enough that a thumb resting on the card while the map settles cannot
/// reach it, and short enough to be one comfortable flick.
// tokens.json gap: the web and Flutter both spell this 72 as a file-local
// constant. Lift it to `size.confirmCardDismissDrag` when the token document
// next moves.
public let seatLayerPickerCardDismissDrag: Double = 72

/// A downward flick this fast cancels however short it was.
///
/// A deliberate flick clears it easily; the drift at the end of a slow,
/// reconsidered drag does not.
public let seatLayerPickerCardDismissVelocity =
    SeatLayerPickerPhysicsTokens.swipeFlingVelocity

/// How far the card actually moves when it has been pushed `drag` points.
///
/// One to one until the card is far enough down to let go of, and a third of
/// that afterwards, so the resistance itself says the card is already far
/// enough. Upward it barely moves at all: there is nothing above the card to
/// drag it towards.
public func seatLayerPickerCardRubberBand(_ drag: Double) -> Double {
    if drag <= 0 { return drag / 6 }
    if drag <= seatLayerPickerCardDismissDrag { return drag }
    return seatLayerPickerCardDismissDrag
        + ((drag - seatLayerPickerCardDismissDrag) / 3)
}

/// Whether letting go here answers the card.
public func seatLayerPickerCardDragDismisses(
    drag: Double,
    velocity: Double
) -> Bool {
    drag >= seatLayerPickerCardDismissDrag
        || velocity >= seatLayerPickerCardDismissVelocity
}

/// How much of the decision row the quiet answer takes.
///
/// The web picker's `flex: 0 0 34%`. Not a half, because the two answers are
/// not equally likely; not a third, because `Cancel` still has to read as a
/// button rather than as a margin.
// tokens.json gap: a file-local `_cancelShare` in Flutter too.
public let seatLayerPickerCardCancelShare = 0.34

/// How far above the foot of the screen the flying chip aims.
///
/// The collapsed sheet's summary line is what the ticket has just changed, so
/// that is where the chip lands.
// tokens.json gap: Flutter's file-local `_peekAim`.
public let seatLayerPickerCartChipAim: Double = 24

/// When the flying chip reaches full size, as a fraction of its flight.
// tokens.json gap: Flutter's file-local `_flyRise`.
public let seatLayerPickerCartChipRise = 0.22

/// The longest section label that keeps the identity grid's big centred type.
///
/// Six characters covers every numbered section a chart writes — `209`, `A12`,
/// `Box 4` — and stops at the venue phrases that need to wrap.
public let seatLayerPickerConfirmSectionShortMax =
    SeatLayerPickerSizeTokens.confirmSectionShortMax

// MARK: - What the card prints

/// One labelled cell of the identity grid.
struct SeatLayerPickerIdentityCell: Equatable {
    let eyebrow: String
    let value: String
    let longSection: Bool
}

/// The cells a seat earns, in reading order.
///
/// A cell the runtime reported as present but empty prints an em dash rather
/// than disappearing: a grid that loses a column between two seats in the same
/// section is a grid the eye has to re-learn.
func seatLayerPickerIdentityCells(
    _ seat: SelectedSeat,
    strings: SeatLayerPickerStrings,
    sectionCode: String?
) -> [SeatLayerPickerIdentityCell] {
    let section = seat.sectionLabel?.trimmingCharacters(in: .whitespaces) ?? ""
    let row = seatLayerPickerRowLabel(
        seat.rowLabel,
        section: seat.sectionLabel,
        sectionCode: sectionCode
    )
    let seatNumber = seat.seatNumber?.trimmingCharacters(in: .whitespaces) ?? ""
    var cells: [SeatLayerPickerIdentityCell] = []
    if seat.sectionLabel != nil {
        cells.append(SeatLayerPickerIdentityCell(
            eyebrow: strings.text(.sectionWord),
            value: section.isEmpty ? "—" : section,
            longSection: section.count > seatLayerPickerConfirmSectionShortMax
        ))
    }
    if seat.rowLabel != nil {
        cells.append(SeatLayerPickerIdentityCell(
            eyebrow: seatLayerPickerRowWord(seat, strings: strings),
            value: row.isEmpty ? "—" : row,
            longSection: false
        ))
    }
    cells.append(SeatLayerPickerIdentityCell(
        eyebrow: seatLayerPickerSeatWord(seat, strings: strings),
        value: seatNumber.isEmpty ? seat.buyerFacingLabel : seatNumber,
        longSection: false
    ))
    return cells
}


/// The metre figure as the runtime rounded it.
///
/// The number arrives already rounded, so this only decides whether to print a
/// decimal point at all: `7` rather than `7.0`, `7.4` unchanged.
func seatLayerPickerSightlineFigure(_ metres: Double) -> String {
    metres == metres.rounded()
        ? String(Int(metres.rounded()))
        : String(metres)
}


// MARK: - The invitation

/// How far the breath's halo reaches, and how deep its colour goes.
// tokens.json gap: `_inviteHalo` / `_inviteHaloInk` / `_inviteSwell` are
// file-local constants in Flutter too.
let seatLayerPickerInviteHalo: Double = 6
let seatLayerPickerInviteHaloInk = 0.35
/// How much the button swells at the top of each breath.
let seatLayerPickerInviteSwell = 0.02


/// Where in the current breath the button is: 0 at rest, 1 at the top.
///
/// Zero before the breathing starts, so the button leaves the invitation at
/// exactly its resting size. In between it is the web's own two-keyframe
/// breath: out to the top by the halfway mark and back down again, each half
/// eased in and out rather than one cosine across the whole cycle — a cosine is
/// symmetric but not the same curve, and the peak is where the eye reads the
/// amplitude.
func seatLayerPickerInviteBreath(elapsedMs: Double?) -> Double {
    guard let elapsedMs else { return 0 }
    let since = elapsedMs - Double(SeatLayerPickerMotionDurationTokens.inviteBreatheDelay)
    guard since > 0 else { return 0 }
    let span = Double(SeatLayerPickerMotionDurationTokens.inviteBreathe)
    let phase = (since.truncatingRemainder(dividingBy: span)) / span
    return phase < 0.5
        ? seatLayerPickerInviteEase(phase * 2)
        : 1 - seatLayerPickerInviteEase((phase - 0.5) * 2)
}

/// How much of the arrival highlight has crossed the button.
func seatLayerPickerInviteSweep(elapsedMs: Double?) -> Double {
    guard let elapsedMs else { return 0 }
    let since = elapsedMs - Double(SeatLayerPickerMotionDurationTokens.inviteDelay)
    let span = Double(SeatLayerPickerMotionDurationTokens.inviteSweep)
    guard span > 0 else { return 1 }
    return min(1, max(0, since / span))
}

/// The curve each half of a breath travels: the web's `cubic-bezier(.4,0,.6,1)`.
func seatLayerPickerInviteEase(_ t: Double) -> Double {
    let clamped = min(1, max(0, t))
    return seatLayerPickerCubicBezierValue(
        SeatLayerPickerCubicBezier(x1: 0.4, y1: 0, x2: 0.6, y2: 1),
        at: clamped
    )
}

/// The y of a cubic-Bézier timing curve at progress `t`.
///
/// Newton on the x polynomial, then the y polynomial: the curve is authored as
/// a CSS easing, where the parameter is not the progress.
func seatLayerPickerCubicBezierValue(
    _ curve: SeatLayerPickerCubicBezier,
    at t: Double
) -> Double {
    func axis(_ p1: Double, _ p2: Double, _ s: Double) -> Double {
        let inverse = 1 - s
        return 3 * inverse * inverse * s * p1 + 3 * inverse * s * s * p2 + s * s * s
    }
    var guess = t
    for _ in 0..<8 {
        let x = axis(curve.x1, curve.x2, guess) - t
        if abs(x) < 1e-6 { break }
        let inverse = 1 - guess
        let slope = 3 * inverse * inverse * curve.x1
            + 6 * inverse * guess * (curve.x2 - curve.x1)
            + 3 * guess * guess * (1 - curve.x2)
        if abs(slope) < 1e-6 { break }
        guess -= x / slope
    }
    return axis(curve.y1, curve.y2, min(1, max(0, guess)))
}

