import XCTest
@testable import SeatLayer

final class PickerSnapshotTests: XCTestCase {
    func testDecodesTheCompleteV1SnapshotAndPreservesAdditions() throws {
        let raw = pickerSnapshot(
            revision: 7,
            additions: ["future": ["loyalty": 42]]
        )
        let snapshot = try XCTUnwrap(decodeSeatLayerPickerSnapshot(raw))

        XCTAssertEqual(snapshot.schema, seatLayerPickerSnapshotSchema)
        XCTAssertEqual(snapshot.sessionId, "session-1")
        XCTAssertEqual(snapshot.revision, 7)
        XCTAssertEqual(snapshot.event.name, "Opening Night")
        XCTAssertEqual(snapshot.event.mode, .test)
        XCTAssertEqual(snapshot.categories.first?.priceMin, 45)
        XCTAssertEqual(snapshot.categories.first?.priceMax, 75)
        XCTAssertEqual(snapshot.sections.first?.dominantCategoryKey, "stalls")
        XCTAssertEqual(snapshot.map.rung, "seats")
        XCTAssertEqual(snapshot.map.viewportInsets?.bottom, 52)
        XCTAssertEqual(snapshot.map.accessNeeds, [
            SeatLayerPickerAccessNeed(key: "step-free", count: 24),
        ])
        XCTAssertEqual(snapshot.ticketCount, 2)
        XCTAssertEqual(snapshot.cartTotal, 120)
        XCTAssertEqual(snapshot.hold.owner, "picker")
        XCTAssertTrue(snapshot.capabilities.contains("venue3d"))
        XCTAssertEqual(snapshot.raw["future"]?["loyalty"]?.intValue, 42)
    }

    func testRejectsOnlyAnInvalidSnapshotIdentity() {
        XCTAssertNil(decodeSeatLayerPickerSnapshot(nil))
        XCTAssertNil(decodeSeatLayerPickerSnapshot(["schema": "future/2"]))

        var raw = pickerSnapshot().objectValue!
        raw["revision"] = .double(1.5)
        XCTAssertNil(decodeSeatLayerPickerSnapshot(.object(raw)))

        raw = pickerSnapshot().objectValue!
        raw["event"] = ["name": "Missing key"]
        XCTAssertNil(decodeSeatLayerPickerSnapshot(.object(raw)))
    }

    func testMalformedOptionalEntriesAreSkippedAndDefaultsStaySafe() throws {
        var raw = pickerSnapshot().objectValue!
        raw["catalog"] = [
            "categories": .array([
                ["label": "missing key"],
                ["key": "balcony", "tiers": .array([])],
            ]),
            "zones": .array([.string("bad")]),
            "sections": .array([.null]),
            "gaAreas": .array([.null]),
        ]
        raw["map"] = [
            "categoryFilter": .array(["a", "a", 4]),
            "accessNeeds": .array([
                ["key": " step-free ", "count": -2],
                ["key": "step-free", "count": 8],
                ["key": "", "count": 1],
            ]),
            "viewportInsets": ["top": -10, "bottom": 40],
        ]
        raw["cart"] = [
            "items": .array([
                ["label": "A-1", "unitPrice": 10, "quantity": 2],
                ["unitPrice": 999],
            ]),
        ]

        let snapshot = try XCTUnwrap(decodeSeatLayerPickerSnapshot(.object(raw)))
        XCTAssertEqual(snapshot.categories.map(\.key), ["balcony"])
        XCTAssertTrue(snapshot.zones.isEmpty)
        XCTAssertEqual(snapshot.map.categoryFilter, ["a"])
        XCTAssertEqual(snapshot.map.accessNeeds.first?.count, 0)
        XCTAssertEqual(snapshot.map.viewportInsets?.top, 0)
        XCTAssertEqual(snapshot.cartLines.count, 1)
        XCTAssertEqual(snapshot.cartTotal, 20)
        XCTAssertEqual(snapshot.currency, "EUR")
    }

