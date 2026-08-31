import Combine
import XCTest
@testable import SeatLayer

@MainActor
final class PickerControllerTests: XCTestCase {
    func testMutationUsesThePickerContractAndPublishesReturnedSnapshot() async throws {
        let response: JSONValue = ["snapshot": pickerSnapshot(revision: 2)]
        let transport = PickerTransportSpy(responses: [
            "picker.setCategoryFilter": response,
            "picker.setViewportInsets": [:],
            "picker.setThemeMode": [:],
        ])
        let controller = readyController(
            transport: transport,
            commands: [
                "picker.setCategoryFilter",
                "picker.setViewportInsets",
                "picker.setThemeMode",
            ],
            capabilities: ["viewport-insets-v1", "native-chrome-contract-v1"]
        )

        let snapshot = try await controller.setCategoryFilter([], focus: true)
        try await controller.setViewportInsets(.init(top: 44, bottom: 72))
        try await controller.setThemeMode(
            .dark,
            mapTheme: .init(background: "#101820", textColor: "#F2F4F8")
        )

        XCTAssertEqual(snapshot?.revision, 2)
        XCTAssertEqual(controller.snapshot?.revision, 2)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [
            .init(
                name: "picker.setCategoryFilter",
                payload: ["categoryKeys": .null, "focus": true]
            ),
            .init(
                name: "picker.setViewportInsets",
                payload: [
                    "top": .double(44),
                    "right": .double(0),
                    "bottom": .double(72),
                    "left": .double(0),
                ]
            ),
            .init(
                name: "picker.setThemeMode",
                payload: [
                    "mode": "dark",
                    "mapTheme": ["background": "#101820", "textColor": "#F2F4F8"],
                ]
            ),
        ])
    }

    func testUnsupportedCommandFailsBeforeItReachesTheTransport() async {
        let transport = PickerTransportSpy()
        let controller = readyController(
            transport: transport,
            commands: ["picker.getSnapshot"]
        )

        do {
            _ = try await controller.focusSection("section-a")
            XCTFail("expected unsupported command")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, BridgeErrorCode.unsupportedCommand)
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [])
    }

    func testControllerKeepsSnapshotSessionAndRevisionOrdering() {
        let transport = PickerTransportSpy()
        let controller = readyController(transport: transport, commands: [])

        controller.accept(snapshot: pickerSnapshot(revision: 3))
        controller.accept(snapshot: pickerSnapshot(revision: 2))
        controller.accept(snapshot: pickerSnapshot(sessionId: "foreign", revision: 4))
        controller.accept(snapshot: pickerSnapshot(revision: 5))

        XCTAssertEqual(controller.snapshot?.sessionId, "session-1")
        XCTAssertEqual(controller.snapshot?.revision, 5)
    }

    func testConcurrentCheckoutCallsShareOneHandoffCommand() async throws {
        let transport = PickerTransportSpy(
            responses: [
                "picker.continue": [
                    "handoff": [
                        "holdId": "hold-private",
                        "expiresAt": .double(1_800_000_000_000),
                        "currency": "EUR",
                        "lineItems": .array([]),
                        "total": 0,
                    ],
                ],
            ],
            delayNanoseconds: 30_000_000
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.continue"]
        )

        async let first: SeatLayerPickerCheckoutHandoff = controller.checkout()
        async let second: SeatLayerPickerCheckoutHandoff = controller.checkout()
        let handoffs = try await [first, second]
        let calls = await transport.recordedCalls()

        XCTAssertEqual(handoffs.map { $0.holdId }, ["hold-private", "hold-private"])
        XCTAssertEqual(calls.map { $0.name }, ["picker.continue"])
    }

    func testInvalidArgumentsFailWithoutSendingACommand() async {
        let transport = PickerTransportSpy()
        let controller = readyController(
            transport: transport,
            commands: ["picker.setRung", "picker.setViewportInsets"],
            capabilities: ["viewport-insets-v1"]
        )

        do {
            _ = try await controller.setRung("overview")
            XCTFail("expected bad payload")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, BridgeErrorCode.badPayload)
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        do {
            try await controller.setViewportInsets(.init(top: -.infinity))
            XCTFail("expected bad payload")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, BridgeErrorCode.badPayload)
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [])
    }

    func testConcurrentAvailabilityRefreshSharesOneCommandAndRecordsLapse() async {
        let transport = PickerTransportSpy(
            responses: [
                "picker.refreshAvailability": [
                    "outcome": [
                        "refreshed": true,
                        "lost": .array(["A-1"]),
                        "holdLapsed": true,
                        "lapsedLabels": .array(["A-2", "A-3"]),
                        "recoverableLabels": .array(["A-3"]),
                    ],
                ],
            ],
            delayNanoseconds: 30_000_000
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.refreshAvailability"],
            capabilities: ["availability-refresh-v1"]
        )

        async let first = controller.refreshAvailability()
        async let second = controller.refreshAvailability()
        let results = await [first, second]

        XCTAssertEqual(results.compactMap { $0?.outcome }.count, 2)
        XCTAssertEqual(controller.holdLapse?.recovery, .partial)
        XCTAssertEqual(controller.holdLapse?.recoverableLabels, ["A-3"])
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), ["picker.refreshAvailability"])
    }

    func testOptionalRefreshAndHoldSelectionDoNotSendWhenUnsupported() async throws {
        let transport = PickerTransportSpy()
        let controller = readyController(transport: transport, commands: [])

        let refresh = await controller.refreshAvailability()
        let hold = try await controller.holdSelection(ttlMs: 120_000)
        XCTAssertNil(refresh)
        XCTAssertNil(hold)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [])
    }

    func testHoldSelectionValidatesAndSendsConfiguredTTLWhenSupported() async throws {
        let transport = PickerTransportSpy(responses: [
            "picker.holdSelection": ["snapshot": pickerSnapshot(revision: 2)],
        ])
        let controller = readyController(
            transport: transport,
            commands: ["picker.holdSelection"],
            capabilities: ["hold-selection-v1"]
        )

        let snapshot = try await controller.holdSelection(ttlMs: 120_000)

        XCTAssertEqual(snapshot?.revision, 2)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [
            .init(name: "picker.holdSelection", payload: ["ttlMs": 120_000]),
        ])
    }

    func testLifecycleNormalizesForegroundAndKeepsTheReturnedLapseOutcome() async throws {
        let transport = PickerTransportSpy(responses: [
            "picker.lifecycle": [
                "outcome": [
                    "refreshed": true,
                    "holdLapsed": true,
                    "lapsedLabels": .array(["A-1"]),
                    "recoverableLabels": .array(["A-1"]),
                ],
            ],
        ])
        let controller = readyController(
            transport: transport,
            commands: ["picker.lifecycle"]
        )

        let result = try await controller.lifecycle("resumed")

        XCTAssertEqual(result?.outcome?.lapsedLabels, ["A-1"])
        XCTAssertEqual(controller.holdLapse?.recovery, .all)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [
            .init(name: "picker.lifecycle", payload: ["state": "foreground"]),
        ])
    }

    func testLifecycleRejectsAnUnknownStateBeforeTransport() async {
        let transport = PickerTransportSpy()
        let controller = readyController(
            transport: transport,
            commands: ["picker.lifecycle"]
        )

        do {
            _ = try await controller.lifecycle("inactive")
            XCTFail("expected bad payload")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, BridgeErrorCode.badPayload)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        let calls = await transport.recordedCalls()
        XCTAssertTrue(calls.isEmpty)
    }

    func testReadyHostLifecyclePolicyReconcilesForegroundAfterTheLifecycleReply() async {
        let transport = PickerTransportSpy(responses: [
            "picker.lifecycle": [
                "outcome": [
                    "refreshed": true,
                    "holdLapsed": true,
                    "lapsedLabels": .array(["A-1"]),
                    "recoverableLabels": .array(["A-1"]),
                ],
            ],
            "picker.getSnapshot": ["snapshot": pickerSnapshot(revision: 2)],
        ])
        let controller = readyController(
            transport: transport,
            commands: ["picker.lifecycle", "picker.getSnapshot"]
        )

        await controller.reconcileApplicationLifecycle(
            foreground: true,
            refreshOnResume: true
        )

        XCTAssertEqual(controller.holdLapse?.lapsedLabels, ["A-1"])
        XCTAssertEqual(controller.snapshot?.revision, 2)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [
            .init(name: "picker.lifecycle", payload: ["state": "foreground"]),
            .init(name: "picker.getSnapshot", payload: nil),
        ])
    }

    func testAccessibilityDraftSendsIndependentChangesThenFocusesSeats() async throws {
        let transport = PickerTransportSpy()
        let controller = readyController(
            transport: transport,
            commands: [
                "picker.setAccessibilityFilter",
                "picker.setLimitedViewFilter",
                "picker.setColorblindSafe",
                "picker.setRung",
            ],
            capabilities: [
                "native-chrome-contract-v1", "access-needs-v1", "colorblind-safe",
            ]
        )
        controller.accept(snapshot: [
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": "session-1",
            "revision": 1,
            "event": ["key": "ev_picker", "currency": "EUR"],
            "features": [
                "accessibilityFilter": true,
                "limitedViewFilter": true,
            ],
            "map": [
                "rung": "zones",
                "accessibilityFilter": .array(["step-free"]),
                "accessNeeds": .array([
                    ["key": "step-free", "count": 12],
                    ["key": "companion", "count": 4],
                ]),
                "hideLimitedView": false,
                "colorblindSafe": false,
            ],
        ])
        let initial = SeatLayerPickerAccessibility.draft(from: controller.snapshot)
        let draft = SeatLayerPickerAccessibilityDraft(
            types: ["companion"],
            hideLimitedView: true,
            colorblindSafe: true
        )

        let applied = try await controller.applyAccessibilityFilters(draft, from: initial)
        XCTAssertTrue(applied)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [
            .init(
                name: "picker.setAccessibilityFilter",
                payload: ["types": .array(["companion"])]
            ),
            .init(name: "picker.setLimitedViewFilter", payload: ["on": true]),
            .init(name: "picker.setColorblindSafe", payload: ["on": true]),
            .init(name: "picker.setRung", payload: ["rung": "seats"]),
        ])
    }

    func testSupersededRuntimeCannotPublishOrDestroyTheCurrentSession() {
        let controller = SeatLayerPickerController()
        let firstOwner = UUID()
        let secondOwner = UUID()
        let transport = PickerTransportSpy()
        let bundle = BundleInfo([
            "bundle": "0.71.5",
            "protocol": ["min": 2, "max": 2],
            "capabilities": .array([]),
            "commands": .array([]),
            "events": .array(["picker.snapshot"]),
        ])
        let ready = ReadyInfo([
            "protocol": 2,
            "mode": "live",
            "transport": "ios",
            "chart": ["event": "ev_picker"],
        ])

        controller.beginLoading(owner: firstOwner)
        controller.connect(transport: transport, bundleInfo: bundle, owner: firstOwner)
        controller.markReady(ready, payload: nil, owner: firstOwner)

        controller.beginLoading(owner: secondOwner)
        controller.connect(transport: transport, bundleInfo: bundle, owner: secondOwner)
        controller.markReady(ready, payload: nil, owner: secondOwner)
        controller.accept(
            snapshot: pickerSnapshot(sessionId: "session-current", revision: 1),
            owner: secondOwner
        )

        controller.accept(
            snapshot: pickerSnapshot(sessionId: "session-stale", revision: 99),
            owner: firstOwner
        )
        controller.markDestroyed(owner: firstOwner)

        XCTAssertTrue(controller.isReady)
        XCTAssertEqual(controller.snapshot?.sessionId, "session-current")
        XCTAssertEqual(controller.snapshot?.revision, 1)
    }

    func testTypedObservationStreamsDedupeValidityAndPublishAccessEvents() {
        let controller = readyController(transport: PickerTransportSpy(), commands: [])
        let validity = SelectionValidity(
            isValid: true,
            count: 1,
            required: 1,
            remaining: 0,
            seats: [],
            violations: []
        )
        let expired = BuyerAccessExpiredEvent(
            reason: .expired,
            code: "access_expired",
            refreshed: false
        )
        let unavailable = BuyerAccessUnavailableEvent(
            reason: .revoked,
            code: "access_revoked",
            status: 403,
            retryable: false
        )
        let lost = SelectedObjectUnavailableEvent(
            labels: ["A-1"],
            reason: .taken,
            code: "seat_taken"
        )
        var validityValues: [SelectionValidity] = []
        var expiredValues: [BuyerAccessExpiredEvent] = []
        var unavailableValues: [BuyerAccessUnavailableEvent] = []
        var lostValues: [SelectedObjectUnavailableEvent] = []
        var cancellables: Set<AnyCancellable> = []
        controller.selectionValidityChanges.sink { validityValues.append($0) }.store(in: &cancellables)
        controller.accessExpirations.sink { expiredValues.append($0) }.store(in: &cancellables)
        controller.accessUnavailability.sink { unavailableValues.append($0) }.store(in: &cancellables)
        controller.selectedObjectUnavailability.sink { lostValues.append($0) }.store(in: &cancellables)

        controller.accept(selectionValidity: validity)
        controller.accept(selectionValidity: validity)
        controller.accept(accessExpired: expired)
        controller.accept(accessUnavailable: unavailable)
        controller.accept(selectedObjectsUnavailable: lost)

        XCTAssertEqual(validityValues, [validity])
        XCTAssertEqual(expiredValues, [expired])
        XCTAssertEqual(unavailableValues, [unavailable])
        XCTAssertEqual(lostValues, [lost])
    }

    private func readyController(
        transport: PickerTransportSpy,
        commands: [String],
        capabilities: [String] = []
    ) -> SeatLayerPickerController {
        let bundle = BundleInfo([
            "bundle": "0.71.5",
            "protocol": ["min": 2, "max": 2],
            "capabilities": .array(capabilities.map(JSONValue.string)),
            "commands": .array(commands.map(JSONValue.string)),
            "events": .array(["picker.snapshot"]),
        ])
        let controller = SeatLayerPickerController(
            transport: transport,
            bundleInfo: bundle,
            revisionWaitNanoseconds: 20_000_000
        )
        controller.markReady(
            ReadyInfo([
                "protocol": 2,
                "mode": "live",
                "transport": "ios",
                "chart": ["event": "ev_picker"],
            ]),
            payload: nil
        )
        return controller
    }

    private func pickerSnapshot(
        sessionId: String = "session-1",
        revision: Int
    ) -> JSONValue {
        [
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": .string(sessionId),
            "revision": .int(revision),
            "event": [
                "key": "ev_picker",
                "name": "Opening Night",
                "currency": "EUR",
            ],
        ]
    }
}

private actor PickerTransportSpy: SeatLayerPickerCommandTransport {
    struct Call: Sendable, Equatable {
        let name: String
        let payload: JSONValue?
    }

    private var calls: [Call] = []
    private let responses: [String: JSONValue]
    private let delayNanoseconds: UInt64

    init(
        responses: [String: JSONValue] = [:],
        delayNanoseconds: UInt64 = 0
    ) {
        self.responses = responses
        self.delayNanoseconds = delayNanoseconds
    }

    func command(_ name: String, payload: JSONValue?) async throws -> JSONValue {
        calls.append(Call(name: name, payload: payload))
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return responses[name] ?? .object([:])
    }

    func recordedCalls() -> [Call] { calls }
}
