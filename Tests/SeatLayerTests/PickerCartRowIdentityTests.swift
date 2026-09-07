import XCTest
@testable import SeatLayer

/// The cart list draws one card per line, and it identifies them itself.
///
/// A chart that keys its cart lines by ROW hands two seats in the same row the
/// same `lineKey`. A list identified by that key drew the first card twice.
final class PickerCartRowIdentityTests: XCTestCase {
    func testDistinctKeysAreLeftAlone() {
        let identities = seatLayerPickerCartRowIdentities([
            line(key: "a", label: "102-A-5"),
            line(key: "b", label: "102-A-6"),
        ])
        XCTAssertEqual(identities, ["a", "b"])
    }

    func testTwoSeatsSharingOneRowKeyAreStillTwoRows() {
        let identities = seatLayerPickerCartRowIdentities([
            line(key: "row_1", label: "102-A-5"),
            line(key: "row_1", label: "102-A-6"),
        ])
        XCTAssertEqual(identities.count, Set(identities).count)
        XCTAssertEqual(identities.first, "row_1")
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
        XCTAssertEqual(identities.last, "row_2")
    }

    private func line(key: String, label: String) -> SeatLayerPickerCartLine {
        SeatLayerPickerCartLine(
            lineKey: key,
            label: label,
            displayLabel: nil,
            displayType: nil,
            objectId: "object-\(label)",
            objectType: "seat",
            categoryKey: "standard",
            tierId: nil,
            tierName: nil,
            unitPrice: 180,
            currency: "EUR",
            quantity: 1,
            seatId: label,
            sectionLabel: "102",
            rowLabel: "102-A",
            seatNumber: String(label.suffix(1))
        )
    }
}
