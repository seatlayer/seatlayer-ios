#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Compact mutually-exclusive ticket choices used by reserved-seat and
/// general-admission decisions. Choosing a row updates native price state;
/// the owning prompt decides when to send the runtime mutation.
public struct SeatLayerPickerTicketTierChoices: View {
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let tiers: [CategoryTier]
    private let fallbackCurrency: String
    private let enabled: Bool
    @Binding private var selection: String?

    public init(
        tiers: [CategoryTier],
        fallbackCurrency: String,
        selection: Binding<String?>,
        enabled: Bool = true
    ) {
        self.tiers = tiers
        self.fallbackCurrency = fallbackCurrency
        self.enabled = enabled
        _selection = selection
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: nil
        )
        VStack(spacing: 7) {
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(selected ? palette.accent.opacity(0.10) : Color.clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button)
                            .stroke(
                                selected ? palette.accent : palette.divider,
                                lineWidth: selected ? 1.5 : 1
                            )
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

    @ViewBuilder
    private func tierLabel(
        _ tier: CategoryTier,
        selected: Bool,
        guidance: String?,
        quote: SeatLayerPickerTierQuote?,
        palette: SeatLayerPickerPalette
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    tierSelectionImage(selected: selected, palette: palette)
                    Text(tier.name)
                        .seatLayerPickerFont(size: 14, weight: .heavy)
                        .foregroundColor(palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let guidance {
                    Text(guidance)
                        .seatLayerPickerFont(size: 11, weight: .semibold)
                        .foregroundColor(palette.mutedText)
                        .multilineTextAlignment(.leading)
                }
                if let quote {
                    tierPrice(quote, palette: palette)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        } else {
            HStack(spacing: 10) {
                tierSelectionImage(selected: selected, palette: palette)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.name)
                        .seatLayerPickerFont(size: 14, weight: .heavy)
                        .foregroundColor(palette.text)
                    if let guidance {
                        Text(guidance)
                            .seatLayerPickerFont(size: 11, weight: .semibold)
                            .foregroundColor(palette.mutedText)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                if let quote { tierPrice(quote, palette: palette) }
            }
        }
    }

    private func tierSelectionImage(
        selected: Bool,
        palette: SeatLayerPickerPalette
    ) -> some View {
        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
            .font(.system(
                size: dynamicTypeSize.isAccessibilitySize ? 24 : 18,
                weight: .semibold
            ))
            .foregroundColor(selected ? palette.accent : palette.mutedText)
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
