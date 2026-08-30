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

    func testTierMutationPrecedesLocalConfirmationAndUpdatesCartTruth() async throws {
        let tiers: [JSONValue] = [
            ["id": "adult", "name": "Adult", "price": 100, "currency": "EUR"],
            ["id": "child", "name": "Child", "price": 60, "currency": "EUR"],
        ]
        let transport = PresentationTransportSpy(
            responses: [
                "picker.setSeatTier": ["snapshot": snapshot(
                    revision: 2,
                    labels: ["G-1"],
                    seatPrice: 60,
                    tierId: "child",
                    tiers: tiers
                )],
            ]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.setSeatTier"]
        )
        let presentation = SeatLayerPickerPresentationModel(controller: controller)
        controller.accept(snapshot: snapshot(
            revision: 1,
            labels: ["G-1"],
            seatPrice: 100,
            tierId: "adult",
            tiers: tiers
        ))

        XCTAssertEqual(presentation.pendingSeat?.tierId, "adult")
        let confirmed = await presentation.confirmPending(tierId: "child")
        XCTAssertTrue(confirmed)
        XCTAssertNil(presentation.pendingSeat)
        XCTAssertEqual(presentation.confirmedCartLines.first?.tierId, "child")
        XCTAssertEqual(presentation.confirmedCartLines.first?.unitPrice, 60)
        XCTAssertEqual(presentation.selectionFlight?.seatId, "seat-1")
        XCTAssertEqual(presentation.selectionFlight?.label, "G-1")

        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), ["picker.setSeatTier"])
        XCTAssertEqual(calls.first?.payload, ["seatId": "seat-1", "tierId": "child"])
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

    func testBackConsumesPromptCartConfirmation3DTargetOverviewThenHost() async {
        let targetedMap: [String: JSONValue] = [
            "view3dTargetSeatId": "seat-1",
            "view3dPreviousSeatId": .null,
            "view3dNextSeatId": .null,
            "view3dFocusedSectionId": "section-a",
        ]
        let overviewMap: [String: JSONValue] = [
            "view3dPreviousSeatId": .null,
            "view3dNextSeatId": .null,
            "view3dFocusedSectionId": .null,
        ]
        let transport = PresentationTransportSpy(
            responses: [
                "picker.deselectObjects": ["snapshot": snapshot(
                    revision: 5,
                    labels: [],
                    buyerView: "map"
                )],
                "picker.abort": ["snapshot": snapshot(revision: 6, labels: [])],
            ],
            responseSequences: [
                "picker.setBuyerView": [
                    ["snapshot": snapshot(
                        revision: 3,
                        labels: ["A-1"],
                        buyerView: "venue3d",
                        mapAdditions: overviewMap
                    )],
                    ["snapshot": snapshot(revision: 4, labels: ["A-1"])],
                ],
            ]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.deselectObjects", "picker.setBuyerView", "picker.abort"],
            capabilities: ["venue-3d-v1"]
        )
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(panelInitiallyCollapsed: false)
        )
        controller.accept(snapshot: snapshot(
            revision: 1,
            labels: ["A-1"],
            buyerView: "venue3d",
            mapAdditions: targetedMap
        ))
        controller.accept(generalAdmissionCandidate: GAArea(id: "ga-1", label: "Standing"))

        var steps: [SeatLayerPickerBackStep] = []
        steps.append(await presentation.back())
        steps.append(await presentation.back())
        steps.append(await presentation.back())
        XCTAssertEqual(presentation.pendingSeat?.label, "A-1")
        steps.append(await presentation.back())
        XCTAssertEqual(presentation.pendingSeat?.label, "A-1")
        steps.append(await presentation.back())
        XCTAssertNil(presentation.pendingSeat)
        var hostCloseCount = 0
        steps.append(await presentation.back { hostCloseCount += 1 })

        XCTAssertEqual(steps, [.prompt, .cart, .venue, .venue, .confirmation, .close])
        XCTAssertEqual(hostCloseCount, 1)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), [
            "picker.setBuyerView", "picker.setBuyerView", "picker.deselectObjects", "picker.abort",
        ])
        XCTAssertEqual(calls[0].payload, ["view": "venue3d", "resetView": true])
        XCTAssertEqual(calls[1].payload, ["view": "map"])
        XCTAssertEqual(calls[2].payload, ["objects": ["A-1"]])
    }

    func testBackWalksOne2DMapRungAtATime() async {
        let transport = PresentationTransportSpy(
            responses: ["picker.abort": ["snapshot": snapshot(revision: 4, labels: [])]],
            responseSequences: [
                "picker.zoomOut": [
                    ["snapshot": snapshot(revision: 2, labels: [], rung: "sections")],
                    ["snapshot": snapshot(revision: 3, labels: [], rung: "zones")],
                ],
            ]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.zoomOut", "picker.abort"]
        )
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false, panelInitiallyCollapsed: true)
        )
        controller.accept(snapshot: snapshot(
            revision: 1,
            labels: [],
            focused: true,
            rung: "seats"
        ))

        var hostCloseCount = 0
        let steps = [
            await presentation.back(),
            await presentation.back(),
            await presentation.back { hostCloseCount += 1 },
        ]

        XCTAssertEqual(steps, [.section, .section, .close])
        XCTAssertEqual(hostCloseCount, 1)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), ["picker.zoomOut", "picker.zoomOut", "picker.abort"])
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
        buyerView: String = "map",
        rung: String = "zones",
        mapAdditions: [String: JSONValue] = [:],
        seatPrice: Int = 25,
        tierId: String? = nil,
        tiers: [JSONValue]? = nil
    ) -> JSONValue {
        let seats: [JSONValue] = labels.enumerated().map { index, label in
            var seat: [String: JSONValue] = [
                "id": .string("seat-\(index + 1)"),
                "label": .string(label),
                "objectId": .string("row-a"),
                "objectType": .string("seat"),
                "currency": .string("EUR"),
                "price": .int(seatPrice),
            ]
            if let tierId { seat["tierId"] = .string(tierId) }
            if let tiers { seat["tiers"] = .array(tiers) }
            return .object(seat)
        }
        let items: [JSONValue] = labels.enumerated().map { index, label in
            var item: [String: JSONValue] = [
                "lineKey": .string("line-\(index + 1)"),
                "label": .string(label),
                "objectId": .string("row-a"),
                "objectType": .string("seat"),
                "categoryKey": .string("standard"),
                "unitPrice": .int(seatPrice),
                "currency": .string("EUR"),
                "quantity": .int(1),
                "seatId": .string("seat-\(index + 1)"),
            ]
            if let tierId { item["tierId"] = .string(tierId) }
            return .object(item)
        }
        var map: [String: JSONValue] = [
            "rung": .string(rung),
            "buyerView": .string(buyerView),
        ]
        if focused { map["focusedSectionId"] = .string("section-a") }
        map.merge(mapAdditions) { _, value in value }
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
            "map": .object(map),
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
                "total": .int(labels.count * seatPrice),
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
    private let responseSequences: [String: [JSONValue]]
    private var responseOffsets: [String: Int] = [:]
    private let delayNanoseconds: UInt64

    init(
        responses: [String: JSONValue] = [:],
        responseSequences: [String: [JSONValue]] = [:],
        delayNanoseconds: UInt64 = 0
    ) {
        self.responses = responses
        self.responseSequences = responseSequences
        self.delayNanoseconds = delayNanoseconds
    }

    func command(_ name: String, payload: JSONValue?) async throws -> JSONValue {
        calls.append(.init(name: name, payload: payload))
        if delayNanoseconds > 0 { try await Task.sleep(nanoseconds: delayNanoseconds) }
        if let sequence = responseSequences[name] {
            let offset = responseOffsets[name, default: 0]
            if offset < sequence.count {
                responseOffsets[name] = offset + 1
                return sequence[offset]
            }
        }
        return responses[name] ?? [:]
    }

    func recordedCalls() -> [Call] { calls }
}
