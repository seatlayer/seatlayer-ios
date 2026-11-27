import Foundation

/// How a failure is told: a lost line (`connection`: no answer, nothing came
/// back in time), a server that answered with a fault of its own (`server`,
/// 5xx), or anything else, a refusal included (`other`).
enum SeatLayerPickerFailureKind: Equatable {
    case connection
    case server
    case other
}

/// Which kind of failure `error` is.
func seatLayerPickerFailureKind(_ error: Error?) -> SeatLayerPickerFailureKind {
    guard let error = error as? SeatLayerError else { return .other }
    switch error {
    case .timeout:
        return .connection
    case .transport(let message):
        if let status = seatLayerPickerPageHttpStatus(message) {
            return status >= 500 ? .server : .other
        }
        return seatLayerPickerPageNotReached(message) ? .connection : .other
    case .bridge(let payload):
        let meta = payload.meta ?? payload.details
        guard let status = meta?["status"]?.doubleValue, status.isFinite else {
            return seatLayerPickerNoConnection(payload.message) ? .connection : .other
        }
        let serverCode = ["command_failed", "picker_error", "internal_error"].contains(payload.code)
        return status >= 500 && (serverCode || payload.message.hasPrefix("request_failed"))
            ? .server
            : .other
    default:
        return .other
    }
}

/// The HTTP status a page load answered with, from the host's
/// `page returned HTTP 502.`.
func seatLayerPickerPageHttpStatus(_ message: String) -> Int? {
    guard let range = message.range(of: "page returned HTTP ") else { return nil }
    let digits = message[range.upperBound...].prefix(3)
    guard digits.count == 3, digits.allSatisfy(\.isNumber) else { return nil }
    return Int(digits)
}

/// Whether a page load failed because nothing answered.
func seatLayerPickerPageNotReached(_ message: String) -> Bool {
    // The web view's own words follow the host's prefix, which itself reads
    // like one of them ("load failed").
    guard let range = message.range(of: "page load failed", options: .caseInsensitive) else { return false }
    return seatLayerPickerNoConnection(String(message[range.upperBound...]))
}

/// Whether `error` is told by the small message rather than the red line: no
/// answer, or a server fault while securing seats. An app's own checkout
/// error keeps its own words.
func seatLayerPickerToldAsMessage(_ error: Error?, failure: SeatLayerPickerActionFailure?) -> Bool {
    guard failure?.buyerMessage == nil else { return false }
    switch seatLayerPickerFailureKind(error) {
    case .connection:
        return true
    case .server:
        var command = failure?.command
        if command == nil, case .timeout(let timedOut, _)? = error as? SeatLayerError { command = timedOut }
        return seatLayerPickerSecuresSeats(command)
    case .other:
        return false
    }
}

/// How long a hold or a best-seats search runs before the buyer is told to wait.
let seatLayerPickerTakingLongerSeconds: TimeInterval = 10

/// The presses that wait on the server, per picker: the best-seats search says
/// when it starts and ends, and the checkout button leaves how to run the
/// app's checkout again.
@MainActor
final class SeatLayerPickerPressWatch: ObservableObject {
    @Published private(set) var waiting = false
    private var count = 0
    /// Runs the app's checkout again, through the same path as its button.
    var retry: (() -> Void)?

    /// A press now waits on the server; call the returned function when it ends.
    func begin() -> () -> Void {
        var ended = false
        count += 1
        if count == 1 { waiting = true }
        return { [weak self] in
            guard let self, !ended else { return }
            ended = true
            self.count -= 1
            if self.count == 0 { self.waiting = false }
        }
    }
}

@MainActor
private let seatLayerPickerPressWatches = NSMapTable<SeatLayerPickerController, SeatLayerPickerPressWatch>
    .weakToStrongObjects()

/// The press watch of the picker `controller`.
@MainActor
func seatLayerPickerPressWatch(for controller: SeatLayerPickerController) -> SeatLayerPickerPressWatch {
    if let watch = seatLayerPickerPressWatches.object(forKey: controller) { return watch }
    let watch = SeatLayerPickerPressWatch()
    seatLayerPickerPressWatches.setObject(watch, forKey: controller)
    return watch
}
