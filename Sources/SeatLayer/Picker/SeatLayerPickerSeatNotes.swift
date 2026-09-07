import Foundation

/// SEAT NOTES — the one list of what a seat's own attributes say.
///
/// A seat can carry twelve accommodations, a wheelchair provision, three
/// selling marks and the organizer's own sentence, and every surface that
/// mentioned any of them used to decide for itself which ones matter: the tap
/// card showed one limited-view line in which restricted beat obstructed, so a
/// seat marked both told the buyer only half; the cart showed two markers;
/// premium reached some surfaces and not others.
///
/// So the answer lives here — `seatLayerSeatNoteRows` decides which rows a seat
/// earns and in what order — and the surfaces only draw it. Two rules are
/// worth naming:
///
/// * **Restricted and obstructed are separate rows.** Collapsing them into one
///   line with restricted winning means a seat behind both a rail and a pillar
///   is told about the rail and never about the pillar.
/// * **A wheelchair seat with a provision gets the provision row instead.**
///   "Empty wheelchair space" already says everything "wheelchair" would, and
///   more precisely; listing both is one seat explained twice.

/// How a note row reads: its meaning is here, its colour is the surface's.
public enum SeatLayerSeatNoteTone: String, Sendable, Equatable, CaseIterable {
    /// An accommodation or a wheelchair provision — a neutral, factual row.
    case access
    /// A view restriction. Surfaces give this the amber caution treatment.
    case warn
    /// A premium seat — the gold tag.
    case premium
    /// The organizer's own sentence, with no attribute of its own.
    case note
}

/// One row of a seat's notes.
public struct SeatLayerSeatNote: Sendable, Equatable {
    /// Stable identity for the row, for keying and for tests.
    public let key: String
    /// Which glyph this row wears.
    public let iconKey: String
    /// The row's title, already in the buyer's language.
    public let title: String
    /// The tone the surface paints it in.
    public let tone: SeatLayerSeatNoteTone
    /// The organizer's free text, attached to the row it belongs to.
    public let note: String?

    public init(
        key: String,
        iconKey: String,
        title: String,
        tone: SeatLayerSeatNoteTone,
        note: String? = nil
    ) {
        self.key = key
        self.iconKey = iconKey
        self.title = title
        self.tone = tone
        self.note = note
    }
}

private let seatLayerWheelchairNeedKey = "wheelchair"

/// Every row a seat's attributes earn, in reading order.
///
/// The order is fixed and is not discovery order: what the seat provides first
/// (accommodations, then the physical wheelchair fact), then what a buyer
/// should know before paying (restricted, obstructed, premium), then the
/// organizer's own words. Two seats with the same attributes always produce
/// the same list.
public func seatLayerSeatNoteRows(
    strings: SeatLayerPickerStrings,
    accessibility: [String]? = nil,
    wheelchairSpaceType: String? = nil,
    commercial: SeatCommercialAttributes? = nil
) -> [SeatLayerSeatNote] {
    var rows: [SeatLayerSeatNote] = []
    let provision = wheelchairSpaceType

    for type in accessibility ?? [] {
        if type == seatLayerWheelchairNeedKey, provision != nil { continue }
        rows.append(SeatLayerSeatNote(
            key: "access:\(type)",
            iconKey: type,
            title: strings.accessNeed(type),
            tone: .access
        ))
    }
    if provision == "no-seat" {
        rows.append(SeatLayerSeatNote(
            key: "wheelchair:no-seat",
            iconKey: seatLayerWheelchairNeedKey,
            title: strings.text(.emptyWheelchairSpace),
            tone: .access
        ))
    } else if provision == "seat-present" {
        rows.append(SeatLayerSeatNote(
            key: "wheelchair:seat-present",
            iconKey: seatLayerWheelchairNeedKey,
            title: strings.text(.accessiblePhysicalSeat),
            tone: .access
        ))
    }
    if commercial?.restrictedView == true {
        rows.append(SeatLayerSeatNote(
            key: "mark:restrictedView",
            iconKey: "restrictedView",
            title: strings.text(.restrictedView),
            tone: .warn
        ))
    }
    if commercial?.obstructedView == true {
        rows.append(SeatLayerSeatNote(
            key: "mark:obstructedView",
            iconKey: "obstructedView",
            title: strings.text(.obstructedView),
            tone: .warn
        ))
    }
    if commercial?.premium == true {
        rows.append(SeatLayerSeatNote(
            key: "mark:premium",
            iconKey: "premium",
            title: strings.text(.premiumSeat),
            tone: .premium
        ))
    }

    let note = commercial?.note?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let note, !note.isEmpty else { return rows }
    // The sentence belongs to the FIRST selling mark on the seat: an organizer
    // writing "pillar at the aisle end" is explaining the restriction, not
    // adding a second unrelated fact. With no mark to explain, it is its own
    // row.
    if let owner = rows.firstIndex(where: { $0.tone == .warn || $0.tone == .premium }) {
        let explained = rows[owner]
        rows[owner] = SeatLayerSeatNote(
            key: explained.key,
            iconKey: explained.iconKey,
            title: explained.title,
            tone: explained.tone,
            note: note
        )
        return rows
    }
    rows.append(SeatLayerSeatNote(
        key: "note",
        iconKey: "note",
        title: strings.text(.organizerNote),
        tone: .note,
        note: note
    ))
    return rows
}

