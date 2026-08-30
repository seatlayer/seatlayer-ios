import Combine
import Foundation

/// Revision-ordered source used by both the ready-made and custom picker paths.
@MainActor
final class SeatLayerPickerSnapshotStore: ObservableObject {
    @Published private(set) var snapshot: SeatLayerPickerSnapshot?

    @discardableResult
    func ingest(_ value: JSONValue?) -> SeatLayerPickerSnapshot? {
        guard let candidate = decodeSeatLayerPickerSnapshot(value),
              apply(candidate) else { return nil }
        return candidate
    }

    @discardableResult
    func apply(_ candidate: SeatLayerPickerSnapshot) -> Bool {
        if let current = snapshot {
            guard candidate.sessionId == current.sessionId,
                  candidate.revision > current.revision else { return false }
        }
        snapshot = candidate
        return true
    }

    func clear() {
        snapshot = nil
    }
}
