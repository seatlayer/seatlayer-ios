import XCTest
@testable import SeatLayer

/// The nine numbered rules the sheet foot and the wide checkout bar share, and
/// the precedence between them.
final class PickerCheckoutCtaTests: XCTestCase {
    private let strings = SeatLayerPickerStrings()

    private func input(
        label: String = "Hold seats & checkout",
        canCheckout: Bool = true,
        ticketCount: Int? = 2
    ) -> SeatLayerPickerCheckoutCtaInput {
        SeatLayerPickerCheckoutCtaInput(
            label: label,
            canCheckout: canCheckout,
            ticketCount: ticketCount
        )
    }

    private func resolve(
        _ mutate: (inout SeatLayerPickerCheckoutCtaInput) -> Void = { _ in }
    ) -> SeatLayerPickerCheckoutCta {
        var value = input()
        mutate(&value)
        return seatLayerCheckoutCtaState(value, strings: strings)
    }

    func testNothingOutranksAnEventThatHasStoppedSelling() {
        let cta = resolve {
            $0.salesClosed = true
            $0.promptOpen = true
            $0.creatingHold = true
        }
        XCTAssertEqual(cta.label, strings.text(.salesClosedCta))
        XCTAssertFalse(cta.enabled)
        XCTAssertTrue(cta.statesReason)
    }

    func testAnUnansweredPromptOutranksTheHoldAPressWouldCreate() {
        let cta = resolve {
            $0.promptOpen = true
            $0.creatingHold = true
        }
        XCTAssertEqual(cta.label, strings.text(.confirmYourTickets))
        XCTAssertFalse(cta.enabled)
    }

    func testAnOpenSeatCardHoldsTheButtonWithoutChangingItsWords() {
        let cta = resolve { $0.seatCardOpen = true }
        XCTAssertEqual(cta.label, "Hold seats & checkout")
        XCTAssertFalse(cta.enabled)
        XCTAssertFalse(cta.statesReason)
    }

    func testAnOpenSeatCardWithdrawsEvenTheFinder() {
        let cta = resolve {
            $0.seatCardOpen = true
            $0.ticketCount = 0
            $0.canOfferFind = true
        }
        XCTAssertEqual(cta.label, strings.text(.findBestSeatsCta))
        XCTAssertFalse(cta.enabled)
        XCTAssertFalse(cta.findsBestSeats)
    }

    func testWorkAlreadyAskedForSpeaksAndSpins() {
        let securing = resolve { $0.creatingHold = true }
        XCTAssertEqual(securing.label, strings.text(.securingSeats))
        XCTAssertTrue(securing.busy)

        let opening = resolve { $0.handoffInFlight = true }
        XCTAssertEqual(opening.label, strings.text(.openingCheckout))
        XCTAssertTrue(opening.busy)
    }

    func testARejectedSelectionSaysWhatWouldFixIt() {
        let more = resolve {
            $0.validity = SelectionValidity(
                isValid: false, count: 1, required: 3, remaining: 2,
                seats: [], violations: []
            )
        }
        XCTAssertEqual(more.label, "Choose 2 more")

        let fewer = resolve {
            $0.validity = SelectionValidity(
                isValid: false, count: 4, required: 2, remaining: 0,
                seats: [], violations: []
            )
        }
        XCTAssertEqual(fewer.label, "Remove 2 tickets")
    }

    func testASelectionRejectedForItsShapeFallsBackToTheGeneralSentence() {
        // `required` is 0 for a rule about the SHAPE of a selection rather than
        // its size, and "Remove 1 ticket" would be a wrong instruction there.
        let cta = resolve {
            $0.validity = SelectionValidity(
                isValid: false, count: 3, required: 0, remaining: 0,
                seats: [], violations: []
            )
        }
        XCTAssertEqual(cta.label, strings.text(.adjustSelection))
    }

    func testTheEmptyPhoneCartGetsADoorNotADeadButton() {
        let cta = resolve {
            $0.ticketCount = 0
            $0.canOfferFind = true
        }
        XCTAssertEqual(cta.label, strings.text(.findBestSeatsCta))
        XCTAssertTrue(cta.enabled)
        XCTAssertTrue(cta.findsBestSeats)
    }

    func testTheDoorIsWithheldWhereTheFormWouldBeRefused() {
        let noOffer = resolve { $0.ticketCount = 0 }
        XCTAssertEqual(noOffer.label, strings.text(.selectSeats))
        XCTAssertFalse(noOffer.enabled)
        XCTAssertTrue(noOffer.statesReason)

        let held = resolve {
            $0.ticketCount = 0
            $0.canOfferFind = true
            $0.holdActive = true
        }
        XCTAssertNotEqual(held.label, strings.text(.findBestSeatsCta))
        XCTAssertFalse(held.findsBestSeats)
    }

    func testAStandingHoldOffersTheTillOrTheSeatsPickedSince() {
        let till = resolve { $0.holdActive = true }
        XCTAssertEqual(till.label, strings.text(.continueToCheckout))
        XCTAssertTrue(till.enabled)

        let more = resolve {
            $0.holdActive = true
            $0.pendingCount = 3
        }
        XCTAssertEqual(more.label, "Secure 3 more & checkout")
    }

    func testNothingInTheWayKeepsTheCallersOwnLabel() {
        let cta = resolve()
        XCTAssertEqual(cta.label, "Hold seats & checkout")
        XCTAssertTrue(cta.enabled)
        XCTAssertFalse(cta.statesReason)
        XCTAssertFalse(cta.findsBestSeats)
    }

    func testTheButtonNeverCarriesTheTotal() {
        // The total is on the line above it; no rung on the ladder prints
        // money.
        for cta in [
            resolve(),
            resolve { $0.holdActive = true },
            resolve { $0.ticketCount = 0; $0.canOfferFind = true },
        ] {
            XCTAssertFalse(cta.label.contains("€"))
            XCTAssertFalse(cta.label.contains("{money}"))
        }
    }
}
