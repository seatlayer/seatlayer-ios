import Combine
import XCTest
@testable import SeatLayer

/// The run page: its handshake, what it reports and what the app asks of it.
@MainActor
final class RunTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Handshake

    func testTheRunProfileAsksForTheRunSurfaceAndItsAppShell() throws {
        let profile = SeatLayerBridgeProfile.group(config: ["theme": "dark"])
        XCTAssertEqual(profile.protocolRange, ProtocolRange(min: 2, max: 2))
        XCTAssertEqual(profile.requiredCapabilities, ["group-surface-v1", "group-app-shell-v1"])
        XCTAssertEqual(profile.destroyCommand, "group.destroy")
        XCTAssertTrue(profile.hostsSession)
        XCTAssertFalse(profile.isPicker)

        let payload = profile.initPayload(configuration: SeatLayerRunConfiguration(run: "pg_1", apiBase: "https://api.example"))
        XCTAssertEqual(payload["protocol"], ["min": 2, "max": 2])
        XCTAssertEqual(payload["surface"], ["kind": "group"])
        XCTAssertEqual(payload["host"]?["platform"]?.stringValue, "ios")
        XCTAssertEqual(payload["config"], [
            "performanceGroup": "pg_1",
            "apiBase": "https://api.example",
            "theme": "dark",
            "header": false,
            "appBar": true,
            "checkout": "handoff",
        ])
        // The picker's own fields stay out.
        XCTAssertNil(payload["chrome"])
        XCTAssertNil(payload["requirements"])
    }

    func testAReplacementPageOpensOnTheLastHoldOrOnNone() {
        let configuration = SeatLayerRunConfiguration(
            run: "pg_1",
            initialHoldId: "h_old",
            initialOperationId: "op_old"
        )
        let resumed = SeatLayerBridgeProfile.group().settingConfig([
            "initialHoldId": "h_2", "initialOperationId": "op_2",
        ])
        XCTAssertEqual(resumed.initPayload(configuration: configuration)["config"]?["initialHoldId"], "h_2")
        XCTAssertEqual(resumed.initPayload(configuration: configuration)["config"]?["initialOperationId"], "op_2")

        let fresh = SeatLayerBridgeProfile.group().settingConfig([
            "initialHoldId": .null, "initialOperationId": .null,
        ])
        let config = fresh.initPayload(configuration: configuration)["config"]
        XCTAssertNil(config?["initialHoldId"])
        XCTAssertNil(config?["initialOperationId"])
    }

    func testTheConfigurationNamesEveryChoiceAndTheHostedRunPage() {
        var configuration = SeatLayerRunConfiguration(
            run: "pg_1",
            selectionMode: .perPerformance,
            allowSelectionModeSwitch: true,
            numberOfPlacesToSelect: 2,
            maxSelection: 4,
            buyerAccessTokenProvider: { _ in BuyerAccessToken(token: "t") },
            initialHoldId: "h_1",
            initialOperationId: "op_1",
            locale: "de",
            colorblindSafe: true,
            enable3D: false
        )
        configuration.hostInfo = ["app": "demo"]
        let payload = configuration.initPayload()
        XCTAssertEqual(payload["host"]?["app"], "demo")
        XCTAssertEqual(payload["config"]?["selectionMode"], "per_performance")
        XCTAssertEqual(payload["config"]?["allowSelectionModeSwitch"], true)
        XCTAssertEqual(payload["config"]?["numberOfPlacesToSelect"], 2)
        XCTAssertEqual(payload["config"]?["maxSelection"], 4)
        XCTAssertEqual(payload["config"]?["nativeAccessProvider"], true)
        XCTAssertNil(payload["config"]?["buyerAccessToken"])
        XCTAssertEqual(payload["config"]?["initialHoldId"], "h_1")
        XCTAssertEqual(payload["config"]?["initialOperationId"], "op_1")
        XCTAssertEqual(payload["config"]?["locale"], "de")
        XCTAssertEqual(payload["config"]?["colorblindSafe"], true)
        XCTAssertEqual(payload["config"]?["enable3D"], false)
        // The run page takes the token from its config: a page without the
        // event page's access feature still serves it.
        XCTAssertNil(configuration.compatibilityProblem(with: bundle(capabilities: [])))
        XCTAssertEqual(
            configuration.resolvedPageURL.absoluteString,
            "https://cdn.seatlayer.io/seatlayer-js@\(SeatLayer.hostedWebVersion)/group.html"
        )
    }

    func testRefusesWhatThePageWouldRefuse() {
        func refused(_ configuration: SeatLayerRunConfiguration) -> Bool {
            do {
                try configuration.validate()
                return false
            } catch let error as SeatLayerError {
                return error.code == BridgeErrorCode.badPayload
            } catch {
                return false
            }
        }
        XCTAssertFalse(refused(SeatLayerRunConfiguration(run: "pg_1")))
        XCTAssertTrue(refused(SeatLayerRunConfiguration(run: "  ")))
        XCTAssertTrue(refused(SeatLayerRunConfiguration(run: "pg_1", maxSelection: 0)))
        XCTAssertTrue(refused(SeatLayerRunConfiguration(run: "pg_1", numberOfPlacesToSelect: 0)))
        XCTAssertTrue(refused(SeatLayerRunConfiguration(run: "pg_1", selectionMode: .perPerformance)))
        XCTAssertTrue(refused(SeatLayerRunConfiguration(run: "pg_1", allowSelectionModeSwitch: true)))
        XCTAssertFalse(refused(SeatLayerRunConfiguration(
            run: "pg_1",
            selectionMode: .perPerformance,
            numberOfPlacesToSelect: 2
        )))
        XCTAssertTrue(refused(SeatLayerRunConfiguration(run: "pg_1", initialHoldId: "h_1")))
        XCTAssertTrue(refused(SeatLayerRunConfiguration(run: "pg_1", buyerAccessToken: BuyerAccessToken(token: " "))))
    }

    // MARK: - What the page reports

    func testReadsTheRunTheStatusAndTheHold() {
        let controller = readyController()
        controller.sessionEvent("group.ready", payload: [
            "performanceGroup": [
                "key": "pg_1",
                "name": "Spring run",
                "mode": "test",
                "performances": [
                    ["position": 1, "eventKey": "ev_1", "name": "Fri", "startsAt": 1_800_000_000_000, "startsAtLabel": "Fri 8 pm"],
                    ["position": 2, "name": "missing key"],
                ],
            ],
            "selectionMode": "same_seat",
        ], owner: nil)
        XCTAssertEqual(controller.descriptor?.name, "Spring run")
        XCTAssertEqual(controller.descriptor?.mode, "test")
        XCTAssertEqual(controller.descriptor?.performances.map(\.eventKey), ["ev_1"])
        XCTAssertEqual(controller.descriptor?.performances.first?.startsAt, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(controller.selectionMode, .sameSeat)

        controller.sessionEvent("group.status", payload: [
            "kind": "sales_closed",
            "message": "Sales have closed.",
            "branding": ["brandName": "Club", "logoUrl": "https://example.com/l.png"],
        ], owner: nil)
        XCTAssertEqual(controller.status?.kind, .salesClosed)
        XCTAssertEqual(controller.status?.branding?.logoURL, "https://example.com/l.png")

        controller.sessionEvent("group.hold", payload: ["handoff": handoff("op_1")], owner: nil)
        XCTAssertEqual(controller.hold?.holdId, "h_op_1")
        XCTAssertEqual(controller.hold?.seatLabels, ["A1", "A2"])
        // A hold event without a hold changes nothing; a change to none clears it.
        controller.sessionEvent("group.hold", payload: [:], owner: nil)
        XCTAssertNotNil(controller.hold)
        controller.sessionEvent("group.holdChanged", payload: [:], owner: nil)
        XCTAssertNil(controller.hold)

        controller.sessionEvent("group.selectionMode.changed", payload: ["selectionMode": "per_performance"], owner: nil)
        XCTAssertEqual(controller.selectionMode, .perPerformance)
        controller.sessionEvent("group.someday", payload: ["x": 1], owner: nil)
    }

    func testContinueAndBookedAreToldOncePerOperation() {
        let controller = readyController()
        var continued: [String] = []
        var booked: [String] = []
        var expired = 0
        controller.continues.sink { continued.append($0.operationId) }.store(in: &cancellables)
        controller.bookings.sink { booked.append($0.operationId) }.store(in: &cancellables)
        controller.holdExpirations.sink { expired += 1 }.store(in: &cancellables)

        for _ in 0..<2 {
            controller.sessionEvent("group.checkout", payload: ["handoff": handoff("op_1")], owner: nil)
            controller.sessionEvent("group.booked", payload: ["handoff": handoff("op_1", booked: true)], owner: nil)
        }
        controller.sessionEvent("group.checkout", payload: ["handoff": handoff("op_2")], owner: nil)
        XCTAssertEqual(continued, ["op_1", "op_2"])
        XCTAssertEqual(booked, ["op_1"])

        controller.sessionEvent("group.hold", payload: ["handoff": handoff("op_2")], owner: nil)
        controller.sessionEvent("group.holdExpired", payload: [:], owner: nil)
        XCTAssertNil(controller.hold)
        XCTAssertEqual(expired, 1)
    }

    func testAnOlderPagesEventsAreNotRead() {
        let controller = SeatLayerRunController()
        let first = UUID()
        controller.sessionBeginLoading(owner: first)
        controller.sessionBeginLoading(owner: UUID())
        controller.sessionEvent("group.hold", payload: ["handoff": handoff("op_1")], owner: first)
        XCTAssertNil(controller.hold)
    }

    func testTheLineIsReadOnlyFromAPageThatReportsIt() {
        let silent = readyController(capabilities: [])
        silent.sessionConnection(["state": "offline"], owner: nil)
        XCTAssertNil(silent.connection)

        let reporting = readyController()
        reporting.sessionConnection(["state": "offline"], owner: nil)
        XCTAssertEqual(reporting.connection, .offline)
        XCTAssertEqual(reporting.connection?.lineDown, true)
    }

    func testAFailureAfterReadyIsAnErrorNotAFailedPage() {
        let controller = readyController()
        var errors: [SeatLayerError] = []
        controller.errors.sink { errors.append($0) }.store(in: &cancellables)
        controller.sessionFailed(.transport("late"), owner: nil)
        XCTAssertTrue(controller.isReady)
        XCTAssertEqual(errors, [.transport("late")])

        let starting = SeatLayerRunController()
        starting.sessionBeginLoading(owner: nil)
        starting.sessionFailed(.handshakeTimeout(seconds: 45), owner: nil)
        XCTAssertEqual(starting.phase, .failed(.handshakeTimeout(seconds: 45)))
    }

    // MARK: - What the app asks

    func testAPageEndedAfterItFailedLeavesTheFailureInView() {
        let controller = SeatLayerRunController()
        let owner = UUID()
        controller.sessionBeginLoading(owner: owner)
        let error = SeatLayerError.handshakeTimeout(seconds: 45)
        controller.sessionFailed(error, owner: owner)
        controller.sessionDestroyed(owner: owner)
        guard case .failed = controller.phase else {
            return XCTFail("phase \(controller.phase)")
        }
        // A page ended without a failure is destroyed.
        controller.sessionBeginLoading(owner: owner)
        controller.sessionDestroyed(owner: owner)
        XCTAssertEqual(controller.phase, .destroyed)
    }

    func testCommandsSayWhatThePageAnswers() async throws {
        let transport = RunTransportSpy(responses: [
            "group.continue": ["handoff": handoff("op_9")],
            "group.getHeldOrder": ["heldOrder": handoff("op_8")],
            "group.release": ["released": true],
            "group.setSelectionMode": ["changed": true],
            "group.markBooked": ["status": "booked"],
            "group.lifecycle": ["held": false],
        ])
        let controller = readyController(transport: transport)
        let continued = try await controller.continueToCheckout()
        XCTAssertEqual(continued.operationId, "op_9")
        let held = try await controller.getHeldOrder()
        XCTAssertEqual(held?.operationId, "op_8")
        let released = try await controller.release()
        XCTAssertTrue(released)
        let changed = try await controller.setSelectionMode(.perPerformance)
        XCTAssertTrue(changed)
        let status = try await controller.markBooked(operationId: "op_9")
        XCTAssertEqual(status, .booked)
        try await controller.setViewportInsets(bottom: 34)
        let stillHeld = try await controller.setForeground(false)
        XCTAssertEqual(stillHeld, false)

        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), [
            "group.continue", "group.getHeldOrder", "group.release", "group.setSelectionMode",
            "group.markBooked", "group.setViewportInsets", "group.lifecycle",
        ])
        XCTAssertEqual(calls[3].payload, ["mode": "per_performance"])
        XCTAssertEqual(calls[4].payload, ["operationId": "op_9"])
        XCTAssertEqual(calls[5].payload, ["top": 0, "right": 0, "bottom": 34, "left": 0])
        XCTAssertEqual(calls[6].payload, ["state": "background"])
    }

    func testAPageThatOpenedOnAHoldIsAskedForIt() async {
        let transport = RunTransportSpy(responses: ["group.getHeldOrder": ["heldOrder": handoff("op_5")]])
        let controller = SeatLayerRunController()
        controller.readsHeldOrderOnReady = true
        controller.sessionBeginLoading(owner: nil)
        controller.sessionConnect(transport: transport, bundleInfo: bundle(), owner: nil)
        controller.sessionReady(ReadyInfo(["protocol": 2]), payload: nil, owner: nil)
        for _ in 0..<20 where controller.hold == nil { await Task.yield() }
        XCTAssertEqual(controller.hold?.operationId, "op_5")
    }

    func testContinueWaitsAsLongAsAHoldMay() {
        // The page waits up to 40 s for the server's hold; a shorter native
        // limit would call a hold that worked failed.
        XCTAssertEqual(
            BridgeClient.timeout(for: "group.continue", base: BridgeClient.defaultTimeout),
            BridgeClient.holdCommandTimeout
        )
        XCTAssertEqual(BridgeClient.timeout(for: "group.release", base: 10), 10)
    }

    func testNothingIsSentBeforeThePageIsReady() async {
        let controller = SeatLayerRunController()
        do {
            _ = try await controller.release()
            XCTFail("sent before ready")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, BridgeErrorCode.notReady)
        } catch {
            XCTFail("\(error)")
        }
    }

    // MARK: - Helpers

    private func bundle(capabilities: [String] = ["group-surface-v1", "group-app-shell-v1", "connection-state-v1"]) -> BundleInfo {
        BundleInfo([
            "bundle": "1.0.8",
            "protocol": ["min": 1, "max": 2],
            "capabilities": .array(capabilities.map(JSONValue.string)),
            "commands": ["group.continue", "group.setViewportInsets"],
            "events": ["group.ready", "group.hold"],
        ])
    }

    private func readyController(
        transport: any SeatLayerPickerCommandTransport = RunTransportSpy(),
        capabilities: [String] = ["group-surface-v1", "group-app-shell-v1", "connection-state-v1"]
    ) -> SeatLayerRunController {
        let controller = SeatLayerRunController()
        controller.sessionBeginLoading(owner: nil)
        controller.sessionConnect(transport: transport, bundleInfo: bundle(capabilities: capabilities), owner: nil)
        controller.sessionReady(ReadyInfo(["protocol": 2]), payload: nil, owner: nil)
        return controller
    }

    private func handoff(_ operation: String, booked: Bool = false) -> JSONValue {
        .object(compacting: [
            "operationId": .string(operation),
            "holdId": .string("h_\(operation)"),
            "expiresAt": 1_800_000_900_000,
            "performanceKeys": ["ev_1", "ev_2"],
            "seatLabels": ["A1", "A2"],
            "selectionMode": "same_seat",
            "bookingState": booked ? "booked" : nil,
        ])
    }
}

private actor RunTransportSpy: SeatLayerPickerCommandTransport {
    struct Call: Sendable {
        let name: String
        let payload: JSONValue?
    }

    private var calls: [Call] = []
    private let responses: [String: JSONValue]

    init(responses: [String: JSONValue] = [:]) {
        self.responses = responses
    }

    func command(_ name: String, payload: JSONValue?) async throws -> JSONValue {
        calls.append(Call(name: name, payload: payload))
        return responses[name] ?? .object([:])
    }

    func recordedCalls() -> [Call] { calls }
}
