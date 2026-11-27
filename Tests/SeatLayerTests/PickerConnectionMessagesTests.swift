import XCTest
@testable import SeatLayer

final class PickerConnectionMessagesTests: XCTestCase {
    private func refused(_ code: String, status: Int?, message: String? = nil) -> SeatLayerError {
        .bridge(BridgeErrorPayload(
            code: code,
            message: message ?? code,
            meta: status.map { ["status": .int($0)] }
        ))
    }

    func testReadsNoAnswerAsTheLine() {
        XCTAssertEqual(seatLayerPickerFailureKind(SeatLayerError.timeout(command: "picker.holdSelection", seconds: 45)), .connection)
        XCTAssertEqual(seatLayerPickerFailureKind(refused("unknown", status: nil, message: "TypeError: Load failed")), .connection)
        XCTAssertEqual(seatLayerPickerFailureKind(SeatLayerError.transport(
            "page load failed: The Internet connection appears to be offline."
        )), .connection)
    }

    func testReadsAServerFaultAsTheServerAndARefusalAsNeither() {
        XCTAssertEqual(seatLayerPickerFailureKind(refused("command_failed", status: 502)), .server)
        XCTAssertEqual(seatLayerPickerFailureKind(refused("internal_error", status: 500)), .server)
        XCTAssertEqual(seatLayerPickerFailureKind(SeatLayerError.transport("page returned HTTP 503.")), .server)
        XCTAssertEqual(seatLayerPickerFailureKind(SeatLayerError.transport("page returned HTTP 404.")), .other)
        XCTAssertEqual(seatLayerPickerFailureKind(refused("conflict", status: 409)), .other)
        XCTAssertEqual(seatLayerPickerFailureKind(SeatLayerError.handshakeTimeout(seconds: 45)), .other,
                       "a page that only answered too slowly keeps today's panel")
        XCTAssertEqual(seatLayerPickerFailureKind(SeatLayerError.transport("page load failed: bad certificate")), .other)
    }

    func testTellsAServerFaultAsAMessageOnlyWhileSecuringSeats() {
        let fault = refused("command_failed", status: 502)
        XCTAssertTrue(seatLayerPickerToldAsMessage(fault, failure: .init(command: "picker.holdSelection")))
        XCTAssertTrue(seatLayerPickerToldAsMessage(fault, failure: .init(command: "picker.continue")))
        XCTAssertFalse(seatLayerPickerToldAsMessage(fault, failure: .init(command: "picker.removeCartLine")))
        XCTAssertFalse(seatLayerPickerToldAsMessage(refused("conflict", status: 409), failure: .init(command: "picker.holdSelection")))
        XCTAssertTrue(seatLayerPickerToldAsMessage(SeatLayerError.timeout(command: "picker.bestAvailable", seconds: 45), failure: nil))
        XCTAssertFalse(
            seatLayerPickerToldAsMessage(fault, failure: .init(command: "picker.continue", buyerMessage: "Our checkout is down.")),
            "an app's own checkout words stay in the red line"
        )
    }

    @MainActor
    func testThePressWatchSaysWhenTheFirstPressStartsAndTheLastEnds() {
        let watch = SeatLayerPickerPressWatch()
        let first = watch.begin()
        let second = watch.begin()
        XCTAssertTrue(watch.waiting)
        first()
        first()
        XCTAssertTrue(watch.waiting)
        second()
        XCTAssertFalse(watch.waiting)
    }
}
