import Combine
import Foundation

// Holds, checkout handoff, lifecycle and availability refresh.
//
// Split out of SeatLayerPickerController.swift so no one file in this
// package crosses the readability cap. Behaviour is unchanged.

@MainActor
extension SeatLayerPickerController {
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
            return try await self.enqueue { generation in
                let result = try await self.send(
                    "picker.continue",
                    .object(compacting: ["ttlMs": ttlMs.map(JSONValue.int)])
                )
                let updated = try await self.applyMutationResult(result, generation: generation)
                let categories = updated?.categories ?? self.snapshot?.categories ?? []
                guard let handoff = decodeSeatLayerPickerCheckoutHandoff(
                    result["handoff"],
                    categories: categories
                ) else {
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

    /// Hold the current selection without minting a checkout handoff.
    @discardableResult
    public func holdSelection(ttlMs: Int? = nil) async throws -> SeatLayerPickerSnapshot? {
        if let ttlMs { try validatePositive(ttlMs, named: "ttlMs") }
        guard supportsHoldSelection else { return snapshot }
        return try await mutation(
            "picker.holdSelection",
            .object(compacting: ["ttlMs": ttlMs.map(JSONValue.int)])
        )
    }

    /// Report a foreground/background transition and retain any availability
    /// outcome carried by a foreground reply.
    public func lifecycle(_ state: String) async throws -> SeatLayerPickerLifecycleResult? {
        try validateNonEmpty(state, named: "state")
        let resolved: String
        switch state {
        case "resumed", "foreground":
            resolved = "foreground"
        case "paused", "background":
            resolved = "background"
        default:
            throw badPayload("SeatLayer lifecycle state must be foreground or background.")
        }
        return try await lifecycleMutation(
            "picker.lifecycle",
            ["state": .string(resolved)]
        )
    }

    @discardableResult
    public func setLifecycle(_ state: String) async throws -> SeatLayerPickerSnapshot? {
        try await lifecycle(state)?.snapshot ?? snapshot
    }

    /// Shared ready-picker lifecycle policy. SwiftUI calls this from
    /// `scenePhase`; the UIKit convenience host calls it from application
    /// notifications because an embedded hosting controller does not always
    /// receive scene-phase changes.
    func reconcileApplicationLifecycle(
        foreground: Bool,
        refreshOnResume: Bool
    ) async {
        guard isReady else { return }
        do {
            let lifecycle = try await lifecycle(foreground ? "foreground" : "background")
            guard foreground else { return }
            if refreshOnResume, lifecycle?.outcome == nil {
                _ = await refreshAvailability()
            }
            _ = try? await synchronize()
        } catch let error as SeatLayerError {
            record(error)
        } catch {
            record(.transport(error.localizedDescription))
        }
    }

    /// Re-read live availability. Unsupported runtimes and housekeeping
    /// failures leave the picker usable. Overlapping callers share one read.
    public func refreshAvailability() async -> SeatLayerPickerLifecycleResult? {
        if let availabilityRefreshFlight {
            return await availabilityRefreshFlight.value
        }
        guard supportsAvailabilityRefresh else { return nil }

        let task = Task { @MainActor [weak self] () -> SeatLayerPickerLifecycleResult? in
            guard let self else { return nil }
            do {
                return try await self.lifecycleMutation("picker.refreshAvailability")
            } catch let error as SeatLayerError {
                self.record(error)
                return nil
            } catch {
                self.record(.transport(error.localizedDescription))
                return nil
            }
        }
        availabilityRefreshFlight = task
        let result = await task.value
        availabilityRefreshFlight = nil
        return result
    }

    public func dismissHoldLapse() {
        holdLapse = nil
    }

    /// Re-select only labels the server reported recoverable, then recreate a
    /// hold when the optional runtime command exists.
    @discardableResult
    public func reselectLapsedSeats(ttlMs: Int? = nil) async throws -> SeatLayerPickerSnapshot? {
        guard let lapse = holdLapse, !lapse.recoverableLabels.isEmpty else { return snapshot }
        _ = try await selectObjects(lapse.recoverableLabels)
        holdLapse = nil
        if supportsHoldSelection { _ = try await holdSelection(ttlMs: ttlMs) }
        return snapshot
    }

    public func destroy() async throws {
        guard phase != .destroyed else { return }
        _ = try? await enqueue { _ in try await self.send("picker.destroy") }
        markDestroyed()
    }

}
