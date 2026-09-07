import Foundation

/// A stable, unique row identity for each cart line, in the list's own order.
///
/// `lineKey` comes from the runtime and is NOT guaranteed unique: a chart that
/// keys its lines by ROW hands two seats in the same row the same key, and a
/// `ForEach` identified by a key it shares with its neighbour draws the first
/// card twice — two tickets, one seat shown, the other invisible. So the key is
/// the starting point and the line's own label, then its position, break the
/// ties. Pure, so the rule is tested rather than watched for.
public func seatLayerPickerCartRowIdentities(
    _ lines: [SeatLayerPickerCartLine]
) -> [String] {
    var used: Set<String> = []
    var identities: [String] = []
    identities.reserveCapacity(lines.count)
    for (index, line) in lines.enumerated() {
        var identity = line.lineKey
        if used.contains(identity) { identity = "\(line.lineKey)#\(line.label)" }
        if used.contains(identity) { identity = "\(line.lineKey)#\(line.label)#\(index)" }
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
