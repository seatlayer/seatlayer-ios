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

/// The widths of one label at one letter size.
struct SeatLayerPickerCartBarWidths: Equatable {
    /// The whole label on one line.
    var whole: Double
    /// Each part a line may not break.
    var parts: [Double]
}

/// Where the row's button stands and how wide it is.
struct SeatLayerPickerCartBarPlan: Equatable {
    /// Whether the button stands under the words.
    var under: Bool
    var buttonWidth: Double
    /// The room its balanced words take.
    var textWidth: Double
    /// An index into `SeatLayerPickerCartBar.letters`.
    var letters: Int
    /// The room for the words beside the circle.
    var wordsWidth: Double
}

/// The parts a line may not break. Scripts written without spaces break
/// between their own letters.
func seatLayerPickerCartBarParts(_ label: String) -> [String] {
    label.split(whereSeparator: { $0.isWhitespace }).flatMap { word -> [String] in
        word.unicodeScalars.contains(where: seatLayerPickerUnspaced)
            ? word.map(String.init)
            : [String(word)]
    }
}

private func seatLayerPickerUnspaced(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x0E00...0x0E7F, 0x3040...0x30FF, 0x3400...0x9FFF, 0xF900...0xFAFF: return true
    default: return false
    }
}

/// How many lines the label takes in `room`, as the text engines break it.
func seatLayerPickerCartBarLines(_ widths: SeatLayerPickerCartBarWidths, room: Double) -> Int {
    let gap: Double = {
        guard widths.parts.count > 1 else { return 0 }
        let sum = widths.parts.reduce(0, +)
        return max(0, (widths.whole - sum) / Double(widths.parts.count - 1))
    }()
    var lines = 1
    var used = 0.0
    for part in widths.parts {
        let next = used == 0 ? part : used + gap + part
        if used > 0, next > room + 0.01 {
            lines += 1
            used = part
        } else {
            used = next
        }
    }
    return lines
}

private func seatLayerPickerCartBarFitsTwoLines(_ widths: SeatLayerPickerCartBarWidths, room: Double) -> Bool {
    (widths.parts.max() ?? 0) <= room && seatLayerPickerCartBarLines(widths, room: room) <= 2
}

/// The narrowest width that keeps the label on as many lines as `room` gives it.
func seatLayerPickerCartBarBalanced(_ widths: SeatLayerPickerCartBarWidths, room: Double) -> Double {
    let lines = seatLayerPickerCartBarLines(widths, room: room)
    if lines < 2 { return min(room, widths.whole) }
    var low = min(room, widths.parts.max() ?? 0)
    var high = room
    while high - low > 0.5 {
        let middle = (low + high) / 2
        if seatLayerPickerCartBarLines(widths, room: middle) <= lines { high = middle } else { low = middle }
    }
    return high
}

/// One row: the circle, the words, the button. The button takes the width of
/// its own words, up to 46% of the row and two balanced lines; only where its
/// words need more does it go under the others, at full width.
///
/// - Parameters:
///   - width: the row's width, its own padding included.
///   - own: every label that stays on the button, so the row stands the same
///     in every state.
///   - label: the label it wears now, at each of the letter sizes.
///   - labelIsOwn: whether the label is one of its own; those never get smaller.
func seatLayerPickerCartBarPlan(
    width: Double,
    own: [SeatLayerPickerCartBarWidths],
    label: [SeatLayerPickerCartBarWidths],
    labelIsOwn: Bool
) -> SeatLayerPickerCartBarPlan {
    typealias Bar = SeatLayerPickerCartBar
    let inner = max(0, width - Bar.padX * 2)
    let besideDisc = max(0, inner - Bar.disc - Bar.gap)
    let most = inner * Bar.buttonMaxShare
    let room = most - Bar.buttonPadX * 2
    let under = own.contains { !seatLayerPickerCartBarFitsTwoLines($0, room: room) }
    var letters = 0
    if !under, !labelIsOwn {
        letters = label.firstIndex { seatLayerPickerCartBarFitsTwoLines($0, room: room) }
            ?? max(0, label.count - 1)
    }
    let worn = label.indices.contains(letters)
        ? label[letters]
        : (label.first ?? SeatLayerPickerCartBarWidths(whole: 0, parts: []))
    if under {
        let textRoom = max(0, inner - Bar.buttonPadX * 2)
        return .init(
            under: true,
            buttonWidth: inner,
            textWidth: (seatLayerPickerCartBarBalanced(worn, room: textRoom)).rounded(.up) + 1,
            letters: letters,
            wordsWidth: besideDisc
        )
    }
    let natural = (worn.whole + Bar.buttonPadX * 2).rounded(.up) + 1
    let buttonWidth = min(most, max(Bar.buttonMinWidth, natural))
    let textRoom = buttonWidth - Bar.buttonPadX * 2
    return .init(
        under: false,
        buttonWidth: buttonWidth,
        textWidth: min(textRoom, seatLayerPickerCartBarBalanced(worn, room: textRoom).rounded(.up) + 1),
        letters: letters,
        wordsWidth: max(0, besideDisc - Bar.gap - buttonWidth)
    )
}
