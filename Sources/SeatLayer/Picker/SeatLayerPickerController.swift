import Combine
import Foundation

protocol SeatLayerPickerCommandTransport: Sendable {
    func command(_ name: String, payload: JSONValue?) async throws -> JSONValue
}

extension BridgeClient: SeatLayerPickerCommandTransport {}

/// Lifecycle of one protocol-2 picker runtime.
public enum SeatLayerPickerPhase: Sendable, Equatable {
    case idle
    case loading
    case ready(ReadyInfo)
    case failed(SeatLayerError)
    case destroyed
}

/// Headless protocol-2 picker API.
///
/// Observe `snapshot` to render custom SwiftUI or UIKit chrome, then call these
/// semantic actions instead of sending bridge envelopes yourself. Mutations are
/// serialized so two taps cannot reorder inventory operations.
@MainActor
public final class SeatLayerPickerController: ObservableObject {
    @Published public internal(set) var phase: SeatLayerPickerPhase = .idle
    @Published public internal(set) var snapshot: SeatLayerPickerSnapshot?
    @Published public internal(set) var seatView: SeatLayerSeatView?
    @Published public internal(set) var lastError: SeatLayerError?
    @Published public internal(set) var availabilityOutcome: SeatLayerPickerAvailabilityOutcome?
    @Published public internal(set) var holdLapse: SeatLayerPickerHoldLapse?
    @Published public internal(set) var generalAdmissionCandidate: GAArea?
    /// False until the first viewport-inset report settles with the runtime
    /// ready.
    ///
    /// The first snapshot arrives before the renderer has been told what the
    /// native chrome covers, so a map revealed on that snapshot alone is drawn
    /// once and re-fitted a frame later — which a buyer reads as the screen
    /// loading twice. Presentation only: nothing waits on it, and the picker
    /// is fully ready and callable while it is still false.
    @Published public internal(set) var mapFramed = false

    /// Non-replaying stream of advertised runtime chart-load attempts.
    public var chartLoads: AnyPublisher<SeatLayerChartLoad, Never> {
        chartLoadSubject.eraseToAnyPublisher()
    }

    /// Non-replaying signal for an explicitly expired hold. Deliberate hold
    /// release does not publish here.
    public var holdExpirations: AnyPublisher<Void, Never> {
        holdExpirationSubject.eraseToAnyPublisher()
    }

    /// De-duplicated validity values from either the optional event or the
    /// next authoritative snapshot, whichever arrives first.
    public var selectionValidityChanges: AnyPublisher<SelectionValidity, Never> {
        selectionValiditySubject.eraseToAnyPublisher()
    }

    public var accessExpirations: AnyPublisher<BuyerAccessExpiredEvent, Never> {
        accessExpirationSubject.eraseToAnyPublisher()
    }

    public var accessUnavailability: AnyPublisher<BuyerAccessUnavailableEvent, Never> {
        accessUnavailableSubject.eraseToAnyPublisher()
    }

    /// The buyer tapped a seat that is already in their selection.
    ///
    /// The runtime does not remove it: a second tap is a question, and the
    /// native card answers it. Chrome that draws no card can ignore this
    /// entirely and the seat stays selected, exactly as before.
    public var seatRetaps: AnyPublisher<SelectedSeat, Never> {
        seatRetapSubject.eraseToAnyPublisher()
    }

    public var selectedObjectUnavailability: AnyPublisher<SelectedObjectUnavailableEvent, Never> {
        selectedObjectUnavailableSubject.eraseToAnyPublisher()
    }

    public private(set) var bundleInfo: BundleInfo?

    public var isReady: Bool {
        if case .ready = phase { return true }
        return false
    }

    public var supportsFloorStack: Bool {
        supports(capability: "floor-stack-v1", command: "picker.setFloor")
    }

    public var supportsViewportInsets: Bool {
        supports(capability: "viewport-insets-v1", command: "picker.setViewportInsets")
    }

    public var supportsVenue3D: Bool {
        supports(capability: "venue-3d-v1", command: "picker.setBuyerView")
    }

    public var supportsSeatView: Bool {
        supports(capability: "seat-view-v1", command: "picker.openSeatView")
    }

