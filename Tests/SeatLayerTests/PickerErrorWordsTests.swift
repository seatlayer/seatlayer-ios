import XCTest
@testable import SeatLayer

/// What a refused action says to the buyer: the web picker's sentences, chosen
/// by the code where it names its own and otherwise by what was asked for.
final class PickerErrorWordsTests: XCTestCase {
    private let strings = SeatLayerPickerStrings(localeIdentifier: "en")

    private func bridge(
        _ code: String,
        message: String = "",
        details: JSONValue? = nil,
        meta: JSONValue? = nil
    ) -> SeatLayerError {
        .bridge(.init(code: code, message: message, details: details, meta: meta))
    }

    private func words(
        _ error: SeatLayerError,
        command: String? = nil,
        quantity: Int? = nil,
        label: String? = nil
    ) -> SeatLayerPickerErrorWords {
        let failure = command.map {
            SeatLayerPickerActionFailure(command: $0, quantity: quantity, label: label)
        }
        return seatLayerPickerErrorWords(error, failure: failure, strings: strings)
    }

    func testNeverEchoesTheServerOrTheAppsOwnDescription() {
        let opaque = "hold_private_123"
        let refused = bridge("sold_out", message: "Could not transfer \(opaque)")
        let host = SeatLayerError.transport("Host rejected \(opaque)")

        XCTAssertEqual(words(refused).message, strings.text(.ticketTypeSoldOut))
        XCTAssertEqual(words(host).message, strings.text(.checkConnection))
        XCTAssertFalse(words(refused).message.contains(opaque))
        XCTAssertFalse(words(host).message.contains(opaque))
    }

    func testTheAppsOwnBuyerSentenceIsSaidAsItIs() {
        struct Declined: SeatLayerPickerBuyerFacingError {
            var buyerMessage: String? { "  Your card was declined.  " }
        }
        struct Plain: Error {}
        XCTAssertEqual(seatLayerPickerOwnBuyerMessage(Declined()), "Your card was declined.")
        XCTAssertNil(seatLayerPickerOwnBuyerMessage(Plain()))
        let failure = SeatLayerPickerActionFailure(buyerMessage: "Your card was declined.")
        XCTAssertEqual(
            seatLayerPickerErrorWords(.transport("x"), failure: failure, strings: strings).message,
            "Your card was declined."
        )
    }

    func testMaintenanceSaysTheNoticeOrHowLong() {
        XCTAssertEqual(
            words(bridge("maintenance_mode", meta: ["notice": " Back at 10:00 "])).message,
            "Back at 10:00"
        )
        XCTAssertEqual(
            words(bridge("maintenance_mode", meta: ["retryAfterS": 90])).message,
            strings.text(SeatLayerPickerPluralKeys.maintenancePaused, count: 2)
        )
        XCTAssertEqual(
            words(bridge("maintenance_mode", meta: ["retryAfterS": 30])).message,
            strings.text(SeatLayerPickerPluralKeys.maintenancePaused, count: 1)
        )
        XCTAssertEqual(
            words(bridge("maintenance_mode")).message,
            strings.text(.maintenancePausedShortly)
        )
    }

    func testCodesWithTheirOwnSentenceAndLine() {
        let paused = words(bridge("channel_paused"), command: "picker.holdSelection")
        XCTAssertEqual(paused.message, strings.text(.accessPausedTitle))
        XCTAssertEqual(paused.detail, strings.text(.accessPausedCopy))
        XCTAssertEqual(words(bridge("rate_limited")).message, strings.text(.tooManyAttempts))
        XCTAssertEqual(words(.timeout(command: "picker.holdSelection", seconds: 10)).message,
                       strings.text(.checkConnection))
        let mismatch = words(bridge("buyer_access_event_mismatch"))
        XCTAssertEqual(mismatch.message, strings.text(.accessUnverifiedTitle))
        XCTAssertEqual(mismatch.detail, strings.text(.accessUnverifiedCopy))
    }

    func testARequestThatReachedNoServerSaysCheckTheConnection() {
        XCTAssertEqual(
            words(bridge("command_failed", message: "TypeError: Load failed"),
                  command: "picker.holdSelection").message,
            strings.text(.checkConnection)
        )
        XCTAssertEqual(
            words(bridge("command_failed", message: "x", meta: ["status": 503]),
                  command: "picker.holdSelection").message,
            strings.text(.checkConnection)
        )
        XCTAssertEqual(
            words(bridge("command_failed", message: "seat sales are closed for this event")).message,
            strings.text(.salesClosedToast)
        )
    }

