import Combine
import XCTest
@testable import SeatLayer

@MainActor
final class PickerControllerTests: XCTestCase {
    func testTheMapCountsAsFramedOnceTheChromeHasBeenReported() async throws {
        let transport = PickerTransportSpy(responses: ["picker.setViewportInsets": [:]])
        let controller = readyController(
            transport: transport,
            commands: ["picker.setViewportInsets"],
            capabilities: ["viewport-insets-v1", "native-chrome-contract-v1"]
        )
        XCTAssertFalse(controller.mapFramed)

        try await controller.setViewportInsets(.init(top: 44, bottom: 72))
        XCTAssertTrue(controller.mapFramed)
    }

    func testARuntimeThatTakesNoViewportReportStillCountsAsFramed() async throws {
        let transport = PickerTransportSpy()
        let controller = readyController(transport: transport, commands: [])

        try await controller.setViewportInsets(.init(top: 44))
        XCTAssertTrue(controller.mapFramed)
        let calls = await transport.recordedCalls()
        XCTAssertTrue(calls.isEmpty)
    }

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
            "bundle": "1.0.6",
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

    // MARK: - A page the system ended

    func testAPageEndedWithAHandedOffHoldAsksTheNextPageForThatHold() async throws {
        let transport = PickerTransportSpy(responses: [
            "picker.continue": [
                "handoff": [
                    "holdId": "hold-handed-off",
                    "expiresAt": .double(1_800_000_000_000),
                    "currency": "EUR",
                    "lineItems": .array([]),
                    "total": 0,
                ],
            ],
        ])
        let controller = readyController(
            transport: transport,
            commands: ["picker.continue", "picker.resumeHold"]
        )
        _ = try await controller.checkout()
        controller.accept(snapshot: pickerSnapshot(revision: 2, holdActive: true))

        let bundle = try XCTUnwrap(controller.bundleInfo)
        controller.pageLost()
        XCTAssertEqual(controller.holdToResumeAfterReload, "hold-handed-off")
        // Until the replacement is ready nothing is sent to the closed page.
        XCTAssertFalse(controller.isReady)
        controller.connect(transport: transport, bundleInfo: bundle)
        controller.markReady(readyInfo(), payload: nil)
        XCTAssertNil(controller.holdToResumeAfterReload)

        let resumed = try await waitForCall("picker.resumeHold", on: transport)
        XCTAssertEqual(resumed?.payload?["holdId"]?.stringValue, "hold-handed-off")
    }

    func testAPageEndedWithNoActiveHoldAsksTheNextPageForNothing() async throws {
        let transport = PickerTransportSpy()
        let controller = readyController(transport: transport, commands: ["picker.resumeHold"])
        controller.lastHandoffHoldId = "an-old-handoff"
        controller.accept(snapshot: pickerSnapshot(revision: 2, holdActive: false))

        let bundle = try XCTUnwrap(controller.bundleInfo)
        controller.pageLost()
        controller.connect(transport: transport, bundleInfo: bundle)
        controller.markReady(readyInfo(), payload: nil)

        XCTAssertNil(controller.holdToResumeAfterReload)
        let resumed = try await waitForCall("picker.resumeHold", on: transport, attempts: 5)
        XCTAssertNil(resumed)
    }

    func testAPageEndedBeforeAnyHandoffFallsBackToTheAppsInitialHold() {
        let controller = readyController(transport: PickerTransportSpy(), commands: [])
        controller.initialHoldId = "hold-from-app"
        controller.accept(snapshot: pickerSnapshot(revision: 2, holdActive: true))

        controller.pageLost()

        XCTAssertEqual(controller.holdToResumeAfterReload, "hold-from-app")
    }