    public var supportsNativeSeatViewChrome: Bool {
        bundleInfo?.supports(capability: "native-seat-view-chrome-v1") == true
            && bundleInfo?.events.contains("seatView.changed") == true
    }

    public var supportsAvailabilityRefresh: Bool {
        supports(capability: "availability-refresh-v1", command: "picker.refreshAvailability")
    }

    public var supportsHoldSelection: Bool {
        supports(capability: "hold-selection-v1", command: "picker.holdSelection")
    }

    let snapshots = SeatLayerPickerSnapshotStore()
    let revisionWaitNanoseconds: UInt64
    var transport: (any SeatLayerPickerCommandTransport)?
    var actionTail: Task<Void, Never>?
    var checkoutFlight: (id: UUID, task: Task<SeatLayerPickerCheckoutHandoff, Error>)?
    var availabilityRefreshFlight: Task<SeatLayerPickerLifecycleResult?, Never>?
    let chartLoadSubject = PassthroughSubject<SeatLayerChartLoad, Never>()
    var chartLoadStartedAtMs: Double?
    var chartLoadTapToReadyMs: Int?
    var chartLoadReady: ReadyInfo?
    var pendingSuccessfulChartLoads: [SeatLayerChartLoadTrace] = []
    let holdExpirationSubject = PassthroughSubject<Void, Never>()
    let selectionValiditySubject = PassthroughSubject<SelectionValidity, Never>()
    let accessExpirationSubject = PassthroughSubject<BuyerAccessExpiredEvent, Never>()
    let accessUnavailableSubject = PassthroughSubject<BuyerAccessUnavailableEvent, Never>()
    let selectedObjectUnavailableSubject = PassthroughSubject<SelectedObjectUnavailableEvent, Never>()
    let seatRetapSubject = PassthroughSubject<SelectedSeat, Never>()
    var lastPublishedSelectionValidity: SelectionValidity?
    var hapticPolicy = SeatLayerPickerHaptics.initialState
    var hapticsEnabled = false
    var hapticAdapter: (any SeatLayerPickerHapticAdapter)?
    var runtimeOwner: UUID?
    var runtimeGeneration: UInt64 = 0

    public init() {
        revisionWaitNanoseconds = 2_000_000_000
    }

    init(
        transport: any SeatLayerPickerCommandTransport,
        bundleInfo: BundleInfo,
        revisionWaitNanoseconds: UInt64 = 2_000_000_000
    ) {
        self.transport = transport
        self.bundleInfo = bundleInfo
        self.revisionWaitNanoseconds = revisionWaitNanoseconds
        self.phase = .loading
    }

    public func supports(capability: String) -> Bool {
        bundleInfo?.supports(capability: capability) == true
    }

    public func supports(command: String) -> Bool {
        bundleInfo?.supports(command: command) == true
    }

    public func supports(event: String) -> Bool {
        bundleInfo?.events.contains(event) == true
    }

    /// Configure optional native feedback without placing a haptic choice in
    /// the renderer configuration. State continues tracking while disabled so
    /// enabling feedback never replays earlier buyer actions.
    public func configureHaptics(
        enabled: Bool,
        adapter: (any SeatLayerPickerHapticAdapter)?
    ) {
        hapticsEnabled = enabled
        hapticAdapter = adapter
    }

    /// Dismiss the current inline command error without changing picker state.
    public func dismissError() {
        lastError = nil
    }

    // MARK: - Snapshot and selection

    @discardableResult
    public func synchronize() async throws -> SeatLayerPickerSnapshot? {
        try await mutation("picker.getSnapshot")
    }

