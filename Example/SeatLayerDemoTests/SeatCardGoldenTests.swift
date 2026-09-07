import SwiftUI
import UIKit
import XCTest
@testable import SeatLayer

/// Rendered coverage of the seat card's five shapes: the plain question, the
/// one that offers a seat back, the one carrying a seat's own notes, the one
/// with a photograph of the view, and the one drawn inside the 3D venue.
///
/// The package unit suite runs on macOS, where the view files are not even
/// compiled, so these run in a simulator and compare a fixed phone canvas
/// against checked-in PNGs.
@available(iOS 16.0, *)
@MainActor
final class SeatCardGoldenTests: XCTestCase {
    func testAddCardGolden() throws {
        let fixture = makeFixture()
        XCTAssertNotNil(fixture.presentation.pendingSeat)
        try renderBothSchemes(named: "seat-card-add", fixture: fixture) {
            SeatLayerPickerSeatConfirmation()
        }
    }

    /// The same box, placement, grid and band; only the primary answer changes.
    func testRemoveCardGolden() throws {
        let fixture = makeFixture(confirmSelection: false)
        let seat = try XCTUnwrap(fixture.controller.snapshot?.selection.first)
        fixture.presentation.askAboutRemoving(seat)
        XCTAssertNil(fixture.presentation.pendingSeat)
        XCTAssertNotNil(fixture.presentation.candidateSeat)
        try renderBothSchemes(named: "seat-card-remove", fixture: fixture) {
            SeatLayerPickerSeatConfirmation()
        }
    }

    /// Full-bleed bands under the category band: an accommodation, restricted
    /// and obstructed each with a row of their own, premium, and the
    /// organizer's sentence hanging on the mark it explains.
    func testCardWithNotesGolden() throws {
        let fixture = makeFixture(notes: true)
        try renderBothSchemes(named: "seat-card-notes", fixture: fixture) {
            SeatLayerPickerSeatConfirmation()
        }
    }

    /// The photograph, the two pills that open it, and the sight line in the
    /// trailing top corner. With a strip there is no 3D square in the decision
    /// row.
    func testCardWithPhotographGolden() throws {
        let fixture = makeFixture(photograph: true)
        // Drawn once, here on the main actor, so the fetch itself is a plain
        // handover of bytes rather than a second rendering pass.
        let bytes = seatCardGoldenPhotograph()
        let loader = SeatLayerBuyerAssetLoader(
            eventKey: "golden-event",
            token: BuyerAccessToken(token: "golden"),
            fetch: { _, _ in bytes }
        )
        try renderBothSchemes(named: "seat-card-photo", fixture: fixture) {
            SeatLayerPickerSeatConfirmation()
                .environment(\.seatLayerBuyerAssetLoader, loader)
        }
    }

    /// Inside the scene the venue is already the picture, so the strip gives
    /// way to one compact inspection row and the card takes its own dimensions.
    func testCardInside3DGolden() throws {
        let fixture = makeFixture(photograph: true, immersive: true)
        try renderBothSchemes(named: "seat-card-3d", fixture: fixture) {
            SeatLayerPickerSeatConfirmation()
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
        confirmSelection: Bool = true,
        notes: Bool = false,
        photograph: Bool = false,
        immersive: Bool = false
    ) -> Fixture {
        var options = SeatLayerPickerOptions()
        options.confirmSelection = confirmSelection
        options.layout = .phone

        let controller = SeatLayerPickerController(
            transport: SeatCardInertTransport(),
            bundleInfo: BundleInfo([
                "bundle": "golden",
                "protocol": ["min": 2, "max": 2],
                "capabilities": .array([
                    "native-chrome-contract-v1",
                    "seat-view-v1",
                    "venue-3d-v1",
                    seatLayerSeatViewThumbnailCapability,
                    seatLayerScreenPointCapability,
                ].map(JSONValue.string)),
                "commands": .array([
                    "picker.openSeatView",
                    "picker.setBuyerView",
                    "picker.setSelectionFocus",
                    "picker.frameSeat",
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
        controller.accept(snapshot: snapshot(
            notes: notes,
            photograph: photograph,
            immersive: immersive
        ))

        var style = SeatLayerPickerStyleEnvironment()
        style.options = options
        return Fixture(controller: controller, presentation: presentation, style: style)
    }

    private func snapshot(
        notes: Bool,
        photograph: Bool,
        immersive: Bool
    ) -> JSONValue {
        var seat: [String: JSONValue] = [
            "id": "seat-1",
            "label": "A-11",
            "objectId": "row-a",
            "objectType": "seat",
            // Written with the section's own prefix, which the card strips.
            "rowLabel": "STL-A",
            "seatNumber": "11",
            "sectionLabel": "Stalls",
            "categoryKey": "standard",
            "currency": "EUR",
            "price": 45,
            "screenPoint": ["x": 172, "y": 260],
        ]
        if notes {
            seat["accessibility"] = .array(["step-free"])
            seat["commercial"] = [
                "restrictedView": true,
                "obstructedView": true,
                "premium": true,
                "note": "A handrail crosses the lower third of the view.",
            ]
        }
        if photograph {
            seat["seatViewThumb"] = [
                "reference": "/pub/events/golden-event/assets/seat-a11.png",
                "kind": "real",
            ]
            seat["sightlineMetres"] = 24
            seat["seatViewConfidence"] = [
                "headline": "Modelled from the venue plan",
                "modeledTarget": "Row A, eye height 1.2 m",
            ]
        }
        let seats: [JSONValue] = [.object(seat)]
        let items: [JSONValue] = [
            .object([
                "lineKey": "line-1",
                "label": "A-11",
                "objectId": "row-a",
                "objectType": "seat",
                "categoryKey": "standard",
                "unitPrice": 45,
                "currency": "EUR",
                "quantity": 1,
                "seatId": "seat-1",
            ]),
        ]
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
            "features": ["seatView": true, "venue3d": true],
            "map": [
                "rung": .string(immersive ? "seats" : "zones"),
                "buyerView": .string(immersive ? "venue3d" : "map"),
                "accessNeeds": .array([]),
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
                ]),
            ],
            "selection": [
                "seats": .array(seats),
                "validity": [
                    "isValid": true,
                    "count": 1,
                    "required": 1,
                    "remaining": 0,
                    "seats": .array(seats),
                    "violations": .array([]),
                ],
            ],
            "cart": [
                "currency": "EUR",
                "quantity": 1,
                "total": 45,
                "items": .array(items),
            ],
            "hold": ["active": false],
        ]
    }
}

/// A deterministic stand-in for an authored seat photograph: a gradient with a
/// horizon, so a golden shows the strip's crop and its pills rather than a flat
/// colour that could equally be the loading gradient.
@MainActor
private func seatCardGoldenPhotograph() -> Data {
    let size = CGSize(width: 640, height: 200)
    let image = UIGraphicsImageRenderer(size: size).image { context in
        let colors = [
            UIColor(red: 0.16, green: 0.20, blue: 0.34, alpha: 1).cgColor,
            UIColor(red: 0.62, green: 0.48, blue: 0.38, alpha: 1).cgColor,
        ] as CFArray
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) {
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
        UIColor(white: 0.92, alpha: 0.9).setFill()
        context.fill(CGRect(x: 0, y: size.height * 0.55, width: size.width, height: 3))
    }
    return image.pngData() ?? Data()
}

/// The goldens never mutate inventory; every command resolves to an empty
/// object so a stray call cannot hang a render.
private actor SeatCardInertTransport: SeatLayerPickerCommandTransport {
    func command(_ name: String, payload: JSONValue?) async throws -> JSONValue {
        .object([:])
    }
}
