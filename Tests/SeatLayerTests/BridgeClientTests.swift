import XCTest
@testable import SeatLayer

/// A `BridgeChannel` double. No WebView anywhere in this file — the whole
/// correlation/timeout/ordering layer is exercised in isolation.
private final class FakeChannel: BridgeChannel, @unchecked Sendable {
    private let lock = NSLock()
    private var _sent: [Envelope] = []
    /// Invoked on every send, so a test can answer a command synchronously.
    var onSend: (@Sendable (Envelope) -> Void)?

    var sent: [Envelope] {
        lock.withLock { _sent }
    }

    func send(_ envelope: Envelope) async {
        lock.withLock { _sent.append(envelope) }
        onSend?(envelope)
    }
}

final class BridgeClientTests: XCTestCase {

    // MARK: - Correlation

    func testACommandResolvesWithItsCorrelatedReply() async throws {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)
        channel.onSend = { envelope in
            Task {
                await client.ingest(Envelope(
                    kind: .res,
                    type: envelope.type,
                    id: envelope.id,
                    payload: ["hold": ["holdId": "h1", "expiresAt": 123]]
                ))
            }
        }

        let result = try await client.command("hold", payload: ["ttlMs": 5000])
        XCTAssertEqual(result["hold"]?["holdId"]?.stringValue, "h1")

