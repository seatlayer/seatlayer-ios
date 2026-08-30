import Foundation

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

public struct SeatLayerPickerDenseDisplay: Sendable, Equatable {
    public let section: String?
    public let rowLabel: String?
    public let seatLabel: String?
    public let categoryLabel: String?
    public let amountText: String?

    public init(
        section: String? = nil,
        rowLabel: String? = nil,
        seatLabel: String? = nil,
        categoryLabel: String? = nil,
        amountText: String? = nil
    ) {
        self.section = section
        self.rowLabel = rowLabel
        self.seatLabel = seatLabel
        self.categoryLabel = categoryLabel
        self.amountText = amountText
    }
}

public struct SeatLayerPickerDenseLine: Sendable, Equatable {
    public let item: SeatLayerPickerCartLine
    public let identity: SeatLayerPickerTicketIdentity
    public let section: String
    public let rowLabel: String
    public let seatLabel: String
    public let categoryLabel: String
    public let amountText: String
    public let quantity: Int
    public let total: Double
    public let held: Bool
    public let groupable: Bool
}

public struct SeatLayerPickerDenseRun: Sendable, Equatable {
    public let members: [SeatLayerPickerDenseLine]
    public let seatsLabel: String
    public let total: Double
    public let quantity: Int

    public var isGroup: Bool { members.count > 1 }
    public var id: String {
        members.first?.identity.lineKey
            ?? members.first?.identity.removalLabel
            ?? members.first?.identity.objectId
            ?? members.first?.identity.seatId
            ?? "empty-run"
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
        guard let pending else {
            return .init(items: items, totals: totals(items))
        }
        let pendingId = nonBlank(pending.id)
        let pendingLabel = nonBlank(pending.label)
        let kept = items.filter { line in
            let identity = ticketIdentity(of: line)
            return identity.seatId == nil
                ? identity.removalLabel != pendingLabel
                : identity.seatId != pendingId
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

    public static func denseLine(
        _ item: SeatLayerPickerCartLine,
        selection: [SelectedSeat] = [],
        display: SeatLayerPickerDenseDisplay = .init(),
        held: Bool = false
    ) -> SeatLayerPickerDenseLine {
        let identity = ticketIdentity(of: item)
        let selected = uniqueSelection(for: identity, in: selection)
        let section = firstKnown(display.section, item.sectionLabel, selected?.sectionLabel,
                                 display.categoryLabel, item.categoryKey,
                                 item.displayLabel, identity.removalLabel) ?? ""
        let row = firstKnown(display.rowLabel, item.rowLabel, selected?.rowLabel) ?? ""
        let seat = firstKnown(display.seatLabel, item.seatNumber, selected?.seatNumber,
                              item.displayLabel, identity.removalLabel, identity.objectId) ?? ""
        let category = firstKnown(display.categoryLabel, item.categoryKey) ?? ""
        let quantity = validQuantity(item.quantity)
        let amount = firstKnown(display.amountText, "\(item.currency) · \(item.unitPrice * Double(quantity))") ?? ""
        return SeatLayerPickerDenseLine(
            item: item,
            identity: identity,
            section: section,
            rowLabel: row,
            seatLabel: seat,
            categoryLabel: category,
            amountText: amount,
            quantity: quantity,
            total: item.unitPrice * Double(quantity),
            held: held,
            groupable: item.objectType != "ga"
                && quantity <= 1
                && (selected?.tiers?.count ?? 0) <= 1
                && identity.removalLabel != nil
        )
    }

    /// Folds only adjacent lines whose complete buyer-facing run key matches.
    public static func denseRuns(_ lines: [SeatLayerPickerDenseLine]) -> [SeatLayerPickerDenseRun] {
        var groups: [[SeatLayerPickerDenseLine]] = []
        for line in lines {
            if let last = groups.indices.last,
               let first = groups[last].first,
               canJoin(first, line) {
                groups[last].append(line)
            } else {
                groups.append([line])
            }
        }
        return groups.map { members in
            SeatLayerPickerDenseRun(
                members: members,
                seatsLabel: seatRunLabel(members.map(\.seatLabel)),
                total: members.reduce(0) { $0 + $1.total },
                quantity: members.reduce(0) { $0 + $1.quantity }
            )
        }
    }

    public static func membersInSeatOrder(
        _ run: SeatLayerPickerDenseRun
    ) -> [SeatLayerPickerDenseLine] {
        let numbered = run.members.map { seatNumber($0.seatLabel) }
        guard numbered.allSatisfy({ $0 != nil }) else { return run.members }
        return run.members.enumerated().sorted {
            let left = numbered[$0.offset] ?? 0
            let right = numbered[$1.offset] ?? 0
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
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

    private static func canJoin(
        _ left: SeatLayerPickerDenseLine,
        _ right: SeatLayerPickerDenseLine
    ) -> Bool {
        left.groupable && right.groupable
            && left.held == right.held
            && left.section == right.section
            && left.rowLabel == right.rowLabel
            && left.categoryLabel == right.categoryLabel
            && left.amountText == right.amountText
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
