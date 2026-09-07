import XCTest
@testable import SeatLayer

/// The rest table, the fling rule and the rubber band — the three things that
/// decide where the sheet ends up under a finger.
final class PickerSheetDetentTests: XCTestCase {
    func testPeekIsZeroAndOpenIsTheContentHeight() {
        let detents = SeatLayerPickerSheetDetents(content: 180, full: 300)
        XCTAssertEqual(detents.height(of: .peek), 0)
        XCTAssertEqual(detents.height(of: .mini), 0)
        XCTAssertEqual(detents.height(of: .open), 180)
    }

    func testMiniSlidesTheWholeSurfaceDownInstead() {
        let detents = SeatLayerPickerSheetDetents(content: 180, full: 180, surfaceDrop: 38)
        XCTAssertEqual(detents.surfaceOffset(of: .mini), 38)
        XCTAssertEqual(detents.surfaceOffset(of: .peek), 0)
        XCTAssertEqual(detents.surfaceOffset(of: .open), 0)
    }

    func testAFullBelowContentIsClampedUpToIt() {
        let detents = SeatLayerPickerSheetDetents(content: 240, full: 100)
        XCTAssertEqual(detents.full, 240)
        XCTAssertFalse(detents.offersFull)
        XCTAssertEqual(detents.top, 240)
    }

    func testALetGoTakesTheNearestRest() {
        let detents = SeatLayerPickerSheetDetents(content: 200, full: 200)
        XCTAssertEqual(detents.settle(height: 40, velocity: 0), .peek)
        XCTAssertEqual(detents.settle(height: 160, velocity: 0), .open)
    }

    func testAFlingPicksTheRestItWasThrownAt() {
        let detents = SeatLayerPickerSheetDetents(content: 200, full: 200)
        let fling = SeatLayerPickerPhysicsTokens.sheetFlingVelocity + 1
        XCTAssertEqual(detents.settle(height: 10, velocity: fling), .open)
        XCTAssertEqual(detents.settle(height: 190, velocity: -fling), .peek)
    }

    func testAShortDeliberateDragStillAnswers() {
        let detents = SeatLayerPickerSheetDetents(content: 200, full: 200)
        XCTAssertEqual(
            seatLayerPickerSheetStep(from: .peek, travel: 20, in: detents),
            .open
        )
        XCTAssertEqual(
            seatLayerPickerSheetStep(from: .open, travel: -20, in: detents),
            .peek
        )
        XCTAssertGreaterThan(seatLayerPickerSheetDragThreshold, 0)
    }

    func testTheEndsGiveRatherThanStop() {
        let give = SeatLayerPickerPhysicsTokens.rubberBand
        XCTAssertEqual(seatLayerPickerRubberBand(150, 0, 200), 150)
        XCTAssertEqual(seatLayerPickerRubberBand(300, 0, 200), 200 + 100 * give)
        XCTAssertEqual(seatLayerPickerRubberBand(-50, 0, 200), -50 * give)
    }

    func testCeilingsFollowTheCartRatherThanTheScreenAlone() {
        // A tall screen is capped by the absolute ceiling, a short one by the
        // fraction; an empty tray stays shorter than a full cart either way.
        XCTAssertEqual(seatLayerPickerSheetCeiling(screenHeight: 2000, hasTickets: true), 480)
        XCTAssertEqual(
            seatLayerPickerSheetCeiling(screenHeight: 600, hasTickets: true),
            600 * SeatLayerPickerSizeTokens.sheetMaxHeightFraction
        )
        XCTAssertLessThan(
            seatLayerPickerSheetCeiling(screenHeight: 2000, hasTickets: false),
            seatLayerPickerSheetCeiling(screenHeight: 2000, hasTickets: true)
        )
    }

