import Foundation

/// The page's line to the server, as `connection.changed` and the snapshot's
/// `map.connection` name it.
public enum SeatLayerConnectionState: String, Sendable, Equatable {
    /// The live line is open.
    case live
    /// It closed and a retry is set.
    case reconnecting
    /// Seats come by the page's regular poll.
    case polling
    /// The device says it has no network.
    case offline

    /// The state `value` names, or nil for a value this SDK does not know.
    init?(page value: JSONValue?) {
        guard let raw = value?.stringValue, let state = SeatLayerConnectionState(rawValue: raw) else {
            return nil
        }
        self = state
    }

    /// Whether the line is down: the page says `offline` or `reconnecting`.
    public var lineDown: Bool {
        self == .offline || self == .reconnecting
    }
}

/// What the picker's connection status says: nothing, "You're offline",
/// "Updating…" (coming back, or no seat news for a while), or "Back online"
/// for a moment after an outage the buyer was told about.
public enum SeatLayerConnectionShown: Sendable, Equatable {
    case none
    case offline
    case updating
    case back
}

/// Something that can be stopped before it runs.
protocol SeatLayerConnectionTimer: AnyObject {
    func cancel()
}

/// Runs `work` after `seconds` on the main actor.
typealias SeatLayerConnectionSchedule = @MainActor (
    _ seconds: TimeInterval,
    _ work: @escaping @MainActor () -> Void
) -> SeatLayerConnectionTimer

private final class SeatLayerConnectionTaskTimer: SeatLayerConnectionTimer {
    private var task: Task<Void, Never>?

    init(seconds: TimeInterval, work: @escaping @MainActor () -> Void) {
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            work()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

/// Turns the page's line into what the buyer is told, and when.
///
/// "You're offline" waits `offlineAfter`, so a blink of the network says
/// nothing. A line that is merely retrying says "Updating…" after
/// `updatingAfter`. "Back online" follows only an outage the buyer was told
/// about, and only once the seats have been read again; it stays `backFor`.
@MainActor
final class SeatLayerConnectionWatch {
    let offlineAfter: TimeInterval
    let updatingAfter: TimeInterval
    let backFor: TimeInterval

    /// What the status says now.
    private(set) var shown: SeatLayerConnectionShown = .none
    /// The page's latest state, or nil when it has said none.
    private(set) var state: SeatLayerConnectionState?
    /// Whether the buyer has been told they are offline and is not yet back.
    private(set) var saidOffline = false

    /// Called when what the status says changes.
    var onShown: ((SeatLayerConnectionShown) -> Void)?
    /// Called when the page's state changes, whether or not the status does.
    var onState: ((SeatLayerConnectionState?) -> Void)?

    private var waitingForSeats = false
    private var timer: SeatLayerConnectionTimer?
    private let schedule: SeatLayerConnectionSchedule

    init(
        offlineAfter: TimeInterval = 3,
        updatingAfter: TimeInterval = 10,
        backFor: TimeInterval = 2.5,
        schedule: SeatLayerConnectionSchedule? = nil
    ) {
        self.offlineAfter = offlineAfter
        self.updatingAfter = updatingAfter
        self.backFor = backFor
        self.schedule = schedule ?? { seconds, work in
            SeatLayerConnectionTaskTimer(seconds: seconds, work: work)
        }
    }

    /// The page reported `next`. Nil (a value this SDK does not know) and a
    /// repeat change nothing.
    func heard(_ next: SeatLayerConnectionState?) {
        guard let next, next != state else { return }
        state = next
        clearTimer()
        onState?(next)
        switch next {
        case .offline:
            waitingForSeats = false
            if saidOffline {
                show(.offline)
            } else {
                timer = schedule(offlineAfter) { [weak self] in
                    guard let self else { return }
                    self.timer = nil
                    self.saidOffline = true
                    self.show(.offline)
                }
            }
        case .reconnecting:
            waitingForSeats = false
            if saidOffline {
                show(.updating)
            } else if shown != .updating {
                timer = schedule(updatingAfter) { [weak self] in
                    self?.timer = nil
                    self?.show(.updating)
                }
            }
        case .live, .polling:
            if saidOffline {
                // Back: say so once the seats have been read again.
                waitingForSeats = true
                show(.updating)
            } else {
                show(.none)
            }
        }
    }

    /// The page's seats were read: a snapshot arrived.
    func seatsRead() {
        guard waitingForSeats else { return }
        waitingForSeats = false
        saidOffline = false
        show(.back)
        clearTimer()
        timer = schedule(backFor) { [weak self] in
            self?.timer = nil
            self?.show(.none)
        }
    }

    /// A new page: nothing it has not said yet is known.
    func reset() {
        clearTimer()
        let hadState = state != nil
        state = nil
        saidOffline = false
        waitingForSeats = false
        if hadState { onState?(nil) }
        show(.none)
    }

    func stop() {
        clearTimer()
        onShown = nil
        onState = nil
    }

    private func clearTimer() {
        timer?.cancel()
        timer = nil
    }

    private func show(_ next: SeatLayerConnectionShown) {
        guard next != shown else { return }
        shown = next
        onShown?(next)
    }
}
