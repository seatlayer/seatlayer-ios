#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Where a seat lands when a cart card is tapped: the middle of the map, so
/// the buyer can see it without the sheet having to move out of the way.
public let seatLayerSheetRestoreFraction = 0.5

extension Font.Weight {
    /// The nearest platform weight to a token's 100–950 numeric weight.
    static func seatLayerPickerWeight(_ value: Double) -> Font.Weight {
        switch value {
        case ..<250: return .ultraLight
        case ..<350: return .light
        case ..<450: return .regular
        case ..<550: return .medium
        case ..<650: return .semibold
        case ..<750: return .bold
        case ..<850: return .heavy
        default: return .black
        }
    }
}

extension View {
    /// Draws text at one role from the generated type ramp.
    func seatLayerPickerFont(_ token: SeatLayerPickerTypeToken) -> some View {
        seatLayerPickerFont(
            size: token.size,
            weight: .seatLayerPickerWeight(token.weight)
        )
    }
}

// tokens.json gap: the card's own blends are Dart-local in
// `picker_cart_list.dart` — held ground 7 % accent, held border 45 % accent,
// category hairline 22 % of the category ink, mark ↔ text gap 10, text ↔
// amount gap 8, lock disc 17 pt with a 10 pt glyph.
enum SeatLayerPickerCartCardMetrics {
    static let heldGroundBlend: Double = 0.07
    static let heldBorderBlend: Double = 0.45
    static let markHairline: Double = 0.22
    static let markSize: Double = 9
    static let lockDisc: Double = 17
    static let lockGlyph: Double = 10
    static let markGap: Double = 10
    static let amountGap: Double = 8
    static let padLeading: Double = 12
    static let padOther: Double = 4
}

