import XCTest
@testable import SeatLayer

/// The cart list draws one card per ticket, and it identifies them itself.
///
/// A chart that keys its cart lines by ROW hands two seats in the same row the
/// same `lineKey`. A list identified by that key drew the first card twice; a
/// removal matched on it faded both cards and blocked the undo of the one that
/// actually left. There is ONE identity, and the seat comes first.
final class PickerCartRowIdentityTests: XCTestCase {
    func testASeatIsIdentifiedByItsSeatId() {
        XCTAssertEqual(
            seatLayerPickerCartRowIdentity(line(key: "row_1", label: "102-A-5")),
            "seat:102-A-5"
        )
    }

    func testALineWithNoSeatIdFallsBackToItsInventoryLabel() {
        XCTAssertEqual(
            seatLayerPickerCartRowIdentity(
                line(key: "row_1", label: "Table-1", seatId: nil)
            ),
            "label:Table-1"
        )
    }

    func testTwoSeatsSharingOneRowKeyAreStillTwoRows() {
        let identities = seatLayerPickerCartRowIdentities([
            line(key: "row_1", label: "102-A-5"),
            line(key: "row_1", label: "102-A-6"),
        ])
        XCTAssertEqual(identities, ["seat:102-A-5", "seat:102-A-6"])
    }

    /// The point of putting the seat first: the surviving card keeps the
    /// identity it was drawn under, so its arrival does not replay and the
    /// removing mark on the seat that left cannot land on it.
    func testASiblingLeavingDoesNotMoveTheIdentityOfWhatStays() {
        let both = [
            line(key: "row_1", label: "102-A-5"),
            line(key: "row_1", label: "102-A-6"),
        ]
        XCTAssertEqual(
            seatLayerPickerCartRowIdentities(both).last,
            seatLayerPickerCartRowIdentities([both[1]]).first
        )
    }

    func testEvenALineRepeatedWholeIsStillItsOwnRow() {
        let identities = seatLayerPickerCartRowIdentities([
            line(key: "row_1", label: "102-A-5"),
            line(key: "row_1", label: "102-A-5"),
            line(key: "row_1", label: "102-A-5"),
        ])
        XCTAssertEqual(identities.count, 3)
        XCTAssertEqual(Set(identities).count, 3)
    }

    func testTheOrderIsTheListsOwn() {
        let lines = [
            line(key: "row_1", label: "102-A-5"),
            line(key: "row_1", label: "102-A-6"),
            line(key: "row_2", label: "103-B-1"),
        ]
        let identities = seatLayerPickerCartRowIdentities(lines)
        XCTAssertEqual(identities.count, lines.count)
        XCTAssertEqual(identities.last, "seat:103-B-1")
    }

    // MARK: - sameTicket

    func testTwoSeatsOfOneRowAreNotTheSameTicket() {
        XCTAssertFalse(SeatLayerPickerProjections.sameTicket(
            line(key: "row_1", label: "102-A-5"),
            line(key: "row_1", label: "102-A-6")
        ))
    }

    func testASeatIsTheSameTicketAsItselfUnderADifferentKey() {
        XCTAssertTrue(SeatLayerPickerProjections.sameTicket(
            line(key: "row_1", label: "102-A-5"),
            line(key: "line_9", label: "102-A-5")
        ))
    }

    func testLinesWithNoSeatIdFallBackToTheLabelBeforeTheKey() {
        XCTAssertFalse(SeatLayerPickerProjections.sameTicket(
            line(key: "row_1", label: "Table-1", seatId: nil),
            line(key: "row_1", label: "Table-2", seatId: nil)
        ))
    }

    func testTheKeyDecidesOnlyWhenNothingElseIsNamed() {
        XCTAssertTrue(SeatLayerPickerProjections.sameTicket(
            line(key: "row_1", label: "", objectId: "", seatId: nil),
            line(key: "row_1", label: "", objectId: "", seatId: nil)
        ))
    }

    /// Removing seat 5 of a two-seat row leaves seat 6 in the cart — and the
    /// cart still containing seat 6 must not read as seat 5 still being there.
    func testTheSurvivingSiblingDoesNotStandInForTheSeatThatLeft() {
        let five = line(key: "row_1", label: "102-A-5")
        let six = line(key: "row_1", label: "102-A-6")
        XCTAssertFalse(SeatLayerPickerProjections.containsTicket([six], five))
        XCTAssertTrue(SeatLayerPickerProjections.containsTicket([six], six))
    }

    private func line(
        key: String,
        label: String,
        objectId: String? = nil,
        seatId: String? = "="
    ) -> SeatLayerPickerCartLine {
        SeatLayerPickerCartLine(
            lineKey: key,
            label: label,
            displayLabel: nil,
            displayType: nil,
            objectId: objectId ?? "object-\(label)",
            objectType: "seat",
            categoryKey: "standard",
            tierId: nil,
            tierName: nil,
            unitPrice: 180,
            currency: "EUR",
            quantity: 1,
            seatId: seatId == "=" ? label : seatId,
            sectionLabel: "102",
            rowLabel: "102-A",
            seatNumber: String(label.suffix(1))
        )
    }
}
