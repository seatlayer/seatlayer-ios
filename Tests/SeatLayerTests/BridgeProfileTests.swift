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
        XCTAssertEqual(payload["chrome"]?["seatViewCaption"]?.boolValue, false)
        // The runtime's own seat-view badge would otherwise be drawn on top of
        // the native seat-view chrome.
        XCTAssertEqual(payload["chrome"]?["seatViewBadge"]?.boolValue, false)
    }

    func testPickerRequiresOnlyWhatTheSessionCannotRunWithout() {
        let profile = SeatLayerBridgeProfile.picker()

        XCTAssertEqual(profile.requiredCapabilities, [
            "picker-session-v2",
            "picker-snapshot-v1",
            "picker-actions-v1",
            "native-picker-chrome-v1",
            "checkout-handoff-v1",
            "checkout-handoff-reject-v1",
            "hold-ownership-v1",
            "cart-line-remove-v1",
            "table-quantity-v1",
            "venue-3d-v1",
            "venue-3d-controls-v1",
            "seat-view-v1",
        ])
        // Commands and events are read from the bundle's own tables at the
        // call site, never demanded of the handshake.
        XCTAssertTrue(profile.requiredCommands.isEmpty)
        XCTAssertTrue(profile.requiredEvents.isEmpty)
    }

    func testAdditiveContractsAreOptionalAndWithheldSilently() {
        let profile = SeatLayerBridgeProfile.picker()
        for gate in [
            // A wrapper that failed the handshake over this one would refuse
            // to boot against a runtime it could have degraded on.
            "native-chrome-contract-v1",
            "native-seat-view-chrome-v1",
            "viewport-insets-v1",
            "floor-stack-v1",
            "chart-load-trace-v1",
            "availability-refresh-v1",
            "access-needs-v1",
            "hold-selection-v1",
            "seat-view-thumbnail-v1",
            "accessibility-focus-v1",
            "section-access-counts-v1",
            "seat-screen-point-v1",
            "category-availability-v1",
        ] {
            XCTAssertTrue(profile.optionalCapabilities.contains(gate), gate)
            XCTAssertFalse(profile.requiredCapabilities.contains(gate), gate)
        }
    }

    func testABundleWithNoCommandsOrEventsStillBoots() throws {
        let profile = SeatLayerBridgeProfile.picker()
        let bare = BundleInfo([
            "bundle": "0.84.1",
            "protocol": ["min": 1, "max": 2],
            "capabilities": .array(
                profile.requiredCapabilities.map(JSONValue.string)
            ),
            "commands": .array([]),
            "events": .array([]),
        ])

        XCTAssertNoThrow(try profile.validate(bare))
    }

    func testPickerProfileDoesNotSuppressPanoramaDisclosureWithoutItsEventContract() {
        let profile = SeatLayerBridgeProfile.picker()
        let bundle = completePickerBundle(
            capabilities: profile.requiredCapabilities + ["native-seat-view-chrome-v1"],
            events: []
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
            "commands": .array([]),
            "events": .array([]),
        ])

        XCTAssertThrowsError(try profile.validate(oldBundle)) { error in
            XCTAssertEqual((error as? SeatLayerError)?.code, "sl_incompatible")
        }
    }

    func testPickerProfileReportsAMissingRequiredCapability() {
        let profile = SeatLayerBridgeProfile.picker()
        let incomplete = BundleInfo([
            "bundle": "0.84.1",
            "protocol": ["min": 1, "max": 2],
            "capabilities": .array(
                profile.requiredCapabilities.dropLast().map(JSONValue.string)
            ),
            "commands": .array([]),
            "events": .array([]),
        ])

        XCTAssertThrowsError(try profile.validate(incomplete)) { error in
            guard case .incompatible(_, _, let reason) = error as? SeatLayerError else {
                return XCTFail("expected an incompatible picker contract")
            }
            XCTAssertTrue(reason.contains(profile.requiredCapabilities.last!), reason)
        }
    }

    func testDisablingImmersiveFeaturesRemovesOnlyTheirRequirements() throws {
        let profile = SeatLayerBridgeProfile.picker(
            enable3D: false,
            enableSeatView: false
        )

        XCTAssertFalse(profile.requiredCapabilities.contains("venue-3d-v1"))
        XCTAssertFalse(profile.requiredCapabilities.contains("venue-3d-controls-v1"))
        XCTAssertFalse(profile.requiredCapabilities.contains("seat-view-v1"))
        XCTAssertNoThrow(try profile.validate(completePickerBundle(profile: profile)))
    }

    private func completePickerBundle(
        profile: SeatLayerBridgeProfile = .picker(),
        capabilities: [String]? = nil,
        commands: [String]? = nil,
        events: [String]? = nil
    ) -> BundleInfo {
        BundleInfo([
            "bundle": "0.84.1",
            "protocol": ["min": 1, "max": 2],
            "capabilities": .array(
                (capabilities ?? profile.requiredCapabilities + ["native-seat-view-chrome-v1"])
                    .map(JSONValue.string)
            ),
            "commands": .array((commands ?? []).map(JSONValue.string)),
            "events": .array(
                (events ?? ["picker.snapshot", "seatView.changed"]).map(JSONValue.string)
            ),
        ])
    }
}