        let sent = channel.sent
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0].kind, .cmd)
        XCTAssertEqual(sent[0].type, "hold")
        XCTAssertNotNil(sent[0].id)
    }

    /// Two commands in flight; the second answers first. Each must resolve with
    /// ITS OWN reply, matched by id.
    func testConcurrentCommandsAreCorrelatedByID() async throws {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)

        async let slow = client.command("hold")
        // Let the first command register before issuing the second.
        try await Task.sleep(nanoseconds: 50_000_000)
        async let fast = client.command("getFloors")
        try await Task.sleep(nanoseconds: 50_000_000)

        let sent = channel.sent
        XCTAssertEqual(sent.count, 2)
        let holdID = try XCTUnwrap(sent.first { $0.type == "hold" }?.id)
        let floorsID = try XCTUnwrap(sent.first { $0.type == "getFloors" }?.id)
        XCTAssertNotEqual(holdID, floorsID)

        // Answer out of order.
        await client.ingest(Envelope(kind: .res, type: "getFloors", id: floorsID,
                                     payload: ["floors": .array([["id": "f1", "name": "Floor 1"]])]))
        await client.ingest(Envelope(kind: .res, type: "hold", id: holdID,
                                     payload: ["hold": ["holdId": "hX", "expiresAt": 1]]))

        let floorsResult = try await fast
        let holdResult = try await slow
        XCTAssertEqual(floorsResult["floors"]?[0]?["id"]?.stringValue, "f1")
        XCTAssertEqual(holdResult["hold"]?["holdId"]?.stringValue, "hX")
    }

    /// An `err` carries the API's own code through untouched — `sold_out` must
    /// not be flattened into a generic failure.
    func testAnErrReplyThrowsWithTheApiCodeIntact() async {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)
        channel.onSend = { envelope in
            Task {
                await client.ingest(Envelope(kind: .err, type: envelope.type, id: envelope.id, payload: [
                    "code": "sold_out",
                    "message": "seats gone",
                    "details": ["status": 409, "conflicts": .array([["label": "A-1", "status": "booked"]])],
                ]))
            }
        }

        do {
            _ = try await client.command("hold")
            XCTFail("expected a throw")
        } catch let error as SeatLayerError {
            guard case .bridge(let payload) = error else { return XCTFail("expected .bridge, got \(error)") }
            XCTAssertEqual(payload.code, "sold_out")
            XCTAssertEqual(payload.message, "seats gone")
            XCTAssertEqual(payload.details?["status"]?.intValue, 409)
            XCTAssertFalse(error.requiresAppUpdate)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    /// A correlated `err` throws with the API code AND the typed `conflicts`
    /// intact — a 409 must reach the caller as data it can render, not a blob.
    func testACorrelatedErrThrowsWithCodeAndConflicts() async {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)
        channel.onSend = { envelope in
            Task {
                await client.ingest(Envelope(kind: .err, type: envelope.type, id: envelope.id, payload: [
                    "code": "not_enough_together",
                    "message": "no 4 seats side by side",
                    "details": ["status": 409, "conflicts": .array([
                        ["label": "A-1", "status": "booked"],
                        ["label": "A-2", "status": "held"],
                    ])],
                ]))
            }
        }
        do {
            _ = try await client.command("bestAvailable", payload: ["qty": 4])
            XCTFail("expected a throw")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, "not_enough_together")
            XCTAssertEqual(error.conflicts?.count, 2)
            XCTAssertEqual(error.conflicts?.first?.label, "A-1")
            XCTAssertEqual(error.conflicts?.first?.status, "booked")
            XCTAssertEqual(error.conflicts?.last?.label, "A-2")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    /// The reported bug. The web bundle answers a failed `bestAvailable` OUT OF
    /// BAND: an uncorrelated `error` event, then a `res { hold: null }`. The call
    /// must THROW that error — not return nil while the failure escapes to the
    /// delegate — and the event must NOT also reach the signal handler.
    func testAnOutOfBandErrorEventFailsTheInFlightCommandAndIsNotAlsoAnEvent() async {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)

        let events = Received()
        await client.onSignal { signal in
            if case .event(let name, let payload, let sequence) = signal {
                events.append((name, payload, sequence))
            }
        }

        channel.onSend = { envelope in
            Task {
                // Exactly what the bundle sends: the `error` event first…
                await client.ingest(Envelope(kind: .evt, type: "error", sequence: 7, payload: [
                    "code": "sold_out",
                    "message": "seats gone",
                    "details": ["conflicts": .array([["label": "A-1", "status": "booked"]])],
                ]))
                // …then the command's own success reply carrying a null hold.
                await client.ingest(Envelope(kind: .res, type: envelope.type, id: envelope.id,
                                             payload: ["hold": .null]))
            }
        }

        do {
            _ = try await client.command("bestAvailable", payload: ["qty": 4])
            XCTFail("expected a throw, not a silent nil")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, "sold_out")
            XCTAssertEqual(error.conflicts?.first?.label, "A-1")
        } catch {
            XCTFail("unexpected error \(error)")
        }

        // Not double-reported: the delegate/signal path never saw the error.
        XCTAssertTrue(events.all.isEmpty, "a reconciled command failure must not also fire as an event")
        let open = await client.openCommandCount
        XCTAssertEqual(open, 0, "the trailing res must be dropped, leaving nothing pending")
    }

    /// An `error` event with NO command in flight is genuinely out of band and
    /// must reach the delegate (as a signal), throwing nowhere.
    func testAnOutOfBandErrorEventWithNoPendingCommandReachesTheDelegate() async {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)
        let events = Received()
        await client.onSignal { signal in
            if case .event(let name, let payload, let sequence) = signal {
                events.append((name, payload, sequence))
            }
        }

        await client.ingest(Envelope(kind: .evt, type: "error", sequence: 1, payload: [
            "code": "ws_dropped", "message": "reconnecting",
        ]))

        XCTAssertEqual(events.all.map(\.0), ["error"])
        XCTAssertEqual(events.all.first?.1?["code"]?.stringValue, "ws_dropped")
    }

    /// The reconciliation is SCOPED to mutating commands. An `error` event while
    /// a getter is in flight is out of band: the getter must NOT be failed by it,
    /// and the event still reaches the delegate.
    func testAnErrorEventDoesNotFailANonFailableGetter() async throws {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)
        let events = Received()
        await client.onSignal { signal in
            if case .event(let name, _, _) = signal { events.append((name, nil, 0)) }
        }

        async let selection = client.command("getSelection")
        try await Task.sleep(nanoseconds: 50_000_000)

        // An out-of-band error arrives while the getter is open.
        await client.ingest(Envelope(kind: .evt, type: "error", sequence: 1, payload: [
            "code": "picker_error", "message": "hover glitch",
        ]))
        // It went to the delegate, not into the getter.
        XCTAssertEqual(events.all.map(\.0), ["error"])
        let stillOpen = await client.openCommandCount
        XCTAssertEqual(stillOpen, 1, "the getter must remain in flight")

        // The getter still resolves normally with its own reply.
        let id = try XCTUnwrap(channel.sent.first { $0.type == "getSelection" }?.id)
        await client.ingest(Envelope(kind: .res, type: "getSelection", id: id,
                                     payload: ["seats": .array([["id": "s1", "label": "A-1"]])]))
        let result = try await selection
        XCTAssertEqual(result["seats"]?[0]?["label"]?.stringValue, "A-1")
    }

    /// `sys.error` is never a command failure: it must stay on the delegate path
    /// and never fail an in-flight command, whatever is open.
    func testSysErrorEventNeverFailsAnInFlightCommand() async throws {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)
        let events = Received()
        await client.onSignal { signal in
            if case .event(let name, _, _) = signal { events.append((name, nil, 0)) }
        }

        async let hold = client.command("hold")
        try await Task.sleep(nanoseconds: 50_000_000)

        await client.ingest(Envelope(kind: .evt, type: "sys.error", sequence: 1, payload: [
            "code": "internal_error", "message": "boom",
        ]))
        XCTAssertEqual(events.all.map(\.0), ["sys.error"])
        let open = await client.openCommandCount
        XCTAssertEqual(open, 1, "sys.error must not fail the pending command")

        // Clean up the still-open command so the test task can finish.
        let id = try XCTUnwrap(channel.sent.first { $0.type == "hold" }?.id)
        await client.ingest(Envelope(kind: .res, type: "hold", id: id,
                                     payload: ["hold": ["holdId": "h1", "expiresAt": 1]]))
        _ = try await hold
    }

    func testUnsupportedCommandComesBackAsATypedBridgeError() async {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)
        channel.onSend = { envelope in
            Task {
                await client.ingest(Envelope(kind: .err, type: envelope.type, id: envelope.id, payload: [
                    "code": "unsupported_command",
                    "message": "unknown command `teleportBuyer`",
                ]))
            }
        }
        do {
            _ = try await client.command("teleportBuyer")
            XCTFail("expected a throw")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, BridgeErrorCode.unsupportedCommand)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    // MARK: - Timeout

    func testACommandWithNoReplyTimesOutWithSLTimeout() async {
        let channel = FakeChannel() // never answers
        let client = BridgeClient(channel: channel, timeout: 0.25)

        let started = Date()
        do {
            _ = try await client.command("hold")
            XCTFail("expected a timeout")
        } catch let error as SeatLayerError {
            guard case .timeout(let command, let seconds) = error else {
                return XCTFail("expected .timeout, got \(error)")
            }
            XCTAssertEqual(command, "hold")
            XCTAssertEqual(seconds, 0.25)
            XCTAssertEqual(error.code, BridgeErrorCode.timeout)
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
    }

    /// A reply that arrives after its command already timed out must be
    /// DROPPED, not delivered — the continuation is gone and resuming it twice
    /// would trap.
    func testALateReplyForATimedOutCommandIsDropped() async throws {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 0.2)

        do {
            _ = try await client.command("hold")
            XCTFail("expected a timeout")
        } catch {
            // expected
        }

        let staleID = try XCTUnwrap(channel.sent.first?.id)
        var openCount = await client.openCommandCount
        XCTAssertEqual(openCount, 0, "the timed-out command must be off the pending table")

        // The late reply lands. If it were delivered, this would crash on a
        // double-resume; the test passing IS the assertion.
        await client.ingest(Envelope(kind: .res, type: "hold", id: staleID,
                                     payload: ["hold": ["holdId": "late", "expiresAt": 1]]))
        openCount = await client.openCommandCount
        XCTAssertEqual(openCount, 0)
    }

    func testAReplyForAnUnknownIDIsIgnored() async {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)
        await client.ingest(Envelope(kind: .res, type: "hold", id: "never-sent", payload: .object([:])))
        let open = await client.openCommandCount
        XCTAssertEqual(open, 0)
    }

    // MARK: - Event ordering

    /// `evt` carries a monotonic `n`. An envelope whose `n` is not greater than
    /// the highest already applied FOR THAT TYPE is stale and must be dropped.
    func testStaleEventsAreDroppedPerType() async {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)

        let received = Received()
        await client.onSignal { signal in
            if case .event(let name, let payload, let sequence) = signal {
                received.append((name, payload, sequence))
            }
        }

        await client.ingest(Envelope(kind: .evt, type: "selection.changed", sequence: 5,
                                     payload: ["seats": .array([["id": "s1", "label": "A-1"]])]))
        // Out-of-order older snapshot of the SAME type → dropped.
        await client.ingest(Envelope(kind: .evt, type: "selection.changed", sequence: 3,
                                     payload: ["seats": .array([])]))
        // Same sequence again → also stale.
        await client.ingest(Envelope(kind: .evt, type: "selection.changed", sequence: 5,
                                     payload: ["seats": .array([])]))
        // Newer → applied.
        await client.ingest(Envelope(kind: .evt, type: "selection.changed", sequence: 8,
                                     payload: ["seats": .array([["id": "s2", "label": "A-2"]])]))

        let events = received.all
        XCTAssertEqual(events.map(\.2), [5, 8])
        XCTAssertEqual(events.last?.1?["seats"]?[0]?["id"]?.stringValue, "s2")
    }

    /// The watermark is PER TYPE: a low `n` on a different event type is not
    /// stale just because another type has run ahead.
    func testTheStaleFilterIsScopedToTheEventType() async {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)
        let received = Received()
        await client.onSignal { signal in
            if case .event(let name, let payload, let sequence) = signal {
                received.append((name, payload, sequence))
            }
        }

        await client.ingest(Envelope(kind: .evt, type: "selection.changed", sequence: 20, payload: .object([:])))
        await client.ingest(Envelope(kind: .evt, type: "hold.expired", sequence: 2, payload: .object([:])))

        XCTAssertEqual(received.all.map(\.0), ["selection.changed", "hold.expired"])
        let selectionWatermark = await client.highestSequence(for: "selection.changed")
        let holdWatermark = await client.highestSequence(for: "hold.expired")
        XCTAssertEqual(selectionWatermark, 20)
        XCTAssertEqual(holdWatermark, 2)
    }

    func testHelloIsSurfacedAsItsOwnSignal() async {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)
        let box = Box<JSONValue?>(nil)
        await client.onSignal { signal in
            if case .hello(let payload) = signal { box.value = payload }
        }
        await client.ingest(Envelope(kind: .hello, type: "hello", payload: [
            "bundle": "0.25.0", "protocol": ["min": 1, "max": 1],
        ]))
        XCTAssertEqual(box.value?["bundle"]?.stringValue, "0.25.0")
    }

    /// A frame kind this build predates must reach the app as `.unhandled`
    /// rather than being silently swallowed or crashing the router.
    func testAnUnknownKindIsSurfacedNotSwallowed() async {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 5)
        let box = Box<Envelope?>(nil)
        await client.onSignal { signal in
            if case .unhandled(let envelope) = signal { box.value = envelope }
        }
        await client.ingest(Envelope(kind: .unknown("stream"), type: "seat.batch"))
        XCTAssertEqual(box.value?.kind, .unknown("stream"))
        XCTAssertEqual(box.value?.type, "seat.batch")
    }

    // MARK: - Teardown

    func testCloseFailsEveryOpenCommand() async {
        let channel = FakeChannel()
        let client = BridgeClient(channel: channel, timeout: 30)

        let task = Task { try await client.command("hold") }
        try? await Task.sleep(nanoseconds: 50_000_000)
        await client.close()

        do {
            _ = try await task.value
            XCTFail("expected a throw")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, BridgeErrorCode.destroyed)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testCommandsAfterCloseFailImmediately() async {
        let client = BridgeClient(channel: FakeChannel(), timeout: 5)
        await client.close()
        do {
            _ = try await client.command("zoomIn")
            XCTFail("expected a throw")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, BridgeErrorCode.destroyed)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testCloseIsIdempotent() async {
        let client = BridgeClient(channel: FakeChannel(), timeout: 5)
        await client.close()
        await client.close()
        let open = await client.openCommandCount
        XCTAssertEqual(open, 0)
    }
}

// MARK: - Test helpers

private final class Received: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [(String, JSONValue?, Int)] = []

    func append(_ item: (String, JSONValue?, Int)) {
        lock.lock(); items.append(item); lock.unlock()
    }

    var all: [(String, JSONValue?, Int)] {
        lock.lock(); defer { lock.unlock() }
        return items
    }
}

private final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: T

    init(_ value: T) { self.storage = value }

    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return storage }
        set { lock.lock(); storage = newValue; lock.unlock() }
    }
}
