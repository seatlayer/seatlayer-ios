import XCTest
@testable import SeatLayer

final class PickerAccessibilityFocusTests: XCTestCase {
    func testSheetIsBoundedToAFractionOfTheScreenWithAFloor() {
        XCTAssertEqual(seatLayerAccessSheetHeight(screenHeight: 844), 844 * 0.72, accuracy: 0.001)
        // A short screen keeps the floor rather than the fraction.
        XCTAssertEqual(seatLayerAccessSheetHeight(screenHeight: 300), 240, accuracy: 0.001)
        // Never taller than the screen itself.
        XCTAssertEqual(seatLayerAccessSheetHeight(screenHeight: 200), 200, accuracy: 0.001)
    }

    func testTourIsNotDrawnWithoutTheFocusCapability() {
        var tour = SeatLayerPickerAccessibilityTour()
        tour.begin(["wheelchair"])
        XCTAssertEqual(
            tour.state(supportsFocus: false, sectionsWithMatches: 4),
            .absent
        )
    }

    func testTourCountsSectionsBeforeTheFirstStep() {
        var tour = SeatLayerPickerAccessibilityTour()
        tour.begin(["wheelchair"])
        XCTAssertEqual(
            tour.state(supportsFocus: true, sectionsWithMatches: 6),
            .counted(sections: 6)
        )
    }

    func testAnUncountedRuntimeStillHasATour() {
        var tour = SeatLayerPickerAccessibilityTour()
        tour.begin(["wheelchair"])
        XCTAssertEqual(
            tour.state(supportsFocus: true, sectionsWithMatches: nil),
            .uncounted
        )
    }

    func testCountedButNonePositiveNeverDrawsThePill() {
        var tour = SeatLayerPickerAccessibilityTour()
        tour.begin(["wheelchair"])
        XCTAssertEqual(
            tour.state(supportsFocus: true, sectionsWithMatches: 0),
            .absent
        )
    }

    func testAStepIsPrintedOneBased() {
        var tour = SeatLayerPickerAccessibilityTour()
        tour.begin(["wheelchair"])
        tour.advance(to: SeatLayerPickerAccessibleStep(
            id: "s1",
            label: "Stalls",
            free: 3,
            index: 1,
            total: 6
        ))
        XCTAssertEqual(
            tour.state(supportsFocus: true, sectionsWithMatches: 6),
            .step(index: 2, total: 6)
        )
    }

    func testANullStepRemovesThePillRatherThanSayingZeroOfZero() {
        var tour = SeatLayerPickerAccessibilityTour()
        tour.begin(["wheelchair"])
        tour.advance(to: nil)
        XCTAssertEqual(
            tour.state(supportsFocus: true, sectionsWithMatches: 6),
            .absent
        )
    }

    func testChangingTheFilterAbandonsTheWalk() {
        var tour = SeatLayerPickerAccessibilityTour()
        tour.begin(["wheelchair"])
        tour.advance(to: SeatLayerPickerAccessibleStep(
            id: "s1",
            label: "Stalls",
            free: 3,
            index: 1,
            total: 6
        ))
        XCTAssertTrue(tour.reconcile(activeTypes: ["wheelchair", "companion"]))
        XCTAssertFalse(tour.isWalking)
        XCTAssertFalse(tour.reconcile(activeTypes: ["companion", "wheelchair"]))
    }

    func testSectionCountsAreNilWithoutTheCountsCapability() throws {
        let snapshot = try makeSnapshot(sections: [
            ["id": "a", "label": "A", "accessibleFree": 2],
        ])
        XCTAssertNil(seatLayerAccessibleSectionCount(
            snapshot: snapshot,
            types: ["wheelchair"],
            supportsCounts: false
        ))
    }

    func testAnUncountedSectionStaysSilentRatherThanSayingZero() throws {
        let snapshot = try makeSnapshot(sections: [
            ["id": "a", "label": "A"],
            ["id": "b", "label": "B"],
        ])
        XCTAssertNil(seatLayerAccessibleSectionCount(
            snapshot: snapshot,
            types: ["wheelchair"],
            supportsCounts: true
        ))
    }

    func testOnlySectionsHoldingAFreeSpaceAreCounted() throws {
        let snapshot = try makeSnapshot(sections: [
            ["id": "a", "label": "A", "accessibleFree": 2],
            ["id": "b", "label": "B", "accessibleFree": 0],
            ["id": "c", "label": "C", "accessibleFree": 5],
        ])
        XCTAssertEqual(
            seatLayerAccessibleSectionCount(
                snapshot: snapshot,
                types: ["wheelchair"],
                supportsCounts: true
            ),
            2
        )
    }

    private func makeSnapshot(sections: [JSONValue]) throws -> SeatLayerPickerSnapshot {
        try XCTUnwrap(decodeSeatLayerPickerSnapshot([
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": "focus-session",
            "revision": 1,
            "event": ["key": "event", "currency": "EUR"],
            "catalog": ["sections": .array(sections)],
            "map": ["rung": "sections"],
        ]))
    }
}