    func testTheSheetFollowsItsContentAndStopsAtTheCeiling() {
        let short = seatLayerPickerSheetDetents(
            screenHeight: 844,
            chrome: 120,
            contentHeight: 90,
            hasTickets: true
        )
        XCTAssertEqual(short.content, 90)

        let tall = seatLayerPickerSheetDetents(
            screenHeight: 844,
            chrome: 120,
            contentHeight: 900,
            hasTickets: true
        )
        XCTAssertEqual(tall.content, min(844 * 0.72, 480) - 120, accuracy: 0.001)
        XCTAssertTrue(tall.offersFull)
        XCTAssertEqual(tall.full, 844 * 0.92 - 120, accuracy: 0.001)
    }

    // MARK: - Giving the map back

    func testACardOverTheMapCollapsesAnOpenSheet() {
        XCTAssertTrue(seatLayerPickerSheetShouldCollapse(
            detent: .open,
            cardIsUp: true,
            previousRung: "seats",
            rung: "seats"
        ))
    }

    func testACollapsedSheetIsLeftAlone() {
        XCTAssertFalse(seatLayerPickerSheetShouldCollapse(
            detent: .peek,
            cardIsUp: true,
            previousRung: "seats",
            rung: "zones"
        ))
        XCTAssertFalse(seatLayerPickerSheetShouldCollapse(
            detent: .mini,
            cardIsUp: true,
            previousRung: nil,
            rung: nil
        ))
    }

    func testSteppingOutOfTheSeatsCollapsesTheSheet() {
        XCTAssertTrue(seatLayerPickerSheetShouldCollapse(
            detent: .open,
            cardIsUp: false,
            previousRung: "seats",
            rung: "zones"
        ))
    }

    func testDescendingIntoTheSeatsLeavesTheSheetOpen() {
        XCTAssertFalse(seatLayerPickerSheetShouldCollapse(
            detent: .open,
            cardIsUp: false,
            previousRung: "zones",
            rung: "seats"
        ))
        XCTAssertFalse(seatLayerPickerSheetShouldCollapse(
            detent: .open,
            cardIsUp: false,
            previousRung: "seats",
            rung: "seats"
        ))
        XCTAssertFalse(seatLayerPickerSheetShouldCollapse(
            detent: .open,
            cardIsUp: false,
            previousRung: nil,
            rung: "zones"
        ))
    }

    // MARK: - Pushing a ticket out of the list

    func testASwipeCommitsWhenItIsCarriedFarEnough() {
        let width: Double = 320
        let commit = width * SeatLayerPickerPhysicsTokens.swipeCommitFraction
        XCTAssertFalse(seatLayerPickerSwipeCommits(
            travelled: commit - 1,
            width: width,
            velocity: 0
        ))
        XCTAssertTrue(seatLayerPickerSwipeCommits(
            travelled: commit,
            width: width,
            velocity: 0
        ))
        // A card whose width has not been measured yet cannot be pushed out by
        // a gesture that would otherwise have committed at zero.
        XCTAssertFalse(seatLayerPickerSwipeCommits(travelled: 0, width: 0, velocity: 0))
    }

    func testASwipeCommitsWhenItIsThrown() {
        let width: Double = 320
        let fling = SeatLayerPickerPhysicsTokens.swipeFlingVelocity
        XCTAssertTrue(seatLayerPickerSwipeCommits(
            travelled: 20,
            width: width,
            velocity: fling
        ))
        XCTAssertFalse(seatLayerPickerSwipeCommits(
            travelled: 20,
            width: width,
            velocity: fling - 1
        ))
        // Thrown back toward home is not an instruction to remove.
        XCTAssertFalse(seatLayerPickerSwipeCommits(
            travelled: 20,
            width: width,
            velocity: -fling * 4
        ))
    }

    func testTheThrowIsReadBackOutOfTheProjection() {
        XCTAssertEqual(
            seatLayerPickerSwipeVelocity(translation: 40, predictedEnd: 215),
            700,
            accuracy: 0.001
        )
        // A finger that stopped is projected to where it already is.
        XCTAssertEqual(
            seatLayerPickerSwipeVelocity(translation: 40, predictedEnd: 40),
            0,
            accuracy: 0.001
        )
    }
}
