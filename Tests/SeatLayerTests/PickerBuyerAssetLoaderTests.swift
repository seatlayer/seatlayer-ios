import XCTest
@testable import SeatLayer

/// The buyer-scoped image transport behind the seat card's photograph.
@MainActor
final class PickerBuyerAssetLoaderTests: XCTestCase {
    private let reference = "/pub/events/evt_1/assets/seat-a1.jpg"

    /// A reference that reached this side wrong is a request that must not be
    /// MADE, not a request that fails.
    func testOnlyThisEventsOwnAssetPathsResolve() {
        let loader = SeatLayerBuyerAssetLoader(
            eventKey: "evt_1",
            apiBase: "https://api.example.test/"
        ) { _, _ in Data() }

        XCTAssertEqual(
            loader.resolve(reference)?.absoluteString,
            "https://api.example.test/pub/events/evt_1/assets/seat-a1.jpg"
        )
        // Another event's asset, a path that is not an asset at all, and a
        // traversal dressed as an asset name.
        XCTAssertNil(loader.resolve("/pub/events/evt_2/assets/seat-a1.jpg"))
        XCTAssertNil(loader.resolve("/pub/events/evt_1/holds/abc"))
        XCTAssertNil(loader.resolve("/pub/events/evt_1/assets/../../secrets"))
        XCTAssertNil(loader.resolve("https://elsewhere.test/pub/events/evt_1/assets/x.jpg"))
        XCTAssertNil(loader.resolve("/pub/events//assets/x.jpg"))
        XCTAssertNil(loader.resolve("/pub/events/evt_1/assets/"))
    }

    /// A picker with no session above it draws no photograph rather than
    /// taking a different code path.
    func testAnInertLoaderResolvesEveryReferenceToNothing() async {
        let loader = SeatLayerBuyerAssetLoader(eventKey: "")
        XCTAssertNil(loader.resolve(reference))
        let bytes = await loader.load(reference)
        XCTAssertNil(bytes)
    }

    func testTheBearerRidesTheRequestAndTheBytesAreCached() async {
        let transport = AssetTransport(answer: Data([1, 2, 3]))
        let loader = SeatLayerBuyerAssetLoader(
            eventKey: "evt_1",
            apiBase: "https://api.example.test",
            token: BuyerAccessToken(token: "abc"),
            fetch: transport.fetch
        )

        let first = await loader.load(reference)
        XCTAssertEqual(first, Data([1, 2, 3]))
        let sent = await transport.headers
        XCTAssertEqual(sent.first?["Authorization"], "Bearer abc")

        // A second card asking about the same seat costs no request.
        _ = await loader.load(reference)
        let count = await transport.calls
        XCTAssertEqual(count, 1)
    }

    /// Two seats in the same row can share a photograph, and a buyer scrubbing
    /// the map can reopen a card before the first fetch has landed.
    func testOneRequestPerReferenceHoweverManyCardsAsk() async {
        let transport = AssetTransport(answer: Data([9]))
        let loader = SeatLayerBuyerAssetLoader(
            eventKey: "evt_1",
            token: BuyerAccessToken(token: "abc"),
            fetch: transport.fetch
        )
        async let a = loader.load(reference)
        async let b = loader.load(reference)
        let (first, second) = await (a, b)
        XCTAssertEqual(first, Data([9]))
        XCTAssertEqual(second, Data([9]))
        let count = await transport.calls
        XCTAssertEqual(count, 1)
    }

    /// Every failure is the same failure: "no photograph".
    func testEveryFailureResolvesToNoPhotographWithoutThrowing() async {
        let refusing = SeatLayerBuyerAssetLoader(
            eventKey: "evt_1",
            token: BuyerAccessToken(token: "abc")
        ) { _, _ in throw SeatLayerAssetUnavailable() }
        let missed = await refusing.load(reference)
        XCTAssertNil(missed)

        // No bearer at all, on an event that needs one.
        let anonymous = SeatLayerBuyerAssetLoader(eventKey: "evt_1") { _, _ in
            XCTFail("a request must not be made without a bearer")
            return Data()
        }
        let none = await anonymous.load(reference)
        XCTAssertNil(none)
    }

