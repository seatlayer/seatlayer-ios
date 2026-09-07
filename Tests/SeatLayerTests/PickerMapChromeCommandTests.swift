import Combine
import XCTest
@testable import SeatLayer

/// The commands that only paint or guard: the candidate seat, the pan that
/// makes room for its card, the rectangles a touch must not fall through, and
/// the accessible-section tour.
@MainActor
final class PickerMapChromeCommandTests: XCTestCase {
    func testPaintOnlyCommandsAreWithheldFromARuntimeThatDoesNotAdvertiseThem() async {
        let transport = ChromeTransportSpy()
        let controller = readyController(transport: transport, commands: [])

        XCTAssertFalse(controller.supportsSelectionFocus)
        XCTAssertFalse(controller.supportsSeatFraming)
        XCTAssertFalse(controller.supportsBlockedRegions)

        await controller.setSelectionFocus("seat-1")
        await controller.setBlockedRegions([.init(x: 0, y: 0, w: 10, h: 10)])
        let frame = await controller.frameSeat("seat-1")

        XCTAssertNil(frame)
        XCTAssertNil(controller.lastError)
        let calls = await transport.recordedCalls()
        XCTAssertTrue(calls.isEmpty)
    }

    func testSelectionFocusCarriesTheSeatAndClearsWithNull() async {
        let transport = ChromeTransportSpy()
        let controller = readyController(
            transport: transport,
            commands: ["picker.setSelectionFocus"]
        )

        await controller.setSelectionFocus("seat-7")
        await controller.setSelectionFocus(nil)

        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [
            .init(name: "picker.setSelectionFocus", payload: ["seatId": "seat-7"]),
            .init(name: "picker.setSelectionFocus", payload: ["seatId": .null]),
        ])
    }

    func testFrameSeatClampsItsFractionAndReadsTheRuntimeReply() async {
        let transport = ChromeTransportSpy(responses: [
            "picker.frameSeat": ["dy": .double(-84), "gestures": .int(3)],
        ])
        let controller = readyController(
            transport: transport,
            commands: ["picker.frameSeat"]
        )

        let frame = await controller.frameSeat(
            "  seat-7 ",
            fraction: 4.2,
            animate: true,
            gestures: -1
        )

        XCTAssertEqual(frame, SeatLayerSeatFrame(dy: -84, gestures: 3))
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [
            .init(name: "picker.frameSeat", payload: [
                "seatId": "seat-7",
                "fraction": .double(1),
                "animate": .bool(true),
                "gestures": .int(0),
            ]),
        ])
    }

    func testFrameSeatDefaultsToTheSheetFractionAndRefusesABlankSeat() async {
        let transport = ChromeTransportSpy()
        let controller = readyController(
            transport: transport,
            commands: ["picker.frameSeat"]
        )

        let refused = await controller.frameSeat("   ")
        XCTAssertNil(refused)
        _ = await controller.frameSeat("seat-2")

        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(
            calls.first?.payload?["fraction"]?.doubleValue,
            seatLayerSheetSeatFraction
        )
    }

    func testBlockedRegionsSendTheWholeListAndFloorABadRectangle() async {
        let transport = ChromeTransportSpy()
        let controller = readyController(
            transport: transport,
            commands: ["picker.setBlockedRegions"]
        )

        await controller.setBlockedRegions([
            .init(x: 4, y: 8, w: 36, h: 36),
            .init(x: .nan, y: 0, w: -10, h: .infinity),
        ])

        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls, [
            .init(name: "picker.setBlockedRegions", payload: [
                "rects": .array([
                    ["x": .double(4), "y": .double(8), "w": .double(36), "h": .double(36)],
                    ["x": .double(0), "y": .double(0), "w": .double(0), "h": .double(0)],
                ]),
            ]),
        ])
    }

    func testTheRegistryKeepsARectangleForItsLingerAfterAControlLeaves() async throws {
        var reports: [[SeatLayerBlockedRegion]] = []
        let registry = SeatLayerPickerBlockedRegionRegistry(linger: 0.05) {
            reports.append($0)
        }
        let disc = SeatLayerBlockedRegion(x: 0, y: 0, w: 36, h: 36)
        let pill = SeatLayerBlockedRegion(x: 40, y: 0, w: 80, h: 36)

        registry.set("disc", disc)
        registry.set("pill", pill)
        registry.set("disc", disc) // a repeat measures the same rectangle
        registry.set("disc", nil)

        // The touch this guards against lands after the control has gone.
        XCTAssertEqual(registry.regions, [disc, pill])
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(registry.regions, [pill])
        XCTAssertEqual(reports, [[disc], [disc, pill], [pill]])
    }

    func testTheRegistryDropsEverythingAtOnceWhenItsLayoutGoes() {
        var reports: [[SeatLayerBlockedRegion]] = []
        let registry = SeatLayerPickerBlockedRegionRegistry(linger: 0) {
            reports.append($0)
        }
        registry.set("disc", .init(x: 0, y: 0, w: 36, h: 36))
        registry.removeAll()

        XCTAssertTrue(registry.regions.isEmpty)
        XCTAssertEqual(reports.last, [])
    }

    func testTheCoalescedReportDropsARepeatAndSendsAChange() async {
        var sent: [[SeatLayerBlockedRegion]] = []
        let report = SeatLayerPickerBlockedRegionsReport(
            equals: seatLayerBlockedRegionsEqual
        ) { sent.append($0) }
        let first = [SeatLayerBlockedRegion(x: 0, y: 0, w: 1, h: 1)]
        let second = [SeatLayerBlockedRegion(x: 2, y: 0, w: 1, h: 1)]

        report.report(first)
        await report.flush()
        report.report(first)
        await report.flush()
        report.report(second)
        await report.flush()

        XCTAssertEqual(sent, [first, second])

        // A fresh runtime knows nothing until it is told.
        report.forget()
        report.report(second)
        await report.flush()
        XCTAssertEqual(sent, [first, second, second])
    }

    func testTheCoalescedReportFoldsSeveralReportsOfOnePassIntoTheLast() async {
        var sent: [[SeatLayerBlockedRegion]] = []
        let report = SeatLayerPickerBlockedRegionsReport(
            equals: seatLayerBlockedRegionsEqual
        ) { sent.append($0) }
        let last = [SeatLayerBlockedRegion(x: 9, y: 0, w: 1, h: 1)]

        report.report([SeatLayerBlockedRegion(x: 0, y: 0, w: 1, h: 1)])
        report.report([SeatLayerBlockedRegion(x: 1, y: 0, w: 1, h: 1)])
        report.report(last)
        await report.flush()

        XCTAssertEqual(sent, [last])
    }

    func testTheAccessibleTourReadsTheRuntimeStepAndTreatsNoneAsNoStep() async throws {
        let transport = ChromeTransportSpy(responses: [
            "picker.focusNextAccessibleSection": [
                "step": [
                    "id": "sec-b",
                    "label": "Balcony",
                    "free": .int(4),
                    "index": .int(1),
                    "total": .int(3),
                ],
            ],
        ])
        let controller = readyController(
            transport: transport,
            commands: [
                "picker.focusNextAccessibleSection",
                "picker.focusAccessibilityFilter",
            ],
            capabilities: ["accessibility-focus-v1", "section-access-counts-v1"]
        )

        XCTAssertTrue(controller.supportsAccessibilityFocus)
        XCTAssertTrue(controller.supportsSectionAccessCounts)

        let step = try await controller.focusNextAccessibleSection(types: ["wheelchair"])
        XCTAssertEqual(
            step,
            SeatLayerPickerAccessibleStep(
                id: "sec-b",
                label: "Balcony",
                free: 4,
                index: 1,
                total: 3
            )
        )

        // A runtime that answers with no step is telling the chrome that
        // nothing matches, which is not an error.
        XCTAssertNil(SeatLayerPickerAccessibleStep(nil))
        XCTAssertNil(SeatLayerPickerAccessibleStep(["id": ""]))

        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.first?.payload, ["types": .array(["wheelchair"])])
    }

    func testARetappedSeatIsPublishedWithoutLeavingTheSelection() throws {
        let controller = SeatLayerPickerController()
        var retapped: [String] = []
        var bag: Set<AnyCancellable> = []
        controller.seatRetaps
            .sink { retapped.append($0.id) }
            .store(in: &bag)

        let raw: JSONValue = ["id": "seat-3", "label": "A-3"]
        controller.accept(seatRetap: try raw.decode(SelectedSeat.self))

        XCTAssertEqual(retapped, ["seat-3"])
    }

    /// The last cover lowering must reach the runtime as an EMPTY list.
    ///
    /// Nothing else lifts the guard: the runtime keeps whatever rectangles it
    /// was last told about, so a reporter that stops talking leaves the map
    /// blocked for good.
    func testTheRuntimeIsToldTheListIsEmptyAfterTheLastCoverLowers() async throws {
        let transport = ChromeTransportSpy()
        let controller = readyController(
            transport: transport,
            commands: ["picker.setBlockedRegions"]
        )
        let reporter = SeatLayerPickerBlockedRegionsReporter(linger: 0.05)
        reporter.attach(to: controller)

        reporter.cover("decision", SeatLayerBlockedRegion(x: 0, y: 0, w: 390, h: 700))
        await reporter.flush()
        reporter.cover("decision", nil)
        try await Task.sleep(nanoseconds: 250_000_000)
        await reporter.flush()

        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), [
            "picker.setBlockedRegions", "picker.setBlockedRegions",
        ])
        XCTAssertEqual(calls.first?.payload, [
            "rects": .array([["x": .double(0), "y": .double(0), "w": .double(390), "h": .double(700)]]),
        ])
        XCTAssertEqual(calls.last?.payload, ["rects": .array([])])
    }

    private func readyController(
        transport: ChromeTransportSpy,
        commands: [String],
        capabilities: [String] = []
    ) -> SeatLayerPickerController {
        let bundle = BundleInfo([
            "bundle": "0.84.1",
            "protocol": ["min": 2, "max": 2],
            "capabilities": .array(capabilities.map(JSONValue.string)),
            "commands": .array(commands.map(JSONValue.string)),
            "events": .array(["picker.snapshot"]),
        ])
        let controller = SeatLayerPickerController(
            transport: transport,
            bundleInfo: bundle,
            revisionWaitNanoseconds: 1_000_000
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
}

private actor ChromeTransportSpy: SeatLayerPickerCommandTransport {
    struct Call: Sendable, Equatable {
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
