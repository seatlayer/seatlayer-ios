import Foundation

/// The candidate seat, and the pan that puts it where the card can stand.
///
/// A tapped seat joins `selection` the moment it is tapped, and every selected
/// seat is painted alike — the one a card is asking about and the five settled
/// minutes ago. `picker.setSelectionFocus` tells the runtime which one the
/// card is about, so it can ring that seat and pale its neighbours.
/// `picker.frameSeat` is the pan that keeps the seat and its card together:
/// x untouched, zoom untouched, the seat landing at a fraction of the band
/// left clear above the sheet.
///
/// Both are gated on the command appearing in the bundle's own `hello` table
/// rather than on a capability string: neither changes anything a snapshot
/// reports, so the command table is the whole contract. A runtime that
/// advertises neither is left drawing and framing exactly as it did before.

/// The bridge command that paints the candidate seat.
let seatLayerSelectionFocusCommand = "picker.setSelectionFocus"

/// The bridge command that pans one seat into the clear band.
let seatLayerFrameSeatCommand = "picker.frameSeat"

/// Where in the band left clear above the card the seat comes to rest.
public let seatLayerSheetSeatFraction = 0.48

/// What the runtime answers a frame with.
public struct SeatLayerSeatFrame: Sendable, Equatable {
    /// The screen-space vertical pan the runtime made. Zero when it declined,
    /// or when the seat was already in place.
    public let dy: Double
    /// The runtime's count of the buyer's own camera moves, handed back on a
    /// later frame so it can refuse once the buyer has taken the wheel.
    public let gestures: Int

    public init(dy: Double, gestures: Int) {
        self.dy = dy
        self.gestures = gestures
    }

    /// From the command's reply, or nil for a reply that is not one.
    public init?(_ value: JSONValue?) {
        guard let dy = value?["dy"]?.doubleValue,
              let gestures = value?["gestures"]?.intValue else { return nil }
        self.init(dy: dy, gestures: gestures)
    }
}

@MainActor
extension SeatLayerPickerController {
    /// Whether the mounted runtime paints a candidate seat.
    public var supportsSelectionFocus: Bool {
        isReady && supports(command: seatLayerSelectionFocusCommand)
    }

    /// Whether the mounted runtime can pan a seat into place.
    public var supportsSeatFraming: Bool {
        isReady && supports(command: seatLayerFrameSeatCommand)
    }

    /// Paint `seatId` as the seat the buyer is being asked about, or clear the
    /// candidate with nil.
    ///
    /// Paint only: it selects nothing, holds nothing and moves no camera, so
    /// it is safe on a read-only picker. Nothing is sent to a runtime that
    /// does not advertise the command, and a runtime that advertises it and
    /// still answers `unsupported_command` leaves the seat painted as it was
    /// rather than raising a failure the buyer can do nothing about.
    public func setSelectionFocus(_ seatId: String?) async {
        guard supportsSelectionFocus else { return }
        do {
            try await presentation(
                seatLayerSelectionFocusCommand,
                .object(["seatId": seatId.map(JSONValue.string) ?? .null])
            )
        } catch {
            swallowUnsupported(error)
        }
    }

    /// Pan `seatId` into the band left clear above the card.
    ///
    /// - Parameters:
    ///   - fraction: where in the clear band the seat lands, 0...1.
    ///   - animate: whether the runtime tweens the pan.
    ///   - gestures: the buyer camera-move count a previous frame returned, so
    ///     the runtime can decline once the buyer has moved the map themselves.
    ///
    /// Returns nil when the runtime cannot frame, declined, or answered with
    /// something that is not a frame.
    @discardableResult
    public func frameSeat(
        _ seatId: String,
        fraction: Double? = seatLayerSheetSeatFraction,
        animate: Bool? = nil,
        gestures: Int? = nil
    ) async -> SeatLayerSeatFrame? {
        guard supportsSeatFraming else { return nil }
        let trimmed = seatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // The runtime refuses the whole command for one out-of-range value,
        // so clamp here rather than hand it something it will reject.
        var payload: [String: JSONValue] = ["seatId": .string(trimmed)]
        if let fraction {
            payload["fraction"] = .double(min(1, max(0, fraction)))
        }
        if let animate { payload["animate"] = .bool(animate) }
        if let gestures { payload["gestures"] = .int(max(0, gestures)) }
        do {
            return try await enqueue { _ in
                SeatLayerSeatFrame(
                    try await self.send(seatLayerFrameSeatCommand, .object(payload))
                )
            }
        } catch {
            swallowUnsupported(error)
            return nil
        }
    }

    /// Keeps a command a runtime declined out of the buyer's way, and lets
    /// every other failure surface as usual.
    func swallowUnsupported(_ error: Error) {
        guard let seatLayerError = error as? SeatLayerError else { return }
        if case .bridge(let payload) = seatLayerError,
           payload.code == BridgeErrorCode.unsupportedCommand {
            // Only ours to take back: anything that has landed since is a live
            // failure with chrome of its own.
            if lastError == seatLayerError { lastError = nil }
            return
        }
        record(seatLayerError)
    }
}