    func testDecodesExplicit3DTargetNeighboursAndFocusedSection() throws {
        var raw = try XCTUnwrap(pickerSnapshot().objectValue)
        var map = try XCTUnwrap(raw["map"]?.objectValue)
        map["buyerView"] = "venue3d"
        map["view3dTargetSeatId"] = "seat-unselected"
        map["view3dTargetSeat"] = [
            "id": "seat-unselected",
            "label": "T22-2",
            "sectionLabel": "Guest tables",
            "rowLabel": "T22",
            "seatNumber": "2",
        ]
        map["view3dPreviousSeatId"] = .null
        map["view3dNextSeatId"] = "seat-next"
        map["view3dFocusedSectionId"] = "guest-tables"
        raw["map"] = .object(map)

        let snapshot = try XCTUnwrap(decodeSeatLayerPickerSnapshot(.object(raw)))
        XCTAssertTrue(snapshot.map.reportsView3DPosition)
        XCTAssertEqual(snapshot.map.view3DTargetSeatId, "seat-unselected")
        XCTAssertEqual(snapshot.map.view3DTargetSeat?.label, "T22-2")
        XCTAssertNil(snapshot.map.view3DPreviousSeatId)
        XCTAssertEqual(snapshot.map.view3DNextSeatId, "seat-next")
        XCTAssertEqual(snapshot.map.view3DFocusedSectionId, "guest-tables")
    }

    func testOldRuntime3DTargetDoesNotInventReportedRowBoundaries() throws {
        var raw = try XCTUnwrap(pickerSnapshot().objectValue)
        var map = try XCTUnwrap(raw["map"]?.objectValue)
        map["buyerView"] = "venue3d"
        map["view3dTargetSeatId"] = "seat-1"
        raw["map"] = .object(map)

        let snapshot = try XCTUnwrap(decodeSeatLayerPickerSnapshot(.object(raw)))
        XCTAssertFalse(snapshot.map.reportsView3DPosition)
        XCTAssertNil(snapshot.map.view3DPreviousSeatId)
        XCTAssertNil(snapshot.map.view3DNextSeatId)
        XCTAssertNil(snapshot.map.view3DFocusedSectionId)
    }

    func testTierMetadataSurvivesForNativeGuidanceAndCurrency() throws {
        let tier = try JSONValue.object([
            "id": "companion",
            "name": "Companion",
            "price": 0,
            "currency": "EUR",
            "restriction": "companion",
            "buyerMessage": "Requires the adjacent wheelchair place.",
        ]).decode(CategoryTier.self)

        XCTAssertEqual(tier.currency, "EUR")
        XCTAssertEqual(tier.restriction, "companion")
        XCTAssertEqual(tier.buyerMessage, "Requires the adjacent wheelchair place.")
    }

    @MainActor
    func testStoreDropsStaleAndForeignSessionSnapshots() throws {
        let store = SeatLayerPickerSnapshotStore()
        let first = try XCTUnwrap(decodeSeatLayerPickerSnapshot(pickerSnapshot(revision: 2)))
        let stale = try XCTUnwrap(decodeSeatLayerPickerSnapshot(pickerSnapshot(revision: 1)))
        let equal = try XCTUnwrap(decodeSeatLayerPickerSnapshot(pickerSnapshot(revision: 2)))
        let fresh = try XCTUnwrap(decodeSeatLayerPickerSnapshot(pickerSnapshot(revision: 3)))
        let foreign = try XCTUnwrap(
            decodeSeatLayerPickerSnapshot(pickerSnapshot(sessionId: "session-2", revision: 4))
        )

        XCTAssertTrue(store.apply(first))
        XCTAssertFalse(store.apply(stale))
        XCTAssertFalse(store.apply(equal))
        XCTAssertFalse(store.apply(foreign))
        XCTAssertTrue(store.apply(fresh))
        XCTAssertEqual(store.snapshot?.revision, 3)
    }

    func testCheckoutHandoffIsTheOnlyTypedSurfaceWithAHoldId() throws {
        let handoff = try XCTUnwrap(decodeSeatLayerPickerCheckoutHandoff([
            "holdId": "hold-secret",
            "expiresAt": 1_800_000_000_000,
            "lineItems": .array([
                ["label": "A-1", "unitPrice": 30, "currency": "EUR", "quantity": 2],
            ]),
        ]))

        XCTAssertEqual(handoff.holdId, "hold-secret")
        XCTAssertEqual(handoff.currency, "EUR")
        XCTAssertEqual(handoff.total, 60)
        XCTAssertFalse(Mirror(reflecting: SeatLayerPickerHold(active: true, expiresAt: nil, owner: "picker"))
            .children.contains { $0.label == "holdId" })
    }

