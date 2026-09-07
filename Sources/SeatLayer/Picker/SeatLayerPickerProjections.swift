import Foundation

/// The ONE identity of a cart line, used by every surface that has to say
/// which ticket it means.
///
/// `lineKey` comes from the runtime and is NOT an identity: a chart that keys
/// its lines by ROW hands both seats of row 102-A the same key. A list keyed
/// on it drew one card twice; a removal keyed on it faded the wrong card and
/// blocked the undo of the right one. So the line's own seat id answers first,
/// its inventory label — the address `picker.removeCartLine` itself takes —
/// second, and the runtime's key only when a line names nothing else.
///
/// Order-independent by construction: the identity of a line does not move
/// when a sibling above it leaves.
public func seatLayerPickerCartRowIdentity(
    _ line: SeatLayerPickerCartLine
) -> String {
    let identity = SeatLayerPickerProjections.ticketIdentity(of: line)
    if let seatId = identity.seatId { return "seat:\(seatId)" }
    if let label = identity.removalLabel { return "label:\(label)" }
    if let objectId = identity.objectId { return "object:\(objectId)" }
    return "line:\(identity.lineKey ?? "")"
}

/// A stable, unique row identity for each cart line, in the list's own order.
///
/// The identity above, with the list position appended only for lines that
/// name nothing to tell them apart — two identical rows are indistinguishable
/// inventory, and the position is the only thing left that separates them.
public func seatLayerPickerCartRowIdentities(
    _ lines: [SeatLayerPickerCartLine]
) -> [String] {
    var used: Set<String> = []
    var identities: [String] = []
    identities.reserveCapacity(lines.count)
    for (index, line) in lines.enumerated() {
        var identity = seatLayerPickerCartRowIdentity(line)
        if used.contains(identity) { identity = "\(identity)#\(index)" }
        used.insert(identity)
        identities.append(identity)
    }
    return identities
}

/// Exact inventory identity used by remove, undo, and pending-cart projection.
public struct SeatLayerPickerTicketIdentity: Sendable, Equatable {
    public let lineKey: String?
    public let removalLabel: String?
    public let objectId: String?
    public let seatId: String?

    public init(lineKey: String?, removalLabel: String?, objectId: String?, seatId: String?) {
        self.lineKey = lineKey
        self.removalLabel = removalLabel
        self.objectId = objectId
        self.seatId = seatId
    }
}

public struct SeatLayerPickerCartTotals: Sendable, Equatable {
    public let quantity: Int
    public let total: Double
    public let currency: String?
    public let hasMixedCurrencies: Bool

    public init(quantity: Int, total: Double, currency: String?, hasMixedCurrencies: Bool) {
        self.quantity = quantity
        self.total = total
        self.currency = currency
        self.hasMixedCurrencies = hasMixedCurrencies
    }
}

public struct SeatLayerPickerConfirmedCartProjection: Sendable, Equatable {
    public let items: [SeatLayerPickerCartLine]
    public let totals: SeatLayerPickerCartTotals

    public init(items: [SeatLayerPickerCartLine], totals: SeatLayerPickerCartTotals) {
        self.items = items
        self.totals = totals
    }
}

public enum SeatLayerPickerRemovalPhase: String, Sendable, Equatable, CaseIterable {
    case awaitingRemove
    case undoWindow
    case restoring
}

/// Platform-neutral, pure cart projections used by every native composition.
public enum SeatLayerPickerProjections {
    public static func ticketIdentity(
        of line: SeatLayerPickerCartLine
    ) -> SeatLayerPickerTicketIdentity {
        SeatLayerPickerTicketIdentity(
            lineKey: nonBlank(line.lineKey),
            removalLabel: nonBlank(line.label),
            objectId: nonBlank(line.objectId),
            seatId: line.seatId.flatMap(nonBlank)
        )
    }

    /// Whether two cart lines are the same ticket.
    ///
    /// Ordered exactly as the identity is: a seat id decides when both lines
    /// name one, then the inventory label, and the runtime's row-scoped
    /// `lineKey` only as the last resort. Comparing the key first is what made
    /// dropping one seat of a row look like dropping the row.
    public static func sameTicket(
        _ a: SeatLayerPickerCartLine,
        _ b: SeatLayerPickerCartLine
    ) -> Bool {
        sameTicket(ticketIdentity(of: a), ticketIdentity(of: b))
    }

    public static func sameTicket(
        _ a: SeatLayerPickerTicketIdentity,
        _ b: SeatLayerPickerTicketIdentity
    ) -> Bool {
        if let left = a.seatId, let right = b.seatId { return left == right }
        if let left = a.removalLabel, let right = b.removalLabel { return left == right }
        if let left = a.objectId, let right = b.objectId { return left == right }
        if let left = a.lineKey, let right = b.lineKey { return left == right }
        return false
    }

    /// Whether `line` is still one of `lines`, by ticket identity.
    public static func containsTicket(
        _ lines: [SeatLayerPickerCartLine],
        _ line: SeatLayerPickerCartLine
    ) -> Bool {
        let wanted = ticketIdentity(of: line)
        return lines.contains { sameTicket(ticketIdentity(of: $0), wanted) }
    }

