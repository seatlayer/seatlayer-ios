import Foundation

/// The phone's cart row: its measures, the seats line under the count and the
/// rule for where the count, the total and the button stand.
enum SeatLayerPickerCartBar {
    /// Points at text size 1.
    static let padX = 12.0
    static let padY = 10.0
    static let gap = 10.0
    /// Between the words and a button that stands under them.
    static let underGap = 8.0
    static let minHeight = 44.0
    static let disc = 28.0
    static let chevron = 16.0
    static let buttonPadX = 14.0
    static let buttonPadY = 6.0
    static let buttonMinWidth = 112.0
    static let buttonRadius = 7.7
    /// The part of the row a button beside the words may take.
    static let buttonMaxShare = 0.46
    static let buttonFont = 14.0
    static let countFont = 13.5
    static let totalFont = 14.5
    static let totalGap = 7.0
    static let namesFont = 12.5
    /// The row while a seat card is asking.
    static let askingOpacity = 0.58
    /// The cards, or the best-seats form, over the row.
    static let listMaxHeight = 240.0
    static let listPadBottom = 10.0
    /// The button's letters, the largest that fits first.
    static let letters = [buttonFont, 12.5, 11.5]
}

/// The seats under the count, as the hosted map writes them: the section once
/// when every ticket shares it, then each seat as row-seat ("Dress Circle ·
/// C-6, C-7"). A table booked as one, a booth or a standing area is its own
/// name, and the same place stands once.
func seatLayerPickerCartSeatsLine(_ lines: [SeatLayerPickerCartLine]) -> String {
    func trimmed(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let sections = Set(lines.map { trimmed($0.sectionLabel) })
    let one = sections.count == 1 ? trimmed(lines.first?.sectionLabel) : ""
    var seen = Set<String>()
    let places: [String] = lines.compactMap { line in
        let section = trimmed(line.sectionLabel)
        let row = trimmed(seatLayerPickerRowLabel(line.rowLabel, section: line.sectionLabel))
        let seat = [row, trimmed(line.seatNumber)].filter { !$0.isEmpty }.joined(separator: "-")
        let place = !seat.isEmpty ? seat : (!trimmed(line.displayLabel).isEmpty
            ? trimmed(line.displayLabel) : trimmed(line.label))
        let named = ((one.isEmpty && !section.isEmpty) ? "\(section) " : "") + place
        let text = named.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, seen.insert(text).inserted else { return nil }
        return text
    }
    let head = !one.isEmpty && !places.isEmpty ? "\(one) · " : ""
    return head + places.joined(separator: ", ")
}

/// Whether the count and the total stand on one line, and the total's own
/// scale. The total is never cut: a longer one is drawn smaller.
func seatLayerPickerCartBarTotal(
    count: Double,
    total: Double,
    room: Double
) -> (beside: Bool, scale: Double) {
    if count + SeatLayerPickerCartBar.totalGap + total <= room { return (true, 1) }
    return (false, total > room && total > 0 ? max(0.5, room / total) : 1)
}
