import Foundation

/// Decides when a hand-off has actually become a sale.
///
/// "You're all set" is never shown on the hand-off: a buyer on the way to pay
/// has not paid, and a pilot host hit exactly that bug when a buyer backed out
/// of checkout without paying. The sale is read the way the web picker reads
/// it — the handed-off hold vanishes from the snapshot **with no `hold.expired`
/// announced first**. The expiry arrives on the same hop as the snapshot that
/// follows it, so the order on the wire is the order this decision sees.
///
/// Pure and macOS-testable: the view and the host callback both read it.
public struct SeatLayerPickerBookedTracker: Sendable, Equatable {
    /// The hand-off being watched, until it settles one way or the other.
    public private(set) var pending: SeatLayerPickerCheckoutHandoff?
    /// The hand-off that settled to booked. Set once, and only once.
    public private(set) var booked: SeatLayerPickerCheckoutHandoff?
    private var expiredSinceHandoff = false
    private var sawHoldAfterHandoff = false

    public init() {}

    /// The picker handed a hold to checkout.
    public mutating func handedOff(_ handoff: SeatLayerPickerCheckoutHandoff) {
        pending = handoff
        expiredSinceHandoff = false
        sawHoldAfterHandoff = false
    }

    /// The runtime announced an expiry. Whatever happens to the hold next, it
    /// was not a sale.
    public mutating func holdExpired() {
        expiredSinceHandoff = true
        pending = nil
    }

    /// One snapshot's hold state.
    ///
    /// Returns true exactly once — on the read where the handed-off hold has
    /// gone and no expiry preceded it.
    @discardableResult
    public mutating func observe(holdActive: Bool) -> Bool {
        guard let handoff = pending, !expiredSinceHandoff else { return false }
        guard sawHoldAfterHandoff else {
            // The hold must be seen alive at least once after the hand-off,
            // so a snapshot read before the hand-off landed cannot be mistaken
            // for the hold vanishing.
            sawHoldAfterHandoff = holdActive
            return false
        }
        guard !holdActive else { return false }
        pending = nil
        booked = handoff
        return true
    }

    /// Clears the reading, for a picker that resumes after checkout.
    public mutating func reset() {
        pending = nil
        booked = nil
        expiredSinceHandoff = false
        sawHoldAfterHandoff = false
    }
}

/// Why the buyer cannot use their access right now.
///
/// Four reasons, four tellings, and — since the round that added this — every
/// one of them has exactly one action. Two used to have none, which left the
/// buyer behind a panel with nothing to press.
public enum SeatLayerPickerAccessPanelReason: String, Sendable, Equatable, CaseIterable {
    /// The organizer has stopped selling for the moment.
    case paused
    /// The link itself is no longer active.
    case revoked
    /// The session's token has gone, or the host's provider failed.
    case expired
    /// Nothing could be verified — the default.
    case unverified

    /// The reason a `buyer.access.unavailable` event describes.
    public init(_ event: BuyerAccessUnavailableEvent) {
        switch event.reason {
        case .paused: self = .paused
        case .revoked: self = .revoked
        case .noToken, .providerFailed: self = .expired
        default: self = .unverified
        }
    }

    /// The reason a `buyer.access.expired` event describes.
    ///
    /// A refresh that already succeeded is not a reason to say anything.
    public init?(_ event: BuyerAccessExpiredEvent) {
        guard !event.refreshed else { return nil }
        switch event.reason {
        case .unauthorized: self = .unverified
        default: self = .expired
        }
    }

    public var title: SeatLayerPickerStringKey {
        switch self {
        case .paused: return .accessPausedTitle
        case .revoked: return .accessRevokedTitle
        case .expired: return .accessExpiredTitle
        case .unverified: return .accessUnverifiedTitle
        }
    }

    public var body: SeatLayerPickerStringKey {
        switch self {
        case .paused: return .accessPausedCopy
        case .revoked: return .accessRevokedCopy
        case .expired: return .accessExpiredCopy
        case .unverified: return .accessUnverifiedCopy
        }
    }

    /// `accessRefresh` is its own word, not `retry`: that one is the paused
    /// screen's "Try again", and one string cannot carry two verbs.
    public var action: SeatLayerPickerStringKey {
        self == .paused ? .retry : .accessRefresh
    }

    /// The paused screen keeps its plain remount: nothing is wrong with the
    /// session there, the organizer has simply stopped selling.
    public var refreshesInPlace: Bool { self != .paused }
}
