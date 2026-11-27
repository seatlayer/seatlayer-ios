import Foundation

/// How long the offline panel waits before its next try: 10 s, 20 s, then
/// every 30 s.
func seatLayerPickerOfflineRetryAfter(_ tries: Int) -> TimeInterval {
    tries == 0 ? 10 : tries == 1 ? 20 : 30
}

/// How long the opening waits before it says it is taking longer.
let seatLayerPickerSlowOpeningSeconds: TimeInterval = 8

/// The panel's tries, kept per picker: each try opens the page again and so
/// draws a new panel.
@MainActor
final class SeatLayerPickerOfflineTries {
    private(set) var count = 0
    private var last: Date
    /// A picker that has been fine this long starts the steps again.
    static let freshAfter: TimeInterval = 120

    init(now: Date = Date()) {
        last = now
    }

    /// The wait before the next try, starting the steps again after a quiet spell.
    func nextWait(now: Date = Date()) -> TimeInterval {
        if now.timeIntervalSince(last) > Self.freshAfter { count = 0 }
        return seatLayerPickerOfflineRetryAfter(count)
    }

    func tried(now: Date = Date()) {
        count += 1
        last = now
    }

    /// Back in front: the steps start again.
    func restart(now: Date = Date()) {
        count = 0
        last = now
    }
}

@MainActor
private let seatLayerPickerOfflineTriesByPicker = NSMapTable<AnyObject, SeatLayerPickerOfflineTries>
    .weakToStrongObjects()

@MainActor
func seatLayerPickerOfflineTries(for owner: AnyObject) -> SeatLayerPickerOfflineTries {
    if let tries = seatLayerPickerOfflineTriesByPicker.object(forKey: owner) { return tries }
    let tries = SeatLayerPickerOfflineTries()
    seatLayerPickerOfflineTriesByPicker.setObject(tries, forKey: owner)
    return tries
}