    func testTheOrderLimitIsNamed() {
        XCTAssertEqual(
            words(bridge("hold_quantity_exceeded", meta: ["max": 4]), command: "picker.holdSelection").message,
            "You can select up to 4 tickets for this order."
        )
        XCTAssertEqual(
            words(bridge("hold_quantity_exceeded", details: ["limit": 1]), command: "picker.holdSelection").message,
            strings.text(.maxOneTicketForOrder)
        )
    }

    func testBestAvailableSaysWhatItCouldNotFind() {
        XCTAssertEqual(
            words(bridge("not_enough_together"), command: "picker.bestAvailable", quantity: 3).message,
            "We couldn’t find 3 seats together. Try fewer seats or another ticket type."
        )
        XCTAssertEqual(
            words(bridge("sold_out"), command: "picker.bestAvailable").message,
            strings.text(.ticketTypeSoldOut)
        )
        XCTAssertEqual(
            words(bridge("conflict"), command: "picker.bestAvailable").message,
            strings.text(.seatsNoLongerAvailableTryAnother)
        )
        XCTAssertEqual(
            words(bridge("not_found"), command: "picker.bestAvailable").message,
            strings.text(.eventUnavailable)
        )
    }

    func testARemovalAndMoreTimeHaveTheirOwnSentence() {
        XCTAssertEqual(
            words(bridge("conflict"), command: "picker.removeCartLine", label: "A-7").message,
            "Couldn’t remove A-7. Your hold is unchanged."
        )
        XCTAssertEqual(
            words(bridge("conflict"), command: "picker.removeCartLine", label: "__sl_ga__floor").message,
            strings.text(.couldNotRemoveLabel, replacing: ["label": strings.text(.generalAdmission)])
        )
        XCTAssertEqual(
            words(bridge("hold_not_active"), command: "picker.extendHold").message,
            strings.text(.couldNotAddMoreTime)
        )
        XCTAssertEqual(
            words(bridge("hold_not_active"), command: "picker.holdSelection").message,
            strings.text(.holdExpired)
        )
    }

    func testTakenSeatsAreNamedButStandingPlacesAreNot() {
        let two = bridge("conflict", details: ["conflicts": [["label": "A-1"], ["label": "A-2"]]])
        XCTAssertEqual(words(two, command: "picker.holdSelection").message,
                       "A-1, A-2 are no longer available. Choose another group.")
        let one = bridge("conflict", details: ["conflicts": [["label": "B-4"], ["label": "__sl_ga__x"]]])
        XCTAssertEqual(words(one, command: "picker.holdSelection").message,
                       "B-4 is no longer available. Choose another seat.")
        let standing = bridge("hold_unavailable", details: ["conflicts": [["label": "__sl_ga__x"]]])
        XCTAssertEqual(words(standing, command: "picker.holdGA").message, strings.text(.seatsJustTaken))
        XCTAssertEqual(words(bridge("not_for_sale")).message, strings.text(.seatUnavailable))
    }

    func testAFailureOfThePageOrTheCallIsNotBlamedOnTheSeats() {
        XCTAssertEqual(words(bridge("bad_payload"), command: "picker.holdSelection").message,
                       strings.text(.eventUnavailable))
        XCTAssertEqual(words(bridge("not_ready"), command: "picker.holdSelection").message,
                       strings.text(.checkConnection))
        XCTAssertEqual(words(bridge("something_new"), command: "picker.holdSelection").message,
                       strings.text(.seatsJustTaken))
        XCTAssertEqual(words(bridge("something_new")).message, strings.text(.checkConnection))
    }

    func testTheErrorPayloadKeepsTheServersMeta() {
        let payload = BridgeErrorPayload([
            "code": "hold_quantity_exceeded", "message": "m", "meta": ["max": 6],
        ])
        XCTAssertEqual(payload.meta?["max"]?.intValue, 6)
        XCTAssertNil(BridgeErrorPayload(["code": "x", "meta": "text"]).meta)
    }
}
