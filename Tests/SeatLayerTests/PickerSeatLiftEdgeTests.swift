import XCTest
@testable import SeatLayer

/// The page answers the pan it ASKED its map for, and the map stops at its
/// edge. The spotlight stands where the seat is, not where it was asked to go.
@MainActor
final class PickerSeatLiftEdgeTests: XCTestCase {
    /// A map whose seat stands at `at` and cannot rise above `least`.
    private final class EdgeMap {
        var at: Double
        var least: Double
        var asked: [Double] = []
        init(from: Double, edge: Double) {
            at = from
            least = edge
        }
    }

    private var map = EdgeMap(from: 0, edge: 0)
    private var changed = 0
    private var lift: SeatLayerPickerSeatLift!

    override func tearDown() async throws {
        lift?.forget()
        lift = nil
        try await super.tearDown()
    }

    private func mapOf(from: Double, edge: Double, settle: [Double] = [0.02, 0.02]) {
        lift?.forget()
        let map = EdgeMap(from: from, edge: edge)
        self.map = map
        changed = 0
        lift = SeatLayerPickerSeatLift(
            settle: settle,
            onChanged: { [weak self] in self?.changed += 1 },
            frame: { _, fraction, _ in
                let dy = (60 + (844 - 60) * fraction - map.at).rounded()
                map.asked.append(dy)
                map.at = max(map.least, map.at + dy)
                return SeatLayerSeatFrame(dy: abs(dy) < 2 ? 0 : dy, gestures: 2)
            }
        )
    }

    private func show(revision: Int = 1, seat: String = "s1") async {
        for _ in 0..<2 {
            lift.sync(seatId: seat, mapHeight: 844, top: 60, bottom: 0, sheet: 300, revision: revision)
        }
        for _ in 0..<8 { await Task.yield() }
    }

    private func wait(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func rest() async { await wait(0.16) }

    func testAMapThatCouldMove() async {
        mapOf(from: 500, edge: 0)
        await show()
        XCTAssertEqual(lift.anchorDy, map.at - 500, accuracy: 1)
        await rest()
        XCTAssertEqual(lift.anchorDy, map.at - 500, accuracy: 1)
        XCTAssertEqual(changed, 1)
        XCTAssertEqual(lift.dy, map.at - 500, accuracy: 1)
    }

    func testAMapThatStoppedAtItsEdge() async {
        mapOf(from: 500, edge: 465)
        await show()
        await rest()
        XCTAssertEqual(map.at, 465)
        XCTAssertEqual(lift.anchorDy, -35, accuracy: 1)
        XCTAssertEqual(lift.dy, -35, accuracy: 1)
    }

    func testAMapThatCouldNotMoveAtAll() async {
        mapOf(from: 500, edge: 500)
        await show()
        await rest()
        XCTAssertEqual(lift.anchorDy, 0, accuracy: 1)
        // Nothing was moved, so nothing is put back.
        let before = map.asked.count
        lift.release()
        for _ in 0..<8 { await Task.yield() }
        XCTAssertEqual(map.asked.count, before)
    }

    func testAMapThatLetGoOfItsEdgeLater() async {
        mapOf(from: 500, edge: 465)
        await show()
        await wait(0.03)
        XCTAssertEqual(lift.anchorDy, -35, accuracy: 1)
        map.least = 0
        await rest()
        XCTAssertEqual(lift.anchorDy, map.at - 500, accuracy: 1)
        XCTAssertLessThan(map.at, 400)
    }

    func testAMapPutBackByItsOwnRefitBeforeItWasSeenToArrive() async {
        mapOf(from: 500, edge: 0)
        await show()
        map.at = 500
        await rest()
        XCTAssertLessThan(map.at, 400)
        XCTAssertEqual(lift.anchorDy, map.at - 500, accuracy: 1)
    }

    func testAMapPutBackByItsOwnRefitAfterItArrived() async {
        mapOf(from: 500, edge: 0)
        await show()
        await wait(0.03)
        map.at = 500
        await rest()
        XCTAssertLessThan(map.at, 400)
        XCTAssertEqual(lift.anchorDy, map.at - 500, accuracy: 1)
    }

    func testANewerSnapshotAlreadySaysWhereTheSeatIs() async {
        mapOf(from: 500, edge: 0)
        await show()
        await rest()
        await show(revision: 2)
        XCTAssertEqual(lift.anchorDy, 0)
        // At its edge, too.
        mapOf(from: 500, edge: 465)
        await show()
        await rest()
        await show(revision: 2)
        XCTAssertEqual(lift.anchorDy, 0)
        await rest()
        XCTAssertEqual(lift.anchorDy, 0)
    }

    func testAnotherSeatOnAMapAtItsEdge() async {
        mapOf(from: 500, edge: 465)
        await show()
        await rest()
        map.at = 520
        map.least = 520
        await show(revision: 2, seat: "s2")
        await rest()
        XCTAssertEqual(lift.anchorDy, 0, accuracy: 1)
    }

    func testForgetsItAll() async {
        mapOf(from: 500, edge: 0)
        await show()
        lift.forget()
        XCTAssertEqual(lift.anchorDy, 0)
    }
}
