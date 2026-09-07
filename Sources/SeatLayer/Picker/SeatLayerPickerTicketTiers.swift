#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Which ticket the seat is being bought as.
///
/// A labelled set of rows rather than a dropdown: on a card this small the
/// prices are the point of the choice, and a closed menu hides them.
///
/// The chosen row is marked three ways at once — an accent edge, an accent
/// wash, and a rail on its leading side — because on a phone the difference
/// between two rows a few points apart has to survive a glance. There is no
/// radio disc: the marking IS the state, a screen reader hears the row as
/// selected, and a disc beside every price is a column of furniture on a card
/// that has room for none.
public struct SeatLayerPickerTicketTierChoices: View {
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let tiers: [CategoryTier]
    private let fallbackCurrency: String
    private let enabled: Bool
    /// Whether this is the phone card's tighter form.
    private let compact: Bool
    @Binding private var selection: String?

    public init(
        tiers: [CategoryTier],
        fallbackCurrency: String,
        selection: Binding<String?>,
        enabled: Bool = true,
        compact: Bool = false
    ) {
        self.tiers = tiers
        self.fallbackCurrency = fallbackCurrency
        self.enabled = enabled
        self.compact = compact
        _selection = selection
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: nil
        )
        VStack(spacing: 6) {
            ForEach(tiers, id: \.id) { tier in
                let selected = selection == tier.id
                let guidance = SeatLayerPickerTiering.guidance(
                    for: tier,
                    companionFallback: style.strings.text(.tierCompanionGuidance)
                )
                let quote = SeatLayerPickerTiering.quote(
                    for: tier,
                    fallbackCurrency: fallbackCurrency
                )
                Button {
                    selection = tier.id
                } label: {
                    tierLabel(
                        tier,
                        selected: selected,
                        guidance: guidance,
                        quote: quote,
                        palette: palette
                    )
                    .padding(.horizontal, compact ? 9 : 10)
                    .padding(.vertical, compact ? 7 : 8)
                    .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
                    .background(rowGround(selected: selected, palette: palette))
                    .overlay(alignment: .leading) {
                        if selected {
                            Rectangle().fill(palette.accent).frame(width: 3)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button)
                            .stroke(selected ? palette.accent : palette.divider, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: tier, guidance: guidance))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("seatlayer-tier-\(tier.id)")
            }
        }
        .onAppear(perform: normalizeSelection)
        .onChange(of: tierSignature) { _ in normalizeSelection() }
    }

    /// A shade off the surface, so the rows read as choices sitting on the card
    /// rather than as lines ruled across it.
    private func rowGround(
        selected: Bool,
        palette: SeatLayerPickerPalette
    ) -> Color {
        selected
            ? seatLayerPickerBlend(palette.accent, 0.13, over: palette.surface)
            : seatLayerPickerBlend(palette.background, 0.72, over: palette.surface)
    }

    private var rowHeight: Double {
        if dynamicTypeSize.isAccessibilitySize {
            return SeatLayerPickerSizeTokens.minimumHitTarget
        }
        return compact
            ? SeatLayerPickerSizeTokens.confirmTierHeight
            : SeatLayerPickerSizeTokens.confirmActionHeight
    }

    @ViewBuilder
    private func tierLabel(
        _ tier: CategoryTier,
        selected: Bool,
        guidance: String?,
        quote: SeatLayerPickerTierQuote?,
        palette: SeatLayerPickerPalette
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                Text(tier.name)
                    .seatLayerPickerFont(size: 12.5, weight: .heavy)
                    .foregroundColor(palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let guidance {
                    Text(guidance)
                        .seatLayerPickerFont(size: 10.5)
                        .foregroundColor(selected ? palette.text : palette.mutedText)
                        .multilineTextAlignment(.leading)
                }
                if let quote {
                    tierPrice(quote, palette: palette)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        } else {
            HStack(spacing: 9) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.name)
                        .seatLayerPickerFont(size: 12.5, weight: .heavy)
                        .foregroundColor(palette.text)
                    if let guidance {
                        Text(guidance)
                            .seatLayerPickerFont(size: 10.5)
                            .lineSpacing(3)
                            // The note is the reason the row exists once it is
                            // chosen, so it takes the full ink.
                            .foregroundColor(selected ? palette.text : palette.mutedText)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 9)
                if let quote { tierPrice(quote, palette: palette) }
            }
        }
    }

    private func tierPrice(
        _ quote: SeatLayerPickerTierQuote,
        palette: SeatLayerPickerPalette
    ) -> some View {
        Text(seatLayerPickerMoney(
            quote.amount,
            currency: quote.currency ?? fallbackCurrency,
            style: style
        ))
        .seatLayerPickerFont(size: 13, weight: .heavy)
        .monospacedDigit()
        .foregroundColor(palette.text)
    }

    private var tierSignature: String { tiers.map(\.id).joined(separator: "\u{1f}") }

    private func normalizeSelection() {
        guard !tiers.isEmpty,
              !tiers.contains(where: { $0.id == selection }) else { return }
        selection = tiers[0].id
    }

    private func accessibilityLabel(for tier: CategoryTier, guidance: String?) -> String {
        let quote = SeatLayerPickerTiering.quote(
            for: tier,
            fallbackCurrency: fallbackCurrency
        )
        return [
            tier.name,
            quote.map {
                seatLayerPickerMoney(
                    $0.amount,
                    currency: $0.currency ?? fallbackCurrency,
                    style: style
                )
            },
            guidance,
        ].compactMap { $0 }.joined(separator: " · ")
    }
}
#endif
