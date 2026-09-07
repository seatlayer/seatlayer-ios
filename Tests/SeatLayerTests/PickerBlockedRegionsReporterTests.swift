import XCTest
@testable import SeatLayer

/// The bookkeeping between what is drawn and what the runtime was told.
@MainActor
final class PickerBlockedRegionsReporterTests: XCTestCase {
    func testEveryDrawnControlIsReportedInTheOrderItRegistered() {
        let reporter = SeatLayerPickerBlockedRegionsReporter()
        reporter.apply([entry("legend", x: 0), entry("column", x: 40)])

        XCTAssertEqual(reporter.regions.map(\.x), [0, 40])
    }

    func testAMovedControlReplacesItsOwnRectangleRatherThanAddingOne() {
        let reporter = SeatLayerPickerBlockedRegionsReporter()
        reporter.apply([entry("column", x: 40)])
        reporter.apply([entry("column", x: 40, y: 120)])

        XCTAssertEqual(reporter.regions.count, 1)
        XCTAssertEqual(reporter.regions.first?.y, 120)
    }

    func testAControlThatLeavesKeepsGuardingForItsLinger() async throws {
        let reporter = SeatLayerPickerBlockedRegionsReporter()
        reporter.apply([entry("card", x: 10)])
        reporter.apply([])

        XCTAssertEqual(
            reporter.regions.count,
            1,
            "the touch this guards against arrives after the tap was handled"
        )
        try await Task.sleep(nanoseconds: UInt64((seatLayerBlockedRegionLinger + 0.2) * 1_000_000_000))
        XCTAssertTrue(reporter.regions.isEmpty)
    }

    func testTheLayoutLeavingClearsTheGuardAtOnce() {
        let reporter = SeatLayerPickerBlockedRegionsReporter()
        reporter.apply([entry("column", x: 40), entry("legend", x: 0)])
        reporter.detach()

        XCTAssertTrue(reporter.regions.isEmpty)
    }

    func testAWholeMapCoverIsHeldAndReleasedUnderItsOwnKey() {
        let reporter = SeatLayerPickerBlockedRegionsReporter()
        reporter.apply([entry("column", x: 40)])
        reporter.cover("sheet", SeatLayerBlockedRegion(x: 0, y: 0, w: 390, h: 700))

        XCTAssertEqual(reporter.regions.count, 2)
        XCTAssertEqual(reporter.regions.last?.w, 390)

        // A later layout pass names only the chrome it measured, and must not
        // take the modal's cover away with it.
        reporter.apply([entry("column", x: 40)])
        XCTAssertEqual(reporter.regions.count, 2)
    }

    func testAMalformedRectangleIsFlooredRatherThanDroppingTheWholeList() {
        let reporter = SeatLayerPickerBlockedRegionsReporter()
        reporter.apply([
            SeatLayerPickerBlockedRegionEntry(
                key: "broken",
                region: SeatLayerBlockedRegion(x: .nan, y: 0, w: -4, h: 20)
            ),
            entry("column", x: 40),
        ])

        XCTAssertEqual(reporter.regions.count, 2)
        XCTAssertEqual(reporter.regions.first?.x, 0)
        XCTAssertEqual(reporter.regions.first?.w, 0)
    }

    /// A key the layout has taken away is on its way out, and a measurement
    /// that names it again is a late pass until the registry says it is gone.
    ///
    /// Reviving on one of those is how a cover over the whole map came back
    /// after it was lowered — and a cover that never lifts is a map that takes
    /// no tap, pan or pinch again.
    func testALoweredKeyIsNotRevivedByALateMeasurement() async throws {
        let reporter = SeatLayerPickerBlockedRegionsReporter(linger: 0.05)
        reporter.apply([entry("card", x: 10)])
        reporter.apply([])
        // The pass that measured the card before it left, delivered after.
        reporter.apply([entry("card", x: 10)])

        XCTAssertEqual(reporter.regions.count, 1, "the linger is still guarding")
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertTrue(reporter.regions.isEmpty, "the lowered key went, and stayed gone")
    }

    /// The same for a cover, which is lowered by name rather than by absence.
    func testALoweredCoverIsNotRevivedByALateLayoutPass() async throws {
        let reporter = SeatLayerPickerBlockedRegionsReporter(linger: 0.05)
        reporter.cover("decision", SeatLayerBlockedRegion(x: 0, y: 0, w: 390, h: 700))
        reporter.cover("decision", nil)
        reporter.apply([
            SeatLayerPickerBlockedRegionEntry(
                key: "decision",
                region: SeatLayerBlockedRegion(x: 0, y: 0, w: 390, h: 700)
            ),
        ])

        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertTrue(reporter.regions.isEmpty)
    }

    /// A raise carries the value its own change delivered, so it IS the truth:
    /// a card dismissed and another opened inside the linger guards again.
    func testARaisedCoverComesBackEvenInsideTheLinger() async throws {
        let reporter = SeatLayerPickerBlockedRegionsReporter(linger: 0.05)
        let whole = SeatLayerBlockedRegion(x: 0, y: 0, w: 390, h: 700)
        reporter.cover("decision", whole)
        reporter.cover("decision", nil)
        reporter.cover("decision", whole)

        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(reporter.regions, [whole])
    }

    /// Once the registry has let the key go, the control is ordinary again.
    func testAControlMeasuredAfterItsLingerIsRegisteredAfresh() async throws {
        let reporter = SeatLayerPickerBlockedRegionsReporter(linger: 0.05)
        reporter.apply([entry("card", x: 10)])
        reporter.apply([])
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertTrue(reporter.regions.isEmpty)

        reporter.apply([entry("card", x: 10)])
        XCTAssertEqual(reporter.regions.count, 1)
    }

    private func entry(
        _ key: String,
        x: Double,
        y: Double = 0
    ) -> SeatLayerPickerBlockedRegionEntry {
        SeatLayerPickerBlockedRegionEntry(
            key: key,
            region: SeatLayerBlockedRegion(x: x, y: y, w: 36, h: 36)
        )
    }
}
