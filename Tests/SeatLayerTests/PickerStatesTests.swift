import XCTest
@testable import SeatLayer

final class PickerStatesTests: XCTestCase {
    // MARK: - Booked

    func testHandOffAloneIsNeverBooked() {
        var tracker = SeatLayerPickerBookedTracker()
        tracker.handedOff(handoff())
        XCTAssertFalse(tracker.observe(holdActive: true))
        XCTAssertNil(tracker.booked)
    }

    func testAHoldThatVanishesAfterHandOffIsBooked() {
        var tracker = SeatLayerPickerBookedTracker()
        tracker.handedOff(handoff())
        XCTAssertFalse(tracker.observe(holdActive: true))
        XCTAssertTrue(tracker.observe(holdActive: false))
        XCTAssertEqual(tracker.booked?.holdId, "hold-1")
        // Fires once.
        XCTAssertFalse(tracker.observe(holdActive: false))
    }

    func testAnExpiryBeforeTheHoldVanishesIsNotASale() {
        var tracker = SeatLayerPickerBookedTracker()
        tracker.handedOff(handoff())
        _ = tracker.observe(holdActive: true)
        tracker.holdExpired()
        XCTAssertFalse(tracker.observe(holdActive: false))
        XCTAssertNil(tracker.booked)
    }

    func testASnapshotBeforeTheHandOffLandedIsNotASale() {
        var tracker = SeatLayerPickerBookedTracker()
        tracker.handedOff(handoff())
        // The picker has not yet seen the hold alive under the hand-off.
        XCTAssertFalse(tracker.observe(holdActive: false))
        XCTAssertNil(tracker.booked)
    }

    // MARK: - Access panel

    func testEveryAccessReasonHasATitleBodyAndOneAction() {
        for reason in SeatLayerPickerAccessPanelReason.allCases {
            XCTAssertFalse(reason.title.englishDefault.isEmpty)
            XCTAssertFalse(reason.body.englishDefault.isEmpty)
            XCTAssertFalse(reason.action.englishDefault.isEmpty)
        }
    }

    func testPausedAsksToTryAgainAndDoesNotRefreshInPlace() {
        let paused = SeatLayerPickerAccessPanelReason(BuyerAccessUnavailableEvent(
            reason: .paused,
            code: nil,
            status: nil,
            retryable: true
        ))
        XCTAssertEqual(paused, .paused)
        XCTAssertEqual(paused.action, .retry)
        XCTAssertFalse(paused.refreshesInPlace)
    }

    func testRevokedAndProviderFailuresOfferRefresh() {
        XCTAssertEqual(
            SeatLayerPickerAccessPanelReason(BuyerAccessUnavailableEvent(
                reason: .revoked,
                code: nil,
                status: nil,
                retryable: false
            )),
            .revoked
        )
        XCTAssertEqual(
            SeatLayerPickerAccessPanelReason(BuyerAccessUnavailableEvent(
                reason: .providerFailed,
                code: nil,
                status: nil,
                retryable: true
            )),
            .expired
        )
        XCTAssertEqual(SeatLayerPickerAccessPanelReason.revoked.action, .accessRefresh)
    }

    func testAnUnknownReasonFallsBackToUnverified() {
        XCTAssertEqual(
            SeatLayerPickerAccessPanelReason(BuyerAccessUnavailableEvent(
                reason: .unknown("something-new"),
                code: nil,
                status: nil,
                retryable: true
            )),
            .unverified
        )
    }

    func testARefreshThatAlreadySucceededSaysNothing() {
        XCTAssertNil(SeatLayerPickerAccessPanelReason(BuyerAccessExpiredEvent(
            reason: .expired,
            code: nil,
            refreshed: true
        )))
    }

    // MARK: - Sold out

    func testAVenueWithGeneralAdmissionIsNeverSoldOutOnItsSeatsAlone() throws {
        let snapshot = try makeSnapshot(
            categories: [["key": "a", "label": "A", "color": "#111111", "available": 0]],
            gaAreas: [["id": "ga", "label": "Floor", "available": 0]]
        )
        XCTAssertEqual(seatLayerPickerInventoryStatus(snapshot), .availableOrUnknown)
    }

    func testEverySeatedCategoryAtZeroIsSoldOut() throws {
        let snapshot = try makeSnapshot(
            categories: [
                ["key": "a", "label": "A", "color": "#111111", "available": 0],
                ["key": "b", "label": "B", "color": "#222222", "available": 0],
            ]
        )
        XCTAssertEqual(seatLayerPickerInventoryStatus(snapshot), .soldOut)
    }

    func testAnUnreportedCategoryIsNotEvidence() throws {
        let snapshot = try makeSnapshot(
            categories: [
                ["key": "a", "label": "A", "color": "#111111", "available": 0],
                ["key": "b", "label": "B", "color": "#222222"],
            ]
        )
        XCTAssertEqual(seatLayerPickerInventoryStatus(snapshot), .availableOrUnknown)
    }

    func testSalesClosedWinsOverEveryCount() throws {
        let snapshot = try makeSnapshot(
            categories: [["key": "a", "label": "A", "color": "#111111", "available": 9]],
            salesClosed: true
        )
        XCTAssertEqual(seatLayerPickerInventoryStatus(snapshot), .salesClosed)
    }

    // MARK: - Fixtures

    private func handoff() -> SeatLayerPickerCheckoutHandoff {
        SeatLayerPickerCheckoutHandoff(
            holdId: "hold-1",
            expiresAt: 0,
            currency: "EUR",
            lineItems: [],
            total: 0
        )
    }

    private func makeSnapshot(
        categories: [JSONValue],
        gaAreas: [JSONValue] = [],
        salesClosed: Bool = false
    ) throws -> SeatLayerPickerSnapshot {
        try XCTUnwrap(decodeSeatLayerPickerSnapshot([
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": "states-session",
            "revision": 1,
            "event": [
                "key": "event",
                "currency": "EUR",
                "salesClosed": .bool(salesClosed),
            ],
            "catalog": [
                "categories": .array(categories),
                "gaAreas": .array(gaAreas),
            ],
            "map": ["rung": "sections"],
        ]))
    }
}

final class PickerHoldStateNoticeTests: XCTestCase {
    func testAHostOwnedHoldSaysTheSeatsAreInCheckoutAndOffersARelease() {
        let notice = seatLayerPickerHoldStateNotice(
            code: "hold_owned_by_host",
            hasHandoff: true
        )
        XCTAssertEqual(notice, .inCheckout)
        XCTAssertTrue(notice?.releases == true)
        XCTAssertEqual(notice?.title, .holdInCheckoutTitle)
    }

    func testASelectionMismatchIsTheSameState() {
        XCTAssertEqual(
            seatLayerPickerHoldStateNotice(code: "hold_selection_mismatch", hasHandoff: true),
            .inCheckout
        )
    }

    func testASecondHoldWithNothingToGiveBackOffersOnlyDismiss() {
        let notice = seatLayerPickerHoldStateNotice(
            code: "hold_already_active",
            hasHandoff: false
        )
        XCTAssertEqual(notice, .alreadyHeld)
        XCTAssertFalse(notice?.releases == true)
        XCTAssertEqual(notice?.body, .holdAlreadyHeldBody)
    }

    func testARealErrorKeepsThePlainLine() {
        XCTAssertNil(seatLayerPickerHoldStateNotice(code: "sold_out", hasHandoff: true))
        XCTAssertNil(seatLayerPickerHoldStateNotice(code: "transport", hasHandoff: false))
    }
}
