import XCTest
@testable import SeatLayer

/// The bundle ships new enum values to apps compiled a year earlier. Nothing
/// here may throw, and nothing may crash.
final class UnknownToleranceTests: XCTestCase {

    // MARK: - Open enums

    func testEventModeDecodesAnUnfamiliarValue() throws {
        XCTAssertEqual(try decode(EventMode.self, from: "\"live\""), .live)
        XCTAssertEqual(try decode(EventMode.self, from: "\"test\""), .test)

        // A mode introduced after this app shipped.
        let rehearsal = try decode(EventMode.self, from: "\"rehearsal\"")
        XCTAssertEqual(rehearsal, .unknown("rehearsal"))
        XCTAssertTrue(rehearsal.isUnknown)
        XCTAssertFalse(EventMode.live.isUnknown)
        // And it round-trips back out unchanged.
        XCTAssertEqual(rehearsal.rawValue, "rehearsal")
    }

    func testTransportNameDecodesAnUnfamiliarValue() throws {
        XCTAssertEqual(try decode(TransportName.self, from: "\"ios\""), .ios)
        XCTAssertEqual(try decode(TransportName.self, from: "\"rn\""), .reactNative)
        XCTAssertEqual(try decode(TransportName.self, from: "\"visionos\""), .unknown("visionos"))
    }

    func testObjectTypeDecodesAnUnfamiliarValue() throws {
        XCTAssertEqual(try decode(ObjectType.self, from: "\"seat\""), .seat)
        XCTAssertEqual(try decode(ObjectType.self, from: "\"cabana\""), .unknown("cabana"))
    }

    func testSeatStatusDecodesAnUnfamiliarValue() throws {
        XCTAssertEqual(try decode(SeatStatus.self, from: "\"booked\""), .booked)
        XCTAssertEqual(try decode(SeatStatus.self, from: "\"reserved_for_donor\""), .unknown("reserved_for_donor"))
    }

    func testViewModeDecodesAnUnfamiliarValue() throws {
        XCTAssertEqual(try decode(SeatLayerViewMode.self, from: "\"perspective\""), .perspective)
        XCTAssertEqual(
            try decode(SeatLayerViewMode.self, from: "\"immersive\""),
            .unknown("immersive")
        )
    }

    // MARK: - Structs

    /// A payload gaining fields is the normal case, not an error case.
    func testStructsIgnoreFieldsThisBuildDoesNotKnow() throws {
        let json: JSONValue = [
            "id": "s1",
            "label": "A-1",
            "categoryKey": "vip",
            "price": 45,
            "loyaltyBonusPoints": 250,        // added after this app shipped
            "seatViewImage": ["url": "x"],    // ditto
        ]
        let seat = try json.decode(SelectedSeat.self)
        XCTAssertEqual(seat.id, "s1")
        XCTAssertEqual(seat.label, "A-1")
        XCTAssertEqual(seat.price, 45)
    }

    /// Optional fields that the bundle omits must simply be absent.
    func testStructsTolerateOmittedOptionalFields() throws {
        let minimal: JSONValue = ["id": "s1", "label": "A-1"]
        let seat = try minimal.decode(SelectedSeat.self)
        XCTAssertNil(seat.categoryKey)
        XCTAssertNil(seat.tiers)
        XCTAssertNil(seat.commercial)
        // Buyer-facing label falls back to the inventory label.
        XCTAssertEqual(seat.buyerFacingLabel, "A-1")
    }

    func testDisplayLabelIsPreferredForDisplayOnly() throws {
        let labelled: JSONValue = ["id": "s1", "label": "A-1", "displayLabel": "Balcony 1"]
        let seat = try labelled.decode(SelectedSeat.self)
        XCTAssertEqual(seat.buyerFacingLabel, "Balcony 1")
        XCTAssertEqual(seat.label, "A-1", "booking identity must remain `label`")
    }

    func testHoldLineItemToleratesAnUnknownObjectType() throws {
        let raw: JSONValue = ["label": "GA-1", "objectType": "cabana", "unitPrice": 30, "currency": "USD"]
        let item = try raw.decode(HoldLineItem.self)
        XCTAssertEqual(item.objectType, .unknown("cabana"))
        XCTAssertEqual(item.unitPrice, 30)
    }

