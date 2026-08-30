import Combine
import XCTest
@testable import SeatLayer

@MainActor
final class PickerChartLoadTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testTraceDecodesKnownFieldsAndKeepsUnknownRawJSON() throws {
        let trace = try XCTUnwrap(decodeSeatLayerChartLoadEvent([
            "trace": [
                "event": "ev_reference",
                "scope": "event",
                "surface": "seating_chart",
                "outcome": "success",
                "stage": "",
                "ms": 800,
                "api": 569,
                "scene": 128,
                "panel": 0,
                "paint": 40,
                "normalize": 26,
                "renderer": 11,
                "availabilityMs": 563,
                "seats": 3_628,
                "floors": 2,
                "view": "map",
                "load": "cold",
                "transport": "pubapi",
                "chartBytes": 184_320,
                "chartCache": "hit",
                "server": 41,
                "r2Head": 7,
                "cacheLookup": 3,
                "r2Get": 0,
                "transform": 12,
                "host": "webview",
                "platform": "ios",
                "bundle": "0.71.5",
                "protocol": 2,
                "chromeOwner": "native",
                "bootMs": 1_018,
                "documentMs": 212,
                "handshakeMs": 1,
                "futureMetric": ["keep": .array(["me"])],
            ],
        ]))

        XCTAssertEqual(trace.event, "ev_reference")
        XCTAssertEqual(trace.scope, "event")
        XCTAssertEqual(trace.surface, "seating_chart")
        XCTAssertEqual(trace.ms, 800)
        XCTAssertEqual(trace.api, 569)
        XCTAssertEqual(trace.scene, 128)
        XCTAssertEqual(trace.panel, 0)
        XCTAssertEqual(trace.paint, 40)
        XCTAssertEqual(trace.normalize, 26)
        XCTAssertEqual(trace.renderer, 11)
        XCTAssertEqual(trace.availabilityMs, 563)
        XCTAssertEqual(trace.seats, 3_628)
        XCTAssertEqual(trace.floors, 2)
        XCTAssertEqual(trace.chartBytes, 184_320)
        XCTAssertEqual(trace.chartCache, "hit")
        XCTAssertEqual(trace.protocolRevision, 2)
        XCTAssertEqual(trace.bootMs, 1_018)
        XCTAssertEqual(trace.documentMs, 212)
        XCTAssertEqual(trace.handshakeMs, 1)
        XCTAssertEqual(trace.raw["futureMetric"], ["keep": .array(["me"])])
        XCTAssertTrue(trace.succeeded)
    }

    func testInvalidTypedMetricsStayAvailableOnlyInRaw() throws {
        let trace = try XCTUnwrap(decodeSeatLayerChartLoadTrace([
            "ms": -1,
            "seats": .double(2.5),
            "chartBytes": "future-number",
            "futureMetric": -4,
        ]))

        XCTAssertNil(trace.ms)
        XCTAssertNil(trace.seats)
        XCTAssertNil(trace.chartBytes)
        XCTAssertEqual(trace.raw["ms"], -1)
        XCTAssertEqual(trace.raw["seats"], .double(2.5))
        XCTAssertEqual(trace.raw["chartBytes"], "future-number")
        XCTAssertEqual(trace.raw["futureMetric"], -4)
        XCTAssertTrue(trace.succeeded)
        XCTAssertNil(decodeSeatLayerChartLoadEvent(["trace": .array([])]))
    }

    func testAdvertisedTraceMergesNativeTimingAndDoesNotReplay() throws {
        let controller = chartController(capability: true, event: true)
        controller.markReady(
            ReadyInfo([
                "protocol": 2,
                "mode": "test",
                "transport": "ios",
                "chart": ["event": "ev_reference"],
            ]),
            payload: nil,
            readyAtMilliseconds: 1_450
        )

        var first: [SeatLayerChartLoad] = []
        controller.chartLoads
            .sink { first.append($0) }
            .store(in: &cancellables)

        controller.accept(chartLoad: ["trace": [
            "outcome": "success",
            "bootMs": 1_000,
        ]])

        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first[0].tapToReadyMs, 1_350)
        XCTAssertEqual(first[0].hostMs, 350)
        XCTAssertEqual(first[0].ready?.eventKey, "ev_reference")

        var late: [SeatLayerChartLoad] = []
        controller.chartLoads
            .sink { late.append($0) }
            .store(in: &cancellables)
        XCTAssertTrue(late.isEmpty)

        controller.accept(chartLoad: ["trace": [
            "outcome": "failed",
            "stage": "api",
        ]])

        XCTAssertEqual(first.count, 2)
        XCTAssertEqual(late.count, 1)
        XCTAssertFalse(late[0].trace.succeeded)
        XCTAssertNil(late[0].hostMs)
    }

    func testSuccessfulTraceBeforeReadyWaitsForNativeTiming() throws {
        let controller = chartController(capability: true, event: true)
        var loads: [SeatLayerChartLoad] = []
        controller.chartLoads
            .sink { loads.append($0) }
            .store(in: &cancellables)

        controller.accept(chartLoad: ["trace": [
            "outcome": "success",
            "bootMs": 1_000,
        ]])
        XCTAssertTrue(loads.isEmpty)

        controller.markReady(
            ReadyInfo([
                "protocol": 2,
                "mode": "test",
                "transport": "ios",
                "chart": ["event": "ev_reference"],
            ]),
            payload: nil,
            readyAtMilliseconds: 1_450
        )

        XCTAssertEqual(loads.count, 1)
        XCTAssertEqual(loads[0].tapToReadyMs, 1_350)
        XCTAssertEqual(loads[0].hostMs, 350)
        XCTAssertEqual(loads[0].ready?.eventKey, "ev_reference")
    }

    func testFailedTraceBeforeReadyPublishesImmediately() {
        let controller = chartController(capability: true, event: true)
        var loads: [SeatLayerChartLoad] = []
        controller.chartLoads
            .sink { loads.append($0) }
            .store(in: &cancellables)

        controller.accept(chartLoad: ["trace": [
            "outcome": "failed",
            "stage": "api",
        ]])

        XCTAssertEqual(loads.count, 1)
        XCTAssertFalse(loads[0].trace.succeeded)
        XCTAssertNil(loads[0].tapToReadyMs)
    }

    func testTraceRequiresBothExactCapabilityAndEvent() {
        for (capability, event, expected) in [
            (false, false, 0),
            (true, false, 0),
            (false, true, 0),
            (true, true, 1),
        ] {
            let controller = chartController(capability: capability, event: event)
            var seen = 0
            controller.chartLoads
                .sink { _ in seen += 1 }
                .store(in: &cancellables)

            controller.accept(chartLoad: ["trace": ["outcome": "failed"]])
            XCTAssertEqual(seen, expected)
        }
    }

    private func chartController(
        capability: Bool,
        event: Bool
    ) -> SeatLayerPickerController {
        let controller = SeatLayerPickerController()
        controller.beginLoading(startedAtMilliseconds: 100)
        controller.connect(
            transport: PickerChartLoadTransport(),
            bundleInfo: BundleInfo([
                "bundle": "0.71.5",
                "protocol": ["min": 2, "max": 2],
                "capabilities": .array(
                    capability ? ["chart-load-trace-v1"] : []
                ),
                "commands": .array([]),
                "events": .array(
                    event ? ["telemetry.chartLoad"] : []
                ),
            ])
        )
        return controller
    }
}

private actor PickerChartLoadTransport: SeatLayerPickerCommandTransport {
    func command(_ name: String, payload: JSONValue?) async throws -> JSONValue {
        .object([:])
    }
}
