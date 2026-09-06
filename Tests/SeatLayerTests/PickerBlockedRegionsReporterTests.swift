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
