import CoreGraphics
import XCTest
@testable import SeatLayer

/// Where the card rests, what it covers, and how the map moves out from under
/// it.
final class PickerSeatLiftTests: XCTestCase {
    private let area = CGSize(width: 390, height: 844)

    /// The card has ONE home, and it does not depend on the seat.
    func testTheCardRestsAConstantInsetAboveTheFootOfTheMap() {
        let short = seatLayerConfirmCardTop(card: CGSize(width: 310, height: 220), area: area)
        let tall = seatLayerConfirmCardTop(card: CGSize(width: 310, height: 320), area: area)
        XCTAssertEqual(short, 844 - seatLayerConfirmCardRestInset - 220)
        XCTAssertEqual(tall, 844 - seatLayerConfirmCardRestInset - 320)
        // Both leave the same daylight under them; only the top edge moves.
        XCTAssertEqual(844 - (short + 220), 844 - (tall + 320))
    }

    func testTheCardNeverSlidesUnderTheChromeAboveOrBelowIt() {
        let top = seatLayerConfirmCardTop(
            card: CGSize(width: 310, height: 220),
            area: area,
            topInset: 96,
            bottomInset: 140
        )
        XCTAssertEqual(top, 844 - 140 - seatLayerConfirmCardRestInset - 220)

        // A card taller than the band it lives in stops at the headroom rather
        // than climbing into the header.
        let crowded = seatLayerConfirmCardTop(
            card: CGSize(width: 310, height: 800),
            area: area,
            topInset: 96,
            bottomInset: 140
        )
        XCTAssertEqual(crowded, 96 + seatLayerConfirmCardTopInset)
    }

    /// The clear band ends in daylight above the card, not against its shadow.
    func testTheReportedSheetBandStopsAGapAboveTheCard() {
        let top = seatLayerConfirmCardTop(card: CGSize(width: 310, height: 220), area: area)
        let band = seatLayerConfirmSheetBand(cardTop: top, area: area)
        XCTAssertEqual(band, 220 + seatLayerConfirmCardRestInset + seatLayerConfirmCardSeatGap)
    }

    /// A host short enough that the card fills it has nowhere to put the seat,
    /// and an inset taller than the viewport asks the runtime to frame into
    /// nothing.
    func testABandThatWouldLeaveNoMapIsNotReportedAtAll() {
        let tiny = CGSize(width: 390, height: 240)
        let top = seatLayerConfirmCardTop(card: CGSize(width: 310, height: 300), area: tiny)
        XCTAssertEqual(seatLayerConfirmSheetBand(cardTop: top, area: tiny), 0)
    }

    /// The runtime frames inside the insets it was told about and knows
    /// nothing of the sheet, so the sheet is folded into the fraction.
    func testTheLiftFractionFoldsTheSheetIntoTheBandTheRuntimeKnows() {
        let fraction = seatLayerSheetLiftFraction(
            mapHeight: 800,
            top: 100,
            bottom: 0,
            sheet: 300
        )
        // Clear band = 800 − 100 − 300 = 400; the seat rests at .48 of it,
        // expressed against the 700 pt band the runtime frames in.
        XCTAssertEqual(fraction, (400 * seatLayerSheetSeatFraction) / 700, accuracy: 1e-9)
        XCTAssertLessThan(fraction, seatLayerSheetSeatFraction)
    }

    func testThereIsNoLiftWhereThereIsNoBand() {
        XCTAssertEqual(
            seatLayerSheetLiftFraction(mapHeight: 200, top: 100, bottom: 120, sheet: 40),
            0
        )
        XCTAssertEqual(
            seatLayerSheetLiftFraction(mapHeight: 400, top: 40, bottom: 0, sheet: 400),
            0
        )
    }

    /// A fraction folded against a height caught mid-animation puts the seat
    /// under the card, so a lift is only sent once two syncs agree.
    @MainActor
    func testALiftWaitsForTwoSyncsThatAgreeOnTheMapHeight() async {
        let recorder = FrameRecorder()
        let lift = SeatLayerPickerSeatLift(settle: []) { seatId, fraction, gestures in
            recorder.record(seatId: seatId, fraction: fraction, gestures: gestures)
            return SeatLayerSeatFrame(dy: -40, gestures: 3)
        }

        lift.sync(seatId: "A-1", mapHeight: 700, top: 0, bottom: 0, sheet: 260, revision: 1)
        XCTAssertTrue(lift.pending)
        XCTAssertTrue(recorder.calls.isEmpty)

        lift.sync(seatId: "A-1", mapHeight: 700, top: 0, bottom: 0, sheet: 260, revision: 1)
        XCTAssertFalse(lift.pending)
        await settle()
        XCTAssertEqual(recorder.calls.count, 1)
        XCTAssertEqual(recorder.calls.first?.seatId, "A-1")
        XCTAssertNil(recorder.calls.first?.gestures)
        XCTAssertEqual(lift.dy, -40)
        XCTAssertEqual(lift.anchorDy, -40)

        // The same question again sends nothing.
        lift.sync(seatId: "A-1", mapHeight: 700, top: 0, bottom: 0, sheet: 260, revision: 1)
        await settle()
        XCTAssertEqual(recorder.calls.count, 1)
    }

