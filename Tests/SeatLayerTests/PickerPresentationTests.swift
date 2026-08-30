import XCTest
@testable import SeatLayer

@MainActor
final class PickerPresentationTests: XCTestCase {
    func testNewestUnansweredSeatIsExcludedUntilLocalConfirmation() throws {
        let transport = PresentationTransportSpy()
        let controller = readyController(transport: transport, commands: [])
        let presentation = SeatLayerPickerPresentationModel(controller: controller)

        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))
        XCTAssertEqual(presentation.pendingSeat?.label, "A-1")
        presentation.confirmPending()
        XCTAssertNil(presentation.pendingSeat)

        controller.accept(snapshot: snapshot(revision: 2, labels: ["A-1", "A-2"]))
        XCTAssertEqual(presentation.pendingSeat?.label, "A-2")
        XCTAssertEqual(presentation.confirmedCartLines.map(\.label), ["A-1"])
        XCTAssertFalse(presentation.canCheckout)

        presentation.confirmPending()
        XCTAssertNil(presentation.pendingSeat)
        XCTAssertEqual(presentation.confirmedCartLines.map(\.label), ["A-1", "A-2"])
        XCTAssertTrue(presentation.canCheckout)
    }

    func testPresentationCheckoutIsSingleFlightThroughTheHostCallback() async throws {
        let transport = PresentationTransportSpy(
            responses: ["picker.continue": checkoutResponse()],
            delayNanoseconds: 30_000_000
        )
        let controller = readyController(transport: transport, commands: ["picker.continue"])
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false)
        )
        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))
        XCTAssertTrue(presentation.canCheckout)

        var callbackCount = 0
        let handler: SeatLayerPickerCheckoutHandler = { _ in
            callbackCount += 1
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        async let first = presentation.checkout(using: handler)
        async let second = presentation.checkout(using: handler)
        let handoffs = try await [first, second]
        let calls = await transport.recordedCalls()

        XCTAssertEqual(handoffs.map(\.holdId), ["opaque-test-hold", "opaque-test-hold"])
        XCTAssertEqual(callbackCount, 1)
        XCTAssertEqual(calls.map(\.name), ["picker.continue"])
        XCTAssertEqual(presentation.checkoutHandoff?.holdId, "opaque-test-hold")
        XCTAssertFalse(presentation.canCheckout)
    }

    func testHostRejectionReleasesTheExactHandoffAndDoesNotRetainIt() async {
        let transport = PresentationTransportSpy(
            responses: [
                "picker.continue": checkoutResponse(),
                "picker.rejectHandoff": [:],
            ]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.continue", "picker.rejectHandoff"]
        )
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false)
        )
        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))

        do {
            _ = try await presentation.checkout { _ in throw HostDeclinedCheckout.example }
            XCTFail("expected the host rejection to surface")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, "sl_transport")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        XCTAssertNil(presentation.checkoutHandoff)
        XCTAssertFalse(presentation.actionInFlight)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), ["picker.continue", "picker.rejectHandoff"])
        XCTAssertEqual(calls.last?.payload, ["holdId": "opaque-test-hold"])
    }

    func testBackConsumesPromptCartConfirmationSectionVenueThenHost() async {
        let transport = PresentationTransportSpy(responses: [
            "picker.deselectObjects": ["snapshot": snapshot(revision: 2, labels: [], focused: true, buyerView: "venue3d")],
            "picker.overview": ["snapshot": snapshot(revision: 3, labels: [], focused: false, buyerView: "venue3d")],
            "picker.setBuyerView": ["snapshot": snapshot(revision: 4, labels: [], focused: false, buyerView: "map")],
            "picker.abort": ["snapshot": snapshot(revision: 5, labels: [], focused: false, buyerView: "map")],
        ])
        let controller = readyController(
            transport: transport,
            commands: ["picker.deselectObjects", "picker.overview", "picker.setBuyerView", "picker.abort"],
            capabilities: ["venue-3d-v1"]
        )
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(panelInitiallyCollapsed: false)
        )
        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"], focused: true, buyerView: "venue3d"))
        controller.accept(generalAdmissionCandidate: GAArea(id: "ga-1", label: "Standing"))

        var steps: [SeatLayerPickerBackStep] = []
        steps.append(await presentation.back())
        steps.append(await presentation.back())
        steps.append(await presentation.back())
        steps.append(await presentation.back())
        steps.append(await presentation.back())
        var hostCloseCount = 0
        steps.append(await presentation.back { hostCloseCount += 1 })

        XCTAssertEqual(steps, [.prompt, .cart, .confirmation, .section, .venue, .close])
        XCTAssertEqual(hostCloseCount, 1)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), [
            "picker.deselectObjects", "picker.overview", "picker.setBuyerView", "picker.abort",
        ])
        XCTAssertEqual(calls[0].payload, ["objects": ["A-1"]])
        XCTAssertEqual(calls[2].payload, ["view": "map"])
    }

    private func readyController(
        transport: PresentationTransportSpy,
        commands: [String],
        capabilities: [String] = []
    ) -> SeatLayerPickerController {
        let controller = SeatLayerPickerController(
            transport: transport,
            bundleInfo: BundleInfo([
                "bundle": "0.71.5",
                "protocol": ["min": 2, "max": 2],
                "capabilities": .array(capabilities.map(JSONValue.string)),
                "commands": .array(commands.map(JSONValue.string)),
                "events": .array(["picker.snapshot"]),
            ]),
            revisionWaitNanoseconds: 20_000_000
        )
        controller.markReady(
            ReadyInfo([
                "protocol": 2,
                "mode": "test",
                "transport": "ios",
                "chart": ["event": "event-test"],
            ]),
            payload: nil
        )
        return controller
    }

    private func snapshot(
        revision: Int,
        labels: [String],
        focused: Bool = false,
        buyerView: String = "map"
    ) -> JSONValue {
        let seats: [JSONValue] = labels.enumerated().map { index, label in
            [
                "id": .string("seat-\(index + 1)"),
                "label": .string(label),
                "objectId": .string("row-a"),
                "objectType": .string("seat"),
                "currency": .string("EUR"),
                "price": .int(25),
            ]
        }
        let items: [JSONValue] = labels.enumerated().map { index, label in
            [
                "lineKey": .string("line-\(index + 1)"),
                "label": .string(label),
                "objectId": .string("row-a"),
                "objectType": .string("seat"),
                "categoryKey": .string("standard"),
                "unitPrice": .int(25),
                "currency": .string("EUR"),
                "quantity": .int(1),
                "seatId": .string("seat-\(index + 1)"),
            ]
        }
        return [
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": "session-test",
            "revision": .int(revision),
            "event": [
                "key": "event-test",
                "name": "Opening Night",
                "mode": "test",
                "currency": "EUR",
            ],
            "features": ["venue3d": true],
            "map": .object(compacting: [
                "rung": .string("zones"),
                "buyerView": .string(buyerView),
                "focusedSectionId": focused ? .string("section-a") : nil,
            ]),
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
                "total": .int(labels.count * 25),
                "items": .array(items),
            ],
            "hold": ["active": false],
        ]
    }

    private func checkoutResponse() -> JSONValue {
        [
            "handoff": [
                "holdId": "opaque-test-hold",
                "expiresAt": 1_800_000_000_000,
                "currency": "EUR",
                "lineItems": .array([]),
                "total": 25,
            ],
        ]
    }
}

private enum HostDeclinedCheckout: Error {
    case example
}

private actor PresentationTransportSpy: SeatLayerPickerCommandTransport {
    struct Call: Sendable, Equatable {
        let name: String
        let payload: JSONValue?
    }

    private var calls: [Call] = []
    private let responses: [String: JSONValue]
    private let delayNanoseconds: UInt64

    init(responses: [String: JSONValue] = [:], delayNanoseconds: UInt64 = 0) {
        self.responses = responses
        self.delayNanoseconds = delayNanoseconds
    }

    func command(_ name: String, payload: JSONValue?) async throws -> JSONValue {
        calls.append(.init(name: name, payload: payload))
        if delayNanoseconds > 0 { try await Task.sleep(nanoseconds: delayNanoseconds) }
        return responses[name] ?? [:]
    }

    func recordedCalls() -> [Call] { calls }
}
