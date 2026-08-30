import XCTest
@testable import SeatLayer

final class PickerImmersiveTests: XCTestCase {
    func testExplicitUnselectedTargetUsesAuthoredNeighboursAndNullBoundary() throws {
        let snapshot = try makeSnapshot(map: [
            "buyerView": "venue3d",
            "view3dTargetSeatId": "target",
            "view3dTargetSeat": [
                "id": "target",
                "label": "T22-2",
                "rowLabel": "T22",
                "seatNumber": "2",
            ],
            "view3dPreviousSeatId": .null,
            "view3dNextSeatId": "target-next",
            "view3dFocusedSectionId": "guest-tables",
        ], selection: [
            ["id": "cart-a", "label": "D-4"],
            ["id": "cart-b", "label": "D-5"],
        ])

        let position = SeatLayerPickerImmersive.position(in: snapshot)
        XCTAssertEqual(position.targetSeat?.label, "T22-2")
        XCTAssertNil(position.previousSeatId)
        XCTAssertEqual(position.nextSeatId, "target-next")
        XCTAssertEqual(
            SeatLayerPickerImmersive.request(for: .next, snapshot: snapshot),
            SeatLayerPickerBuyerViewRequest(view: "venue3d", flyToSeatId: "target-next")
        )
        XCTAssertNil(SeatLayerPickerImmersive.request(for: .previous, snapshot: snapshot))
    }

    func testOldRuntimeFallbackIsBoundedToSelectionOrder() throws {
        let snapshot = try makeSnapshot(map: [
            "buyerView": "venue3d",
            "view3dTargetSeatId": "cart-b",
        ], selection: [
            ["id": "cart-a", "label": "D-4"],
            ["id": "cart-b", "label": "D-5"],
            ["id": "cart-c", "label": "D-6"],
        ])

        let position = SeatLayerPickerImmersive.position(in: snapshot)
        XCTAssertEqual(position.targetSeat?.label, "D-5")
        XCTAssertEqual(position.previousSeatId, "cart-a")
        XCTAssertEqual(position.nextSeatId, "cart-c")
    }

    func testBackWalksTargetOrSectionTo3DOverviewThenMap() throws {
        let target = try makeSnapshot(map: [
            "buyerView": "venue3d",
            "view3dTargetSeatId": "target",
            "view3dPreviousSeatId": .null,
            "view3dNextSeatId": .null,
            "view3dFocusedSectionId": "section-a",
        ])
        XCTAssertEqual(
            SeatLayerPickerImmersive.request(for: .back, snapshot: target),
            SeatLayerPickerBuyerViewRequest(view: "venue3d", resetView: true)
        )

        let overview = try makeSnapshot(map: [
            "buyerView": "venue3d",
            "view3dPreviousSeatId": .null,
            "view3dNextSeatId": .null,
            "view3dFocusedSectionId": .null,
        ])
        XCTAssertEqual(
            SeatLayerPickerImmersive.request(for: .back, snapshot: overview),
            SeatLayerPickerBuyerViewRequest(view: "map")
        )
    }

    func testCapabilityGatesRequireEveryAdvertisedContractLeg() throws {
        let snapshot = try makeSnapshot(map: [
            "buyerView": "venue3d",
            "view3dTargetSeatId": "target",
        ], features: ["venue3d": true, "seatView": true])
        let complete = makeBundle()
        let available = SeatLayerPickerImmersive.availability(
            snapshot: snapshot,
            bundle: complete,
            seatView: makeSeatView()
        )
        XCTAssertTrue(available.venue3D)
        XCTAssertTrue(available.navigationMode)
        XCTAssertTrue(available.seatViewAction)
        XCTAssertTrue(available.panoramaChrome)
        XCTAssertTrue(available.zoomToFit)

        let missingEvent = makeBundle(events: ["picker.snapshot"])
        XCTAssertFalse(SeatLayerPickerImmersive.availability(
            snapshot: snapshot,
            bundle: missingEvent,
            seatView: makeSeatView()
        ).panoramaChrome)

        let missingNavigationCommand = makeBundle(commands: baseCommands.filter {
            $0 != "picker.setVenue3DNavigationMode"
        })
        XCTAssertFalse(SeatLayerPickerImmersive.availability(
            snapshot: snapshot,
            bundle: missingNavigationCommand,
            seatView: nil
        ).navigationMode)
    }

