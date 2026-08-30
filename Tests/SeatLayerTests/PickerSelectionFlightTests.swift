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
        XCTAssertEqual(plan.durationMilliseconds, SeatLayerPickerMotionTokens.flyMilliseconds)
        XCTAssertEqual(SeatLayerPickerSelectionFlight.point(at: 0, in: plan), plan.start)
        XCTAssertEqual(SeatLayerPickerSelectionFlight.point(at: 1, in: plan), plan.end)
        XCTAssertEqual(plan.end.x, 195)
        XCTAssertEqual(plan.end.y, 676)
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