    func testHoldResultExposesExpiryAsADate() throws {
        let raw: JSONValue = ["holdId": "h1", "expiresAt": 1_750_000_000_000]
        let hold = try raw.decode(HoldResult.self)
        XCTAssertEqual(hold.holdId, "h1")
        XCTAssertEqual(hold.expiryDate.timeIntervalSince1970, 1_750_000_000, accuracy: 0.001)
    }

    // MARK: - Handshake payloads

    /// `ReadyInfo` must survive a `sys.ready` whose mode and transport are both
    /// values this build has never seen.
    func testReadyInfoToleratesUnknownModeAndTransport() {
        let info = ReadyInfo([
            "protocol": 1,
            "mode": "rehearsal",
            "transport": "visionos",
            "chart": ["event": "ev_1"],
        ])
        XCTAssertEqual(info.protocolRevision, 1)
        XCTAssertEqual(info.mode, .unknown("rehearsal"))
        XCTAssertEqual(info.transport, .unknown("visionos"))
        XCTAssertEqual(info.eventKey, "ev_1")
    }

    func testReadyInfoToleratesAnEntirelyEmptyPayload() {
        let info = ReadyInfo(nil)
        XCTAssertEqual(info.protocolRevision, seatLayerProtocolMin)
        XCTAssertNil(info.eventKey)
    }

    func testBundleInfoReportsAdvertisedCapabilities() {
        let info = BundleInfo([
            "bundle": "0.25.0",
            "protocol": ["min": 1, "max": 1],
            "capabilities": .array(["hold", "best-available"]),
            "events": .array(["sys.ready"]),
            "commands": .array(["hold", "zoomToFit"]),
        ])
        XCTAssertEqual(info.bundle, "0.25.0")
        XCTAssertEqual(info.protocolRange, ProtocolRange(min: 1, max: 1))
        XCTAssertTrue(info.supports(command: "hold"))
        XCTAssertFalse(info.supports(command: "holdGA"))
        XCTAssertTrue(info.supports(capability: "best-available"))
    }

    /// An error code is an OPEN set: an API code we have never seen must arrive
    /// intact rather than be normalised away.
    func testBridgeErrorPayloadCarriesAnyCode() {
        let payload = BridgeErrorPayload([
            "code": "queue_position_expired",
            "message": "your place in the queue lapsed",
            "details": ["position": 41],
        ])
        XCTAssertEqual(payload.code, "queue_position_expired")
        XCTAssertEqual(payload.details?["position"]?.intValue, 41)
    }

    func testBridgeErrorPayloadHasASafeDefaultForAMalformedError() {
        let payload = BridgeErrorPayload(nil)
        XCTAssertEqual(payload.code, "unknown_error")
        XCTAssertEqual(payload.message, "")
    }

    // MARK: - Config

    func testInitPayloadMatchesTheWebContract() {
        var configuration = SeatLayerConfiguration(
            event: "ev_9",
            apiBase: "https://api.test",
            maxSelection: 4,
            locale: "de",
            initialView: .perspective
        )
        configuration.hostInfo = ["app": "1.4.0"]

        let payload = configuration.initPayload()
        XCTAssertEqual(payload["protocol"], ["min": 1, "max": 1])
        XCTAssertEqual(payload["config"]?["event"]?.stringValue, "ev_9")
        XCTAssertEqual(payload["config"]?["apiBase"]?.stringValue, "https://api.test")
        XCTAssertEqual(payload["config"]?["maxSelection"]?.intValue, 4)
        XCTAssertEqual(payload["config"]?["locale"]?.stringValue, "de")
        XCTAssertEqual(payload["config"]?["initialView"]?.stringValue, "perspective")
        XCTAssertEqual(payload["host"]?["platform"]?.stringValue, "ios")
        XCTAssertEqual(payload["host"]?["app"]?.stringValue, "1.4.0")
        // The native side draws its own seat sheet by default.
        XCTAssertEqual(payload["chrome"]?["seatTooltip"]?.boolValue, false)
        // Absent options must be OMITTED, not sent as null.
        XCTAssertNil(payload["config"]?["currency"])
        XCTAssertNil(payload["config"]?["publicKey"])
    }

    // MARK: - Helper

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
