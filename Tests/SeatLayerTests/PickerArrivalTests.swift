import XCTest
@testable import SeatLayer

/// The deterministic order a set of rows lands in.
final class PickerArrivalTests: XCTestCase {
    func testTheFirstRowLandsImmediatelyAndTheRestQueueBehindIt() throws {
        let first = try XCTUnwrap(seatLayerPickerArrival(index: 0))
        XCTAssertEqual(first.delayMilliseconds, 0)
        XCTAssertEqual(
            first.durationMilliseconds,
            SeatLayerPickerMotionDurationTokens.pop
        )

        let second = seatLayerPickerArrival(index: 1)
        XCTAssertEqual(
            second?.delayMilliseconds,
            SeatLayerPickerMotionDurationTokens.stagger
        )
        XCTAssertEqual(
            second?.durationMilliseconds,
            SeatLayerPickerMotionDurationTokens.pop
        )
    }

    func testALongSetIsBoundedRatherThanBecomingAWait() {
        // Nothing arriving may outlast the longest movement the picker has.
        for index in 0..<200 {
            let arrival = seatLayerPickerArrival(index: index)
            XCTAssertNotNil(arrival)
            XCTAssertLessThanOrEqual(
                arrival?.totalMilliseconds ?? .max,
                SeatLayerPickerMotionDurationTokens.fly
            )
            // And every row still gets some of the run to itself.
            XCTAssertGreaterThan(arrival?.durationMilliseconds ?? 0, 0)
        }
    }

    func testARowThatIsNotArrivingHasNoPlan() {
        XCTAssertNil(seatLayerPickerArrival(index: -1))
    }

    func testOnlyTheRowsThatWereNotThereBeforeArrive() {
        XCTAssertEqual(
            seatLayerPickerArrivals(keys: ["a", "b", "c"], seen: []),
            ["a": 0, "b": 1, "c": 2]
        )
        // Two seats dropped into a cart that already had one: the newcomers
        // number from zero, in the order the list carries them.
        XCTAssertEqual(
            seatLayerPickerArrivals(keys: ["a", "b", "c"], seen: ["b"]),
            ["a": 0, "c": 1]
        )
        // A removal is not an arrival.
        XCTAssertEqual(
            seatLayerPickerArrivals(keys: ["a"], seen: ["a", "b"]),
            [:]
        )
    }

    func testTheSameListArrivesTheSameWayTwice() {
        let once = seatLayerPickerArrivals(keys: ["a", "b"], seen: [])
        let again = seatLayerPickerArrivals(keys: ["a", "b"], seen: [])
        XCTAssertEqual(once, again)
        XCTAssertEqual(
            seatLayerPickerArrival(index: 3),
            seatLayerPickerArrival(index: 3)
        )
    }
}