    func testSeatViewDecoderToleratesAdditions() throws {
        let view = try XCTUnwrap(decodeSeatLayerSeatView([
            "seatId": "seat-1",
            "title": "View from A-1",
            "real": false,
            "generated": true,
            "futureDisclosure": "new",
        ]))
        XCTAssertEqual(view.seatId, "seat-1")
        XCTAssertTrue(view.generated)
    }

    func testAvailabilityOutcomeKeepsOnlyRecoverableLapsedLabels() throws {
        let outcome = try XCTUnwrap(decodeSeatLayerPickerAvailabilityOutcome([
            "outcome": "ignored additive field",
            "lost": .array(["A-1", "A-1", "B-2"]),
            "holdLapsed": true,
            "lapsed": .array(["C-3", "D-4"]),
            "recoverable": .array(["D-4", "not-in-the-expired-hold"]),
            "revision": .double(9),
            "heldForMs": 900_000,
        ]))

        XCTAssertTrue(outcome.refreshed)
        XCTAssertEqual(outcome.lostLabels, ["A-1", "B-2"])
        XCTAssertEqual(outcome.lapsedLabels, ["C-3", "D-4"])
        XCTAssertEqual(outcome.recoverableLabels, ["D-4"])
        XCTAssertEqual(outcome.recovery, .partial)
        XCTAssertEqual(outcome.revision, 9)
    }

    func testAvailabilityOutcomeRequiresEvidenceThatAvailabilityWasRead() {
        XCTAssertNil(decodeSeatLayerPickerAvailabilityOutcome(["state": "background"]))
        XCTAssertNil(decodeSeatLayerPickerAvailabilityOutcome(nil))
    }

    private func pickerSnapshot(
        sessionId: String = "session-1",
        revision: Int = 1,
        additions: [String: JSONValue] = [:]
    ) -> JSONValue {
        var root: [String: JSONValue] = [
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": .string(sessionId),
            "revision": .int(revision),
            "chrome": ["owner": "native"],
            "event": [
                "key": "ev_picker",
                "name": "Opening Night",
                "mode": "test",
                "currency": "EUR",
                "salesClosed": false,
            ],
            "branding": [
                "brandName": "Venue",
                "attributionRequired": true,
                "tokens": ["accent": "#e54558", "radius": 8],
            ],
            "features": ["venue3d": true, "seatView": true, "floors": false],
            "catalog": [
                "categories": .array([
                    [
                        "key": "stalls",
                        "label": "Stalls",
                        "color": "#e54558",
                        "available": 24,
                        "tiers": .array([
                            ["id": "adult", "name": "Adult", "price": 45],
                            ["id": "premium", "name": "Premium", "price": 75],
                        ]),
                    ],
                ]),
                "zones": .array([["id": "main", "label": "Main"]]),
                "sections": .array([
                    [
                        "id": "section-a",
                        "label": "Stalls A",
                        "dominantCategoryKey": "stalls",
                        "seatsLeft": 24,
                    ],
                ]),
                "gaAreas": .array([]),
                "bestAvailableZones": .array([]),
            ],
            "map": [
                "rung": "seats",
                "viewMode": "flat",
                "buyerView": "map",
                "view3dNavigationMode": "orbit",
                "focusedSectionId": "section-a",
                "colorblindSafe": false,
                "hideLimitedView": false,
                "categoryFilter": .array([]),
                "accessibilityFilter": .array([]),
                "accessNeeds": .array([
                    ["key": "step-free", "count": 24],
                    ["key": "step-free", "count": 1],
                ]),
                "floors": .array([]),
                "viewportInsets": ["top": 56, "bottom": 52],
            ],
            "selection": [
                "seats": .array([
                    ["id": "seat-1", "label": "A-1", "price": 45],
                    ["id": "seat-2", "label": "A-2", "price": 75],
                ]),
                "maxSelection": 10,
            ],
            "cart": [
                "currency": "EUR",
                "quantity": 2,
                "total": 120,
                "items": .array([
                    ["label": "A-1", "unitPrice": 45, "currency": "EUR", "quantity": 1],
                    ["label": "A-2", "unitPrice": 75, "currency": "EUR", "quantity": 1],
                ]),
            ],
            "hold": ["active": true, "expiresAt": 1_800_000_000_000, "ownership": "picker"],
            "access": ["configured": true, "status": "ready"],
        ]
        root.merge(additions) { _, addition in addition }
        return .object(root)
    }
}
