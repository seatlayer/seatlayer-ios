import XCTest
@testable import SeatLayer

/// Envelope encode/decode, checked against the shapes in the web bundle's own
/// `bridgeHost.test.ts`.
final class EnvelopeTests: XCTestCase {

    // MARK: - Decoding

    func testDecodesAResEnvelope() {
        let frame: JSONValue = ["sl": 1, "k": "res", "id": "id-zoomIn", "t": "zoomIn", "p": .object([:])]
        let envelope = Envelope.decode(frame)
        XCTAssertEqual(envelope?.kind, .res)
        XCTAssertEqual(envelope?.id, "id-zoomIn")
        XCTAssertEqual(envelope?.type, "zoomIn")
        XCTAssertEqual(envelope?.payload, .object([:]))
        XCTAssertNil(envelope?.sequence)
    }

    func testDecodesAnEvtEnvelopeWithSequence() {
        let frame: JSONValue = [
            "sl": 1, "k": "evt", "n": 4, "t": "sys.ready",
            "p": ["protocol": 1, "mode": "live", "transport": "ios", "chart": ["event": "ev_1"]],
        ]
        let envelope = Envelope.decode(frame)
        XCTAssertEqual(envelope?.kind, .evt)
        XCTAssertEqual(envelope?.sequence, 4)
        XCTAssertEqual(envelope?.payload?["mode"]?.stringValue, "live")
    }

    /// The web side rejects anything without the marker; so must we.
    func testRejectsFramesWithoutTheEnvelopeMarker() {
        XCTAssertNil(Envelope.decode(["k": "res", "t": "zoomIn"]))
        XCTAssertNil(Envelope.decode(["sl": 2, "k": "res", "t": "zoomIn"]))
        XCTAssertNil(Envelope.decode(["hello": "world"]))
        XCTAssertNil(Envelope.decode(.string("not an envelope")))
        XCTAssertNil(Envelope.decode(.array([1, 2, 3])))
    }

    func testRejectsFramesWithAMissingOrEmptyType() {
        XCTAssertNil(Envelope.decode(["sl": 1, "k": "res"]))
        XCTAssertNil(Envelope.decode(["sl": 1, "k": "res", "t": ""]))
    }

    func testRejectsFramesWhoseIdOrSequenceHasTheWrongPrimitive() {
        XCTAssertNil(Envelope.decode(["sl": 1, "k": "res", "t": "zoomIn", "id": 7]))
        XCTAssertNil(Envelope.decode(["sl": 1, "k": "evt", "t": "hint", "n": "4"]))
    }

    /// Regression: JavaScript has ONE number type, so `n: 1` arrives from
    /// `WKScriptMessage` as an NSNumber holding a double. Requiring a strict
    /// integer here rejected every `evt` — the handshake reached `init`, the
    /// chart rendered, and `sys.ready` was then dropped on the floor, so the
    /// native side timed out staring at a fully drawn map.
    func testAcceptsAnEvtWhoseSequenceArrivesAsADouble() {
        let frame = Envelope.decode(["sl": 1, "k": "evt", "n": .double(1), "t": "sys.ready"])
        XCTAssertEqual(frame?.sequence, 1)

        // And the same frame coming the way it really does — through Foundation.
        let body: [String: Any] = ["sl": NSNumber(value: 1.0), "k": "evt",
                                   "n": NSNumber(value: 3.0), "t": "sys.ready"]
        XCTAssertEqual(Envelope.decode(foundation: body)?.sequence, 3)
    }

    /// A non-integral sequence is still malformed, matching `isFiniteInt`.
    func testRejectsANonIntegralSequence() {
        XCTAssertNil(Envelope.decode(["sl": 1, "k": "evt", "n": .double(1.5), "t": "hint"]))
        XCTAssertNil(Envelope.decode(["sl": 1, "k": "evt", "n": .double(.infinity), "t": "hint"]))
    }

    func testDecodesFromAJSONString() {
        let json = #"{"sl":1,"k":"err","id":"c1","t":"hold","p":{"code":"sold_out","message":"seats gone"}}"#
        let envelope = Envelope.decode(json: json)
        XCTAssertEqual(envelope?.kind, .err)
        XCTAssertEqual(envelope?.payload?["code"]?.stringValue, "sold_out")
        XCTAssertNil(Envelope.decode(json: "not json"))
    }

