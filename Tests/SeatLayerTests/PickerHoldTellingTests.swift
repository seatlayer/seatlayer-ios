import XCTest
@testable import SeatLayer

final class PickerHoldTellingTests: XCTestCase {
    func testTheClockIsMinutesAndSecondsFlooredAtZero() {
        XCTAssertEqual(seatLayerPickerHoldClock(0), "0:00")
        XCTAssertEqual(seatLayerPickerHoldClock(9), "0:09")
        XCTAssertEqual(seatLayerPickerHoldClock(605), "10:05")
        XCTAssertEqual(seatLayerPickerHoldClock(-12), "0:00")
    }

    func testRemainingSecondsReadEitherEpochUnit() {
        let now = 1_700_000_000.0
        XCTAssertEqual(
            seatLayerPickerHoldSecondsRemaining(expiresAt: now + 90, now: now),
            90
        )
        XCTAssertEqual(
            seatLayerPickerHoldSecondsRemaining(expiresAt: (now + 90) * 1_000, now: now),
            90
        )
        XCTAssertEqual(
            seatLayerPickerHoldSecondsRemaining(expiresAt: now - 30, now: now),
            0
        )
    }

    func testAllRecoverableIsCountedOnTheSeatsComingBack() {
        let telling = seatLayerPickerHoldLapseTelling(SeatLayerPickerHoldLapse(
            lapsedLabels: ["A-1", "A-2"],
            recoverableLabels: ["A-1", "A-2"]
        ))
        XCTAssertEqual(telling.message, .holdLapsedStillFreeOther)
        XCTAssertEqual(telling.messageCount, 2)
        XCTAssertEqual(telling.tone, .warning)
        XCTAssertEqual(telling.action, .reselectSeatsOther)
        XCTAssertEqual(telling.actionCount, 2)
    }

    func testSomeTakenIsCountedOnTheSeatsThatAreGone() {
        let telling = seatLayerPickerHoldLapseTelling(SeatLayerPickerHoldLapse(
            lapsedLabels: ["A-1", "A-2", "A-3"],
            recoverableLabels: ["A-1", "A-2"]
        ))
        XCTAssertEqual(telling.message, .holdLapsedSomeTakenOne)
        XCTAssertEqual(telling.messageCount, 1)
        XCTAssertEqual(telling.tone, .warning)
        XCTAssertEqual(telling.action, .reselectSeatsOther)
        XCTAssertEqual(telling.actionCount, 2)
    }

    func testNoneRecoverableIsAnErrorWithNoWayForward() {
        let telling = seatLayerPickerHoldLapseTelling(SeatLayerPickerHoldLapse(
            lapsedLabels: ["A-1"],
            recoverableLabels: []
        ))
        XCTAssertEqual(telling.message, .holdLapsedAllTakenOne)
        XCTAssertEqual(telling.tone, .error)
        XCTAssertNil(telling.action)
    }

    func testTheLastMinuteIsTheExpiringBoundary() {
        XCTAssertEqual(seatLayerPickerHoldExpiringSeconds, 60)
    }
}
