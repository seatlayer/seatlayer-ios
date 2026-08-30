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
    @Published public private(set) var phase: SeatLayerPickerPhase = .idle
    @Published public private(set) var snapshot: SeatLayerPickerSnapshot?
    @Published public private(set) var seatView: SeatLayerSeatView?
    @Published public private(set) var lastError: SeatLayerError?

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

    private let snapshots = SeatLayerPickerSnapshotStore()
    private let revisionWaitNanoseconds: UInt64
    private var transport: (any SeatLayerPickerCommandTransport)?
    private var actionTail: Task<Void, Never>?
    private var checkoutFlight: (id: UUID, task: Task<SeatLayerPickerCheckoutHandoff, Error>)?

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

    // MARK: - Filters and map navigation

    @discardableResult
    public func setCategoryFilter(
        _ categoryKeys: [String],
        focus: Bool = false
    ) async throws -> SeatLayerPickerSnapshot? {
        if !categoryKeys.isEmpty { try validateNonEmpty(categoryKeys, named: "categoryKeys") }
        return try await mutation("picker.setCategoryFilter", .object(compacting: [
            "categoryKeys": categoryKeys.isEmpty
                ? .null
                : .array(categoryKeys.map(JSONValue.string)),
            "focus": focus ? .bool(true) : nil,
        ]))
    }

    @discardableResult
    public func setAccessibilityFilter(_ types: [String]) async throws -> SeatLayerPickerSnapshot? {
        if !types.isEmpty { try validateNonEmpty(types, named: "types") }
        return try await mutation("picker.setAccessibilityFilter", [
            "types": types.isEmpty ? .null : .array(types.map(JSONValue.string)),
        ])
    }

    @discardableResult
    public func setLimitedViewFilter(_ enabled: Bool) async throws -> SeatLayerPickerSnapshot? {
        try await mutation("picker.setLimitedViewFilter", ["on": .bool(enabled)])
    }

    @discardableResult
    public func focusSection(_ sectionId: String) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(sectionId, named: "sectionId")
        return try await mutation("picker.focusSection", ["sectionId": .string(sectionId)])
    }

    @discardableResult
    public func overview() async throws -> SeatLayerPickerSnapshot? {
        try await mutation("picker.overview")
    }

    @discardableResult
    public func setRung(_ rung: String) async throws -> SeatLayerPickerSnapshot? {
        guard ["zones", "sections", "seats"].contains(rung) else {
            throw badPayload("SeatLayer rung must be zones, sections, or seats.")
        }
        return try await mutation("picker.setRung", ["rung": .string(rung)])
    }

    @discardableResult
    public func setFloor(_ floorId: String) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(floorId, named: "floorId")
        return try await mutation("picker.setFloor", ["floorId": .string(floorId)])
    }

    @discardableResult
    public func showAllFloors() async throws -> SeatLayerPickerSnapshot? {
        guard supportsFloorStack else { return snapshot }
        return try await setFloor(seatLayerAllFloors)
    }

    @discardableResult
    public func setColorblindSafe(_ enabled: Bool) async throws -> SeatLayerPickerSnapshot? {
        try await mutation("picker.setColorblindSafe", ["on": .bool(enabled)])
    }

    @discardableResult
    public func setViewMode(_ mode: SeatLayerViewMode) async throws -> SeatLayerPickerSnapshot? {
        try await mutation("picker.setViewMode", ["mode": .string(mode.rawValue)])
    }

    @discardableResult
    public func setBuyerView(
        _ view: String,
        flyToSeatId: String? = nil,
        resetView: Bool = false
    ) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(view, named: "view")
        if let flyToSeatId { try validateNonEmpty(flyToSeatId, named: "flyToSeatId") }
        guard supportsVenue3D else { return snapshot }
        return try await mutation("picker.setBuyerView", .object(compacting: [
            "view": .string(view),
            "flyToSeatId": flyToSeatId.map(JSONValue.string),
            "resetView": resetView ? .bool(true) : nil,
        ]))
    }

    @discardableResult
    public func openSeatView(_ seatId: String) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(seatId, named: "seatId")
        guard supportsSeatView else { return snapshot }
        return try await mutation("picker.openSeatView", ["seatId": .string(seatId)])
    }

    @discardableResult
    public func setVenue3DNavigationMode(_ mode: String) async throws -> SeatLayerPickerSnapshot? {
        guard ["orbit", "pan"].contains(mode) else {
            throw badPayload("SeatLayer 3D navigation mode must be orbit or pan.")
        }
        guard supports(capability: "venue-3d-controls-v1", command: "picker.setVenue3DNavigationMode") else {
            return snapshot
        }
        return try await mutation("picker.setVenue3DNavigationMode", ["mode": .string(mode)])
    }

    public func zoomIn() async throws { _ = try await mutation("picker.zoomIn") }
    public func zoomOut() async throws { _ = try await mutation("picker.zoomOut") }
    public func zoomToFit() async throws { _ = try await mutation("picker.zoomToFit") }

    public func setThemeMode(
        _ mode: SeatLayerPickerThemeMode?,
        mapTheme: SeatLayerPickerMapTheme? = nil
    ) async throws {
        if let mapTheme { try validate(mapTheme: mapTheme) }
        var payload: [String: JSONValue] = [
            "mode": mode.map { .string($0.rawValue) } ?? .null,
        ]
        if supports(capability: "native-chrome-contract-v1"), let mapTheme {
            payload["mapTheme"] = mapTheme.jsonValue
        }
        try await presentation("picker.setThemeMode", .object(payload))
    }

    public func setInteractionEnabled(_ enabled: Bool) async throws {
        try await presentation("picker.setInteractionEnabled", ["enabled": .bool(enabled)])
    }

    public func setViewportInsets(_ insets: SeatLayerPickerViewportInsets?) async throws {
        guard supportsViewportInsets else { return }
        let payload: JSONValue
        if let insets {
            guard [insets.top, insets.right, insets.bottom, insets.left]
                .allSatisfy({ $0.isFinite && $0 >= 0 }) else {
                throw badPayload("SeatLayer viewport insets must be finite numbers greater than or equal to zero.")
            }
            payload = [
                "top": .double(insets.top),
                "right": .double(insets.right),
                "bottom": .double(insets.bottom),
                "left": .double(insets.left),
            ]
        } else {
            payload = ["insets": .null]
        }
        try await presentation("picker.setViewportInsets", payload)
    }

    // MARK: - Holds and checkout

    @discardableResult
    public func holdGeneralAdmission(
        areaId: String,
        quantity: Int,
        tierId: String?? = nil,
        ttlMs: Int? = nil
    ) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(areaId, named: "areaId")
        try validatePositive(quantity, named: "quantity")
        if let tierId, let tier = tierId { try validateNonEmpty(tier, named: "tierId") }
        if let ttlMs { try validatePositive(ttlMs, named: "ttlMs") }
        var payload: [String: JSONValue] = [
            "areaId": .string(areaId),
            "qty": .int(quantity),
        ]
        if let tierId { payload["tierId"] = tierId.map(JSONValue.string) ?? .null }
        if let ttlMs { payload["ttlMs"] = .int(ttlMs) }
        return try await mutation("picker.holdGA", .object(payload))
    }

    @discardableResult
    public func bestAvailable(
        quantity: Int,
        categoryKey: String? = nil,
        zoneId: String? = nil,
        preferPremium: Bool = false,
        ttlMs: Int? = nil
    ) async throws -> SeatLayerPickerSnapshot? {
        try validatePositive(quantity, named: "quantity")
        if let categoryKey { try validateNonEmpty(categoryKey, named: "categoryKey") }
        if let zoneId { try validateNonEmpty(zoneId, named: "zoneId") }
        if let ttlMs { try validatePositive(ttlMs, named: "ttlMs") }
        return try await mutation("picker.bestAvailable", .object(compacting: [
            "qty": .int(quantity),
            "categoryKey": categoryKey.map(JSONValue.string),
            "zoneId": zoneId.map(JSONValue.string),
            "preferPremium": .bool(preferPremium),
            "ttlMs": ttlMs.map(JSONValue.int),
        ]))
    }

    @discardableResult
    public func resumeHold(_ holdId: String) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(holdId, named: "holdId")
        return try await mutation("picker.resumeHold", ["holdId": .string(holdId)])
    }

    @discardableResult
    public func extendHold(ttlMs: Int? = nil) async throws -> SeatLayerPickerSnapshot? {
        if let ttlMs { try validatePositive(ttlMs, named: "ttlMs") }
        return try await mutation(
            "picker.extendHold",
            .object(compacting: ["ttlMs": ttlMs.map(JSONValue.int)])
        )
    }

    @discardableResult
    public func abort() async throws -> SeatLayerPickerSnapshot? {
        try await mutation("picker.abort")
    }

    @discardableResult
    public func rejectHandoff(_ holdId: String) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(holdId, named: "holdId")
        return try await mutation("picker.rejectHandoff", ["holdId": .string(holdId)])
    }

    public func checkout(ttlMs: Int? = nil) async throws -> SeatLayerPickerCheckoutHandoff {
        if let ttlMs { try validatePositive(ttlMs, named: "ttlMs") }
        if let checkoutFlight { return try await checkoutFlight.task.value }

        let id = UUID()
        let task = Task { @MainActor [weak self] in
            guard let self else { throw SeatLayerError.destroyed }
            return try await self.enqueue {
                let result = try await self.send(
                    "picker.continue",
                    .object(compacting: ["ttlMs": ttlMs.map(JSONValue.int)])
                )
                _ = try await self.applyMutationResult(result)
                guard let handoff = decodeSeatLayerPickerCheckoutHandoff(result["handoff"]) else {
                    throw SeatLayerError.decoding("picker.continue returned no checkout handoff")
                }
                return handoff
            }
        }
        checkoutFlight = (id, task)
        defer {
            if checkoutFlight?.id == id { checkoutFlight = nil }
        }
        return try await task.value
    }

    @discardableResult
    public func setLifecycle(_ state: String) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(state, named: "state")
        let wireState = state == "resumed" || state == "foreground" ? "foreground" : "background"
        return try await mutation("picker.lifecycle", ["state": .string(wireState)])
    }

    public func destroy() async throws {
        guard phase != .destroyed else { return }
        _ = try? await enqueue { try await self.send("picker.destroy") }
        markDestroyed()
    }

    // MARK: - Runtime integration

    func beginLoading() {
        actionTail?.cancel()
        actionTail = nil
        checkoutFlight?.task.cancel()
        checkoutFlight = nil
        snapshots.clear()
        snapshot = nil
        seatView = nil
        lastError = nil
        bundleInfo = nil
        transport = nil
        phase = .loading
    }

    func connect(
        transport: any SeatLayerPickerCommandTransport,
        bundleInfo: BundleInfo
    ) {
        self.transport = transport
        self.bundleInfo = bundleInfo
    }

    func markReady(_ info: ReadyInfo, payload: JSONValue?) {
        if let candidate = decodeSeatLayerPickerSnapshot(payload?["snapshot"] ?? payload) {
            accept(snapshot: candidate)
        }
        phase = .ready(info)
    }

    func accept(snapshot value: JSONValue?) {
        guard let decoded = decodeSeatLayerPickerSnapshot(value) else { return }
        accept(snapshot: decoded)
    }

    func accept(snapshot candidate: SeatLayerPickerSnapshot) {
        guard snapshots.apply(candidate) else { return }
        snapshot = candidate
    }

    func accept(seatView value: JSONValue?) {
        guard supportsNativeSeatViewChrome else { return }
        seatView = decodeSeatLayerSeatView(value)
    }

    func fail(_ error: SeatLayerError) {
        lastError = error
        phase = .failed(error)
    }

    func record(_ error: SeatLayerError) {
        lastError = error
    }

    func markDestroyed() {
        actionTail?.cancel()
        actionTail = nil
        checkoutFlight?.task.cancel()
        checkoutFlight = nil
        transport = nil
        seatView = nil
        phase = .destroyed
    }

    // MARK: - Command plumbing

    private func supports(capability: String, command: String) -> Bool {
        isReady && supports(capability: capability) && supports(command: command)
    }

    private func send(_ command: String, _ payload: JSONValue? = nil) async throws -> JSONValue {
        guard phase != .destroyed else { throw SeatLayerError.destroyed }
        guard isReady || command == "picker.destroy" else {
            throw SeatLayerError.bridge(.init(
                code: BridgeErrorCode.notReady,
                message: "SeatLayer picker is not ready."
            ))
        }
        guard let transport else {
            throw SeatLayerError.bridge(.init(
                code: BridgeErrorCode.notReady,
                message: "SeatLayer picker is not connected."
            ))
        }
        guard supports(command: command) else {
            throw SeatLayerError.bridge(.init(
                code: BridgeErrorCode.unsupportedCommand,
                message: "The loaded picker does not advertise '\(command)'."
            ))
        }
        return try await transport.command(command, payload: payload)
    }

    private func mutation(
        _ command: String,
        _ payload: JSONValue? = nil
    ) async throws -> SeatLayerPickerSnapshot? {
        try await enqueue {
            try await self.applyMutationResult(try await self.send(command, payload))
        }
    }

    private func presentation(_ command: String, _ payload: JSONValue? = nil) async throws {
        try await enqueue { _ = try await self.send(command, payload) }
    }

    private func applyMutationResult(_ result: JSONValue) async throws -> SeatLayerPickerSnapshot? {
        if let decoded = decodeSeatLayerPickerSnapshot(result["snapshot"] ?? result) {
            accept(snapshot: decoded)
        }

        guard let targetRevision = exactRevision(result["revision"]),
              (snapshot?.revision ?? -1) < targetRevision else {
            return snapshot
        }

        let started = DispatchTime.now().uptimeNanoseconds
        while (snapshot?.revision ?? -1) < targetRevision,
              DispatchTime.now().uptimeNanoseconds - started < revisionWaitNanoseconds {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        if (snapshot?.revision ?? -1) >= targetRevision { return snapshot }

        let refreshed = try await send("picker.getSnapshot")
        if let decoded = decodeSeatLayerPickerSnapshot(refreshed["snapshot"] ?? refreshed) {
            accept(snapshot: decoded)
        }
        guard (snapshot?.revision ?? -1) >= targetRevision else {
            throw SeatLayerError.decoding(
                "picker.getSnapshot did not reach revision \(targetRevision)"
            )
        }
        return snapshot
    }

    private func enqueue<T>(
        _ operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        guard phase != .destroyed else { throw SeatLayerError.destroyed }
        let previous = actionTail
        let task = Task<T, Error> { @MainActor in
            if let previous { _ = await previous.result }
            guard self.phase != .destroyed else { throw SeatLayerError.destroyed }
            return try await operation()
        }
        actionTail = Task { _ = try? await task.value }
        return try await task.value
    }

    private func validateNonEmpty(_ value: String, named name: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw badPayload("SeatLayer \(name) is required.")
        }
    }

    private func validateNonEmpty(_ values: [String], named name: String) throws {
        guard values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw badPayload("SeatLayer \(name) must contain non-empty strings.")
        }
    }

    private func validatePositive(_ value: Int, named name: String) throws {
        guard value > 0 else {
            throw badPayload("SeatLayer \(name) must be a positive integer.")
        }
    }

    private func validate(mapTheme: SeatLayerPickerMapTheme) throws {
        let expression = try NSRegularExpression(pattern: "^#[0-9a-fA-F]{6}$")
        for color in mapTheme.colors {
            let range = NSRange(color.startIndex..<color.endIndex, in: color)
            guard expression.firstMatch(in: color, range: range)?.range == range else {
                throw badPayload("SeatLayer map theme colors must use six-digit hexadecimal notation.")
            }
        }
    }

    private func badPayload(_ message: String) -> SeatLayerError {
        .bridge(.init(code: BridgeErrorCode.badPayload, message: message))
    }

    private func exactRevision(_ value: JSONValue?) -> Int? {
        switch value {
        case .int(let revision):
            return revision
        case .double(let revision) where revision.isFinite && revision.rounded() == revision:
            return Int(exactly: revision)
        default:
            return nil
        }
    }
}
