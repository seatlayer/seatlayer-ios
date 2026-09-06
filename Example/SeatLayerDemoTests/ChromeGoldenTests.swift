import SwiftUI
import XCTest
@testable import SeatLayer

/// First rendered coverage of the picker chrome. The package unit suite runs on
/// macOS, where the view files are not even compiled, so these run in a
/// simulator and compare a fixed phone canvas against checked-in PNGs.
@available(iOS 16.0, *)
@MainActor
final class ChromeGoldenTests: XCTestCase {
    func testHeaderGolden() throws {
        let fixture = makeFixture()
        try renderBothSchemes(named: "header", fixture: fixture) {
            VStack {
                SeatLayerPickerHeader(onClose: {}, compact: true)
                Spacer()
            }
        }
    }

    func testConfirmCardGolden() throws {
        let fixture = makeFixture(confirmSelection: true)
        XCTAssertNotNil(fixture.presentation.pendingSeat)
        try renderBothSchemes(named: "confirm-card", fixture: fixture) {
            SeatLayerPickerSeatConfirmation()
        }
    }

    func testCartSheetCollapsedGolden() throws {
        let fixture = makeFixture(seatCount: 3)
        fixture.presentation.sheetDetent = .peek
        try renderBothSchemes(named: "cart-sheet-collapsed", fixture: fixture) {
            VStack {
                Spacer()
                SeatLayerPickerCartSheet(onCheckout: { _ in })
            }
        }
    }

    func testCartSheetCollapsedEmptyGolden() throws {
        let fixture = makeFixture(seatCount: 0)
        fixture.presentation.sheetDetent = .peek
        try renderBothSchemes(named: "cart-sheet-collapsed-empty", fixture: fixture) {
            VStack {
                Spacer()
                SeatLayerPickerCartSheet(onCheckout: { _ in })
            }
        }
    }

    func testCartSheetExpandedGolden() throws {
        // Four cards against a three-card cap: the fourth is the sliver that
        // tells the buyer the region scrolls.
        let fixture = makeFixture(seatCount: 4)
        fixture.presentation.sheetDetent = .open
        try renderBothSchemes(named: "cart-sheet-expanded", fixture: fixture) {
            VStack {
                Spacer()
                SeatLayerPickerCartSheet(onCheckout: { _ in })
            }
        }
    }

    func testBestSeatsFormGolden() throws {
        let fixture = makeFixture(seatCount: 0)
        try renderBothSchemes(named: "best-seats-form", fixture: fixture) {
            VStack {
                Spacer()
                SeatLayerBestSeatsForm().padding(14)
            }
        }
    }

    func testToastGolden() throws {
        let fixture = makeFixture(seatCount: 2)
        let queue = seatLayerPickerToasts(for: fixture.controller)
        queue.show(
            SeatLayerPickerToast(
                fixture.style.strings.text(.seatsJustTaken),
                tone: .error,
                actionLabel: fixture.style.strings.text(.reselectSeatsOther),
                id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!
            )
        )
        try renderBothSchemes(named: "toast", fixture: fixture) {
            SeatLayerPickerToastBandBody(
                queue: queue,
                bottomInset: 0,
                lifted: false
            )
        }
    }

    func testMapControlsColumnGolden() throws {
        let fixture = makeFixture()
        try renderBothSchemes(named: "map-controls", fixture: fixture) {
            SeatLayerPickerMapControls()
        }
    }

    func testAccessibilityPanelGolden() throws {
        let fixture = makeFixture()
        try renderBothSchemes(named: "accessibility-panel", fixture: fixture) {
            SeatLayerPickerAccessibilityFilters()
        }
    }

    // MARK: - Harness

    struct Fixture {
        let controller: SeatLayerPickerController
        let presentation: SeatLayerPickerPresentationModel
        let style: SeatLayerPickerStyleEnvironment
    }

    private func renderBothSchemes<Content: View>(
        named name: String,
        fixture: Fixture,
        @ViewBuilder content: () -> Content
    ) throws {
        let view = content()
            .environmentObject(fixture.controller)
            .environmentObject(fixture.presentation)
            .environment(\.seatLayerPickerStyle, fixture.style)
        try assertGolden(name: name, colorScheme: .light, view)
        try assertGolden(name: name, colorScheme: .dark, view)
    }

