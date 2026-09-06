import XCTest
@testable import SeatLayer

final class PickerSelectionFlightTests: XCTestCase {
    func testPhoneFlightEndsAtCartAndUsesGeneratedBudget() {
        let plan = SeatLayerPickerSelectionFlight.plan(
            width: 390,
            height: 700,
            layout: .phone,
            reduceMotion: false
        )

        XCTAssertFalse(plan.skipped)
        // The chip carries a seat's name from the card to the count, which is
        // a longer journey than the generic fly budget covers.
        XCTAssertEqual(
            plan.durationMilliseconds,
            SeatLayerPickerMotionDurationTokens.confirmFlight
        )
        XCTAssertEqual(SeatLayerPickerSelectionFlight.point(at: 0, in: plan), plan.start)
        XCTAssertEqual(SeatLayerPickerSelectionFlight.point(at: 1, in: plan), plan.end)
        XCTAssertEqual(plan.end.x, 195)
        XCTAssertEqual(plan.end.y, 700 - seatLayerPickerCartChipAim)
    }

    /// A composition that measures its own card and footer flies between them
    /// rather than between two guesses about where they are.
    func testMeasuredEndsBeatTheFallbacks() {
        let plan = SeatLayerPickerSelectionFlight.plan(
            width: 390,
            height: 700,
            layout: .phone,
            reduceMotion: false,
            origin: .init(x: 120, y: 300),
            target: .init(x: 260, y: 640)
        )
        XCTAssertEqual(plan.start, .init(x: 120, y: 300))
        XCTAssertEqual(plan.end, .init(x: 260, y: 640))
        XCTAssertLessThan(plan.control.y, 300)
    }

    /// It appears at just over half size, reaches full size a fifth of the way
    /// along, and shrinks as it lands.
    func testTheChipRisesThenShrinksAsItLands() {
        let start = SeatLayerPickerSelectionFlight.scaleAndOpacity(at: 0)
        XCTAssertEqual(start.scale, 0.6, accuracy: 0.001)
        XCTAssertEqual(start.opacity, 0, accuracy: 0.001)

        let risen = SeatLayerPickerSelectionFlight.scaleAndOpacity(
            at: seatLayerPickerCartChipRise
        )
        XCTAssertEqual(risen.scale, 1, accuracy: 0.001)
        XCTAssertEqual(risen.opacity, 1, accuracy: 0.001)

        let landed = SeatLayerPickerSelectionFlight.scaleAndOpacity(at: 1)
        XCTAssertEqual(landed.scale, 0.55, accuracy: 0.001)
        XCTAssertEqual(landed.opacity, 0.15, accuracy: 0.001)
    }

    func testWideFlightTargetsVisibleCartRail() {
        let plan = SeatLayerPickerSelectionFlight.plan(
            width: 1024,
            height: 768,
            layout: .wide,
            reduceMotion: false
        )

        XCTAssertEqual(plan.end.x, 864)
        XCTAssertLessThan(plan.control.y, min(plan.start.y, plan.end.y))
    }

    func testReduceMotionSkipsFlightAndProgressIsClamped() {
        let plan = SeatLayerPickerSelectionFlight.plan(
            width: 390,
            height: 700,
            layout: .phone,
            reduceMotion: true
        )

        XCTAssertTrue(plan.skipped)
        XCTAssertEqual(SeatLayerPickerSelectionFlight.point(at: -1, in: plan), plan.start)
        XCTAssertEqual(SeatLayerPickerSelectionFlight.point(at: 2, in: plan), plan.end)
    }
}