/// The rows a selected seat earns, read from the runtime's own fields.
public func seatLayerSeatNotes(
    for seat: SelectedSeat,
    strings: SeatLayerPickerStrings
) -> [SeatLayerSeatNote] {
    seatLayerSeatNoteRows(
        strings: strings,
        accessibility: seat.accessibility,
        wheelchairSpaceType: seat.wheelchairSpaceType,
        commercial: seat.commercial
    )
}

// MARK: - What a tone paints

/// The five roles a note band's colours are mixed from.
///
/// A separate, platform-free spelling of the picker palette so the tone table
/// below — and the contrast gate over it — needs neither SwiftUI nor a
/// simulator. The live chrome fills this in from the resolved palette, which a
/// host's branding may have changed; the tests fill it in from the generated
/// light and dark token sets.
public struct SeatLayerSeatNoteInkPalette: Sendable, Equatable {
    public let surface: SeatLayerPickerInkColor
    public let text: SeatLayerPickerInkColor
    public let mutedText: SeatLayerPickerInkColor
    public let warning: SeatLayerPickerInkColor
    public let warnText: SeatLayerPickerInkColor
    public let premium: SeatLayerPickerInkColor
    public let premiumText: SeatLayerPickerInkColor

    public init(
        surface: SeatLayerPickerInkColor,
        text: SeatLayerPickerInkColor,
        mutedText: SeatLayerPickerInkColor,
        warning: SeatLayerPickerInkColor,
        warnText: SeatLayerPickerInkColor,
        premium: SeatLayerPickerInkColor,
        premiumText: SeatLayerPickerInkColor
    ) {
        self.surface = surface
        self.text = text
        self.mutedText = mutedText
        self.warning = warning
        self.warnText = warnText
        self.premium = premium
        self.premiumText = premiumText
    }

    /// The picker's own colours, as the generated token document names them.
    public static func tokens(dark: Bool) -> SeatLayerSeatNoteInkPalette {
        func hex(_ light: String, _ darkValue: String) -> SeatLayerPickerInkColor {
            SeatLayerPickerInkColor(hex: dark ? darkValue : light)
                ?? SeatLayerPickerInkColor(red: 0, green: 0, blue: 0)
        }
        return SeatLayerSeatNoteInkPalette(
            surface: hex(
                SeatLayerPickerLightColorTokens.surface,
                SeatLayerPickerDarkColorTokens.surface
            ),
            text: hex(
                SeatLayerPickerLightColorTokens.text,
                SeatLayerPickerDarkColorTokens.text
            ),
            mutedText: hex(
                SeatLayerPickerLightColorTokens.mutedText,
                SeatLayerPickerDarkColorTokens.mutedText
            ),
            warning: hex(
                SeatLayerPickerLightColorTokens.warning,
                SeatLayerPickerDarkColorTokens.warning
            ),
            warnText: hex(
                SeatLayerPickerLightColorTokens.warnText,
                SeatLayerPickerDarkColorTokens.warnText
            ),
            premium: hex(
                SeatLayerPickerLightColorTokens.premium,
                SeatLayerPickerDarkColorTokens.premium
            ),
            premiumText: hex(
                SeatLayerPickerLightColorTokens.premiumText,
                SeatLayerPickerDarkColorTokens.premiumText
            )
        )
    }
}

/// A note band's four resolved colours.
public struct SeatLayerSeatNoteInk: Sendable, Equatable {
    /// The band's own ground, tinted out of the surface it sits on.
    public let ground: SeatLayerPickerInkColor
    /// The title's ink, measured against `ground` rather than against the
    /// surface the ground is mixed from.
    public let ink: SeatLayerPickerInkColor
    /// The organizer's second line, one step quieter than `ink`.
    public let bodyInk: SeatLayerPickerInkColor
    /// The glyph's ink.
    public let iconInk: SeatLayerPickerInkColor
}

/// What `tone` paints on `palette`.
///
/// Pure, so a test can measure the contrast of every pair against the ground it
/// ACTUALLY paints on, in both themes — rather than against the surface each
/// tint is mixed from, which is how a 1.8:1 amber shipped.
public func seatLayerSeatNoteInk(
    _ palette: SeatLayerSeatNoteInkPalette,
    _ tone: SeatLayerSeatNoteTone
) -> SeatLayerSeatNoteInk {
    let ground: SeatLayerPickerInkColor
    let ink: SeatLayerPickerInkColor
    switch tone {
    case .warn:
        ground = SeatLayerPickerInk.blend(
            palette.warning,
            SeatLayerPickerOpacityTokens.noteToneWash,
            over: palette.surface
        )
        ink = palette.warnText
    case .premium:
        ground = SeatLayerPickerInk.blend(
            palette.premium,
            SeatLayerPickerOpacityTokens.noteToneWash,
            over: palette.surface
        )
        ink = palette.premiumText
    case .access, .note:
        ground = SeatLayerPickerInk.blend(
            palette.text,
            SeatLayerPickerOpacityTokens.noteNeutralWash,
            over: palette.surface
        )
        ink = palette.text
    }
    return SeatLayerSeatNoteInk(
        ground: ground,
        ink: ink,
        // The organizer's second line is the muted ink walked a quarter of the
        // way toward the text: bare muted on the tint measures below the bar.
        bodyInk: SeatLayerPickerInk.lerp(
            palette.mutedText,
            palette.text,
            1 - SeatLayerPickerOpacityTokens.noteBodyInk
        ),
        iconInk: tone == .warn || tone == .premium ? ink : palette.mutedText
    )
}
