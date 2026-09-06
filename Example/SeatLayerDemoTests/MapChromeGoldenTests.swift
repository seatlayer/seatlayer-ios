import SwiftUI
import XCTest
@testable import SeatLayer

/// The chrome that stands on the map, drawn as a buyer sees it.
///
/// Two cameras, because the column answers the camera: at the whole-venue fit
/// every disc is live, and among the seats `+` has retired into a slot it
/// keeps. Both carry the price rail, the Map/3D control, the floor rail and
/// the test chip, so a change to any one of them is visible here.
@available(iOS 16.0, *)
@MainActor
final class MapChromeGoldenTests: XCTestCase {
    func testOverviewChromeAtVenueFitGolden() throws {
        try renderBothSchemes(named: "map-chrome-venue", fixture: makeFixture())
    }

    func testOverviewChromeInsideASectionRetiresThePlusDiscGolden() throws {
        try renderBothSchemes(
            named: "map-chrome-section",
            fixture: makeFixture(rung: "seats", focusedSection: true)
        )
    }

    // MARK: - Harness

    private struct Fixture {
        let controller: SeatLayerPickerController
        let style: SeatLayerPickerStyleEnvironment
    }

    private func renderBothSchemes(named name: String, fixture: Fixture) throws {
        let view = VStack(spacing: 0) {
            SeatLayerPickerPriceLegend(compact: true)
            ZStack {
                SeatLayerPickerMapControls()
                VStack {
                    HStack {
                        SeatLayerPickerTestModeIndicator()
                        Spacer(minLength: 0)
                    }
                    .padding(.top, SeatLayerPickerSizeTokens.mapAnchorInset)
                    .padding(.leading, SeatLayerPickerSizeTokens.mapAnchorInset)
                    SeatLayerPickerFloorStrip(compact: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .environmentObject(fixture.controller)
        .environment(\.seatLayerPickerStyle, fixture.style)
        // The canvas is captured one run-loop turn in, and the rail's chips
        // stagger in over several. Nothing here is a motion golden, so the
        // whole tree settles without animating.
        .transaction { $0.disablesAnimations = true }

        try assertGolden(name: name, colorScheme: .light, view)
        try assertGolden(name: name, colorScheme: .dark, view)
    }

    private func makeFixture(
        rung: String = "zones",
        focusedSection: Bool = false
    ) -> Fixture {
        var options = SeatLayerPickerOptions()
        options.layout = .phone
        options.enable3D = true
        options.chrome.phoneColorblind = true

        let controller = SeatLayerPickerController(
            transport: InertMapChromeTransport(),
            bundleInfo: BundleInfo([
                "bundle": "golden",
                "protocol": ["min": 2, "max": 2],
                "capabilities": .array([
                    "native-chrome-contract-v1",
                    "access-needs-v1",
                    "colorblind-safe",
                    "floor-stack-v1",
                    "venue-3d-v1",
                ].map(JSONValue.string)),
                "commands": .array([
                    "picker.setAccessibilityFilter",
                    "picker.setColorblindSafe",
                    "picker.setFloor",
                    "picker.showAllFloors",
                    "picker.setBuyerView",
                    "picker.overview",
                    "picker.zoomIn",
                    "picker.zoomOut",
                ].map(JSONValue.string)),
                "events": .array(["picker.snapshot"]),
            ]),
            revisionWaitNanoseconds: 1_000_000
        )
        controller.markReady(
            ReadyInfo([
                "protocol": 2,
                "mode": "test",
                "transport": "ios",
                "chart": ["event": "golden-event"],
            ]),
            payload: nil
        )
        controller.accept(
            snapshot: snapshot(rung: rung, focusedSection: focusedSection)
        )

        var style = SeatLayerPickerStyleEnvironment()
        style.options = options
        return Fixture(controller: controller, style: style)
    }

    private func snapshot(rung: String, focusedSection: Bool) -> JSONValue {
        var map: [String: JSONValue] = [
            "rung": .string(rung),
            "buyerView": "map",
            "atVenueFit": .bool(!focusedSection),
            "canZoomIn": .bool(!focusedSection),
            "canZoomOut": .bool(focusedSection),
            "colorblindSafe": false,
            "accessNeeds": .array([
                ["key": "step-free", "count": 12],
                ["key": "companion", "count": 4],
            ]),
            "accessibilityFilter": .array([]),
            "floorMode": "single",
            "activeFloorId": "stalls",
            "floors": .array([
                ["id": "stalls", "name": "Stalls"],
                ["id": "circle", "name": "Circle"],
            ]),
        ]
        if focusedSection { map["focusedSectionId"] = "section-a" }
        return [
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": "map-chrome-session",
            "revision": 1,
            "event": [
                "key": "golden-event",
                "name": "Opening Night",
                "currency": "EUR",
                "mode": "test",
            ],
            "features": [
                "accessibilityFilter": true,
                "venue3d": true,
            ],
            "map": .object(map),
            "sections": .array([
                ["id": "section-a", "label": "406", "seatsLeft": 32],
            ]),
            "catalog": [
                "categories": .array([
                    .object([
                        "key": "standard",
                        "label": "Standard",
                        "color": "#4C6FFF",
                        "price": 45,
                        "available": 240,
                    ]),
                    .object([
                        "key": "premium",
                        "label": "Premium",
                        "color": "#B4614F",
                        "priceMin": 95,
                        "priceMax": 180,
                        "available": 32,
                    ]),
                    .object([
                        "key": "restricted",
                        "label": "Restricted view",
                        "color": "#7A8699",
                        "price": 20,
                        "available": 0,
                    ]),
                ]),
            ],
            "hold": ["active": false],
        ]
    }
}

/// The goldens never mutate inventory; every command resolves to an empty
/// object so a stray call cannot hang a render.
private actor InertMapChromeTransport: SeatLayerPickerCommandTransport {
    func command(_ name: String, payload: JSONValue?) async throws -> JSONValue {
        .object([:])
    }
}