/// One ticket, on its own card.
///
/// The same card on every width: a run model that folded four seats in a row
/// into one line and a `+N more` was the phone's own list, and a buyer who
/// cannot see the fourth ticket cannot check it.
public struct SeatLayerPickerCartCard: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let line: SeatLayerPickerCartLine
    private let held: Bool
    private let removing: Bool
    private let onRemove: () -> Void

    public init(
        line: SeatLayerPickerCartLine,
        held: Bool,
        removing: Bool,
        onRemove: @escaping () -> Void
    ) {
        self.line = line
        self.held = held
        self.removing = removing
        self.onRemove = onRemove
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        HStack(alignment: .top, spacing: 0) {
            mark(palette: palette)
                .padding(.trailing, SeatLayerPickerCartCardMetrics.markGap)
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .seatLayerPickerFont(SeatLayerPickerTypeTokens.cartCardName)
                    .foregroundColor(palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !position.isEmpty {
                    Text(position)
                        .seatLayerPickerFont(SeatLayerPickerTypeTokens.cartCardPosition)
                        .foregroundColor(palette.mutedText)
                        .monospacedDigit()
                }
                notes(palette: palette)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, SeatLayerPickerCartCardMetrics.amountGap)
            Text(amount)
                .seatLayerPickerFont(SeatLayerPickerTypeTokens.cartCardAmount)
                .foregroundColor(palette.text)
                .monospacedDigit()
                .layoutPriority(1)
            eyeButton(palette: palette)
            removeButton(palette: palette)
        }
        .padding(.leading, SeatLayerPickerCartCardMetrics.padLeading)
        .padding(.trailing, SeatLayerPickerCartCardMetrics.padOther)
        .padding(.vertical, SeatLayerPickerCartCardMetrics.padOther)
        .frame(
            minHeight: SeatLayerPickerSizeTokens.cartCardMinHeight,
            alignment: .center
        )
        .background(ground(palette: palette))
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerSizeTokens.cartCardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: SeatLayerPickerSizeTokens.cartCardRadius)
                .stroke(border(palette: palette), lineWidth: 1)
        }
        .opacity(removing ? SeatLayerPickerOpacityTokens.removing : 1)
        .contentShape(Rectangle())
        .onTapGesture { frameThisSeat() }
        .animation(
            seatLayerPickerAnimation(.crossfade, reduceMotion: reduceMotion),
            value: removing
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(spokenIdentity)
        .accessibilityIdentifier("seatlayer-cart-card")
    }

    // MARK: - Words

    /// The card's name is the venue section — the one fact here that can be
    /// longer than the panel, and the only part that ellipsizes.
    private var name: String {
        let section = line.sectionLabel ?? ""
        if !section.isEmpty { return section }
        if let type = ticketTypeLabel, !type.isEmpty { return type }
        return line.displayLabel ?? line.label
    }

    /// Where the seat is, and what kind it is. The type is dropped when it is
    /// already the name of the card: on a chart with no sections the two are
    /// the same string, and "Standard · Standard" is a stutter.
    private var position: String {
        var parts: [String] = []
        if let row = line.rowLabel, !row.isEmpty { parts.append(row) }
        if let seat = line.seatNumber, !seat.isEmpty { parts.append(seat) }
        if let type = ticketTypeLabel,
           !type.isEmpty,
           type.lowercased() != name.lowercased() {
            parts.append(type)
        }
        return parts.joined(separator: " · ")
    }

    private var amount: String {
        seatLayerPickerMoney(line.total, currency: line.currency, style: style)
    }

    private var ticketTypeLabel: String? {
        line.tierName ?? controller.snapshot?.categories
            .first { $0.key == line.categoryKey }?.label
    }

    private var spokenIdentity: String {
        [name, position, amount]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// The seat this line stands for, where the runtime still reports it.
    private var seat: SelectedSeat? {
        let selection = controller.snapshot?.selection ?? []
        if let seatId = line.seatId, let match = selection.first(where: { $0.id == seatId }) {
            return match
        }
        return selection.first { $0.label == line.label }
    }

    /// The words a seat's own attributes earn, said once, on the card.
    @ViewBuilder
    private func notes(palette: SeatLayerPickerPalette) -> some View {
        let rows = seat.map { seatLayerSeatNotes(for: $0, strings: style.strings) } ?? []
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: SeatLayerPickerSizeTokens.cartNoteGap) {
                Rectangle()
                    .fill(palette.divider.opacity(SeatLayerPickerOpacityTokens.noteHairline))
                    .frame(height: 1)
                    .padding(.bottom, SeatLayerPickerSizeTokens.cartNoteGap)
                ForEach(rows, id: \.key) { row in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.title)
                            .seatLayerPickerFont(SeatLayerPickerTypeTokens.cartNoteTitle)
                            .foregroundColor(noteInk(row.tone, palette: palette))
                        if let note = row.note {
                            Text(note)
                                .seatLayerPickerFont(SeatLayerPickerTypeTokens.cartNoteText)
                                .foregroundColor(palette.mutedText)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        row.note.map { "\(row.title): \($0)" } ?? row.title
                    )
                }
            }
            .padding(.top, SeatLayerPickerSizeTokens.cartNotePadTop)
        }
    }

    private func noteInk(
        _ tone: SeatLayerSeatNoteTone,
        palette: SeatLayerPickerPalette
    ) -> Color {
        switch tone {
        case .warn: return palette.warnText
        case .premium: return palette.premiumText
        case .access, .note: return palette.text
        }
    }

    // MARK: - Marks and grounds

    /// A lock is not a colour: a held ticket wears the lock, and the wash is
    /// only there so the lock has somewhere to sit.
    @ViewBuilder
    private func mark(palette: SeatLayerPickerPalette) -> some View {
        if held {
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(SeatLayerPickerCartCardMetrics.heldBorderBlend))
                    .frame(
                        width: SeatLayerPickerCartCardMetrics.lockDisc,
                        height: SeatLayerPickerCartCardMetrics.lockDisc
                    )
                Image(systemName: "lock.fill")
                    .seatLayerPickerFont(
                        size: SeatLayerPickerCartCardMetrics.lockGlyph,
                        weight: .bold
                    )
                    .foregroundColor(palette.onAccent)
            }
            .accessibilityHidden(true)
        } else {
            Circle()
                .fill(categoryInk(fallback: palette.accent))
                .frame(
                    width: SeatLayerPickerCartCardMetrics.markSize,
                    height: SeatLayerPickerCartCardMetrics.markSize
                )
                .overlay {
                    Circle().stroke(
                        categoryInk(fallback: palette.accent)
                            .opacity(SeatLayerPickerCartCardMetrics.markHairline),
                        lineWidth: 1
                    )
                }
                .padding(.top, 4)
                .accessibilityHidden(true)
        }
    }

    private func ground(palette: SeatLayerPickerPalette) -> Color {
        held
            ? palette.surface.seatLayerPickerBlended(
                with: palette.accent,
                amount: SeatLayerPickerCartCardMetrics.heldGroundBlend
            )
            : palette.surface
    }

    private func border(palette: SeatLayerPickerPalette) -> Color {
        held
            ? palette.divider.seatLayerPickerBlended(
                with: palette.accent,
                amount: SeatLayerPickerCartCardMetrics.heldBorderBlend
            )
            : palette.divider
    }

    private func categoryInk(fallback: Color) -> Color {
        guard let raw = controller.snapshot?.categories
            .first(where: { $0.key == line.categoryKey })?.color,
            let color = UIColor(slHex: raw) else { return fallback }
        return Color(uiColor: color)
    }

    // MARK: - Controls

    /// The eye is withheld unless the host allows it, the runtime advertises
    /// it, and this seat actually has a photograph behind it.
    @ViewBuilder
    private func eyeButton(palette: SeatLayerPickerPalette) -> some View {
        if let seat, canOpenSeatView(seat) {
            Button {
                runPickerAction(controller) {
                    _ = try await controller.openSeatView(seat.id)
                    presentation.recordSeatViewOpened(seat)
                }
            } label: {
                Image(systemName: "eye")
                    .seatLayerPickerFont(size: 13, weight: .semibold)
                    .frame(
                        width: SeatLayerPickerSizeTokens.minimumHitTarget,
                        height: SeatLayerPickerSizeTokens.minimumHitTarget
                    )
            }
            .buttonStyle(.plain)
            .foregroundColor(palette.mutedText)
            .accessibilityLabel(style.strings.text(.viewFromHere))
            .accessibilityIdentifier("seatlayer-cart-card-view")
        }
    }

    private func canOpenSeatView(_ seat: SelectedSeat) -> Bool {
        style.options.enableSeatView
            && controller.supportsSeatView
            && controller.snapshot?.capabilities.contains("seatView") == true
            && seat.seatViewThumb != nil
    }

    /// A line keeps its × while the host owns the hold: the ticket is still
    /// the buyer's to drop, and the refusal belongs to the command, not to a
    /// control that quietly disappears.
    private func removeButton(palette: SeatLayerPickerPalette) -> some View {
        Button(action: onRemove) {
            Image(systemName: "xmark")
                .seatLayerPickerFont(size: 12, weight: .bold)
                .frame(
                    width: SeatLayerPickerSizeTokens.minimumHitTarget,
                    height: SeatLayerPickerSizeTokens.minimumHitTarget
                )
        }
        .buttonStyle(.plain)
        .foregroundColor(palette.mutedText)
        .disabled(removing)
        .accessibilityLabel(
            [style.strings.text(.removeSeat), name, line.seatNumber ?? ""]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        )
        .accessibilityIdentifier("seatlayer-cart-card-remove")
    }

    /// Tapping the card takes the buyer to the seat on the map. The sheet
    /// stays exactly where they put it.
    private func frameThisSeat() {
        guard let seatId = line.seatId ?? seat?.id else { return }
        Task { @MainActor in
            await controller.frameSeat(seatId, fraction: seatLayerSheetRestoreFraction)
        }
    }
}

extension Color {
    /// This colour with `amount` of `other` mixed into it.
    func seatLayerPickerBlended(with other: Color, amount: Double) -> Color {
        let fraction = min(1, max(0, amount))
        let base = UIColor(self)
        let mix = UIColor(other)
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        guard base.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              mix.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else { return self }
        let t = CGFloat(fraction)
        return Color(uiColor: UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        ))
    }
}
#endif
