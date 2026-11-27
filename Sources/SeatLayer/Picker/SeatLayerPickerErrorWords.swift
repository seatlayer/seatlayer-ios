import Foundation

/// An error the app throws from its checkout with a sentence of its own for
/// the buyer. The picker shows `buyerMessage` as it is, in place of its own
/// sentence. Every other app error is said as "check your connection".
public protocol SeatLayerPickerBuyerFacingError: Error {
    var buyerMessage: String? { get }
}

/// What a refused action says to the buyer, in the web picker's own
/// sentences. The code and the server's message stay with the app's error
/// callback; the buyer never reads either.
struct SeatLayerPickerErrorWords: Equatable, Sendable {
    let message: String
    /// The line under it, where the picker has one.
    let detail: String?

    init(message: String, detail: String? = nil) {
        self.message = message
        self.detail = detail
    }
}

/// The action a refusal answered, as far as its sentence needs it.
struct SeatLayerPickerActionFailure: Equatable, Sendable {
    var command: String?
    /// How many seats Best Available was asked for.
    var quantity: Int?
    /// The cart line a removal named, as the buyer reads it.
    var label: String?
    /// The sentence the app gave its own checkout error.
    var buyerMessage: String?
}

/// The sentence an app error carries for the buyer, when it carries one.
func seatLayerPickerOwnBuyerMessage(_ error: Error) -> String? {
    guard let facing = error as? SeatLayerPickerBuyerFacingError,
          let message = facing.buyerMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
          !message.isEmpty else { return nil }
    return message
}

/// Whether the page's `message` is a web view's words for a request that
/// reached no server.
func seatLayerPickerNoConnection(_ message: String) -> Bool {
    let lowered = message.lowercased()
    return SeatLayerPickerRefusals.noConnection.contains { lowered.contains($0) }
}

/// Whether `command` secures seats (a hold, or the step to checkout).
func seatLayerPickerSecuresSeats(_ command: String?) -> Bool {
    command.map(SeatLayerPickerRefusals.holdCommands.contains) == true
}

private enum SeatLayerPickerRefusals {
    /// Commands that secure seats, where any refusal means they were not secured.
    static let holdCommands: Set<String> = [
        "hold", "picker.continue", "picker.holdGA", "picker.holdSelection",
        "picker.resumeHold", "picker.setTableQuantity",
    ]

    /// Failures of the app, the page or the call itself, where asking again
    /// cannot help.
    static let cannotRetry: Set<String> = [
        "bad_payload", "destroyed", "handoff_not_owned", "holdId_required",
        "idempotency_key_conflict", "idempotency_key_reused", "invalid_channel_scope",
        "invalid_expect_extends", "invalid_idempotency_key", "invalid_referral",
        "labels_and_holdId_required", "picker_requires_protocol_2", "read_only",
        "selections_required", "sl_incompatible", "table_quantity_rejected",
        "unsupported_command", "unsupported_state_contract",
        "sl_missing_resource",
    ]

    /// The same, where asking again may help.
    static let mayRetry: Set<String> = [
        "command_failed", "internal_error", "not_ready", "picker_error", "render_failed",
        "sl_decoding", "sl_handshake_timeout", "sl_transport", "unknown", "unknown_error",
    ]

    /// Refusals that are about the seats, whichever action met them.
    static let takenCodes: Set<String> = [
        "allocation_exhausted", "conflict", "hold_unavailable", "invalid_selection",
        "not_enough_together", "release_closed", "release_exhausted",
    ]

    /// What a web view calls a request that reached no server. Such a failure
    /// has no code of its own: it arrives under the page's fallback code with
    /// only the browser's message.
    static let noConnection = [
        "failed to fetch", "load failed", "network error", "networkerror",
        "network connection was lost", "internet connection appears to be offline",
        "could not connect to the server", "request timed out", "hostname could not be found",
    ]

    /// Codes whose sentence does not depend on what was asked for.
    static let ownSentences: [String: (SeatLayerPickerStringKey, SeatLayerPickerStringKey?)] = [
        "sl_timeout": (.checkConnection, nil),
        "host_timeout": (.checkConnection, nil),
        "rate_limited": (.tooManyAttempts, nil),
        "guests_only": (.guestsOnly, nil),
        "guest_choice_closed": (.guestChoiceClosed, nil),
        "event_closed": (.salesClosedToast, nil),
        "companion_pair_required": (.companionPairRequired, nil),
        "ticket_option_not_applicable": (.ticketOptionNotApplicable, nil),
        "cannot_extend": (.couldNotAddMoreTime, nil),
        "channel_paused": (.accessPausedTitle, .accessPausedCopy),
        "buyer_access_revoked": (.accessRevokedTitle, .accessRevokedCopy),
        "buyer_access_invalid": (.accessExpiredTitle, .accessExpiredCopy),
        "buyer_access_expired": (.accessExpiredTitle, .accessExpiredCopy),
        "access_provider_timeout": (.accessExpiredTitle, .accessExpiredCopy),
        "access_provider_closed": (.accessExpiredTitle, .accessExpiredCopy),
        "provider_failed": (.accessExpiredTitle, .accessExpiredCopy),
        "hold_already_active": (.holdAlreadyHeldTitle, .holdAlreadyHeldBody),
        "hold_owned_by_host": (.holdAlreadyHeldTitle, .holdAlreadyHeldBody),
        "hold_selection_mismatch": (.holdAlreadyHeldTitle, .holdAlreadyHeldBody),
        "no_token": (.accessExpiredTitle, .accessExpiredCopy),
        "access_provider_unavailable": (.accessUnverifiedTitle, .accessUnverifiedCopy),
    ]

