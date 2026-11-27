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

    private func widths(_ words: [Double], gap: Double = 4) -> SeatLayerPickerCartBarWidths {
        .init(whole: words.reduce(0, +) + gap * Double(max(0, words.count - 1)), parts: words)
    }

    func testAShortLabelStandsBesideTheWordsAtItsOwnWidth() {
        // 393 pt phone: inner 369, the button may take 169.7, its words 141.7.
        let checkout = widths([60, 20, 60])
        let plan = seatLayerPickerCartBarPlan(width: 393, own: [checkout], label: [checkout], labelIsOwn: true)
        XCTAssertFalse(plan.under)
        // Its own width, 177, is more than the 46% it may take.
        XCTAssertEqual(plan.buttonWidth, 169.74, accuracy: 0.01)
        XCTAssertEqual(plan.letters, 0)
        XCTAssertGreaterThan(plan.wordsWidth, 0)
    }

    func testOwnWordsThatNeedThreeLinesPutTheButtonUnder() {
        let long = widths([90, 90, 90, 90])
        let plan = seatLayerPickerCartBarPlan(width: 320, own: [long], label: [long], labelIsOwn: true)
        XCTAssertTrue(plan.under)
        XCTAssertEqual(plan.buttonWidth, 296)
    }

    func testAnAppsLabelTakesSmallerLettersBeforeTheRowChanges() {
        let own = widths([50, 50])
        let app = [widths([80, 80, 80]), widths([60, 60, 60]), widths([50, 50, 50])]
        let plan = seatLayerPickerCartBarPlan(width: 393, own: [own], label: app, labelIsOwn: false)
        XCTAssertFalse(plan.under)
        XCTAssertEqual(plan.letters, 1)
    }

    func testBalancedLinesAreAsNarrowAsTheirLineCountAllows() {
        let label = widths([50, 50, 50, 50])
        XCTAssertEqual(seatLayerPickerCartBarLines(label, room: 120), 2)
        XCTAssertEqual(seatLayerPickerCartBarBalanced(label, room: 141), 104, accuracy: 0.6)
        XCTAssertEqual(seatLayerPickerCartBarParts("Continue to checkout"), ["Continue", "to", "checkout"])
        XCTAssertEqual(seatLayerPickerCartBarParts("お支払いへ").count, 5)
    }
}