    @discardableResult
    public func selectObjects(_ objects: [String]) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(objects, named: "objects")
        return try await mutation("picker.selectObjects", [
            "objects": .array(objects.map(JSONValue.string)),
        ])
    }

    @discardableResult
    public func deselectObjects(_ objects: [String]) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(objects, named: "objects")
        return try await mutation("picker.deselectObjects", [
            "objects": .array(objects.map(JSONValue.string)),
        ])
    }

    @discardableResult
    public func clearSelection() async throws -> SeatLayerPickerSnapshot? {
        try await mutation("picker.clearSelection")
    }

    @discardableResult
    public func selectCategories(_ categoryKeys: [String]) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(categoryKeys, named: "categoryKeys")
        return try await mutation("picker.selectCategories", [
            "categoryKeys": .array(categoryKeys.map(JSONValue.string)),
        ])
    }

    @discardableResult
    public func deselectCategories(_ categoryKeys: [String]) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(categoryKeys, named: "categoryKeys")
        return try await mutation("picker.deselectCategories", [
            "categoryKeys": .array(categoryKeys.map(JSONValue.string)),
        ])
    }

    @discardableResult
    public func setSeatTier(seatId: String, tierId: String?) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(seatId, named: "seatId")
        if let tierId { try validateNonEmpty(tierId, named: "tierId") }
        return try await mutation("picker.setSeatTier", [
            "seatId": .string(seatId),
            "tierId": tierId.map(JSONValue.string) ?? .null,
        ])
    }

    @discardableResult
    public func removeCartLine(label: String) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(label, named: "label")
        return try await mutation("picker.removeCartLine", ["label": .string(label)])
    }

    @discardableResult
    public func setTableQuantity(
        label: String,
        quantity: Int,
        ttlMs: Int? = nil
    ) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(label, named: "label")
        try validatePositive(quantity, named: "quantity")
        if let ttlMs { try validatePositive(ttlMs, named: "ttlMs") }
        return try await mutation("picker.setTableQuantity", .object(compacting: [
            "label": .string(label),
            "quantity": .int(quantity),
            "ttlMs": ttlMs.map(JSONValue.int),
        ]))
    }

    @discardableResult
    public func setSelectableObjects(_ objects: [String]?) async throws -> SeatLayerPickerSnapshot? {
        if let objects { try validateNonEmpty(objects, named: "objects") }
        return try await mutation("picker.setSelectableObjects", [
            "objects": objects.map { .array($0.map(JSONValue.string)) } ?? .null,
        ])
    }

    @discardableResult
    public func setMaxSelection(_ maximum: Int) async throws -> SeatLayerPickerSnapshot? {
        try validatePositive(maximum, named: "maxSelection")
        return try await mutation("picker.setMaxSelection", ["maxSelection": .int(maximum)])
    }

    // MARK: - Runtime integration

    func beginLoading(
        startedAtMilliseconds: Double? = nil,
        owner: UUID? = nil
    ) {
        runtimeOwner = owner
        runtimeGeneration &+= 1
        actionTail?.cancel()
        actionTail = nil
        checkoutFlight?.task.cancel()
        checkoutFlight = nil
        availabilityRefreshFlight?.cancel()
        availabilityRefreshFlight = nil
        snapshots.clear()
        snapshot = nil
        seatView = nil
        lastError = nil
        availabilityOutcome = nil
        holdLapse = nil
        generalAdmissionCandidate = nil
        mapFramed = false
        hapticPolicy = SeatLayerPickerHaptics.initialState
        chartLoadStartedAtMs = startedAtMilliseconds ?? Self.monotonicMilliseconds()
        chartLoadTapToReadyMs = nil
        chartLoadReady = nil
        pendingSuccessfulChartLoads.removeAll(keepingCapacity: false)
        lastPublishedSelectionValidity = nil
        bundleInfo = nil
        transport = nil
        phase = .loading
    }

    func connect(
        transport: any SeatLayerPickerCommandTransport,
        bundleInfo: BundleInfo,
        owner: UUID? = nil
    ) {
        guard acceptsRuntimeOwner(owner) else { return }
        self.transport = transport
        self.bundleInfo = bundleInfo
    }

    func markReady(
        _ info: ReadyInfo,
        payload: JSONValue?,
        readyAtMilliseconds: Double? = nil,
        owner: UUID? = nil
    ) {
        guard acceptsRuntimeOwner(owner) else { return }
        if let candidate = decodeSeatLayerPickerSnapshot(payload?["snapshot"] ?? payload) {
            accept(snapshot: candidate, owner: owner)
        }
        phase = .ready(info)
        if chartLoadReady == nil, let started = chartLoadStartedAtMs {
            let finished = readyAtMilliseconds ?? Self.monotonicMilliseconds()
            if finished.isFinite, finished >= started {
                chartLoadTapToReadyMs = Int((finished - started).rounded())
            }
            chartLoadReady = info
        }
        if !pendingSuccessfulChartLoads.isEmpty {
            let traces = pendingSuccessfulChartLoads
            pendingSuccessfulChartLoads.removeAll(keepingCapacity: false)
            for trace in traces { publish(chartLoad: trace) }
        }
    }

    func accept(snapshot value: JSONValue?, owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner) else { return }
        guard let decoded = decodeSeatLayerPickerSnapshot(value) else { return }
        accept(snapshot: decoded, owner: owner)
    }

    func accept(snapshot candidate: SeatLayerPickerSnapshot, owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner) else { return }
        guard snapshots.apply(candidate) else { return }
        snapshot = candidate
        publishSelectionValidity(candidate.selectionValidity)
        if candidate.hold.active { holdLapse = nil }
        applyHaptics(for: SeatLayerPickerHapticSnapshot(candidate))
    }

    func accept(seatView value: JSONValue?, owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner) else { return }
        guard supportsNativeSeatViewChrome else { return }
        seatView = decodeSeatLayerSeatView(value)
    }

    func accept(chartLoad payload: JSONValue?, owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner) else { return }
        guard supports(capability: "chart-load-trace-v1"),
              supports(event: "telemetry.chartLoad"),
              let trace = decodeSeatLayerChartLoadEvent(payload) else { return }
        // The hosted runtime reports a completed render immediately before
        // sys.ready. Hold only successful traces for that final native timing
        // edge; failures must remain observable even when ready never arrives.
        if trace.succeeded, chartLoadReady == nil {
            if pendingSuccessfulChartLoads.count == 4 {
                pendingSuccessfulChartLoads.removeFirst()
            }
            pendingSuccessfulChartLoads.append(trace)
            return
        }
        publish(chartLoad: trace)
    }

    func publish(chartLoad trace: SeatLayerChartLoadTrace) {
        chartLoadSubject.send(SeatLayerChartLoad(
            trace: trace,
            tapToReadyMs: chartLoadTapToReadyMs,
            ready: chartLoadReady
        ))
    }

    func acceptHoldExpired(owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner) else { return }
        guard supports(event: "hold.expired") else { return }
        reportHoldExpired()
    }

    func accept(selectionValidity value: SelectionValidity, owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner) else { return }
        publishSelectionValidity(value)
    }

    func accept(accessExpired event: BuyerAccessExpiredEvent, owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner) else { return }
        accessExpirationSubject.send(event)
    }

    func accept(accessUnavailable event: BuyerAccessUnavailableEvent, owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner) else { return }
        accessUnavailableSubject.send(event)
    }

    func accept(
        selectedObjectsUnavailable event: SelectedObjectUnavailableEvent,
        owner: UUID? = nil
    ) {
        guard acceptsRuntimeOwner(owner) else { return }
        selectedObjectUnavailableSubject.send(event)
    }

    func accept(seatRetap seat: SelectedSeat, owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner) else { return }
        seatRetapSubject.send(seat)
    }

    func accept(generalAdmissionCandidate area: GAArea, owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner) else { return }
        guard isReady else { return }
        generalAdmissionCandidate = area
    }

    public func dismissGeneralAdmissionCandidate() {
        generalAdmissionCandidate = nil
    }

    func fail(_ error: SeatLayerError, owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner) else { return }
        lastError = error
        phase = .failed(error)
    }

    func record(_ error: SeatLayerError, owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner) else { return }
        lastError = error
    }

    nonisolated static func monotonicMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }

    func markDestroyed(owner: UUID? = nil) {
        guard acceptsRuntimeOwner(owner) else { return }
        runtimeGeneration &+= 1
        runtimeOwner = nil
        actionTail?.cancel()
        actionTail = nil
        checkoutFlight?.task.cancel()
        checkoutFlight = nil
        availabilityRefreshFlight?.cancel()
        availabilityRefreshFlight = nil
        transport = nil
        seatView = nil
        availabilityOutcome = nil
        holdLapse = nil
        generalAdmissionCandidate = nil
        mapFramed = false
        hapticPolicy = SeatLayerPickerHaptics.initialState
        lastPublishedSelectionValidity = nil
        phase = .destroyed
    }

}
