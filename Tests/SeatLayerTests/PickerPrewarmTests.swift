import XCTest
@testable import SeatLayer

final class PickerPrewarmTests: XCTestCase {
    private let pageA = URL(string: "https://cdn.seatlayer.io/runtime-a/mobile.html")!
    private let pageB = URL(string: "https://cdn.seatlayer.io/runtime-b/mobile.html")!

    func testSamePagePrewarmIsIdempotentAndConsumableOnce() {
        var ledger = SeatLayerPickerPrewarmLedger()
        let first = ledger.start(pageURL: pageA, now: 100, ttl: 30)
        let second = ledger.start(pageURL: pageA, now: 110, ttl: 30)

        XCTAssertEqual(first, .replace(
            previousGeneration: nil,
            entry: .init(generation: 1, pageURL: pageA, expiresAt: 130)
        ))
        XCTAssertEqual(second, .reuse(generation: 1))
        XCTAssertEqual(ledger.consume(pageURL: pageA, now: 120), 1)
        XCTAssertNil(ledger.consume(pageURL: pageA, now: 121))
    }

    func testPageMismatchReplacesButDoesNotConsumeWrongHost() {
        var ledger = SeatLayerPickerPrewarmLedger()
        _ = ledger.start(pageURL: pageA, now: 100, ttl: 30)
        let replacement = ledger.start(pageURL: pageB, now: 105, ttl: 20)

        XCTAssertEqual(replacement, .replace(
            previousGeneration: 1,
            entry: .init(generation: 2, pageURL: pageB, expiresAt: 125)
        ))
        XCTAssertNil(ledger.consume(pageURL: pageA, now: 110))
        XCTAssertEqual(ledger.consume(pageURL: pageB, now: 110), 2)
    }

    func testExpiryAndCancelReleaseOwnership() {
        var ledger = SeatLayerPickerPrewarmLedger()
        _ = ledger.start(pageURL: pageA, now: 100, ttl: 5)
        XCTAssertEqual(ledger.expire(now: 105), 1)
        XCTAssertNil(ledger.consume(pageURL: pageA, now: 105))

        _ = ledger.start(pageURL: pageA, now: 110, ttl: 5)
        XCTAssertEqual(ledger.cancel(), 2)
        XCTAssertNil(ledger.entry)
        XCTAssertNil(ledger.cancel())
    }

    func testLedgerContainsNoEventOrCredentialInput() {
        var ledger = SeatLayerPickerPrewarmLedger()
        _ = ledger.start(pageURL: pageA, now: 100, ttl: 30)

        XCTAssertEqual(ledger.entry?.pageURL, pageA)
        XCTAssertEqual(ledger.entry?.expiresAt, 130)
        // Event identity and buyer credentials enter only after the host is
        // consumed by SeatLayerView.load(configuration:).
        XCTAssertEqual(Mirror(reflecting: ledger.entry!).children.count, 3)
    }
}