    /// A newer snapshot already contains the pans made before it, so what the
    /// chrome adds to a reported screen point resets rather than accumulating.
    @MainActor
    func testANewerSnapshotResetsTheAnchorButKeepsTheStandingPan() async {
        let recorder = FrameRecorder()
        let lift = SeatLayerPickerSeatLift(settle: []) { seatId, fraction, gestures in
            recorder.record(seatId: seatId, fraction: fraction, gestures: gestures)
            // The buyer has not touched the map, so the runtime hands back the
            // same count each time and neither lift is refused.
            return SeatLayerSeatFrame(dy: -30, gestures: 1)
        }
        for _ in 0..<2 {
            lift.sync(seatId: "A-1", mapHeight: 700, top: 0, bottom: 0, sheet: 260, revision: 1)
        }
        await settle()
        XCTAssertEqual(lift.anchorDy, -30)

        lift.sync(seatId: "A-1", mapHeight: 700, top: 0, bottom: 0, sheet: 260, revision: 2)
        await settle()
        XCTAssertEqual(recorder.calls.count, 2)
        // The pan the runtime has made in total keeps growing; what this side
        // still has to add to a reported point starts again from the newer
        // snapshot.
        XCTAssertEqual(lift.dy, -60)
        XCTAssertEqual(lift.anchorDy, -30)
        XCTAssertEqual(recorder.calls.last?.gestures, 1)
    }

    /// Cancelling the card puts the map back — at a fixed resting place, and
    /// only with the gesture count that lets the runtime refuse.
    @MainActor
    func testReleasePutsTheSeatAtItsRestingPlaceWithTheGestureCount() async {
        let recorder = FrameRecorder()
        let lift = SeatLayerPickerSeatLift(settle: []) { seatId, fraction, gestures in
            recorder.record(seatId: seatId, fraction: fraction, gestures: gestures)
            return SeatLayerSeatFrame(dy: -50, gestures: 7)
        }
        for _ in 0..<2 {
            lift.sync(seatId: "A-1", mapHeight: 700, top: 0, bottom: 0, sheet: 260, revision: 1)
        }
        await settle()
        lift.release()
        await settle()

        XCTAssertEqual(recorder.calls.count, 2)
        XCTAssertEqual(recorder.calls.last?.fraction, seatLayerSheetRestoreFraction)
        XCTAssertEqual(recorder.calls.last?.gestures, 7)
        XCTAssertNil(lift.seatId)
        XCTAssertEqual(lift.dy, 0)
    }

    /// The picker is going away: there is nothing left to pan on.
    @MainActor
    func testForgetTouchesTheMapNotAtAll() async {
        let recorder = FrameRecorder()
        let lift = SeatLayerPickerSeatLift(settle: []) { seatId, fraction, gestures in
            recorder.record(seatId: seatId, fraction: fraction, gestures: gestures)
            return SeatLayerSeatFrame(dy: -50, gestures: 1)
        }
        for _ in 0..<2 {
            lift.sync(seatId: "A-1", mapHeight: 700, top: 0, bottom: 0, sheet: 260, revision: 1)
        }
        await settle()
        lift.forget()
        await settle()
        XCTAssertEqual(recorder.calls.count, 1)
    }

    /// A refused lift leaves the count where it was, so the restore is refused
    /// for the same reason.
    @MainActor
    func testARuntimeThatDeclinesLeavesTheLiftWhereItWas() async {
        let recorder = FrameRecorder()
        let lift = SeatLayerPickerSeatLift(settle: []) { seatId, fraction, gestures in
            recorder.record(seatId: seatId, fraction: fraction, gestures: gestures)
            // The buyer has taken the wheel between the two asks.
            return SeatLayerSeatFrame(dy: -20, gestures: recorder.calls.count == 1 ? 1 : 9)
        }
        for _ in 0..<2 {
            lift.sync(seatId: "A-1", mapHeight: 700, top: 0, bottom: 0, sheet: 260, revision: 1)
        }
        await settle()
        lift.sync(seatId: "A-1", mapHeight: 700, top: 0, bottom: 0, sheet: 260, revision: 2)
        await settle()
        XCTAssertEqual(recorder.calls.count, 2)
        XCTAssertEqual(lift.dy, -20)
    }

    @MainActor
    private func settle() async {
        for _ in 0..<8 { await Task.yield() }
    }
}

@MainActor
private final class FrameRecorder {
    struct Call {
        let seatId: String
        let fraction: Double
        let gestures: Int?
    }

    private(set) var calls: [Call] = []

    func record(seatId: String, fraction: Double, gestures: Int?) {
        calls.append(Call(seatId: seatId, fraction: fraction, gestures: gestures))
    }
}
