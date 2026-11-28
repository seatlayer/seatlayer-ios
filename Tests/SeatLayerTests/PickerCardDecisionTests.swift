import XCTest
@testable import SeatLayer

/// The seat card's judgements: which seats may be asked about, which word the
/// answer offers, how a row prints, and how far the card follows a thumb.
final class PickerCardDecisionTests: XCTestCase {
    private let strings = SeatLayerPickerStrings()

    private func seat(_ json: String) throws -> SelectedSeat {
        try JSONDecoder().decode(SelectedSeat.self, from: Data(json.utf8))
    }

    // MARK: - No card over a seat nobody can take

    func testASoldOrBlockedSeatRaisesNoCard() throws {
        let booked = try seat(#"{"id":"s1","label":"A-1","status":"booked"}"#)
        let blocked = try seat(#"{"id":"s1","label":"A-1","status":"blocked"}"#)
        XCTAssertFalse(seatLayerPickerMayAskAboutSeat(booked, holdActive: false))
        XCTAssertFalse(seatLayerPickerMayAskAboutSeat(booked, holdActive: true))
        XCTAssertFalse(seatLayerPickerMayAskAboutSeat(blocked, holdActive: true))
    }

    /// The picker's own hold makes the buyer's seats held, and those seats keep
    /// their card — it is the card that offers them back. With no hold of the
    /// picker's own, a held seat belongs to someone else.
    func testAHeldSeatDependsOnWhoseHoldItIs() throws {
        let held = try seat(#"{"id":"s1","label":"A-1","status":"held"}"#)
        XCTAssertTrue(seatLayerPickerMayAskAboutSeat(held, holdActive: true))
        XCTAssertFalse(seatLayerPickerMayAskAboutSeat(held, holdActive: false))
    }

    /// A live hold does NOT silence the card for ordinary seats — that was the
    /// defect this rule replaced.
    func testAFreeSeatKeepsItsCardWhileAHoldIsLive() throws {
        let free = try seat(#"{"id":"s1","label":"A-1","status":"free"}"#)
        XCTAssertTrue(seatLayerPickerMayAskAboutSeat(free, holdActive: true))
    }

    /// A status this build does not know is not a reason to swallow a seat the
    /// runtime put in the selection.
    func testAnUnknownStatusIsLeftAlone() throws {
        let unknown = try seat(#"{"id":"s1","label":"A-1","status":"reserved-ish"}"#)
        let silent = try seat(#"{"id":"s1","label":"A-1"}"#)
        XCTAssertTrue(seatLayerPickerMayAskAboutSeat(unknown, holdActive: false))
        XCTAssertTrue(seatLayerPickerMayAskAboutSeat(silent, holdActive: false))
    }

    // MARK: - Which word the answer offers

    func testTheAnswerNamesWhatTheBuyerIsActuallyTaking() throws {
        let plain = try seat(#"{"id":"s1","label":"A-1","objectType":"seat"}"#)
        let booth = try seat(#"{"id":"s1","label":"B-1","objectType":"booth"}"#)
        let silent = try seat(#"{"id":"s1","label":"A-1"}"#)
        XCTAssertEqual(seatLayerPickerCardPrimaryKey(plain, question: .add), .addSeat)
        XCTAssertEqual(seatLayerPickerCardPrimaryKey(silent, question: .add), .addSeat)
        // A booth is not a seat, and the button must not call it one.
        XCTAssertEqual(seatLayerPickerCardPrimaryKey(booth, question: .add), .select)
        // A TICK IS THE WRONG PROMISE ON A REMOVE, and so is the word.
        XCTAssertEqual(seatLayerPickerCardPrimaryKey(plain, question: .remove), .removeSeat)
        XCTAssertEqual(seatLayerPickerCardPrimaryKey(booth, question: .remove), .removeSeat)
    }

    func testTheChartsOwnWordForARowSurvives() throws {
        let named = try seat(#"{"id":"s1","label":"A-1","displayType":"Tier"}"#)
        let typed = try seat(#"{"id":"s1","label":"A-1","rowType":"Bank"}"#)
        let plain = try seat(#"{"id":"s1","label":"A-1"}"#)
        let booth = try seat(#"{"id":"s1","label":"B-1","objectType":"booth"}"#)
        XCTAssertEqual(seatLayerPickerRowWord(named, strings: strings), "Tier")
        XCTAssertEqual(seatLayerPickerRowWord(typed, strings: strings), "Bank")
        XCTAssertEqual(seatLayerPickerRowWord(plain, strings: strings), "Row")
        XCTAssertEqual(seatLayerPickerSeatWord(plain, strings: strings), "Seat")
        XCTAssertEqual(seatLayerPickerSeatWord(booth, strings: strings), "Place")
    }

    // MARK: - The row, once its section has been named

    func testARowDropsTheSectionTheCellBesideItAlreadyPrinted() {
        // The section's own id, which is the case the snapshot can settle.
        XCTAssertEqual(
            seatLayerPickerRowLabel("GALL-H", section: "Gallery", sectionCode: "GALL"),
            "H"
        )
        // The section's full name.
        XCTAssertEqual(seatLayerPickerRowLabel("Gallery H", section: "Gallery"), "H")
        // An all-caps abbreviation of it — a PREFIX of the section's letters,
        // which is what a chart writes when it shortens a name.
        XCTAssertEqual(seatLayerPickerRowLabel("UPP-12", section: "Upper Grand Circle"), "12")
    }

    func testARowThatIsNotItsSectionsNameIsPrintedWhole() {
        // A mixed-case token is a place name in its own right.
        XCTAssertEqual(seatLayerPickerRowLabel("Box-4", section: "Gallery"), "Box-4")
        // One letter is a row group far more often than it is a section code.
        XCTAssertEqual(seatLayerPickerRowLabel("A-12", section: "Arena"), "A-12")
        // An initialism is not a prefix, and guessing at one would eat a real
        // row group; only the section's own id settles that case.
        XCTAssertEqual(seatLayerPickerRowLabel("UGC-12", section: "Upper Grand Circle"), "UGC-12")
        XCTAssertEqual(
            seatLayerPickerRowLabel("UGC-12", section: "Upper Grand Circle", sectionCode: "UGC"),
            "12"
        )
        // Nothing to strip at all.
        XCTAssertEqual(seatLayerPickerRowLabel("H", section: "Gallery"), "H")
        XCTAssertEqual(seatLayerPickerRowLabel("  ", section: "Gallery"), "")
        // Stripping the whole label would leave nothing, so it is left alone.
        XCTAssertEqual(seatLayerPickerRowLabel("Gallery", section: "Gallery"), "Gallery")
    }

    // MARK: - The identity grid

    /// A grid that loses a column between two seats in the same section is a
    /// grid the eye has to re-learn.
    func testAPresentButEmptyCellPrintsAnEmDash() throws {
        let seated = try seat(
            #"{"id":"s1","label":"A-1","sectionLabel":"","rowLabel":"A","seatNumber":"1"}"#
        )
        let cells = seatLayerPickerIdentityCells(seated, strings: strings, sectionCode: nil)
        XCTAssertEqual(cells.map(\.value), ["—", "A", "1"])
    }

    /// A cell the runtime never reported is not drawn at all.
    func testACellTheRuntimeNeverReportedIsAbsent() throws {
        let general = try seat(#"{"id":"s1","label":"GA-1"}"#)
        let cells = seatLayerPickerIdentityCells(general, strings: strings, sectionCode: nil)
        XCTAssertEqual(cells.count, 1)
        XCTAssertEqual(cells[0].value, "GA-1")
    }

    /// A table booked as one: its guests and its name, never "Row T2 | Seat
    /// T2". A party table gives the range the buyer chooses from.
    func testATableBookedAsOneShowsGuestsAndItsName() throws {
        let whole = try seat(
            #"{"id":"c1","label":"T2","objectType":"table","bookingMode":"whole","capacity":4,"sectionLabel":"Gallery","rowLabel":"T2"}"#
        )
        let party = try seat(
            #"{"id":"c1","label":"T3","objectType":"table","bookingMode":"variable","minOccupancy":2,"maxOccupancy":6,"capacity":6,"rowLabel":"T3"}"#
        )
        let cells = seatLayerPickerIdentityCells(whole, strings: strings, sectionCode: nil)
        XCTAssertEqual(cells.map(\.eyebrow), ["Section", "Guests", "Table"])
        XCTAssertEqual(cells.map(\.value), ["Gallery", "4", "T2"])
        // No section: the table's name still shows.
        let partyCells = seatLayerPickerIdentityCells(party, strings: strings, sectionCode: nil)
        XCTAssertEqual(partyCells.map(\.value), ["2–6", "T3"])
        // A chair of a table, or a seat, keeps row and seat.
        let chair = try seat(
            #"{"id":"c1","label":"T2-1","objectType":"seat","rowLabel":"T2","seatNumber":"1"}"#
        )
        XCTAssertNil(seatLayerPickerTableIdentity(chair, strings: strings))
    }

    /// A party table asked about from the cart names the party it carries,
    /// not its range; a count outside the range is no party the buyer chose.
    func testAPartyTableInTheCartNamesItsParty() throws {
        let chosen = try seat(
            #"{"id":"c1","label":"T3","objectType":"table","bookingMode":"variable","minOccupancy":2,"maxOccupancy":6,"capacity":6,"quantity":3,"rowLabel":"T3"}"#
        )
        XCTAssertEqual(seatLayerPickerIdentityCells(chosen, strings: strings, sectionCode: nil, inCart: true).map(\.value), ["3", "T3"])
        let outside = try seat(
            #"{"id":"c1","label":"T3","objectType":"table","bookingMode":"variable","minOccupancy":2,"maxOccupancy":6,"quantity":9,"rowLabel":"T3"}"#
        )
        XCTAssertEqual(seatLayerPickerIdentityCells(outside, strings: strings, sectionCode: nil, inCart: true).map(\.value), ["2–6", "T3"])
        let whole = try seat(
            #"{"id":"c1","label":"T2","objectType":"table","bookingMode":"whole","capacity":4,"quantity":1,"rowLabel":"T2"}"#
        )
        XCTAssertEqual(seatLayerPickerIdentityCells(whole, strings: strings, sectionCode: nil, inCart: true).map(\.value), ["4", "T2"])
    }

    /// At the first tap the runtime sends a party table with quantity =
    /// minOccupancy, before the buyer chooses: every card that is not asking
    /// about a cart line, and the 3D caption, keep the range.
    func testAPartyTableBeforeTheBuyerChoosesKeepsItsRange() throws {
        let pending = try seat(
            #"{"id":"c1","label":"T3","objectType":"table","bookingMode":"variable","minOccupancy":2,"maxOccupancy":6,"quantity":2,"rowLabel":"T3"}"#
        )
        XCTAssertEqual(seatLayerPickerIdentityCells(pending, strings: strings, sectionCode: nil).map(\.value), ["2–6", "T3"])
        XCTAssertEqual(seatLayerPickerTableIdentity(pending, strings: strings)?.first?.value, "2–6")
    }

    /// The guest prompt names the table as the seat card does: its row, else
    /// the label the buyer sees.
    func testATableIsNamedByItsRowElseItsLabel() throws {
        let named = try seat(
            #"{"id":"c1","label":"Gallery T3","objectType":"table","bookingMode":"variable","rowLabel":"T3"}"#
        )
        let unnamed = try seat(
            #"{"id":"c1","label":"T4","objectType":"table","bookingMode":"variable","rowLabel":"  "}"#
        )
        XCTAssertEqual(seatLayerPickerTableName(named), "T3")
        XCTAssertEqual(seatLayerPickerTableName(unnamed), unnamed.buyerFacingLabel)
    }

    /// The guest prompt reads as the seat card: "Section | Guests | Table", and
    /// a table with no section gives no section cell.
    func testTheGuestPromptReadsAsTheSeatCard() throws {
        let gallery = try seat(
            #"{"id":"c1","label":"T3","objectType":"table","bookingMode":"variable","rowLabel":"T3","sectionLabel":"Gallery"}"#
        )
        let bare = try seat(
            #"{"id":"c1","label":"T3","objectType":"table","bookingMode":"variable","rowLabel":"T3"}"#
        )
        let blank = try seat(
            #"{"id":"c1","label":"T3","objectType":"table","bookingMode":"variable","rowLabel":"T3","sectionLabel":" "}"#
        )
        func words(_ table: SelectedSeat) -> [String] {
            seatLayerPickerTablePromptCells(table, guests: 4, strings: strings).map { "\($0.word) \($0.value)" }
        }
        let section = strings.text(.sectionWord)
        let guests = strings.text(.guestsWord)
        let tableWord = strings.text(.tableWord)
        XCTAssertEqual(words(gallery), ["\(section) Gallery", "\(guests) 4", "\(tableWord) T3"])
        XCTAssertEqual(words(bare), ["\(guests) 4", "\(tableWord) T3"])
        XCTAssertEqual(words(blank), ["\(section) —", "\(guests) 4", "\(tableWord) T3"])
    }

    /// A prompt taller than its room scrolls; one that fits does not.
    func testAPromptScrollsOnlyWhenTallerThanItsRoom() {
        XCTAssertFalse(seatLayerPickerPromptScrolls(content: 400, room: 400))
        XCTAssertTrue(seatLayerPickerPromptScrolls(content: 401, room: 400))
    }

    /// A clipped section name is a name the buyer cannot check the map against,
    /// so only the long ones give up the big type to wrap.
    func testOnlyALongSectionDropsToTheWrappingType() throws {
        let short = try seat(#"{"id":"s1","label":"A-1","sectionLabel":"209"}"#)
        let long = try seat(
            #"{"id":"s1","label":"A-1","sectionLabel":"Upper Grand Circle"}"#
        )
        XCTAssertFalse(
            seatLayerPickerIdentityCells(short, strings: strings, sectionCode: nil)[0].longSection
        )
        XCTAssertTrue(
            seatLayerPickerIdentityCells(long, strings: strings, sectionCode: nil)[0].longSection
        )
    }

    // MARK: - The push down

    func testTheCardGoesStiffOnceItIsFarEnoughToLetGoOf() {
        XCTAssertEqual(seatLayerPickerCardRubberBand(40), 40)
        XCTAssertEqual(
            seatLayerPickerCardRubberBand(seatLayerPickerCardDismissDrag),
            seatLayerPickerCardDismissDrag
        )
        // A third of the way beyond it.
        XCTAssertEqual(
            seatLayerPickerCardRubberBand(seatLayerPickerCardDismissDrag + 90),
            seatLayerPickerCardDismissDrag + 30
        )
        // There is nothing above the card to drag it towards.
        XCTAssertEqual(seatLayerPickerCardRubberBand(-60), -10)
    }

    func testALongPushOrAFastFlickBothAnswerTheCard() {
        XCTAssertTrue(seatLayerPickerCardDragDismisses(
            drag: seatLayerPickerCardDismissDrag,
            velocity: 0
        ))
        XCTAssertTrue(seatLayerPickerCardDragDismisses(
            drag: 12,
            velocity: seatLayerPickerCardDismissVelocity
        ))
        // The drift at the end of a slow, reconsidered drag does not.
        XCTAssertFalse(seatLayerPickerCardDragDismisses(drag: 30, velocity: 120))
    }

    /// The two answers are not equally likely, and the card should not pretend
    /// that they are.
    func testCancelTakesJustOverAThirdOfTheDecisionRow() {
        XCTAssertEqual(seatLayerPickerCardCancelShare, 0.34, accuracy: 0.0001)
        XCTAssertLessThan(seatLayerPickerCardCancelShare, 0.5)
        XCTAssertGreaterThan(seatLayerPickerCardCancelShare, 1.0 / 3)
    }

    // MARK: - The sight line

    /// The number arrives already rounded, so this only decides whether to
    /// print a decimal point at all.
    func testTheSightLineFigurePrintsNoEmptyDecimal() {
        XCTAssertEqual(seatLayerPickerSightlineFigure(7), "7")
        XCTAssertEqual(seatLayerPickerSightlineFigure(7.4), "7.4")
    }

    // MARK: - The invitation

    /// The offer stays open for as long as the buyer hesitates, and the button
    /// leaves the invitation at exactly its resting size.
    func testTheBreathStartsAtRestAndKeepsCycling() {
        XCTAssertEqual(seatLayerPickerInviteBreath(elapsedMs: nil), 0)
        XCTAssertEqual(seatLayerPickerInviteBreath(elapsedMs: 0), 0)
        let delay = Double(SeatLayerPickerMotionDurationTokens.inviteBreatheDelay)
        let span = Double(SeatLayerPickerMotionDurationTokens.inviteBreathe)
        XCTAssertEqual(seatLayerPickerInviteBreath(elapsedMs: delay), 0)
        // The peak is at the halfway mark of each breath.
        XCTAssertEqual(
            seatLayerPickerInviteBreath(elapsedMs: delay + span / 2),
            1,
            accuracy: 0.01
        )
        // And it comes back down, then goes round again.
        XCTAssertEqual(
            seatLayerPickerInviteBreath(elapsedMs: delay + span * 0.999),
            0,
            accuracy: 0.02
        )
        XCTAssertEqual(
            seatLayerPickerInviteBreath(elapsedMs: delay + span * 1.5),
            1,
            accuracy: 0.01
        )
    }

    /// The button swells two per cent at the top of a breath — the figure the
    /// Flutter widget test pins.
    func testTheBreathPeaksAtTwoPerCentOfTheButton() {
        let delay = Double(SeatLayerPickerMotionDurationTokens.inviteBreatheDelay)
        let span = Double(SeatLayerPickerMotionDurationTokens.inviteBreathe)
        let peak = 1 + seatLayerPickerInviteSwell
            * seatLayerPickerInviteBreath(elapsedMs: delay + span / 2)
        XCTAssertEqual(peak, 1.02, accuracy: 0.001)
    }

    /// One highlight crosses the button, once, after a short wait.
    func testTheArrivalHighlightEntersAndLeaves() {
        XCTAssertEqual(seatLayerPickerInviteSweep(elapsedMs: nil), 0)
        let delay = Double(SeatLayerPickerMotionDurationTokens.inviteDelay)
        let span = Double(SeatLayerPickerMotionDurationTokens.inviteSweep)
        XCTAssertEqual(seatLayerPickerInviteSweep(elapsedMs: delay), 0)
        XCTAssertEqual(seatLayerPickerInviteSweep(elapsedMs: delay + span / 2), 0.5)
        XCTAssertEqual(seatLayerPickerInviteSweep(elapsedMs: delay + span * 4), 1)
    }

    func testTheEasingIsTheWebsOwnTwoKeyframeCurve() {
        XCTAssertEqual(seatLayerPickerInviteEase(0), 0, accuracy: 0.001)
        XCTAssertEqual(seatLayerPickerInviteEase(1), 1, accuracy: 0.001)
        XCTAssertEqual(seatLayerPickerInviteEase(0.5), 0.5, accuracy: 0.02)
        // Eased in and out rather than linear.
        XCTAssertLessThan(seatLayerPickerInviteEase(0.25), 0.25)
        XCTAssertGreaterThan(seatLayerPickerInviteEase(0.75), 0.75)
    }
}
