import XCTest
@testable import SeatLayer

/// A clock the test moves by hand.
@MainActor
final class ManualConnectionClock {
    private final class Entry: SeatLayerConnectionTimer {
        let due: TimeInterval
        let work: @MainActor () -> Void
        var cancelled = false
        init(due: TimeInterval, work: @escaping @MainActor () -> Void) {
            self.due = due
            self.work = work
        }
        func cancel() { cancelled = true }
    }

    private(set) var now: TimeInterval = 0
    private var entries: [Entry] = []

    var schedule: SeatLayerConnectionSchedule {
        { [unowned self] seconds, work in
            let entry = Entry(due: self.now + seconds, work: work)
            self.entries.append(entry)
            return entry
        }
    }

    func advance(_ seconds: TimeInterval) {
        let end = now + seconds
        while let next = entries.filter({ !$0.cancelled && $0.due <= end }).min(by: { $0.due < $1.due }) {
            now = next.due
            next.cancelled = true
            next.work()
        }
        entries.removeAll { $0.cancelled }
        now = end
    }
}

@MainActor
final class PickerConnectionTests: XCTestCase {
    private func watch() -> (SeatLayerConnectionWatch, ManualConnectionClock, () -> [SeatLayerConnectionShown]) {
        let clock = ManualConnectionClock()
        let watch = SeatLayerConnectionWatch(schedule: clock.schedule)
        var seen: [SeatLayerConnectionShown] = []
        watch.onShown = { seen.append($0) }
        return (watch, clock, { seen })
    }

    func testReadsOnlyTheStatesItKnows() {
        XCTAssertEqual(SeatLayerConnectionState(page: .string("offline")), .offline)
        XCTAssertEqual(SeatLayerConnectionState(page: .string("polling")), .polling)
        XCTAssertNil(SeatLayerConnectionState(page: .string("satellite")))
        XCTAssertNil(SeatLayerConnectionState(page: nil))
        XCTAssertTrue(SeatLayerConnectionState.reconnecting.lineDown)
        XCTAssertFalse(SeatLayerConnectionState.polling.lineDown)
    }

    func testABlinkOfTheNetworkSaysNothing() {
        let (watch, clock, seen) = watch()
        watch.heard(.offline)
        clock.advance(2.9)
        watch.heard(.live)
        clock.advance(10)
        XCTAssertEqual(seen(), [])
        XCTAssertEqual(watch.shown, .none)
    }

    func testSaysOfflineAfterThreeSecondsThenUpdatingThenBackOnceSeatsAreRead() {
        let (watch, clock, seen) = watch()
        watch.heard(.offline)
        clock.advance(3)
        XCTAssertEqual(watch.shown, .offline)
        XCTAssertTrue(watch.saidOffline)
        watch.heard(.reconnecting)
        XCTAssertEqual(watch.shown, .updating)
        watch.heard(.live)
        XCTAssertEqual(watch.shown, .updating, "back only once the seats are read again")
        watch.seatsRead()
        XCTAssertEqual(watch.shown, .back)
        clock.advance(2.4)
        XCTAssertEqual(watch.shown, .back)
        clock.advance(0.1)
        XCTAssertEqual(seen(), [.offline, .updating, .back, .none])
    }

    func testARetryingLineSaysUpdatingAfterTenSecondsAndGoesWithoutBackOnline() {
        let (watch, clock, seen) = watch()
        watch.heard(.reconnecting)
        clock.advance(9.9)
        XCTAssertEqual(watch.shown, .none)
        clock.advance(0.1)
        XCTAssertEqual(watch.shown, .updating)
        watch.heard(.live)
        watch.seatsRead()
        XCTAssertEqual(seen(), [.updating, .none])
    }

    func testOfflineAgainWhileStillOutIsSaidAtOnce() {
        let (watch, clock, _) = watch()
        watch.heard(.offline)
        clock.advance(3)
        watch.heard(.reconnecting)
        watch.heard(.offline)
        XCTAssertEqual(watch.shown, .offline)
    }

    func testANewPageForgetsWhatTheOldOneSaid() {
        let (watch, clock, _) = watch()
        var states: [SeatLayerConnectionState?] = []
        watch.onState = { states.append($0) }
        watch.heard(.offline)
        clock.advance(3)
        watch.reset()
        XCTAssertEqual(watch.shown, .none)
        XCTAssertFalse(watch.saidOffline)
        XCTAssertNil(watch.state)
        watch.heard(.live)
        watch.seatsRead()
        XCTAssertEqual(watch.shown, .none)
        XCTAssertEqual(states, [.offline, nil, .live])
    }

    func testARepeatAndAnUnknownValueChangeNothing() {
        let (watch, clock, _) = watch()
        watch.heard(.offline)
        clock.advance(2)
        watch.heard(.offline)
        watch.heard(nil)
        clock.advance(1)
        XCTAssertEqual(watch.shown, .offline, "the repeat did not restart the 3 s wait")
    }
}
