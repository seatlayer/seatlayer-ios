import XCTest
@testable import SeatLayer

/// Version negotiation, exercised in BOTH upgrade directions.
final class NegotiationTests: XCTestCase {

    func testAgreesOnTheHighestRevisionBothSidesSpeak() {
        XCTAssertEqual(
            negotiate(native: ProtocolRange(min: 1, max: 1), web: ProtocolRange(min: 1, max: 1)),
            .agreed(1)
        )
        XCTAssertEqual(
            negotiate(native: ProtocolRange(min: 1, max: 3), web: ProtocolRange(min: 2, max: 5)),
            .agreed(3)
        )
    }

    /// Old app, new bundle: the bundle speaks down to what the app knows.
    func testOldAppWithANewerBundleAgreesOnTheAppsMaximum() {
        let result = negotiate(
            native: ProtocolRange(min: 1, max: 1),
            web: ProtocolRange(min: 1, max: 3)
        )
        XCTAssertEqual(result, .agreed(1))
    }

    /// New app, old bundle: the app can still drop to the bundle's revision.
    func testNewAppWithAnOlderBundleAgreesOnTheBundlesMaximum() {
        let result = negotiate(
            native: ProtocolRange(min: 1, max: 4),
            web: ProtocolRange(min: 1, max: 1)
        )
        XCTAssertEqual(result, .agreed(1))
    }

    /// New app that has DROPPED support for v1, old bundle that only speaks v1.
    /// No shared revision — refuse rather than half-speak a protocol.
    func testRefusesWhenTheAppHasOutgrownTheBundle() {
        guard case .incompatible(let reason) = negotiate(
            native: ProtocolRange(min: 2, max: 4),
            web: ProtocolRange(min: 1, max: 1)
        ) else { return XCTFail("expected incompatible") }
        XCTAssertTrue(reason.contains("no shared protocol revision"))
    }

    /// The mirror case: a bundle that has moved past everything the app knows.
    func testRefusesWhenTheBundleHasOutgrownTheApp() {
        guard case .incompatible = negotiate(
            native: ProtocolRange(min: 1, max: 1),
            web: ProtocolRange(min: 2, max: 4)
        ) else { return XCTFail("expected incompatible") }
    }

    // MARK: - Range parsing

    func testNormalisesABareNumberIntoARange() {
        XCTAssertEqual(ProtocolRange.from(.int(1)), ProtocolRange(min: 1, max: 1))
    }

    func testParsesAnExplicitRange() {
        XCTAssertEqual(
            ProtocolRange.from(["min": 1, "max": 4]),
            ProtocolRange(min: 1, max: 4)
        )
    }

    func testRejectsAMalformedProtocolField() {
        XCTAssertNil(ProtocolRange.from(.string("v1")))
        XCTAssertNil(ProtocolRange.from(nil))
        XCTAssertNil(ProtocolRange.from(["min": 4, "max": 1])) // inverted
        XCTAssertNil(ProtocolRange.from(["min": 1]))
    }

    // MARK: - Error surfacing

    /// An incompatible pairing must be a typed, actionable error — not a blank
    /// view the user is left staring at.
    func testIncompatibilitySurfacesAsAnAppUpdateError() {
        let error = SeatLayerError.incompatible(
            native: ProtocolRange(min: 1, max: 1),
            web: ProtocolRange(min: 2, max: 4),
            reason: "no shared protocol revision"
        )
        XCTAssertTrue(error.requiresAppUpdate)
        XCTAssertEqual(error.code, "sl_incompatible")
        let message = error.errorDescription ?? ""
        XCTAssertTrue(message.contains("update the app"), message)
    }

    func testOtherErrorsDoNotAskForAnAppUpdate() {
        XCTAssertFalse(SeatLayerError.timeout(command: "hold", seconds: 15).requiresAppUpdate)
        XCTAssertFalse(SeatLayerError.bridge(BridgeErrorPayload(code: "sold_out", message: "gone")).requiresAppUpdate)
    }
}