    func testAReplacedPageIsSentTheAppsThemeAgain() async throws {
        let transport = PickerTransportSpy()
        let controller = readyController(transport: transport, commands: ["picker.setThemeMode"])
        try await controller.setThemeMode(.dark)
        let bundle = try XCTUnwrap(controller.bundleInfo)

        controller.pageLost()
        controller.connect(transport: transport, bundleInfo: bundle)
        controller.markReady(readyInfo(), payload: nil)

        for _ in 0..<50 {
            let sent = await transport.recordedCalls().filter { $0.name == "picker.setThemeMode" }
            if sent.count == 2 {
                XCTAssertEqual(sent[1].payload?["mode"]?.stringValue, "dark")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("the replaced page was not sent the theme")
    }

    func testACommandRefusedWhileThePageIsReplacedIsNotReported() throws {
        let controller = readyController(transport: PickerTransportSpy(), commands: [])
        let bundle = try XCTUnwrap(controller.bundleInfo)
        let refused = SeatLayerError.bridge(.init(
            code: BridgeErrorCode.notReady,
            message: "SeatLayer picker is not ready."
        ))

        controller.pageLost()
        controller.record(refused)
        XCTAssertNil(controller.lastError)

        controller.connect(transport: PickerTransportSpy(), bundleInfo: bundle)
        controller.markReady(readyInfo(), payload: nil)
        controller.record(refused)
        XCTAssertEqual(controller.lastError, refused)
    }

    func testMarkBookedSettlesTheHandedOffHoldAndPublishesTheSaleOnce() async throws {
        let transport = PickerTransportSpy(responses: [
            "picker.continue": ["handoff": Self.handoffPayload],
            "picker.markBooked": ["booked": true, "status": "booked", "holdId": "hold-handed-off"],
        ])
        let controller = readyController(
            transport: transport,
            commands: ["picker.continue", "picker.markBooked"],
            capabilities: ["hold-mark-booked-v1"]
        )
        var sales: [String] = []
        let watching = controller.bookings.sink { sales.append($0.holdId) }
        defer { watching.cancel() }
        _ = try await controller.checkout()

        let booked = try await controller.markBooked()

        XCTAssertTrue(booked)
        XCTAssertEqual(sales, ["hold-handed-off"])
        let sent = await transport.recordedCalls().first { $0.name == "picker.markBooked" }
        XCTAssertNil(sent?.payload?["holdId"])
        // The page answers a repeat with already_booked; it is not a second sale.
        _ = try await controller.markBooked()
        XCTAssertEqual(sales, ["hold-handed-off"])
    }

    func testMarkBookedThatThePageRefusesIsNoSale() async throws {
        let transport = PickerTransportSpy(responses: [
            "picker.continue": ["handoff": Self.handoffPayload],
            "picker.markBooked": ["booked": false, "status": "no_hold"],
        ])
        let controller = readyController(
            transport: transport,
            commands: ["picker.continue", "picker.markBooked"],
            capabilities: ["hold-mark-booked-v1"]
        )
        var sales = 0
        let watching = controller.bookings.sink { _ in sales += 1 }
        defer { watching.cancel() }
        _ = try await controller.checkout()

        let booked = try await controller.markBooked()

        XCTAssertFalse(booked)
        XCTAssertEqual(sales, 0)
    }

    func testMarkBookedForAnotherHoldIsNotTheHandedOffSale() async throws {
        let transport = PickerTransportSpy(responses: [
            "picker.continue": ["handoff": Self.handoffPayload],
            "picker.markBooked": ["booked": true, "status": "booked", "holdId": "hold-other"],
        ])
        let controller = readyController(
            transport: transport,
            commands: ["picker.continue", "picker.markBooked"],
            capabilities: ["hold-mark-booked-v1"]
        )
        var sales = 0
        let watching = controller.bookings.sink { _ in sales += 1 }
        defer { watching.cancel() }
        _ = try await controller.checkout()

        let booked = try await controller.markBooked(holdId: "hold-other")

        XCTAssertTrue(booked)
        XCTAssertEqual(sales, 0)
        let sent = await transport.recordedCalls().first { $0.name == "picker.markBooked" }
        XCTAssertEqual(sent?.payload?["holdId"]?.stringValue, "hold-other")
    }

    func testMarkBookedOnAPageThatCannotBeToldSendsNothing() async throws {
        let transport = PickerTransportSpy()
        let controller = readyController(transport: transport, commands: [])

        let booked = try await controller.markBooked()

        XCTAssertFalse(booked)
        XCTAssertFalse(controller.supportsMarkBooked)
        let sent = await transport.recordedCalls().filter { $0.name == "picker.markBooked" }
        XCTAssertTrue(sent.isEmpty)
    }

    func testMarkBookedRefusesAnEmptyHoldId() async {
        let controller = readyController(
            transport: PickerTransportSpy(),
            commands: ["picker.markBooked"],
            capabilities: ["hold-mark-booked-v1"]
        )
        do {
            _ = try await controller.markBooked(holdId: " ")
            XCTFail("an empty holdId was sent")
        } catch {}
    }

    private static let handoffPayload: JSONValue = [
        "holdId": "hold-handed-off",
        "expiresAt": .double(1_800_000_000_000),
        "currency": "EUR",
        "lineItems": .array([]),
        "total": 0,
    ]

    func testTwoEndedPagesInAMinuteAreReplacedAndTheThirdIsNot() {
        var recovery = SeatLayerPickerPageRecovery()
        XCTAssertTrue(recovery.lost(at: 100))
        XCTAssertTrue(recovery.lost(at: 130))
        XCTAssertFalse(recovery.lost(at: 150))
        // A refused loss still counts: at 161 the losses at 130 and 150 are
        // inside the minute. Once 130 has left it, there is room again.
        XCTAssertFalse(recovery.lost(at: 161))
        XCTAssertTrue(recovery.lost(at: 221))
        recovery.reset()
        XCTAssertTrue(recovery.lost(at: 162))
        XCTAssertTrue(recovery.lost(at: 163))
    }

    private func waitForCall(
        _ name: String,
        on transport: PickerTransportSpy,
        attempts: Int = 50
    ) async throws -> PickerTransportSpy.Call? {
        for _ in 0..<attempts {
            if let call = await transport.recordedCalls().first(where: { $0.name == name }) {
                return call
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return nil
    }

    private func readyInfo() -> ReadyInfo {
        ReadyInfo([
            "protocol": 2,
            "mode": "live",
            "transport": "ios",
            "chart": ["event": "ev_picker"],
        ])
    }

    private func readyController(
        transport: PickerTransportSpy,
        commands: [String],
        capabilities: [String] = []
    ) -> SeatLayerPickerController {
        let bundle = BundleInfo([
            "bundle": "1.0.6",
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
        revision: Int,
        holdActive: Bool = false
    ) -> JSONValue {
        [
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": .string(sessionId),
            "revision": .int(revision),
            "hold": ["active": .bool(holdActive), "owner": "host"],
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