    func testPanoramaWordingTrimsAndRequiresVisibleContent() throws {
        let view = try XCTUnwrap(decodeSeatLayerSeatView([
            "title": "  View from T22-3  ",
            "caption": "   ",
            "badge": " Preview ",
            "dragHint": " Drag to look around ",
            "real": false,
            "generated": true,
        ]))
        let wording = SeatLayerPickerImmersive.panoramaWording(view)
        XCTAssertEqual(wording.title, "View from T22-3")
        XCTAssertNil(wording.caption)
        XCTAssertEqual(wording.badge, "Preview")
        XCTAssertEqual(wording.dragHint, "Drag to look around")
        XCTAssertTrue(view.hasContent)

        let empty = try XCTUnwrap(decodeSeatLayerSeatView(["title": "  "]))
        XCTAssertFalse(empty.hasContent)
    }

    func testChromeCompositionYieldsImmersiveGestureSurfaceButKeepsCart() {
        let map = SeatLayerPickerImmersive.chromeVisibility(.unavailable)
        XCTAssertTrue(map.priceLegend)
        XCTAssertTrue(map.floors)
        XCTAssertTrue(map.dock)
        XCTAssertTrue(map.mapControls)
        XCTAssertTrue(map.accessibility)
        XCTAssertTrue(map.cart)
        XCTAssertFalse(map.immersive)

        let venue = SeatLayerPickerImmersive.chromeVisibility(
            availability(venue3D: true)
        )
        XCTAssertTrue(venue.priceLegend)
        XCTAssertFalse(venue.floors)
        XCTAssertFalse(venue.dock)
        XCTAssertFalse(venue.mapControls)
        XCTAssertFalse(venue.accessibility)
        XCTAssertTrue(venue.cart)
        XCTAssertTrue(venue.venue3D)

        let panorama = SeatLayerPickerImmersive.chromeVisibility(
            availability(venue3D: true, panorama: true)
        )
        XCTAssertFalse(panorama.priceLegend)
        XCTAssertFalse(panorama.venue3D)
        XCTAssertTrue(panorama.panorama)
        XCTAssertTrue(panorama.cart)
    }

    private let baseCommands = [
        "picker.setBuyerView",
        "picker.setVenue3DNavigationMode",
        "picker.openSeatView",
        "picker.zoomIn",
        "picker.zoomOut",
        "picker.zoomToFit",
    ]

    private func makeBundle(
        commands: [String]? = nil,
        events: [String] = ["picker.snapshot", "seatView.changed"]
    ) -> BundleInfo {
        BundleInfo([
            "bundle": "test",
            "protocol": ["min": 2, "max": 2],
            "capabilities": .array([
                "native-chrome-contract-v1",
                "venue-3d-v1",
                "venue-3d-controls-v1",
                "seat-view-v1",
                "native-seat-view-chrome-v1",
            ].map(JSONValue.string)),
            "commands": .array((commands ?? baseCommands).map(JSONValue.string)),
            "events": .array(events.map(JSONValue.string)),
        ])
    }

    private func makeSeatView() -> SeatLayerSeatView {
        decodeSeatLayerSeatView([
            "title": "View from T22-2",
            "badge": "Preview",
        ])!
    }

    private func availability(
        venue3D: Bool,
        panorama: Bool = false
    ) -> SeatLayerPickerImmersiveAvailability {
        SeatLayerPickerImmersiveAvailability(
            venue3D: venue3D,
            navigationMode: venue3D,
            seatViewAction: venue3D,
            panoramaChrome: panorama,
            zoomIn: venue3D,
            zoomOut: venue3D,
            zoomToFit: venue3D
        )
    }

    private func makeSnapshot(
        map additions: [String: JSONValue],
        selection: [JSONValue] = [],
        features: [String: JSONValue] = ["venue3d": true]
    ) throws -> SeatLayerPickerSnapshot {
        var map: [String: JSONValue] = [
            "rung": "zones",
            "buyerView": "map",
        ]
        map.merge(additions) { _, value in value }
        return try XCTUnwrap(decodeSeatLayerPickerSnapshot([
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": "immersive-session",
            "revision": 1,
            "event": ["key": "event", "currency": "EUR"],
            "features": .object(features),
            "map": .object(map),
            "selection": ["seats": .array(selection)],
        ]))
    }
}
