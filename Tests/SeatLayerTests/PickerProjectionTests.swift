import XCTest
@testable import SeatLayer

final class PickerProjectionTests: XCTestCase {
    func testConfirmedCartUsesPerLineAddressing() throws {
        let lines = [
            line(key: "one", label: "same", price: 25, seatId: "seat-1"),
            line(key: "two", label: "same", price: 30, seatId: "seat-2"),
            line(key: "three", label: "same", price: 20, seatId: nil),
            line(key: "four", label: "other", price: 15, seatId: nil),
        ]
        let pending = try selectedSeat(id: "seat-2", label: "same", objectId: "row")

        let projection = SeatLayerPickerProjections.confirmedCart(lines, pending: pending)

        XCTAssertEqual(projection.items.map { $0.lineKey }, ["one", "four"])
        XCTAssertEqual(projection.totals.quantity, 2)
        XCTAssertEqual(projection.totals.total, 40)
    }

    func testMixedCurrenciesNeverProduceOneDisplayCurrency() {
        let projection = SeatLayerPickerProjections.totals([
            line(key: "ga", objectType: "ga", price: 12, currency: "EUR", quantity: 3),
            line(key: "table", objectType: "table", price: 20, currency: "USD", quantity: 4),
        ])

        XCTAssertEqual(projection.quantity, 7)
        XCTAssertEqual(projection.total, 116)
        XCTAssertNil(projection.currency)
        XCTAssertTrue(projection.hasMixedCurrencies)
    }

    func testDenseRunsFoldAdjacentSeatsAndSortMembers() throws {
        let lines = [
            line(key: "three", label: "A-3", seatNumber: "3"),
            line(key: "one", label: "A-1", seatNumber: "1"),
            line(key: "two", label: "A-2", seatNumber: "2"),
        ].map {
            SeatLayerPickerProjections.denseLine(
                $0,
                display: .init(categoryLabel: "Adult", amountText: "€25")
            )
        }

        let run = try XCTUnwrap(SeatLayerPickerProjections.denseRuns(lines).first)

        XCTAssertEqual(run.seatsLabel, "1–3")
        XCTAssertEqual(run.total, 75)
        XCTAssertEqual(
            SeatLayerPickerProjections.membersInSeatOrder(run).map(\.seatLabel),
            ["1", "2", "3"]
        )
    }

    func testSeatRunLabelsNeverInventGaps() {
        XCTAssertEqual(
            SeatLayerPickerProjections.seatRunLabel(["1", "2", "4", "5", "6"]),
            "1, 2, 4 +2"
        )
        XCTAssertEqual(SeatLayerPickerProjections.seatRunLabel(["1", "1", "2"]), "1, 1, 2")
        XCTAssertEqual(SeatLayerPickerProjections.seatRunLabel(["A", "C", "E", "G"]), "A, C, E +1")
    }

    func testUndoRequiresSuccessfulSameSessionAbsentInventory() {
        let item = line(key: "one", label: "A-1")
        XCTAssertTrue(SeatLayerPickerProjections.canUndoRemoval(
            line: item,
            phase: .undoWindow,
            sameSession: true,
            stillAbsent: true
        ))
        XCTAssertFalse(SeatLayerPickerProjections.canUndoRemoval(
            line: item,
            phase: .awaitingRemove,
            sameSession: true,
            stillAbsent: true
        ))
        XCTAssertFalse(SeatLayerPickerProjections.canUndoRemoval(
            line: item,
            phase: .undoWindow,
            sameSession: false,
            stillAbsent: true
        ))
    }

    func testStructuralSelectionIdentityMatchesNeutralJSONForm() throws {
        let seat = try selectedSeat(id: "seat-1", label: "A-1", objectId: "row-a")
        XCTAssertEqual(
            SeatLayerPickerProjections.seatIdentity(seat),
            #"["seat-1","A-1","row-a"]"#
        )
    }

    func testGeneratedLocaleCatalogAndFallback() {
        XCTAssertEqual(SeatLayerPickerStrings.supportedLocales.count, 37)
        XCTAssertEqual(
            SeatLayerPickerStrings(localeIdentifier: "de-DE").text(.continueWord),
            "Weiter"
        )
        XCTAssertEqual(
            SeatLayerPickerStrings(localeIdentifier: "zh-TW").text(.continueWord),
            "繼續"
        )
        XCTAssertEqual(
            SeatLayerPickerStrings(localeIdentifier: "xx").text(.continueWord),
            "Continue"
        )
    }

    func testCanonicalBuilderMatrixHasExactlyTwentyFiveUniqueParts() {
#if canImport(SwiftUI) && canImport(UIKit)
        XCTAssertEqual(SeatLayerPickerPart.allCases.count, 25)
        XCTAssertEqual(Set(SeatLayerPickerPart.allCases.map { $0.rawValue }).count, 25)
#endif
    }

    private func line(
        key: String,
        label: String = "A-1",
        objectType: String = "seat",
        price: Double = 25,
        currency: String = "EUR",
        quantity: Int = 1,
        seatNumber: String = "1",
        seatId: String? = nil
    ) -> SeatLayerPickerCartLine {
        SeatLayerPickerCartLine(
            lineKey: key,
            label: label,
            displayLabel: nil,
            displayType: nil,
            objectId: "object-\(key)",
            objectType: objectType,
            categoryKey: "standard",
            tierId: nil,
            unitPrice: price,
            currency: currency,
            quantity: quantity,
            seatId: seatId,
            sectionLabel: "Gallery",
            rowLabel: "A",
            seatNumber: seatNumber
        )
    }

    private func selectedSeat(id: String, label: String, objectId: String) throws -> SelectedSeat {
        try JSONDecoder().decode(
            SelectedSeat.self,
            from: Data(#"{"id":"\#(id)","label":"\#(label)","objectId":"\#(objectId)"}"#.utf8)
        )
    }
}
