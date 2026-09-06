import Combine
import Foundation

// Command plumbing: sending, queueing and validating.
//
// Split out of SeatLayerPickerController.swift so no one file in this
// package crosses the readability cap. Behaviour is unchanged.

@MainActor
extension SeatLayerPickerController {
    // MARK: - Command plumbing

    func supports(capability: String, command: String) -> Bool {
        isReady && supports(capability: capability) && supports(command: command)
    }

    func send(_ command: String, _ payload: JSONValue? = nil) async throws -> JSONValue {
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

    func mutation(
        _ command: String,
        _ payload: JSONValue? = nil
    ) async throws -> SeatLayerPickerSnapshot? {
        try await enqueue { generation in
            try await self.applyMutationResult(
                try await self.send(command, payload),
                generation: generation
            )
        }
    }

    func presentation(_ command: String, _ payload: JSONValue? = nil) async throws {
        try await enqueue { _ in _ = try await self.send(command, payload) }
    }

    func lifecycleMutation(
        _ command: String,
        _ payload: JSONValue? = nil
    ) async throws -> SeatLayerPickerLifecycleResult? {
        try await enqueue { generation in
            let raw = try await self.send(command, payload)
            let updated = try await self.applyMutationResult(raw, generation: generation)
            let outcome = decodeSeatLayerPickerAvailabilityOutcome(
                raw["outcome"] ?? raw["result"] ?? raw
            )
            if let outcome { self.apply(outcome: outcome) }
            guard updated != nil || outcome != nil else { return nil }
            return SeatLayerPickerLifecycleResult(snapshot: updated, outcome: outcome)
        }
    }

    func apply(outcome: SeatLayerPickerAvailabilityOutcome) {
        availabilityOutcome = outcome
        guard outcome.holdLapsed else { return }
        let candidate = SeatLayerPickerHoldLapse(
            lapsedLabels: outcome.lapsedLabels,
            recoverableLabels: outcome.recoverableLabels,
            heldForMs: outcome.heldForMs
        )
        if holdLapse.map({ candidate.lapsedLabels.count > $0.lapsedLabels.count }) ?? true {
            holdLapse = candidate
        }
        reportHoldExpired()
    }

    func applyHaptics(for snapshot: SeatLayerPickerHapticSnapshot) {
        let result = SeatLayerPickerHaptics.reduce(hapticPolicy, snapshot: snapshot)
        hapticPolicy = result.state
        play(result.cues)
    }

    func reportHoldExpired() {
        let result = SeatLayerPickerHaptics.signalHoldExpired(hapticPolicy)
        hapticPolicy = result.state
        guard result.cues.contains(.holdExpired) else { return }
        play(result.cues)
        holdExpirationSubject.send(())
    }

    func play(_ cues: [SeatLayerPickerHapticCue]) {
        guard hapticsEnabled, let hapticAdapter else { return }
        for cue in cues {
            hapticAdapter.play(SeatLayerPickerHaptics.strength(for: cue))
        }
    }

    func applyMutationResult(
        _ result: JSONValue,
        generation: UInt64
    ) async throws -> SeatLayerPickerSnapshot? {
        guard runtimeGeneration == generation, phase != .destroyed else {
            throw SeatLayerError.destroyed
        }
        if let decoded = decodeSeatLayerPickerSnapshot(result["snapshot"] ?? result) {
            accept(snapshot: decoded)
        }

        guard let targetRevision = exactRevision(result["revision"]),
              (snapshot?.revision ?? -1) < targetRevision else {
            return snapshot
        }

        let started = DispatchTime.now().uptimeNanoseconds
        while (snapshot?.revision ?? -1) < targetRevision,
              runtimeGeneration == generation,
              DispatchTime.now().uptimeNanoseconds - started < revisionWaitNanoseconds {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        guard runtimeGeneration == generation, phase != .destroyed else {
            throw SeatLayerError.destroyed
        }
        if (snapshot?.revision ?? -1) >= targetRevision { return snapshot }

        let refreshed = try await send("picker.getSnapshot")
        guard runtimeGeneration == generation, phase != .destroyed else {
            throw SeatLayerError.destroyed
        }
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

    func enqueue<T>(
        _ operation: @escaping @MainActor (UInt64) async throws -> T
    ) async throws -> T {
        guard phase != .destroyed else { throw SeatLayerError.destroyed }
        let generation = runtimeGeneration
        let previous = actionTail
        let task = Task<T, Error> { @MainActor in
            if let previous { _ = await previous.result }
            guard self.phase != .destroyed,
                  self.runtimeGeneration == generation else {
                throw SeatLayerError.destroyed
            }
            let result = try await operation(generation)
            guard self.phase != .destroyed,
                  self.runtimeGeneration == generation else {
                throw SeatLayerError.destroyed
            }
            self.lastError = nil
            return result
        }
        actionTail = Task { _ = try? await task.value }
        return try await task.value
    }

    func validateNonEmpty(_ value: String, named name: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw badPayload("SeatLayer \(name) is required.")
        }
    }

    func validateNonEmpty(_ values: [String], named name: String) throws {
        guard values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw badPayload("SeatLayer \(name) must contain non-empty strings.")
        }
    }

    func validatePositive(_ value: Int, named name: String) throws {
        guard value > 0 else {
            throw badPayload("SeatLayer \(name) must be a positive integer.")
        }
    }

    func validate(mapTheme: SeatLayerPickerMapTheme) throws {
        let expression = try NSRegularExpression(pattern: "^#[0-9a-fA-F]{6}$")
        for color in mapTheme.colors {
            let range = NSRange(color.startIndex..<color.endIndex, in: color)
            guard expression.firstMatch(in: color, range: range)?.range == range else {
                throw badPayload("SeatLayer map theme colors must use six-digit hexadecimal notation.")
            }
        }
    }

    func badPayload(_ message: String) -> SeatLayerError {
        .bridge(.init(code: BridgeErrorCode.badPayload, message: message))
    }

    func acceptsRuntimeOwner(_ owner: UUID?) -> Bool {
        guard let owner else { return true }
        return runtimeOwner == owner
    }

    func publishSelectionValidity(_ value: SelectionValidity?) {
        guard let value, value != lastPublishedSelectionValidity else { return }
        lastPublishedSelectionValidity = value
        selectionValiditySubject.send(value)
    }

    func exactRevision(_ value: JSONValue?) -> Int? {
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
