import Foundation

/// The native→web send path. Implemented by `SeatLayerView` over
/// `WKWebView.callAsyncJavaScript`; tests substitute a double, which is what
/// keeps the whole correlation/timeout layer testable without a WebView.
public protocol BridgeChannel: AnyObject, Sendable {
    func send(_ envelope: Envelope) async
}

/// What the client hands back to its owner. Delivered on the client's actor;
/// `SeatLayerView` hops to the main actor before touching the delegate.
public enum BridgeSignal: Sendable {
    /// The bundle opened the handshake. Payload is the raw `hello`.
    case hello(JSONValue?)
    /// An `evt` that survived stale-sequence filtering.
    case event(name: String, payload: JSONValue?, sequence: Int)
    /// An inbound frame this build could not act on. Surfaced rather than
    /// swallowed so integrators can see a bundle running ahead of the app.
    case unhandled(Envelope)
}

/// Correlation, timeout and event ordering for the bridge.
///
/// Invariants it enforces on the native side:
///   - one `cmd` resolves exactly once, by `id`;
///   - a command with no reply fails with `sl_timeout` after `timeout`;
///   - a LATE reply for an already-timed-out id is dropped, never delivered;
///   - an `evt` whose `n` is not greater than the highest `n` already applied
///     FOR THAT `t` is dropped as stale.
public actor BridgeClient {
    /// Default native-side command deadline.
    public static let defaultTimeout: TimeInterval = 15

    /// Commands whose failure the web bundle reports OUT OF BAND.
    ///
    /// The bundle's `SeatingChart` catches an API error inside these mutating
    /// commands, hands it to `onError`, and resolves the command with a null
    /// hold. On the wire that is an uncorrelated `error` event immediately
    /// followed by a `res` carrying `{ hold: null }` — so a naive client returns
    /// `nil` from `try await` and the real failure only shows up on the delegate.
    /// For exactly these commands, an `error` event that lands while one is in
    /// flight is that command's failure, and must throw from its call. Getters
    /// and view commands are deliberately absent: an error during one of those is
    /// genuinely out of band and belongs on the delegate.
    public static let defaultFailableCommands: Set<String> = [
        "hold", "holdGA", "bestAvailable", "resumeHold", "extendHold",
        "release", "releaseLabels",
    ]

    /// Event types the bundle uses to report a command failure out of band.
    public static let defaultCommandErrorEvents: Set<String> = ["error"]

    private struct Pending {
        let command: String
        /// Issue order — the pending command with the highest order is the most
        /// recently sent, which is the one an out-of-band `error` belongs to.
        let order: UInt64
        let continuation: CheckedContinuation<JSONValue, Error>
        let timeoutTask: Task<Void, Never>
    }

    private weak var channel: BridgeChannel?
    private let timeout: TimeInterval
    private let failableCommands: Set<String>
    private let commandErrorEvents: Set<String>
    private var pending: [String: Pending] = [:]
    /// Highest applied sequence per event type — the stale-event filter.
    private var lastSequence: [String: Int] = [:]
    private var nextID: UInt64 = 0
    private var isClosed = false
    private var signalHandler: (@Sendable (BridgeSignal) -> Void)?

    public init(
        channel: BridgeChannel? = nil,
        timeout: TimeInterval = BridgeClient.defaultTimeout,
        failableCommands: Set<String> = BridgeClient.defaultFailableCommands,
        commandErrorEvents: Set<String> = BridgeClient.defaultCommandErrorEvents
    ) {
        self.channel = channel
        self.timeout = timeout
        self.failableCommands = failableCommands
        self.commandErrorEvents = commandErrorEvents
    }

    public func attach(channel: BridgeChannel) {
        self.channel = channel
    }

    public func onSignal(_ handler: @escaping @Sendable (BridgeSignal) -> Void) {
        self.signalHandler = handler
    }

    // MARK: - Outbound

    /// Send a `cmd` and await its single `res`/`err`.
    public func command(_ name: String, payload: JSONValue? = nil) async throws -> JSONValue {
        guard !isClosed else { throw SeatLayerError.destroyed }
        guard let channel else { throw SeatLayerError.transport("no channel attached") }

        nextID += 1
        let id = "n\(nextID)"
        let order = nextID
        let envelope = Envelope(kind: .cmd, type: name, id: id, payload: payload)

        // Register the continuation BEFORE sending: a synchronous reply must
        // never arrive to an empty pending table.
        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task { [weak self, timeout] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.expire(id: id)
            }
            pending[id] = Pending(command: name, order: order, continuation: continuation, timeoutTask: timeoutTask)
            Task { await channel.send(envelope) }
        }
    }

    /// Send the handshake reply. Fire-and-forget: the bundle answers with the
    /// `sys.ready` / `sys.incompatible` event, not with a correlated reply.
    public func sendInit(payload: JSONValue) async {
        guard !isClosed, let channel else { return }
        await channel.send(Envelope(kind: .initialize, type: "init", payload: payload))
    }

    private func expire(id: String) {
        guard let entry = pending.removeValue(forKey: id) else { return }
        entry.timeoutTask.cancel()
        entry.continuation.resume(
            throwing: SeatLayerError.timeout(command: entry.command, seconds: timeout)
        )
    }

    // MARK: - Inbound

    /// Route one inbound frame. Never throws: a malformed or unfamiliar frame is
    /// dropped, because a decode failure must not take the seat map down.
    public func ingest(_ envelope: Envelope) {
        guard !isClosed else { return }

        switch envelope.kind {
        case .res:
            resolve(envelope, with: .success(envelope.payload ?? .object([:])))

        case .err:
            resolve(envelope, with: .failure(SeatLayerError.bridge(BridgeErrorPayload(envelope.payload))))

        case .evt:
            // A command whose failure the bundle reports out of band: the `error`
            // event lands HERE, synchronously, immediately before the command's
            // own `res { hold: null }`. Turn it back into that command's failure
            // so `try await` throws instead of returning nil — and do it before
            // the trailing `res`, which then finds no pending entry and is
            // dropped. Because the command is failed here and NOT forwarded as an
            // event, the delegate does not also see it: one failure, one report.
            if commandErrorEvents.contains(envelope.type),
               let (id, entry) = mostRecentFailablePending() {
                pending.removeValue(forKey: id)
                entry.timeoutTask.cancel()
                entry.continuation.resume(
                    throwing: SeatLayerError.bridge(BridgeErrorPayload(envelope.payload))
                )
                return
            }

            // A missing `n` cannot be ordered; treat it as fresh rather than
            // dropping a real event.
            let sequence = envelope.sequence ?? Int.min
            if let seen = lastSequence[envelope.type], sequence <= seen {
                return // stale — a newer snapshot of this event type already applied
            }
            lastSequence[envelope.type] = sequence
            signalHandler?(.event(name: envelope.type, payload: envelope.payload, sequence: sequence))

        case .hello:
            signalHandler?(.hello(envelope.payload))

        // `init`/`cmd` are native→web kinds; an inbound one is noise. `unknown`
        // is a bundle newer than this build.
        case .initialize, .cmd, .unknown:
            signalHandler?(.unhandled(envelope))
        }
    }

    /// Deliver a reply to its correlation, if that correlation is still open.
    /// A reply for an unknown id — the late reply to a timed-out command, or a
    /// duplicate — is dropped.
    private func resolve(_ envelope: Envelope, with result: Result<JSONValue, Error>) {
        guard let id = envelope.id, let entry = pending.removeValue(forKey: id) else { return }
        entry.timeoutTask.cancel()
        entry.continuation.resume(with: result)
    }

    /// The in-flight command an out-of-band `error` event should be attributed
    /// to: the most recently issued command from the failable set. `nil` when no
    /// such command is open, in which case the error is genuinely out of band.
    private func mostRecentFailablePending() -> (id: String, entry: Pending)? {
        pending
            .filter { failableCommands.contains($0.value.command) }
            .max { $0.value.order < $1.value.order }
            .map { ($0.key, $0.value) }
    }

    /// Convenience for the WebView message handler.
    public func ingest(foundation value: Any) {
        guard let envelope = Envelope.decode(foundation: value) else { return }
        ingest(envelope)
    }

    // MARK: - Teardown

    /// Fail every open command and stop accepting frames. Idempotent.
    public func close(with error: SeatLayerError = .destroyed) {
        guard !isClosed else { return }
        isClosed = true
        let open = pending
        pending.removeAll()
        for (_, entry) in open {
            entry.timeoutTask.cancel()
            entry.continuation.resume(throwing: error)
        }
        signalHandler = nil
        channel = nil
    }

    // MARK: - Introspection (tests)

    public var openCommandCount: Int { pending.count }
    public func highestSequence(for type: String) -> Int? { lastSequence[type] }
}
