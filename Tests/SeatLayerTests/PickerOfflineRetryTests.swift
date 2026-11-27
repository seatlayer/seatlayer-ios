import XCTest
@testable import SeatLayer

@MainActor
final class PickerOfflineRetryTests: XCTestCase {
    func testTriesAfterTenAndTwentySecondsThenEveryThirty() {
        XCTAssertEqual([0, 1, 2, 3].map(seatLayerPickerOfflineRetryAfter), [10, 20, 30, 30])
        let start = Date(timeIntervalSince1970: 0)
        let tries = SeatLayerPickerOfflineTries(now: start)
        XCTAssertEqual(tries.nextWait(now: start), 10)
        tries.tried(now: start.addingTimeInterval(10))
        XCTAssertEqual(tries.nextWait(now: start.addingTimeInterval(11)), 20)
        tries.tried(now: start.addingTimeInterval(31))
        XCTAssertEqual(tries.nextWait(now: start.addingTimeInterval(32)), 30)
    }

    func testStartsAgainAfterAQuietSpellOrBackInFront() {
        let start = Date(timeIntervalSince1970: 0)
        let tries = SeatLayerPickerOfflineTries(now: start)
        tries.tried(now: start)
        tries.tried(now: start)
        XCTAssertEqual(tries.nextWait(now: start.addingTimeInterval(121)), 10)
        tries.tried(now: start.addingTimeInterval(130))
        tries.restart(now: start.addingTimeInterval(131))
        XCTAssertEqual(tries.nextWait(now: start.addingTimeInterval(132)), 10)
    }

    func testOpeningSaysItIsTakingLongerAfterEightSeconds() {
        XCTAssertEqual(seatLayerPickerSlowOpeningSeconds, 8)
    }
}
