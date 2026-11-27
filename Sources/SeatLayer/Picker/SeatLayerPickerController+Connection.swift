import Foundation

extension SeatLayerPickerController {
    /// Whether the page reports its line to the server.
    public var supportsConnectionState: Bool {
        isReady && supports(capability: "connection-state-v1")
    }

    func makeConnectionWatch(schedule: SeatLayerConnectionSchedule? = nil) -> SeatLayerConnectionWatch {
        let watch = SeatLayerConnectionWatch(schedule: schedule)
        watch.onShown = { [weak self] shown in self?.connectionShown = shown }
        watch.onState = { [weak self] state in self?.connection = state }
        return watch
    }

    /// The page's `connection.changed`.
    func accept(connection payload: JSONValue?, owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner), supportsConnectionState else { return }
        connectionWatch.heard(SeatLayerConnectionState(page: payload?["state"]))
    }
}
