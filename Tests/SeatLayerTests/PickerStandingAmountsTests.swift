import XCTest
@testable import SeatLayer

/// Only amounts the page accepts: it answers any other with no hold and no
/// reason.
final class PickerStandingAmountsTests: XCTestCase {
    private func snapshot(remaining: Int, wheelchairOnly: Bool) throws -> SeatLayerPickerSnapshot {
        try XCTUnwrap(decodeSeatLayerPickerSnapshot([
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": "standing",
            "revision": 1,
            "event": ["key": "event", "currency": "EUR"],
            "map": ["accessibilityFilter": .array(wheelchairOnly ? ["wheelchair"] : [])],
            "selection": ["maxSelection": .int(remaining)],
        ]))
    }

    private func amounts(
        _ area: GAArea,
        remaining: Int = 10,
        wheelchairOnly: Bool = false
    ) throws -> SeatLayerStandingAmounts? {
        seatLayerStandingAmounts(area, snapshot: try snapshot(remaining: remaining, wheelchairOnly: wheelchairOnly))
    }

    private func range(_ minimum: Int, _ maximum: Int) -> SeatLayerStandingAmounts {
        SeatLayerStandingAmounts(minimum: minimum, maximum: maximum)
    }

    func testReadsTheBoxAndWheelchairFactsThePageSends() throws {
        let data = Data("""
        {"id":"box","available":6,"bookingMode":"variable","minOccupancy":2,"maxOccupancy":6,"wheelchairPlaces":1,"wheelchairAvailable":1}
        """.utf8)
        let box = try JSONDecoder().decode(GAArea.self, from: data)
        XCTAssertEqual(box.bookingMode, "variable")
        XCTAssertEqual(box.minOccupancy, 2)
        XCTAssertEqual(box.maxOccupancy, 6)
        XCTAssertEqual(box.wheelchairPlaces, 1)
        XCTAssertEqual(box.wheelchairAvailable, 1)
        // An older page sends none of them.
        let area = try JSONDecoder().decode(GAArea.self, from: Data(#"{"id":"ga"}"#.utf8))
        XCTAssertNil(area.bookingMode)
        XCTAssertNil(area.maxOccupancy)
        XCTAssertNil(area.wheelchairAvailable)
    }

    func testPerPersonOneUpToWhatIsFreeAndLeftInTheOrder() throws {
        XCTAssertEqual(try amounts(GAArea(id: "ga", available: 4)), range(1, 4))
        XCTAssertEqual(try amounts(GAArea(id: "ga", available: 99)), range(1, 10))
        XCTAssertEqual(try amounts(GAArea(id: "ga")), range(1, 10))
        XCTAssertNil(try amounts(GAArea(id: "ga", available: 0)))
        XCTAssertNil(try amounts(GAArea(id: "ga", available: 4), remaining: 0))
    }

    func testAWholeBoxIsExactlyItsPlaces() throws {
        let box = GAArea(id: "box", available: 8, bookingMode: "whole", maxOccupancy: 8)
        XCTAssertEqual(try amounts(box), range(8, 8))
        // The places come from the capacity when no maximum is named.
        XCTAssertEqual(try amounts(GAArea(id: "box", capacity: 8, available: 8, bookingMode: "whole")), range(8, 8))
        XCTAssertNil(try amounts(GAArea(id: "box", available: 0, bookingMode: "whole", maxOccupancy: 8)))
        // More places than the order may still take: it cannot be offered.
        XCTAssertNil(try amounts(box, remaining: 7))
    }

    func testAPartyBoxStaysInsideItsRange() throws {
        let box = GAArea(id: "box", available: 6, bookingMode: "variable", minOccupancy: 2, maxOccupancy: 6)
        XCTAssertEqual(try amounts(box), range(2, 6))
        XCTAssertEqual(try amounts(box, remaining: 4), range(2, 4))
        XCTAssertNil(try amounts(box, remaining: 1))
        XCTAssertEqual(
            try amounts(GAArea(id: "box", available: 6, bookingMode: "variable", maxOccupancy: 6)),
            range(1, 6)
        )
    }

    func testTheWheelchairFilterOffersWheelchairPlacesAlone() throws {
        XCTAssertEqual(
            try amounts(
                GAArea(id: "ga", available: 40, wheelchairPlaces: 4, wheelchairAvailable: 3),
                wheelchairOnly: true
            ),
            range(1, 3)
        )
        XCTAssertNil(try amounts(GAArea(id: "ga", available: 40), wheelchairOnly: true))
        let party = GAArea(id: "box", available: 6, bookingMode: "variable", minOccupancy: 2, maxOccupancy: 6)
        XCTAssertNil(try amounts(party, wheelchairOnly: true))
        XCTAssertEqual(
            try amounts(
                GAArea(
                    id: "box",
                    available: 6,
                    bookingMode: "variable",
                    minOccupancy: 2,
                    maxOccupancy: 6,
                    wheelchairPlaces: 1
                ),
                wheelchairOnly: true
            ),
            range(2, 6)
        )
    }
}
