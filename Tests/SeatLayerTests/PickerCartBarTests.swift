import XCTest
@testable import SeatLayer

final class PickerCartBarTests: XCTestCase {
    private func line(
        _ label: String,
        section: String? = nil,
        row: String? = nil,
        seat: String? = nil,
        display: String? = nil
    ) -> SeatLayerPickerCartLine {
        SeatLayerPickerCartLine(
            lineKey: label, label: label, displayLabel: display, displayType: nil,
            objectId: label, objectType: "seat", categoryKey: "c", tierId: nil, tierName: nil,
            unitPrice: 10, currency: "EUR", quantity: 1, seatId: nil,
            sectionLabel: section, rowLabel: row, seatNumber: seat
        )
    }

    func testOneSectionIsNamedOnceThenEachSeat() {
        XCTAssertEqual(
            seatLayerPickerCartSeatsLine([
                line("DC-C-6", section: "Dress Circle", row: "C", seat: "6"),
                line("DC-C-7", section: "Dress Circle", row: "C", seat: "7"),
            ]),
            "Dress Circle · C-6, C-7"
        )
    }

    func testSeveralSectionsNameEachSeatsSection() {
        XCTAssertEqual(
            seatLayerPickerCartSeatsLine([
                line("a", section: "Stalls", row: "A", seat: "1"),
                line("b", section: "Circle", row: "B", seat: "2"),
            ]),
            "Stalls A-1, Circle B-2"
        )
    }

    func testAPlaceWithoutRowAndSeatIsItsOwnNameOnce() {
        XCTAssertEqual(
            seatLayerPickerCartSeatsLine([
                line("__sl_ga__floor", display: "Standing"),
                line("__sl_ga__floor", display: "Standing"),
                line("T2", display: "Table T2"),
            ]),
            "Standing, Table T2"
        )
    }

    func testTheRowDropsTheSectionsCode() {
        XCTAssertEqual(
            seatLayerPickerCartSeatsLine([line("x", section: "Gallery", row: "Gallery-H", seat: "3")]),
            "Gallery · H-3"
        )
    }

    func testTheTotalIsNeverCut() {
        XCTAssertTrue(seatLayerPickerCartBarTotal(count: 60, total: 40, room: 120).beside)
        let under = seatLayerPickerCartBarTotal(count: 80, total: 60, room: 120)
        XCTAssertFalse(under.beside)
        XCTAssertEqual(under.scale, 1)
        XCTAssertEqual(seatLayerPickerCartBarTotal(count: 80, total: 200, room: 120).scale, 0.6, accuracy: 0.001)
        XCTAssertEqual(seatLayerPickerCartBarTotal(count: 80, total: 400, room: 120).scale, 0.5)
    }
}