    /// Codes with a sentence for every action but a removal and more time.
    static let refusalSentences: [String: SeatLayerPickerStringKey] = [
        "seat_held_for_renewal": .seatHeldForRenewal,
        "channel_access_denied": .accessUnverifiedCopy,
        "hold_not_active": .holdExpired,
        "hold_not_found": .savedSeatsNotRestored,
        "legacy_hold_requires_restart": .savedSeatsNotRestored,
        "order_edit_in_progress": .eventUnavailable,
        "event_not_found": .eventUnavailable,
        "key_not_found": .eventUnavailable,
        "key_revoked": .eventUnavailable,
        "mode_mismatch": .eventUnavailable,
        "org_mismatch": .eventUnavailable,
        "credit_limit_reached": .eventUnavailable,
    ]

    static let standingPlace = "__sl_ga__"
}

/// The buyer's sentence for `error`: the app's own where its checkout error
/// carries one, else the picker's. Never a code, the server's message or an
/// exception's own text.
func seatLayerPickerErrorWords(
    _ error: SeatLayerError,
    failure: SeatLayerPickerActionFailure?,
    strings: SeatLayerPickerStrings
) -> SeatLayerPickerErrorWords {
    if let own = failure?.buyerMessage { return .init(message: own) }
    typealias R = SeatLayerPickerRefusals
    func say(_ key: SeatLayerPickerStringKey, _ detail: SeatLayerPickerStringKey? = nil)
        -> SeatLayerPickerErrorWords {
        .init(message: strings.text(key), detail: detail.map { strings.text($0) })
    }

    let code = error.code
    var command = failure?.command
    if command == nil, case .timeout(let timedOut, _) = error { command = timedOut }
    var meta: JSONValue?
    var pageMessage = ""
    if case .bridge(let payload) = error {
        meta = payload.meta ?? payload.details
        pageMessage = payload.message
    }
    let status = meta?["status"]?.doubleValue
    // The page's fallback codes carry a status when the server did answer,
    // with nothing more to say about it.
    let answered = (!R.cannotRetry.contains(code) && !R.mayRetry.contains(code))
        || (status != nil && (code == "command_failed" || code == "picker_error"))
    // Neither the action's sentence nor one of the code's own is true of it.
    let other = say(R.cannotRetry.contains(code) ? .eventUnavailable : .checkConnection)

    if code == "maintenance_mode" {
        let notice = meta?["notice"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !notice.isEmpty { return .init(message: notice) }
        guard let seconds = meta?["retryAfterS"]?.doubleValue, seconds.isFinite, seconds >= 0 else {
            return say(.maintenancePausedShortly)
        }
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        return .init(message: strings.text(SeatLayerPickerPluralKeys.maintenancePaused, count: minutes))
    }
    if let (key, detail) = R.ownSentences[code] { return say(key, detail) }
    if code.hasPrefix("buyer_access_"), code.hasSuffix("_mismatch") {
        return say(.accessUnverifiedTitle, .accessUnverifiedCopy)
    }
    let unanswered: Bool
    if let status {
        unanswered = status == 503 || (status >= 500 && pageMessage.hasPrefix("request_failed"))
    } else {
        let lowered = pageMessage.lowercased()
        unanswered = R.noConnection.contains { lowered.contains($0) }
    }
    if unanswered { return say(.checkConnection) }
    if pageMessage.contains("seat sales are closed") { return say(.salesClosedToast) }

    // A removal and more time have their own sentence for every refusal; what
    // else was asked for is refused for a reason the code names.
    if command != "picker.removeCartLine", command != "picker.extendHold" {
        if code == "hold_quantity_exceeded" {
            let limit = meta?["max"]?.doubleValue ?? meta?["limit"]?.doubleValue
            if limit == 1 { return say(.maxOneTicketForOrder) }
            if let limit, limit > 1, limit.isFinite {
                return .init(message: strings.text(
                    .maxTicketsForOrder, replacing: ["count": String(Int(limit))]
                ))
            }
        }
        if let key = R.refusalSentences[code] { return say(key) }
        if code == "forbidden" || code == "not_found",
           command == "picker.bestAvailable" || command.map(R.holdCommands.contains) == true {
            return say(.eventUnavailable)
        }
    }

    if command == "picker.bestAvailable" {
        guard answered else { return other }
        if code == "not_enough_together", let quantity = failure?.quantity {
            return .init(message: strings.text(
                .couldNotFindSeatsTogether, replacing: ["count": String(quantity)]
            ))
        }
        return say(code == "sold_out" ? .ticketTypeSoldOut : .seatsNoLongerAvailableTryAnother)
    }
    if command == "picker.removeCartLine" {
        guard let label = failure?.label, answered else { return other }
        let named = label.hasPrefix(R.standingPlace) ? strings.text(.generalAdmission) : label
        return .init(message: strings.text(.couldNotRemoveLabel, replacing: ["label": named]))
    }
    if command == "picker.extendHold", answered { return say(.couldNotAddMoreTime) }

    // A standing place has no name of its own to lose, and its area may well
    // have more: only seats are named.
    let named = (error.conflicts ?? [])
        .compactMap { $0.label }
        .filter { !$0.isEmpty }
        .prefix(3)
        .filter { !$0.hasPrefix(R.standingPlace) }
    if !named.isEmpty {
        return .init(message: strings.text(
            named.count == 1 ? .labelNoLongerAvailable : .labelsNoLongerAvailable,
            replacing: ["labels": named.joined(separator: ", ")]
        ))
    }
    if code == "sold_out" { return say(.ticketTypeSoldOut) }
    if code == "not_for_sale" { return say(.seatUnavailable) }
    if R.takenCodes.contains(code) || (answered && command.map(R.holdCommands.contains) == true) {
        return say(.seatsJustTaken)
    }
    return other
}