    /// The usual reason for a miss is a bearer that had just expired, so the
    /// next open of the same seat has to try again.
    func testAMissIsEvictedSoTheNextOpenRetries() async {
        let transport = AssetTransport(answer: Data([4]))
        let loader = SeatLayerBuyerAssetLoader(
            eventKey: "evt_1",
            token: BuyerAccessToken(token: "abc"),
            fetch: transport.fetch
        )
        _ = await loader.load(reference)
        loader.evict(reference)
        _ = await loader.load(reference)
        let count = await transport.calls
        XCTAssertEqual(count, 2)
    }

    /// A bearer inside its safety margin is re-minted before it is used, with
    /// the reason every other SeatLayer SDK sends.
    func testAnExpiringBearerIsRemintedWithTheAssetReason() async {
        let transport = AssetTransport(answer: Data([7]))
        let reasons = ReasonRecorder()
        let expiring = BuyerAccessToken(
            token: "stale",
            expiresAt: Date().addingTimeInterval(5).timeIntervalSince1970 * 1000
        )
        XCTAssertTrue(SeatLayerBuyerAssetLoader.isExpiring(expiring))
        let loader = SeatLayerBuyerAssetLoader(
            eventKey: "evt_1",
            token: expiring,
            tokenProvider: { context in
                await reasons.record(context.reason.rawValue)
                return BuyerAccessToken(token: "fresh")
            },
            fetch: transport.fetch
        )
        _ = await loader.load(reference)
        let sent = await transport.headers
        let seen = await reasons.reasons
        XCTAssertEqual(sent.first?["Authorization"], "Bearer fresh")
        XCTAssertEqual(seen, ["asset"])
    }

    /// A one-shot bearer that has already expired is not refreshable; it still
    /// gets its one attempt rather than being dropped in silence.
    func testAStaleOneShotBearerIsStillWorthOneAttempt() async {
        let transport = AssetTransport(answer: Data([1]))
        let loader = SeatLayerBuyerAssetLoader(
            eventKey: "evt_1",
            token: BuyerAccessToken(token: "old", expiresAt: 1),
            fetch: transport.fetch
        )
        _ = await loader.load(reference)
        let sent = await transport.headers
        XCTAssertEqual(sent.first?["Authorization"], "Bearer old")
    }

    /// A bearer with no stated expiry is never treated as expiring.
    func testABearerWithNoStatedExpiryNeverGoesStale() {
        XCTAssertFalse(SeatLayerBuyerAssetLoader.isExpiring(.init(token: "x")))
        XCTAssertFalse(
            SeatLayerBuyerAssetLoader.isExpiring(.init(token: "x", expiresAt: .infinity))
        )
    }

    func testTheCacheKeepsTwelveReferencesAndForgetsTheOldestRead() async {
        let transport = AssetTransport(answer: Data([1]))
        let loader = SeatLayerBuyerAssetLoader(
            eventKey: "evt_1",
            token: BuyerAccessToken(token: "abc"),
            fetch: transport.fetch
        )
        let overflow = SeatLayerBuyerAssetLoader.cacheEntries + 1
        for index in 0..<overflow {
            _ = await loader.load("/pub/events/evt_1/assets/seat-\(index).jpg")
        }
        let filled = await transport.calls
        XCTAssertEqual(filled, overflow)

        // The most recent references are still cached and cost nothing.
        _ = await loader.load("/pub/events/evt_1/assets/seat-\(overflow - 1).jpg")
        let unchanged = await transport.calls
        XCTAssertEqual(unchanged, overflow)

        // The oldest read was pushed out, so it is fetched again.
        _ = await loader.load("/pub/events/evt_1/assets/seat-0.jpg")
        let refetched = await transport.calls
        XCTAssertEqual(refetched, overflow + 1)
    }
}

private actor AssetTransport {
    private let answer: Data
    private(set) var calls = 0
    private(set) var headers: [[String: String]] = []

    init(answer: Data) { self.answer = answer }

    nonisolated var fetch: SeatLayerAssetFetch {
        { [self] _, headers in await record(headers) }
    }

    private func record(_ headers: [String: String]) -> Data {
        calls += 1
        self.headers.append(headers)
        return answer
    }
}

private actor ReasonRecorder {
    private(set) var reasons: [String] = []
    func record(_ reason: String) { reasons.append(reason) }
}
