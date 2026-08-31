import XCTest
@testable import SeatLayer

final class PickerAccessibilityTests: XCTestCase {
    func testAvailabilityRequiresInventoryAndEveryContractLeg() throws {
        let snapshot = try makeSnapshot()
        let complete = makeBundle()
        XCTAssertEqual(
            SeatLayerPickerAccessibility.availability(
                snapshot: snapshot,
                bundle: complete
            ),
            SeatLayerPickerAccessibilityAvailability(
                accessibility: true,
                limitedView: true,
                colorblind: true
            )
        )

        let missingTaxonomy = makeBundle(capabilities: [
            "native-chrome-contract-v1", "colorblind-safe",
        ])
        XCTAssertFalse(SeatLayerPickerAccessibility.availability(
            snapshot: snapshot,
            bundle: missingTaxonomy
        ).accessibility)

        let noInventory = try makeSnapshot(needs: [])
        XCTAssertFalse(SeatLayerPickerAccessibility.availability(
            snapshot: noInventory,
            bundle: complete
        ).accessibility)
    }

    func testMutationPlanKeepsFilterFamiliesIndependentAndOrdered() {
        let initial = SeatLayerPickerAccessibilityDraft(
            types: ["step-free", "companion"],
            hideLimitedView: false,
            colorblindSafe: false
        )
        let draft = SeatLayerPickerAccessibilityDraft(
            types: ["companion"],
            hideLimitedView: true,
            colorblindSafe: true
        )
        let available = SeatLayerPickerAccessibilityAvailability(
            accessibility: true,
            limitedView: true,
            colorblind: true
        )

        let plan = SeatLayerPickerAccessibility.mutations(
            from: initial,
            to: draft,
            availability: available
        )
        XCTAssertEqual(plan, [
            .accessibility(["companion"]),
            .limitedView(true),
            .colorblind(true),
        ])
        XCTAssertTrue(SeatLayerPickerAccessibility.shouldFocusSeats(after: plan))
    }

    func testReportedNeedsKeepOrderAndZeroCountTruth() throws {
        let snapshot = try makeSnapshot()
        let availability = SeatLayerPickerAccessibility.availability(
            snapshot: snapshot,
            bundle: makeBundle()
        )
        XCTAssertEqual(
            SeatLayerPickerAccessibility.needs(
                snapshot: snapshot,
                availability: availability
            ),
            [
                SeatLayerPickerAccessNeed(key: "step-free", count: 12),
                SeatLayerPickerAccessNeed(key: "wheelchair", count: 0),
                SeatLayerPickerAccessNeed(key: "companion", count: 4),
            ]
        )
        let strings = SeatLayerPickerStrings(localeIdentifier: "en")
        XCTAssertEqual(strings.accessNeed("step-free", count: 12), "Step-free · 12")
        XCTAssertEqual(strings.accessNeed("step_free", count: 25), "Step-free · 25")
        XCTAssertEqual(strings.accessNeed("wheelchair", count: 0), "Wheelchair · 0")
        XCTAssertEqual(strings.accessNeed("future-need"), "Future need")
    }

    func testSoldOutAuthoredNeedIsVisibleButDroppedFromActiveDraft() throws {
        var raw = try XCTUnwrap(makeSnapshot().raw.objectValue)
        var map = try XCTUnwrap(raw["map"]?.objectValue)
        map["accessibilityFilter"] = .array(["wheelchair", "step-free"])
        raw["map"] = .object(map)
        let snapshot = try XCTUnwrap(decodeSeatLayerPickerSnapshot(.object(raw)))

        XCTAssertEqual(
            SeatLayerPickerAccessibility.draft(from: snapshot).types,
            ["step-free"]
        )
    }

    private func makeSnapshot(
        needs: [JSONValue] = [
            ["key": "step-free", "count": 12],
            ["key": "wheelchair", "count": 0],
            ["key": "companion", "count": 4],
        ]
    ) throws -> SeatLayerPickerSnapshot {
        try XCTUnwrap(decodeSeatLayerPickerSnapshot([
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": "filter-session",
            "revision": 1,
            "event": ["key": "event", "currency": "EUR"],
            "features": [
                "accessibilityFilter": true,
                "limitedViewFilter": true,
            ],
            "map": [
                "rung": "zones",
                "accessibilityFilter": .array(["step-free"]),
                "accessNeeds": .array(needs),
                "hideLimitedView": false,
                "colorblindSafe": false,
            ],
        ]))
    }

    private func makeBundle(
        capabilities: [String] = [
            "native-chrome-contract-v1", "access-needs-v1", "colorblind-safe",
        ]
    ) -> BundleInfo {
        BundleInfo([
            "bundle": "test",
            "protocol": ["min": 2, "max": 2],
            "capabilities": .array(capabilities.map(JSONValue.string)),
            "commands": .array([
                "picker.setAccessibilityFilter",
                "picker.setLimitedViewFilter",
                "picker.setColorblindSafe",
                "picker.setRung",
            ].map(JSONValue.string)),
            "events": .array(["picker.snapshot"]),
        ])
    }
}