    // MARK: - Encoding

    func testEncodesACmdOmittingAbsentFields() {
        let envelope = Envelope(kind: .cmd, type: "hold", id: "n1", payload: ["ttlMs": 5000])
        XCTAssertEqual(envelope.encoded(), [
            "sl": 1, "k": "cmd", "id": "n1", "t": "hold", "p": ["ttlMs": 5000],
        ])
        // No `n` on a cmd, no `p` when there is no payload.
        XCTAssertEqual(
            Envelope(kind: .cmd, type: "zoomIn", id: "n2").encoded(),
            ["sl": 1, "k": "cmd", "id": "n2", "t": "zoomIn"]
        )
    }

    func testEncodesInitWithTheWireKindName() {
        // The Swift case is `initialize` because `init` is a keyword; the WIRE
        // name must still be exactly `init`.
        let envelope = Envelope(kind: .initialize, type: "init", payload: ["protocol": 1])
        XCTAssertEqual(envelope.encoded()["k"]?.stringValue, "init")
    }

    func testRoundTripsThroughTheWire() {
        let original = Envelope(kind: .evt, type: "hold.changed", sequence: 9, payload: [
            "hold": ["holdId": "h1", "expiresAt": 1750000000000],
        ])
        let decoded = Envelope.decode(original.encoded())
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Unknown tolerance

    /// A bundle newer than this app may send a kind this build predates. It must
    /// decode as `.unknown` — never crash, never be mistaken for a known kind.
    func testDecodesAnUnknownKindWithoutCrashing() {
        let envelope = Envelope.decode(["sl": 1, "k": "stream", "t": "seat.batch"])
        XCTAssertEqual(envelope?.kind, .unknown("stream"))
        XCTAssertEqual(envelope?.kind.rawValue, "stream")
    }

    func testPreservesUnknownPayloadFields() {
        let frame: JSONValue = [
            "sl": 1, "k": "res", "id": "c1", "t": "getSelection",
            "p": ["seats": .array([]), "somethingAddedIn2027": ["nested": true]],
        ]
        let envelope = Envelope.decode(frame)
        // The field this build knows nothing about still arrives intact.
        XCTAssertEqual(envelope?.payload?["somethingAddedIn2027"]?["nested"]?.boolValue, true)
    }

    // MARK: - Foundation interop

    /// The iOS shim posts an OBJECT, which arrives as NSDictionary.
    func testDecodesTheNSDictionaryWKScriptMessageHandsOver() {
        let body: [String: Any] = [
            "sl": 1, "k": "evt", "n": 2, "t": "hint",
            "p": ["message": "one seat left over"],
        ]
        let envelope = Envelope.decode(foundation: body)
        XCTAssertEqual(envelope?.type, "hint")
        XCTAssertEqual(envelope?.sequence, 2)
        XCTAssertEqual(envelope?.payload?["message"]?.stringValue, "one seat left over")
    }

    /// `NSNumber` erases Bool; if that is not recovered, `true` would cross the
    /// bridge as `1` and a `Bool` field would fail to decode.
    func testDistinguishesBoolFromNumberComingOutOfFoundation() {
        let value = JSONValue(foundation: ["on": true, "qty": 1, "price": 12.5])
        XCTAssertEqual(value["on"], .bool(true))
        XCTAssertEqual(value["qty"], .int(1))
        XCTAssertEqual(value["price"], .double(12.5))
    }

    func testLowersToAFoundationGraphForCallAsyncJavaScript() throws {
        let envelope = Envelope(kind: .cmd, type: "setColorblindSafe", id: "n1", payload: ["on": true])
        let foundation = envelope.toFoundation()
        // Must be JSON-serialisable or `callAsyncJavaScript` rejects it.
        XCTAssertTrue(JSONSerialization.isValidJSONObject(foundation))
        let dictionary = try XCTUnwrap(foundation as? [String: Any])
        XCTAssertEqual(dictionary["k"] as? String, "cmd")
        XCTAssertEqual(dictionary["sl"] as? Int, 1)
    }
}