    /// Excludes the unanswered seat independently per line: addressed lines
    /// compare seat id; legacy lines compare the exact inventory label.
    public static func confirmedCart(
        _ items: [SeatLayerPickerCartLine],
        pending: SelectedSeat?
    ) -> SeatLayerPickerConfirmedCartProjection {
        confirmedCart(items, excluding: [pending].compactMap { $0 })
    }

    /// The cart with every unanswered seat taken out of it.
    ///
    /// A seat a card is still asking about is in the runtime's selection from
    /// the moment it is tapped, but the buyer has not agreed to it: counting it
    /// would show a ticket and a price for a question that has not been
    /// answered.
    public static func confirmedCart(
        _ items: [SeatLayerPickerCartLine],
        excluding unanswered: [SelectedSeat]
    ) -> SeatLayerPickerConfirmedCartProjection {
        guard !unanswered.isEmpty else {
            return .init(items: items, totals: totals(items))
        }
        let ids = Set(unanswered.compactMap { nonBlank($0.id) })
        let labels = Set(unanswered.compactMap { nonBlank($0.label) })
        let kept = items.filter { line in
            let identity = ticketIdentity(of: line)
            guard let seatId = identity.seatId else {
                return identity.removalLabel.map { !labels.contains($0) } ?? true
            }
            return !ids.contains(seatId)
        }
        return .init(items: kept, totals: totals(kept))
    }

    /// A mixed-currency cart deliberately has no displayable aggregate currency.
    public static func totals(_ items: [SeatLayerPickerCartLine]) -> SeatLayerPickerCartTotals {
        let currencies = Set(items.compactMap { nonBlank($0.currency) })
        return .init(
            quantity: items.reduce(0) { $0 + validQuantity($1.quantity) },
            total: items.reduce(0) { $0 + $1.unitPrice * Double(validQuantity($1.quantity)) },
            currency: currencies.count == 1 ? currencies.first : nil,
            hasMixedCurrencies: currencies.count > 1
        )
    }

    public static func seatRunLabel(_ labels: [String]) -> String {
        guard !labels.isEmpty else { return "" }
        guard labels.count > 1 else { return labels[0] }
        let numbered = labels.map(seatNumber)
        if numbered.allSatisfy({ $0 != nil }) {
            let sorted = numbered.compactMap { $0 }.sorted()
            let consecutive = sorted.enumerated().allSatisfy {
                $0.offset == 0 || $0.element == sorted[$0.offset - 1] + 1
            }
            if consecutive { return "\(sorted[0])–\(sorted[sorted.count - 1])" }
            return compact(sorted.map(String.init))
        }
        return compact(labels)
    }

    /// Undo is available only after a successful exact-label removal, in the
    /// same session, while that inventory identity remains absent.
    public static func canUndoRemoval(
        line: SeatLayerPickerCartLine,
        phase: SeatLayerPickerRemovalPhase,
        sameSession: Bool,
        stillAbsent: Bool
    ) -> Bool {
        ticketIdentity(of: line).removalLabel != nil
            && phase == .undoWindow
            && sameSession
            && stillAbsent
    }

    public static func seatIdentity(_ seat: SelectedSeat) -> String? {
        let fields = [nonBlank(seat.id), nonBlank(seat.label), nonBlank(seat.objectId ?? "")]
        guard fields.contains(where: { $0 != nil }) else { return nil }
        return fields.map { value in
            let escaped = value?.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return escaped.map { "\"\($0)\"" } ?? "null"
        }.joined(separator: ",").withJSONArrayBrackets
    }

    private static func uniqueSelection(
        for identity: SeatLayerPickerTicketIdentity,
        in selection: [SelectedSeat]
    ) -> SelectedSeat? {
        let predicates: [(SelectedSeat) -> Bool] = [
            { identity.seatId != nil && nonBlank($0.id) == identity.seatId },
            { identity.removalLabel != nil && nonBlank($0.label) == identity.removalLabel },
            { identity.objectId != nil && nonBlank($0.objectId ?? "") == identity.objectId },
            { identity.objectId != nil && nonBlank($0.id) == identity.objectId },
        ]
        for predicate in predicates {
            let matches = selection.filter(predicate)
            if matches.count == 1 { return matches[0] }
        }
        return nil
    }

    private static func compact(_ labels: [String]) -> String {
        let shown = labels.prefix(3).joined(separator: ", ")
        return labels.count > 3 ? "\(shown) +\(labels.count - 3)" : shown
    }

    private static func seatNumber(_ label: String) -> Int? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...4).contains(trimmed.count), trimmed.allSatisfy(\.isNumber) else { return nil }
        return Int(trimmed)
    }

    private static func validQuantity(_ quantity: Int) -> Int {
        quantity > 0 ? quantity : 1
    }

    private static func nonBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func firstKnown(_ values: String?...) -> String? {
        values.compactMap { $0.flatMap(nonBlank) }.first
    }
}

private extension String {
    var withJSONArrayBrackets: String { "[\(self)]" }
}
