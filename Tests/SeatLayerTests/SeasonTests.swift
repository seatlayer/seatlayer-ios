import Combine
import XCTest
@testable import SeatLayer

/// The Season page: its handshake, what it reports and what the app asks of it.
@MainActor
final class SeasonTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Handshake

    func testTheSeasonProfileAsksForTheSeasonSurfaceAndItsAppShell() {
        let profile = SeatLayerBridgeProfile.season(config: ["theme": "dark"])
        XCTAssertEqual(profile.protocolRange, ProtocolRange(min: 2, max: 2))
        XCTAssertEqual(profile.requiredCapabilities, ["season-surface-v1", "season-app-shell-v1"])
        XCTAssertEqual(profile.destroyCommand, "season.destroy")
        XCTAssertTrue(profile.hostsSession)
        XCTAssertTrue(profile.isAppShellPage)
        XCTAssertFalse(profile.isPicker)

        let payload = profile.initPayload(configuration: SeatLayerSeasonConfiguration(
            season: "sea_1",
            apiBase: "https://api.example",
            publicKey: "pk_test_1"
        ))
        XCTAssertEqual(payload["protocol"], ["min": 2, "max": 2])
        XCTAssertEqual(payload["surface"], ["kind": "season"])
        XCTAssertEqual(payload["host"]?["platform"]?.stringValue, "ios")
        XCTAssertEqual(payload["config"], [
            "season": "sea_1",
            "apiBase": "https://api.example",
            "publicKey": "pk_test_1",
            "theme": "dark",
            "appBar": true,
        ])
        // The picker's own fields stay out.
        XCTAssertNil(payload["chrome"])
        XCTAssertNil(payload["requirements"])
    }

    func testAReplacementPageOpensOnTheLastHoldOrOnNone() {
        let configuration = SeatLayerSeasonConfiguration(season: "sea_1", initialOperationId: "sop_old")
        let resumed = SeatLayerBridgeProfile.season().settingConfig(["initialOperationId": "sop_2"])
        XCTAssertEqual(resumed.initPayload(configuration: configuration)["config"]?["initialOperationId"], "sop_2")

        let fresh = SeatLayerBridgeProfile.season().settingConfig(["initialOperationId": .null])
        XCTAssertNil(fresh.initPayload(configuration: configuration)["config"]?["initialOperationId"])
    }

    func testTheConfigurationNamesEveryChoiceAndTheHostedSeasonPage() {
        var configuration = SeatLayerSeasonConfiguration(
            season: "sea_1",
            package: "full",
            priceTypes: ["adult", "child"],
            ticketsByEmail: true,
            maxSelection: 4,
            buyerAccessTokenProvider: { _ in BuyerAccessToken(token: "t") },
            initialOperationId: "sop_1",
            locale: "de",
            colorblindSafe: true,
            enable3D: false
        )
        configuration.hostInfo = ["app": "demo"]
        let payload = configuration.initPayload()
        XCTAssertEqual(payload["host"]?["app"], "demo")
        XCTAssertEqual(payload["config"]?["package"], "full")
        XCTAssertEqual(payload["config"]?["priceTypes"], ["adult", "child"])
        XCTAssertEqual(payload["config"]?["ticketsByEmail"], true)
        XCTAssertEqual(payload["config"]?["maxSelection"], 4)
        XCTAssertEqual(payload["config"]?["nativeAccessProvider"], true)
        XCTAssertNil(payload["config"]?["buyerAccessToken"])
        XCTAssertNil(payload["config"]?["publicKey"])
        XCTAssertEqual(payload["config"]?["initialOperationId"], "sop_1")
        XCTAssertEqual(payload["config"]?["locale"], "de")
        XCTAssertEqual(payload["config"]?["colorblindSafe"], true)
        XCTAssertEqual(payload["config"]?["enable3D"], false)
        // The Season page takes the token from its config: a page without the
        // event page's access feature still serves it.
        XCTAssertNil(configuration.compatibilityProblem(with: bundle(capabilities: [])))
        XCTAssertEqual(
            configuration.resolvedPageURL.absoluteString,
            "https://cdn.seatlayer.io/seatlayer-js@\(SeatLayer.hostedWebVersion)/season.html"
        )
    }

    func testRefusesWhatThePageWouldRefuse() {
        func refused(_ configuration: SeatLayerSeasonConfiguration) -> Bool {
            do {
                try configuration.validate()
                return false
            } catch let error as SeatLayerError {
                return error.code == BridgeErrorCode.badPayload
            } catch {
                return false
            }
        }
        XCTAssertFalse(refused(SeatLayerSeasonConfiguration(season: "sea_1")))
        XCTAssertTrue(refused(SeatLayerSeasonConfiguration(season: " ")))
        XCTAssertTrue(refused(SeatLayerSeasonConfiguration(season: "sea_1", maxSelection: 0)))
        XCTAssertTrue(refused(SeatLayerSeasonConfiguration(season: "sea_1", buyerAccessToken: BuyerAccessToken(token: " "))))
        XCTAssertTrue(refused(SeatLayerSeasonConfiguration(
            season: "sea_1",
            buyerAccessToken: BuyerAccessToken(token: "t", expiresAt: .infinity)
        )))
    }

    // MARK: - What the page reports

    func testReadsTheStatusTheDatesAndTheHold() {
        let controller = readyController()
        controller.sessionEvent("season.status", payload: [
            "kind": "ready",
            "message": "Choose your seats.",
            "season": ["name": "Winter season"],
            "branding": ["brandName": "Club", "logoUrl": "https://example.com/l.png"],
            "dates": [
                ["position": 1, "eventKey": "ev_1", "name": "Opening", "startsAt": 1_800_000_000_000,
                 "startsAtLabel": "Sat 15 Aug · 15:00"],
                ["position": 2, "eventKey": "ev_2", "name": "Final", "past": true, "cancelled": true],
                ["position": 3, "name": "missing key"],
            ],
        ], owner: nil)
        XCTAssertEqual(controller.status?.kind, .ready)
        XCTAssertEqual(controller.status?.seasonName, "Winter season")
        XCTAssertEqual(controller.status?.branding?.logoURL, "https://example.com/l.png")
        XCTAssertEqual(controller.status?.dates?.map(\.eventKey), ["ev_1", "ev_2"])
        XCTAssertEqual(controller.status?.dates?.first?.startsAt, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(controller.status?.dates?.first?.startsAtLabel, "Sat 15 Aug · 15:00")
        XCTAssertEqual(controller.status?.dates?.last?.past, true)
        XCTAssertEqual(controller.status?.dates?.last?.cancelled, true)
        // A kind this build predates keeps its raw value.
        controller.sessionEvent("season.status", payload: ["kind": "someday"], owner: nil)
        XCTAssertEqual(controller.status?.kind.rawValue, "someday")
        XCTAssertEqual(controller.status?.message, "")

        controller.sessionEvent("season.hold", payload: ["handoff": handoff("sop_1")], owner: nil)
        XCTAssertEqual(controller.hold?.holdId, "h_sop_1")
        XCTAssertEqual(controller.hold?.planActivationId, "pa_1")
        XCTAssertEqual(controller.hold?.json["allocations"], ["x"])
        // A hold event without a hold changes nothing; a change to none clears it.
        controller.sessionEvent("season.hold", payload: [:], owner: nil)
        XCTAssertNotNil(controller.hold)
        controller.sessionEvent("season.holdChanged", payload: [:], owner: nil)
        XCTAssertNil(controller.hold)
        controller.sessionEvent("season.someday", payload: ["x": 1], owner: nil)
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
            controller.sessionEvent("season.continue", payload: ["handoff": handoff("sop_1")], owner: nil)
            controller.sessionEvent("season.status", payload: ["kind": "booked", "operationId": "sop_1"], owner: nil)
        }
        controller.sessionEvent("season.continue", payload: ["handoff": handoff("sop_2")], owner: nil)
        // A hold this page never saw is not told booked.
        controller.sessionEvent("season.status", payload: ["kind": "booked", "operationId": "sop_9"], owner: nil)
        XCTAssertEqual(continued, ["sop_1", "sop_2"])
        XCTAssertEqual(booked, ["sop_1"])

        controller.sessionEvent("season.hold", payload: ["handoff": handoff("sop_2")], owner: nil)
        controller.sessionEvent("season.holdExpired", payload: [:], owner: nil)
        XCTAssertNil(controller.hold)
        XCTAssertEqual(expired, 1)
        XCTAssertEqual(controller.closeWithoutPage(), SeatLayerSeasonClose(outcome: .closed))
    }

    func testAnOlderPagesEventsAreNotRead() {
        let controller = SeatLayerSeasonController()
        let first = UUID()
        controller.sessionBeginLoading(owner: first)
        controller.sessionBeginLoading(owner: UUID())
        controller.sessionEvent("season.hold", payload: ["handoff": handoff("sop_1")], owner: first)
        XCTAssertNil(controller.hold)
    }

    func testTheLineIsReadOnlyFromAPageThatReportsIt() {
        let silent = readyController(capabilities: [])
        silent.sessionConnection(["state": "offline"], owner: nil)
        XCTAssertNil(silent.connection)

        let reporting = readyController()
        reporting.sessionConnection(["state": "offline"], owner: nil)
        XCTAssertEqual(reporting.connection, .offline)
    }

    func testAFailureAfterReadyIsAnErrorNotAFailedPage() {
        let controller = readyController()
        var errors: [SeatLayerError] = []
        controller.errors.sink { errors.append($0) }.store(in: &cancellables)
        controller.sessionFailed(.transport("late"), owner: nil)
        controller.sessionEvent("season.error", payload: ["code": "sl_api", "message": "down"], owner: nil)
        XCTAssertTrue(controller.isReady)
        XCTAssertEqual(errors.count, 2)
        XCTAssertEqual(errors.first, .transport("late"))

        let starting = SeatLayerSeasonController()
        let owner = UUID()
        starting.sessionBeginLoading(owner: owner)
        starting.sessionFailed(.handshakeTimeout(seconds: 45), owner: owner)
        // The page torn down after it failed leaves the failure in view.
        starting.sessionDestroyed(owner: owner)
        XCTAssertEqual(starting.phase, .failed(.handshakeTimeout(seconds: 45)))
    }

    // MARK: - What the app asks

    func testCommandsSayWhatThePageAnswers() async throws {
        let transport = SeasonTransportSpy(responses: [
            "season.holdSameSeat": ["handoff": handoff("sop_7")],
            "season.holdBestAvailable": ["handoff": handoff("sop_8")],
            "season.restoreOperation": ["handoff": handoff("sop_6")],
            "season.markBooked": ["status": "already_booked"],
            "season.release": ["released": true],
            "season.getHeldOrder": ["heldOrder": [
                "operationId": "sop_7", "expiresAt": 1_800_000_900_000, "currency": "EUR",
                "seats": [["label": "A1"]], "totalMinor": 12000,
            ]],
            "season.requestClose": ["outcome": "kept", "operationId": "sop_7"],
            "season.lifecycle": ["held": true],
        ])
        let controller = readyController(transport: transport)
        let same = try await controller.holdSameSeat(["A1", "A2"], operationId: "sop_7", priceTypes: ["A2": "child"])
        XCTAssertEqual(same.operationId, "sop_7")
        let best = try await controller.holdBestAvailable(2, categoryKey: "cat-1", requireContiguous: true)
        XCTAssertEqual(best.operationId, "sop_8")
        let restored = try await controller.restoreOperation("sop_6")
        XCTAssertEqual(restored?.operationId, "sop_6")
        try await controller.chooseSeats()
        try await controller.choosePackage("pa_2")
        let status = try await controller.markBooked(operationId: "sop_7")
        XCTAssertEqual(status, .alreadyBooked)
        let released = try await controller.release(releaseActionId: "sra_1")
        XCTAssertTrue(released)
        let order = try await controller.getHeldOrder()
        XCTAssertEqual(order?.currency, "EUR")
        XCTAssertEqual(order?.totalMinor, 12000)
        XCTAssertEqual(order?.seats.count, 1)
        let close = try await controller.requestClose()
        XCTAssertEqual(close, SeatLayerSeasonClose(outcome: .kept, operationId: "sop_7"))
        XCTAssertTrue(close.outcome.closes)
        let held = try await controller.setForeground(true)
        XCTAssertEqual(held, true)
        try await controller.setThemeMode(.dark)
        try await controller.setViewportInsets(bottom: 34)

        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), [
            "season.holdSameSeat", "season.holdBestAvailable", "season.restoreOperation",
            "season.chooseSeats", "season.choosePackage", "season.markBooked", "season.release",
            "season.getHeldOrder", "season.requestClose", "season.lifecycle", "season.setThemeMode",
            "season.setViewportInsets",
        ])
        XCTAssertEqual(calls[0].payload, [
            "labels": ["A1", "A2"], "operationId": "sop_7", "priceTypes": ["A2": "child"],
        ])
        XCTAssertEqual(calls[1].payload?["qty"], 2)
        XCTAssertEqual(calls[1].payload?["categoryKey"], "cat-1")
        XCTAssertEqual(calls[1].payload?["requireContiguous"], true)
        XCTAssertNil(calls[1].payload?["zoneId"])
        XCTAssertEqual(calls[2].payload, ["operationId": "sop_6"])
        XCTAssertEqual(calls[4].payload, ["planActivationId": "pa_2"])
        XCTAssertEqual(calls[5].payload, ["operationId": "sop_7"])
        XCTAssertEqual(calls[6].payload, ["releaseActionId": "sra_1"])
        XCTAssertEqual(calls[9].payload, ["state": "foreground"])
        XCTAssertEqual(calls[10].payload, ["mode": "dark"])
        XCTAssertEqual(calls[11].payload, ["top": 0, "right": 0, "bottom": 34, "left": 0])
    }

    func testEachHoldAndReleaseGetsAFreshCallerStableId() async throws {
        let transport = SeasonTransportSpy(responses: ["season.holdBestAvailable": ["handoff": handoff("sop_x")]])
        let controller = readyController(transport: transport)
        _ = try await controller.holdBestAvailable(1)
        _ = try await controller.release()
        let calls = await transport.recordedCalls()
        let operation = try XCTUnwrap(calls[0].payload?["operationId"]?.stringValue)
        let release = try XCTUnwrap(calls[1].payload?["releaseActionId"]?.stringValue)
        XCTAssertTrue(operation.hasPrefix("sop_"))
        XCTAssertTrue(release.hasPrefix("sra_"))
        XCTAssertEqual(operation.count, 24)
        XCTAssertNotEqual(SeatLayerSeasonController.newOperationId(), SeatLayerSeasonController.newOperationId())
    }

    func testAPageAnsweredWithoutAHoldIsAnError() async {
        let controller = readyController(transport: SeasonTransportSpy())
        do {
            _ = try await controller.holdSameSeat(["A1"])
            XCTFail("expected a decoding error")
        } catch let error as SeatLayerError {
            guard case .decoding = error else { return XCTFail("\(error)") }
        } catch {
            XCTFail("\(error)")
        }
        let restored = try? await controller.restoreOperation("sop_gone")
        XCTAssertNil(restored ?? nil)
    }

    func testWithNoPageToAskAHeldSeatStaysHeld() async throws {
        let controller = readyController()
        controller.sessionEvent("season.hold", payload: ["handoff": handoff("sop_1")], owner: nil)
        // The page goes away; the hold it reported is what a close keeps.
        controller.sessionBeginLoading(owner: nil)
        XCTAssertNil(controller.hold)
        let kept = try await controller.requestClose()
        XCTAssertEqual(kept, SeatLayerSeasonClose(outcome: .kept, operationId: "sop_1"))

        // A hold the page showed booked is nothing to keep.
        let booked = readyController()
        booked.sessionEvent("season.continue", payload: ["handoff": handoff("sop_2")], owner: nil)
        booked.sessionEvent("season.hold", payload: ["handoff": handoff("sop_2")], owner: nil)
        booked.sessionEvent("season.status", payload: ["kind": "booked", "operationId": "sop_2"], owner: nil)
        booked.sessionBeginLoading(owner: nil)
        let closed = try await booked.requestClose()
        XCTAssertEqual(closed.outcome, .closed)
        XCTAssertFalse(SeatLayerSeasonCloseOutcome.stayed.closes)
    }

    func testNothingIsSentBeforeThePageIsReady() async {
        let controller = SeatLayerSeasonController()
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

    private func bundle(
        capabilities: [String] = ["season-surface-v1", "season-app-shell-v1", "connection-state-v1"]
    ) -> BundleInfo {
        BundleInfo([
            "bundle": "1.0.9",
            "protocol": ["min": 1, "max": 2],
            "capabilities": .array(capabilities.map(JSONValue.string)),
            "commands": ["season.requestClose", "season.setThemeMode", "season.setViewportInsets"],
            "events": ["season.status", "season.hold"],
        ])
    }

    private func readyController(
        transport: any SeatLayerPickerCommandTransport = SeasonTransportSpy(),
        capabilities: [String] = ["season-surface-v1", "season-app-shell-v1", "connection-state-v1"]
    ) -> SeatLayerSeasonController {
        let controller = SeatLayerSeasonController()
        controller.sessionBeginLoading(owner: nil)
        controller.sessionConnect(transport: transport, bundleInfo: bundle(capabilities: capabilities), owner: nil)
        controller.sessionReady(ReadyInfo(["protocol": 2]), payload: nil, owner: nil)
        return controller
    }

    private func handoff(_ operation: String) -> JSONValue {
        [
            "seasonKey": "sea_1",
            "planActivationId": "pa_1",
            "operationId": .string(operation),
            "holdId": .string("h_\(operation)"),
            "expiresAt": 1_800_000_900_000,
            "allocations": ["x"],
        ]
    }
}

private actor SeasonTransportSpy: SeatLayerPickerCommandTransport {
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
