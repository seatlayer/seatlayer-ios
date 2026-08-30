import XCTest
@testable import SeatLayer

final class PickerTieringTests: XCTestCase {
    func testPendingTierImmediatelyOwnsAmountAndCurrency() throws {
        let seat = try selectedSeat([
            "id": "seat-g1",
            "label": "G-1",
            "price": 100,
            "currency": "EUR",
            "tierId": "adult",
            "tiers": [
                ["id": "adult", "name": "Adult", "price": 100],
                ["id": "child", "name": "Child", "price": 60, "currency": "GBP"],
            ],
        ])

        XCTAssertEqual(
            SeatLayerPickerTiering.quote(
                for: seat,
                preferred: "child",
                fallbackCurrency: "USD"
            ),
            SeatLayerPickerTierQuote(tierId: "child", amount: 60, currency: "GBP")
        )
    }

    func testInvalidLocalTierFallsBackToAuthoritativeThenFirst() throws {
        let authoritative = try selectedSeat([
            "id": "seat-g1",
            "label": "G-1",
            "tierId": "child",
            "tiers": [
                ["id": "adult", "name": "Adult", "price": 100],
                ["id": "child", "name": "Child", "price": 60],
            ],
        ])
        XCTAssertEqual(
            SeatLayerPickerTiering.resolvedTierId(for: authoritative, preferred: "retired"),
            "child"
        )

        let defaulted = try selectedSeat([
            "id": "seat-g2",
            "label": "G-2",
            "tiers": [
                ["id": "adult", "name": "Adult", "price": 100],
                ["id": "child", "name": "Child", "price": 60],
            ],
        ])
        XCTAssertEqual(
            SeatLayerPickerTiering.resolvedTierId(for: defaulted, preferred: nil),
            "adult"
        )
    }

    func testAuthoredGuidanceWinsAndCompanionHasFallback() {
        let authored = CategoryTier(
            id: "companion",
            name: "Companion",
            price: 0,
            restriction: "companion",
            buyerMessage: "  Must accompany an accessible ticket.  "
        )
        XCTAssertEqual(
            SeatLayerPickerTiering.guidance(
                for: authored,
                companionFallback: "Requires the adjacent wheelchair place."
            ),
            "Must accompany an accessible ticket."
        )

        let fallback = CategoryTier(
            id: "companion",
            name: "Companion",
            price: 0,
            restriction: " companion "
        )
        XCTAssertEqual(
            SeatLayerPickerTiering.guidance(
                for: fallback,
                companionFallback: "Requires the adjacent wheelchair place."
            ),
            "Requires the adjacent wheelchair place."
        )
    }

    private func selectedSeat(_ value: JSONValue) throws -> SelectedSeat {
        try value.decode(SelectedSeat.self)
    }
}
