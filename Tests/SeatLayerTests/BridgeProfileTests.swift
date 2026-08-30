import XCTest
@testable import SeatLayer

final class BridgeProfileTests: XCTestCase {
    func testRawProfileKeepsProtocolOneAndTheExistingPayloadShape() throws {
        let profile = SeatLayerBridgeProfile.raw
        let configuration = SeatLayerConfiguration(event: "ev_raw", publicKey: "pk_test")
        let payload = profile.initPayload(configuration: configuration)

        XCTAssertEqual(profile.protocolRange, ProtocolRange(min: 1, max: 1))
        XCTAssertEqual(payload, configuration.initPayload())
        XCTAssertNil(payload["surface"])
        XCTAssertNil(payload["requirements"])
    }

    func testPickerProfileDeclaresTheExactNativeSurface() {
        let profile = SeatLayerBridgeProfile.picker(
            config: ["enableBestAvailable": .bool(false)]
        )
        let bundle = completePickerBundle()
        let payload = profile.initPayload(
            configuration: SeatLayerConfiguration(event: "ev_picker"),
            bundle: bundle
        )

        XCTAssertEqual(payload["protocol"], ["min": 2, "max": 2])
        XCTAssertEqual(payload["surface"], [
            "kind": "picker",
            "stateContract": 1,
            "chromeOwner": "native",
        ])
        XCTAssertEqual(payload["config"]?["event"]?.stringValue, "ev_picker")
        XCTAssertEqual(payload["config"]?["enableBestAvailable"]?.boolValue, false)
        XCTAssertEqual(payload["chrome"]?["owner"]?.stringValue, "native")
        XCTAssertEqual(payload["chrome"]?["seatTooltip"]?.boolValue, false)
        XCTAssertEqual(payload["chrome"]?["testModeIndicator"]?.boolValue, false)
        XCTAssertEqual(payload["chrome"]?["attribution"]?.boolValue, false)
        XCTAssertEqual(payload["chrome"]?["seatViewTitle"]?.boolValue, false)
        XCTAssertTrue(
            payload["requirements"]?["capabilities"]?.arrayValue?.contains(
                .string("native-chrome-contract-v1")
            ) == true
        )
    }

    func testPickerProfileDoesNotSuppressPanoramaDisclosureWithoutItsEventContract() {
        let profile = SeatLayerBridgeProfile.picker()
        let bundle = completePickerBundle(
            capabilities: profile.requiredCapabilities + ["native-seat-view-chrome-v1"],
            events: profile.requiredEvents
        )
        let payload = profile.initPayload(
            configuration: SeatLayerConfiguration(event: "ev_picker"),
            bundle: bundle
        )

        XCTAssertNil(payload["chrome"]?["seatViewTitle"])
        XCTAssertNil(payload["chrome"]?["seatViewCaption"])
        XCTAssertNil(payload["chrome"]?["seatViewBadge"])
    }

    func testPickerProfileFailsWhenProtocolTwoIsUnavailable() {
        let profile = SeatLayerBridgeProfile.picker()
        let oldBundle = BundleInfo([
            "bundle": "0.66.0",
            "protocol": ["min": 1, "max": 1],
            "capabilities": .array(profile.requiredCapabilities.map(JSONValue.string)),
            "commands": .array(profile.requiredCommands.map(JSONValue.string)),
            "events": .array(profile.requiredEvents.map(JSONValue.string)),
        ])

        XCTAssertThrowsError(try profile.validate(oldBundle)) { error in
            XCTAssertEqual((error as? SeatLayerError)?.code, "sl_incompatible")
        }
    }

    func testPickerProfileReportsMissingCapabilitiesCommandsAndEvents() {
        let profile = SeatLayerBridgeProfile.picker()
        let incomplete = BundleInfo([
            "bundle": "0.71.5",
            "protocol": ["min": 1, "max": 2],
            "capabilities": .array(
                profile.requiredCapabilities.dropLast().map(JSONValue.string)
            ),
            "commands": .array(profile.requiredCommands.dropLast().map(JSONValue.string)),
            "events": .array([]),
        ])

        XCTAssertThrowsError(try profile.validate(incomplete)) { error in
            guard case .incompatible(_, _, let reason) = error as? SeatLayerError else {
                return XCTFail("expected an incompatible picker contract")
            }
            XCTAssertTrue(reason.contains(profile.requiredCapabilities.last!), reason)
            XCTAssertTrue(reason.contains(profile.requiredCommands.last!), reason)
            XCTAssertTrue(reason.contains("picker.snapshot"), reason)
        }
    }

    func testDisablingImmersiveFeaturesRemovesOnlyTheirRequirements() throws {
        let profile = SeatLayerBridgeProfile.picker(
            enable3D: false,
            enableSeatView: false
        )

        XCTAssertFalse(profile.requiredCapabilities.contains("venue-3d-v1"))
        XCTAssertFalse(profile.requiredCapabilities.contains("seat-view-v1"))
        XCTAssertFalse(profile.requiredCommands.contains("picker.setBuyerView"))
        XCTAssertFalse(profile.requiredCommands.contains("picker.openSeatView"))
        XCTAssertNoThrow(try profile.validate(completePickerBundle(profile: profile)))
    }

    private func completePickerBundle(
        profile: SeatLayerBridgeProfile = .picker(),
        capabilities: [String]? = nil,
        commands: [String]? = nil,
        events: [String]? = nil
    ) -> BundleInfo {
        BundleInfo([
            "bundle": "0.71.5",
            "protocol": ["min": 1, "max": 2],
            "capabilities": .array(
                (capabilities ?? profile.requiredCapabilities + ["native-seat-view-chrome-v1"])
                    .map(JSONValue.string)
            ),
            "commands": .array(
                (commands ?? profile.requiredCommands).map(JSONValue.string)
            ),
            "events": .array(
                (events ?? profile.requiredEvents + ["seatView.changed"]).map(JSONValue.string)
            ),
        ])
    }
}