    private func makeFixture(
        confirmSelection: Bool = false,
        seatCount: Int = 2
    ) -> Fixture {
        var options = SeatLayerPickerOptions()
        options.confirmSelection = confirmSelection
        options.enableBestAvailable = true
        options.layout = .phone
        // The map control column is otherwise a single disc on a phone.
        options.chrome.phoneOverview = true
        options.chrome.phoneZoom = true
        options.chrome.phoneColorblind = true

        let controller = SeatLayerPickerController(
            transport: InertTransport(),
            bundleInfo: BundleInfo([
                "bundle": "golden",
                "protocol": ["min": 2, "max": 2],
                "capabilities": .array([
                    "native-chrome-contract-v1",
                    "access-needs-v1",
                    "colorblind-safe",
                    "viewport-insets-v1",
                ].map(JSONValue.string)),
                "commands": .array([
                    "picker.setAccessibilityFilter",
                    "picker.setLimitedViewFilter",
                    "picker.setColorblindSafe",
                    "picker.setViewportInsets",
                    "picker.zoomIn",
                    "picker.zoomOut",
                    "picker.zoomToFit",
                    "picker.bestAvailable",
                ].map(JSONValue.string)),
                "events": .array(["picker.snapshot"]),
            ]),
            revisionWaitNanoseconds: 1_000_000
        )
        controller.markReady(
            ReadyInfo([
                "protocol": 2,
                "mode": "live",
                "transport": "ios",
                "chart": ["event": "golden-event"],
            ]),
            payload: nil
        )
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: options
        )
        controller.accept(snapshot: goldenSnapshot(seatCount: seatCount))

        var style = SeatLayerPickerStyleEnvironment()
        style.options = options
        return Fixture(controller: controller, presentation: presentation, style: style)
    }

    private func goldenSnapshot(seatCount: Int = 2) -> JSONValue {
        let labels = (0..<seatCount).map { "A-\($0 + 11)" }
        let seats: [JSONValue] = labels.enumerated().map { index, label in
            .object([
                "id": .string("seat-\(index + 1)"),
                "label": .string(label),
                "objectId": "row-a",
                "objectType": "seat",
                "rowLabel": "A",
                "seatNumber": .string("\(index + 11)"),
                "sectionLabel": "Stalls",
                "categoryKey": "standard",
                "currency": "EUR",
                "price": 45,
            ])
        }
        let items: [JSONValue] = labels.enumerated().map { index, label in
            .object([
                "lineKey": .string("line-\(index + 1)"),
                "label": .string(label),
                "objectId": "row-a",
                "objectType": "seat",
                "categoryKey": "standard",
                "unitPrice": 45,
                "currency": "EUR",
                "quantity": 1,
                "seatId": .string("seat-\(index + 1)"),
                "sectionLabel": "Stalls",
                "rowLabel": "A",
                "seatNumber": .string("\(index + 11)"),
            ])
        }
        return [
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": "golden-session",
            "revision": 1,
            "event": [
                "key": "golden-event",
                "name": "Opening Night",
                "currency": "EUR",
                "mode": "live",
            ],
            "features": ["accessibilityFilter": true, "limitedViewFilter": true],
            "map": [
                "rung": "zones",
                "buyerView": "map",
                "accessNeeds": .array([
                    ["key": "step-free", "count": 12],
                    ["key": "companion", "count": 4],
                ]),
                "accessibilityFilter": .array([]),
                "hideLimitedView": false,
                "colorblindSafe": false,
            ],
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
                        "price": 95,
                        "available": 32,
                    ]),
                ]),
            ],
            "selection": [
                "seats": .array(seats),
                "validity": [
                    "isValid": true,
                    "count": .int(labels.count),
                    "required": .int(labels.count),
                    "remaining": 0,
                    "seats": .array(seats),
                    "violations": .array([]),
                ],
            ],
            "cart": [
                "currency": "EUR",
                "quantity": .int(labels.count),
                "total": .double(Double(labels.count) * 45),
                "items": .array(items),
            ],
            "hold": ["active": false],
        ]
    }
}

/// The goldens never mutate inventory; every command resolves to an empty
/// object so a stray call cannot hang a render.
private actor InertTransport: SeatLayerPickerCommandTransport {
    func command(_ name: String, payload: JSONValue?) async throws -> JSONValue {
        .object([:])
    }
}
