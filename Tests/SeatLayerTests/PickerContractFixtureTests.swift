import Foundation
import XCTest
@testable import SeatLayer

final class PickerContractFixtureTests: XCTestCase {
    func testEveryPureHelperFixtureExecutesAgainstTheShippingProjection() throws {
        let document = try decode(
            HelperFixtureDocument.self,
            at: "Contracts/picker-pure-helpers.v1.json"
        )
        var executed: [String] = []

        for fixture in document.cases {
            executed.append(fixture.id)
            switch fixture.helper {
            case "ticketIdentity":
                let identity = SeatLayerPickerProjections.ticketIdentity(
                    of: try line(fixture.input["line"])
                )
                XCTAssertEqual(identity.lineKey, fixture.expected["lineKey"]?.stringValue, fixture.id)
                XCTAssertEqual(identity.removalLabel, fixture.expected["removalLabel"]?.stringValue, fixture.id)
                XCTAssertEqual(identity.objectId, fixture.expected["objectId"]?.stringValue, fixture.id)
                XCTAssertEqual(identity.seatId, fixture.expected["seatId"]?.stringValue, fixture.id)

            case "confirmedCart":
                let items = try lines(fixture.input["items"])
                let pending = try fixture.input["pending"]?.decode(SelectedSeat.self)
                let result = SeatLayerPickerProjections.confirmedCart(items, pending: pending)
                XCTAssertEqual(
                    result.items.map(\.lineKey),
                    fixture.expected["lineKeys"]?.arrayValue?.compactMap(\.stringValue),
                    fixture.id
                )
                assertTotals(result.totals, expected: fixture.expected, id: fixture.id)

            case "totals":
                assertTotals(
                    SeatLayerPickerProjections.totals(try lines(fixture.input["items"])),
                    expected: fixture.expected,
                    id: fixture.id
                )

            case "denseRuns":
                let display = SeatLayerPickerDenseDisplay(
                    categoryLabel: fixture.input["display"]?["categoryLabel"]?.stringValue,
                    amountText: fixture.input["display"]?["amountText"]?.stringValue
                )
                let runs = SeatLayerPickerProjections.denseRuns(
                    try lines(fixture.input["items"]).map {
                        SeatLayerPickerProjections.denseLine($0, display: display)
                    }
                )
                let expectedRuns = try XCTUnwrap(fixture.expected["runs"]?.arrayValue, fixture.id)
                XCTAssertEqual(runs.count, expectedRuns.count, fixture.id)
                for (run, expected) in zip(runs, expectedRuns) {
                    XCTAssertEqual(
                        run.members.map { $0.item.lineKey },
                        expected["memberLineKeys"]?.arrayValue?.compactMap(\.stringValue),
                        fixture.id
                    )
                    XCTAssertEqual(
                        SeatLayerPickerProjections.membersInSeatOrder(run).map { $0.item.lineKey },
                        expected["orderedMemberLineKeys"]?.arrayValue?.compactMap(\.stringValue),
                        fixture.id
                    )
                    XCTAssertEqual(run.seatsLabel, expected["seatsLabel"]?.stringValue, fixture.id)
                    XCTAssertEqual(run.quantity, expected["quantity"]?.intValue, fixture.id)
                    XCTAssertEqual(
                        run.total,
                        try XCTUnwrap(expected["total"]?.doubleValue, fixture.id),
                        accuracy: 0.000_001,
                        fixture.id
                    )
                }

            case "seatRunLabel":
                let labels = fixture.input["labels"]?.arrayValue?.compactMap(\.stringValue) ?? []
                XCTAssertEqual(
                    SeatLayerPickerProjections.seatRunLabel(labels),
                    fixture.expected["label"]?.stringValue,
                    fixture.id
                )

            case "canUndoRemoval":
                let item = try line(fixture.input["line"])
                let values = try XCTUnwrap(fixture.input["checks"]?.arrayValue, fixture.id).map { check in
                    SeatLayerPickerProjections.canUndoRemoval(
                        line: item,
                        phase: try XCTUnwrap(
                            SeatLayerPickerRemovalPhase(rawValue: try XCTUnwrap(check["phase"]?.stringValue)),
                            fixture.id
                        ),
                        sameSession: try XCTUnwrap(check["sameSession"]?.boolValue, fixture.id),
                        stillAbsent: try XCTUnwrap(check["stillAbsent"]?.boolValue, fixture.id)
                    )
                }
                XCTAssertEqual(
                    values,
                    fixture.expected["values"]?.arrayValue?.compactMap(\.boolValue),
                    fixture.id
                )

            case "seatIdentity":
                let seat = try XCTUnwrap(fixture.input["seat"]).decode(SelectedSeat.self)
                XCTAssertEqual(
                    SeatLayerPickerProjections.seatIdentity(seat),
                    fixture.expected["identity"]?.stringValue,
                    fixture.id
                )

            default:
                XCTFail("Unexecuted helper fixture \(fixture.id): \(fixture.helper)")
            }
        }

        XCTAssertEqual(document.version, 1)
        XCTAssertEqual(executed, Self.helperFixtureIDs)
        XCTAssertEqual(Set(executed).count, executed.count)
    }

