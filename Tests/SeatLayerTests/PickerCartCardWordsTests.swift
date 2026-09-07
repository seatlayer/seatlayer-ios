import XCTest
@testable import SeatLayer

/// What one cart card prints, from the line's own seat facts.
///
/// The card is per ticket, but a runtime that keys its cart lines by ROW hands
/// every seat in a row the same key — so the address a card prints may never
/// come from anything the lines share.
final class PickerCartCardWordsTests: XCTestCase {
    /// The bug the owner saw: `211-Q · 12 · Lower Bowl` under a card already
    /// titled `211`. The row prints short.
    func testAQualifiedRowPrintsShortUnderItsSection() {
        let words = seatLayerPickerCartCardWords(
            line: line(label: "211-Q-12", section: "211", row: "211-Q", number: "12"),
            seat: nil,
            sectionCode: nil,
            typeLabel: "Lower Bowl"
        )
        XCTAssertEqual(words.name, "211")
        XCTAssertEqual(words.position, "Q · 12 · Lower Bowl")
    }

    /// Two tickets in one row, under one row-scoped key: two addresses.
    func testTwoSeatsInOneRowNeverPrintTheSamePosition() {
        let lines = [
            line(label: "102-A-5", section: "102", row: "102-A", number: "5"),
            line(label: "102-A-6", section: "102", row: "102-A", number: "6"),
        ]
        let positions = lines.map {
            seatLayerPickerCartCardWords(
                line: $0,
                seat: nil,
                sectionCode: "102",
                typeLabel: "Premium"
            ).position
        }
        XCTAssertEqual(positions, ["A · 5 · Premium", "A · 6 · Premium"])
        XCTAssertEqual(Set(positions).count, 2)
        for position in positions {
            XCTAssertFalse(position.contains("102-A"))
        }
    }

    /// A line the buyer never tapped is in no selection at all, so the line's
    /// own facts have to carry it; where they are missing, the seat behind the
    /// line answers instead.
    func testTheSeatBehindTheLineFillsInWhatTheLineOmits() throws {
        let seat = try JSONDecoder().decode(
            SelectedSeat.self,
            from: Data(#"""
            {"id":"s1","label":"102-A-6","sectionLabel":"102",
             "rowLabel":"102-A","seatNumber":"6"}
            """#.utf8)
        )
        let words = seatLayerPickerCartCardWords(
            line: line(label: "102-A-6", section: nil, row: nil, number: nil),
            seat: seat,
            sectionCode: nil,
            typeLabel: "Premium"
        )
        XCTAssertEqual(words.name, "102")
        XCTAssertEqual(words.position, "A · 6 · Premium")
    }

    /// A chart with no sections: the type names the card, and saying it twice
    /// is a stutter.
    func testWithNoSectionTheTypeNamesTheCardAndIsNotRepeated() {
        let words = seatLayerPickerCartCardWords(
            line: line(label: "GA-1", section: nil, row: nil, number: nil),
            seat: nil,
            sectionCode: nil,
            typeLabel: "Standard"
        )
        XCTAssertEqual(words.name, "Standard")
        XCTAssertEqual(words.position, "GA-1")
    }

    /// A row that is not the section's abbreviation is left whole: `Box-4` is
    /// the row's own name, not a prefix to strip.
    func testARowThatOnlyLooksQualifiedIsLeftAlone() {
        let words = seatLayerPickerCartCardWords(
            line: line(label: "Box-4-2", section: "Gallery", row: "Box-4", number: "2"),
            seat: nil,
            sectionCode: "GALL",
            typeLabel: nil
        )
        XCTAssertEqual(words.position, "Box-4 · 2")
    }

    private func line(
        label: String,
        section: String?,
        row: String?,
        number: String?
    ) -> SeatLayerPickerCartLine {
        SeatLayerPickerCartLine(
            lineKey: "row_1",
            label: label,
            displayLabel: nil,
            displayType: nil,
            objectId: "row-a",
            objectType: "seat",
            categoryKey: "standard",
            tierId: nil,
            tierName: nil,
            unitPrice: 180,
            currency: "EUR",
            quantity: 1,
            seatId: label,
            sectionLabel: section,
            rowLabel: row,
            seatNumber: number
        )
    }
}
