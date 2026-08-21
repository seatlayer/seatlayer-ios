#if canImport(UIKit)
import Foundation

/// Seat map callbacks. Every method has a no-op default, so adopters implement
/// only what they use and a future event never breaks an existing conformance.
@MainActor
public protocol SeatLayerViewDelegate: AnyObject {
    /// The handshake completed and the chart rendered.
    ///
    /// Check `info.mode` — a `.test` event books no real inventory and must be
    /// badged as such.
    func seatLayerViewDidBecomeReady(_ view: SeatLayerView, info: ReadyInfo)

    /// The buyer's selection changed. Carries the FULL current selection.
    func seatLayerView(_ view: SeatLayerView, selectionDidChange seats: [SelectedSeat])

    /// Exact-count and validator state changed.
    func seatLayerView(_ view: SeatLayerView, selectionValidityDidChange validity: SelectionValidity)

    /// The current selection now satisfies every configured rule.
    func seatLayerView(_ view: SeatLayerView, selectionDidBecomeValid seats: [SelectedSeat])

    /// The current selection no longer satisfies every configured rule.
    func seatLayerView(_ view: SeatLayerView, selectionDidBecomeInvalid validity: SelectionValidity)

    /// The buyer tried to exceed the active selection cap.
    func seatLayerView(_ view: SeatLayerView, didReachSelectionLimit maximum: Int)

    /// The current buyer-access session expired, with refresh outcome.
    func seatLayerView(_ view: SeatLayerView, buyerAccessDidExpire event: BuyerAccessExpiredEvent)

    /// Private inventory cannot currently be shown.
    func seatLayerView(_ view: SeatLayerView, buyerAccessBecameUnavailable event: BuyerAccessUnavailableEvent)

    /// Selected inventory became ineligible or unavailable before hold.
    func seatLayerView(_ view: SeatLayerView, selectedObjectsBecameUnavailable event: SelectedObjectUnavailableEvent)

    /// A hold was created or updated.
    func seatLayerView(_ view: SeatLayerView, holdDidChange hold: HoldResult)

    /// A previously open hold was restored (app relaunch, reconnect).
    func seatLayerView(_ view: SeatLayerView, holdWasRestored hold: HoldResult)

    /// The open hold expired server-side. The seats are gone; return the buyer
    /// to selection.
    func seatLayerViewHoldDidExpire(_ view: SeatLayerView)

    /// Something failed. `error.requiresAppUpdate` distinguishes the one case a
    /// retry cannot fix.
    func seatLayerView(_ view: SeatLayerView, didFailWith error: SeatLayerError)

    /// A transient buyer-facing hint, or `nil` to clear it.
    func seatLayerView(_ view: SeatLayerView, didReceiveHint message: String?)

    /// The buyer tapped a general-admission area — prompt for a quantity, then
    /// call `holdGA`.
    func seatLayerView(_ view: SeatLayerView, didTapGAArea area: GAArea)

    /// The buyer hovered/long-pressed a seat, or `nil` on hover-out. Only fires
    /// when the app draws its own seat popover.
    func seatLayerView(_ view: SeatLayerView, seatHoverDidChange details: SeatHoverDetails?)

    /// The buyer tapped a floor in a multi-floor deck.
    func seatLayerView(_ view: SeatLayerView, didTapFloor floorId: String)

    /// An event this build does not model — a bundle newer than the app.
    /// Delivered raw so it can be logged rather than silently lost.
    func seatLayerView(_ view: SeatLayerView, didReceiveUnknownEvent name: String, payload: JSONValue?)
}

public extension SeatLayerViewDelegate {
    func seatLayerViewDidBecomeReady(_ view: SeatLayerView, info: ReadyInfo) {}
    func seatLayerView(_ view: SeatLayerView, selectionDidChange seats: [SelectedSeat]) {}
    func seatLayerView(_ view: SeatLayerView, selectionValidityDidChange validity: SelectionValidity) {}
    func seatLayerView(_ view: SeatLayerView, selectionDidBecomeValid seats: [SelectedSeat]) {}
    func seatLayerView(_ view: SeatLayerView, selectionDidBecomeInvalid validity: SelectionValidity) {}
    func seatLayerView(_ view: SeatLayerView, didReachSelectionLimit maximum: Int) {}
    func seatLayerView(_ view: SeatLayerView, buyerAccessDidExpire event: BuyerAccessExpiredEvent) {}
    func seatLayerView(_ view: SeatLayerView, buyerAccessBecameUnavailable event: BuyerAccessUnavailableEvent) {}
    func seatLayerView(_ view: SeatLayerView, selectedObjectsBecameUnavailable event: SelectedObjectUnavailableEvent) {}
    func seatLayerView(_ view: SeatLayerView, holdDidChange hold: HoldResult) {}
    func seatLayerView(_ view: SeatLayerView, holdWasRestored hold: HoldResult) {}
    func seatLayerViewHoldDidExpire(_ view: SeatLayerView) {}
    func seatLayerView(_ view: SeatLayerView, didFailWith error: SeatLayerError) {}
    func seatLayerView(_ view: SeatLayerView, didReceiveHint message: String?) {}
    func seatLayerView(_ view: SeatLayerView, didTapGAArea area: GAArea) {}
    func seatLayerView(_ view: SeatLayerView, seatHoverDidChange details: SeatHoverDetails?) {}
    func seatLayerView(_ view: SeatLayerView, didTapFloor floorId: String) {}
    func seatLayerView(_ view: SeatLayerView, didReceiveUnknownEvent name: String, payload: JSONValue?) {}
}

#endif