    func testBehaviorFixturesHaveStableIDsAndCompleteCrossPlatformOutcomes() throws {
        let root = try json(at: "Contracts/picker-behavior.v1.json")
        XCTAssertEqual(root["version"]?.intValue, 1)
        let cases = try XCTUnwrap(root["cases"]?.arrayValue)
        let requiredKeys: Set<String> = [
            "id", "concept", "authoritativeInput", "localEffect", "command",
            "successResult", "failure", "recovery",
        ]

        for fixture in cases {
            let fields = try XCTUnwrap(fixture.objectValue)
            XCTAssertTrue(requiredKeys.isSubset(of: Set(fields.keys)), fields["id"]?.stringValue ?? "missing id")
        }

        let ids = cases.compactMap { $0["id"]?.stringValue }
        XCTAssertEqual(ids, Self.behaviorFixtureIDs)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testPublicConceptContractMatchesTheShippingTwentyFivePartEnum() throws {
        let root = try json(at: "Contracts/picker-public-concepts.v1.json")
        let identifiers = root["builderParts"]?.arrayValue?.compactMap { $0["id"]?.stringValue }
        XCTAssertEqual(identifiers, SeatLayerPickerPart.allCases.map(\.rawValue))
        XCTAssertEqual(identifiers?.count, 25)
        XCTAssertEqual(
            root["builderContext"]?.arrayValue?.compactMap(\.stringValue),
            [
                "part", "snapshot", "controller", "presentation", "themeMode",
                "theme", "strings", "options", "style", "defaultContent",
            ]
        )
    }

    func testProtocolLockMatchesCoreAndConditionalHandshakeProfiles() throws {
        let root = try json(at: "Contracts/seatlayer-picker-protocol-v2.json")
        let core = SeatLayerBridgeProfile.picker(enable3D: false, enableSeatView: false)
        XCTAssertEqual(root["protocolRange"]?["min"]?.intValue, core.protocolRange.min)
        XCTAssertEqual(root["protocolRange"]?["max"]?.intValue, core.protocolRange.max)
        XCTAssertEqual(root["snapshotSchema"]?.stringValue, seatLayerPickerSnapshotSchema)
        XCTAssertEqual(strings(root["requiredCapabilities"]), core.requiredCapabilities)
        XCTAssertEqual(strings(root["requiredCommands"]), core.requiredCommands)
        XCTAssertEqual(strings(root["requiredEvents"]), core.requiredEvents)
        XCTAssertEqual(strings(root["optionalCapabilities"]), core.optionalCapabilities)

        let complete = SeatLayerBridgeProfile.picker()
        XCTAssertEqual(
            complete.requiredCapabilities,
            core.requiredCapabilities
                + strings(root["conditionalRequirements"]?["enable3D"]?["capabilities"])
                + strings(root["conditionalRequirements"]?["enableSeatView"]?["capabilities"])
        )
        XCTAssertEqual(
            complete.requiredCommands,
            core.requiredCommands
                + strings(root["conditionalRequirements"]?["enable3D"]?["commands"])
                + strings(root["conditionalRequirements"]?["enableSeatView"]?["commands"])
        )
        XCTAssertEqual(root["examples"]?["initialize"]?["p"]?["host"]?["sdk"]?.stringValue, SeatLayer.sdkVersion)
    }

    private func assertTotals(
        _ totals: SeatLayerPickerCartTotals,
        expected: JSONValue,
        id: String
    ) {
        XCTAssertEqual(totals.quantity, expected["quantity"]?.intValue, id)
        XCTAssertEqual(
            totals.total,
            expected["total"]?.doubleValue ?? .nan,
            accuracy: 0.000_001,
            id
        )
        let expectedCurrency = expected["currency"]?.isNull == true
            ? nil
            : expected["currency"]?.stringValue
        XCTAssertEqual(totals.currency, expectedCurrency, id)
        XCTAssertEqual(totals.hasMixedCurrencies, expected["hasMixedCurrencies"]?.boolValue, id)
    }

    private func lines(_ value: JSONValue?) throws -> [SeatLayerPickerCartLine] {
        try XCTUnwrap(value?.arrayValue).map(line)
    }

    private func line(_ value: JSONValue?) throws -> SeatLayerPickerCartLine {
        let fields = try XCTUnwrap(value?.objectValue)
        return SeatLayerPickerCartLine(
            lineKey: fields["lineKey"]?.stringValue ?? "",
            label: fields["label"]?.stringValue ?? "",
            displayLabel: fields["displayLabel"]?.stringValue,
            displayType: fields["displayType"]?.stringValue,
            objectId: fields["objectId"]?.stringValue ?? "",
            objectType: fields["objectType"]?.stringValue ?? "",
            categoryKey: fields["categoryKey"]?.stringValue ?? "",
            tierId: fields["tierId"]?.stringValue,
            tierName: fields["tierName"]?.stringValue,
            unitPrice: fields["unitPrice"]?.doubleValue ?? 0,
            currency: fields["currency"]?.stringValue ?? "",
            quantity: fields["quantity"]?.intValue ?? 1,
            seatId: fields["seatId"]?.stringValue,
            sectionLabel: fields["sectionLabel"]?.stringValue,
            rowLabel: fields["rowLabel"]?.stringValue,
            seatNumber: fields["seatNumber"]?.stringValue
        )
    }

    private func strings(_ value: JSONValue?) -> [String] {
        value?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    private func json(at path: String) throws -> JSONValue {
        try decode(JSONValue.self, at: path)
    }

    private func decode<T: Decodable>(_ type: T.Type, at path: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: repositoryRoot.appendingPathComponent(path)))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private struct HelperFixtureDocument: Decodable {
        let version: Int
        let cases: [HelperFixture]
    }

    private struct HelperFixture: Decodable {
        let id: String
        let helper: String
        let input: JSONValue
        let expected: JSONValue
    }

    private static let helperFixtureIDs = [
        "ticket-identity-addressed-v1",
        "confirmed-cart-per-line-addressing-v1",
        "totals-mixed-currency-v1",
        "dense-runs-adjacent-fold-and-order-v1",
        "seat-run-label-never-invents-gaps-v1",
        "undo-requires-same-session-absence-v1",
        "structural-seat-identity-v1",
    ]

    private static let behaviorFixtureIDs = [
        "confirmation-newest-unanswered-v1",
        "confirmation-accept-is-local-v1",
        "confirmation-cancel-exact-v1",
        "checkout-single-flight-host-accept-v1",
        "checkout-host-rejection-releases-exact-handoff-v1",
        "back-ladder-v1",
        "close-picker-owned-hold-v1",
        "close-host-owned-hold-v1",
        "empty-truth-v1",
        "theme-continuity-v1",
        "viewport-insets-coalesced-v1",
        "floor-stack-capability-v1",
        "exclusive-prompt-lease-v1",
        "immersive-renderer-ownership-v1",
        "foreground-availability-reconciliation-v1",
    ]
}
