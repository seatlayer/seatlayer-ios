#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Phone ticket panel. Its collapsed and expanded states read only confirmed
/// cart projections so an unanswered seat never appears committed.
public struct SeatLayerPickerCartSheet: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let onCheckout: SeatLayerPickerCheckoutHandler

    public init(onCheckout: @escaping SeatLayerPickerCheckoutHandler) {
        self.onCheckout = onCheckout
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        VStack(spacing: 0) {
            SeatLayerPickerCartPeek(onCheckout: onCheckout)
            if presentation.cartSheetExpanded {
                if presentation.confirmedCartLines.isEmpty {
                    if presentation.removalUndo != nil {
                        SeatLayerPickerCartUndoView()
                    }
                    VStack(spacing: 10) {
                        Image(systemName: "ticket")
                            .seatLayerPickerFont(size: 22, weight: .semibold)
                            .foregroundColor(palette.mutedText)
                        Text(style.strings.text(.emptyTrayHint))
                            .seatLayerPickerFont(size: 13, weight: .semibold)
                            .foregroundColor(palette.mutedText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: SeatLayerPickerSizeTokens.emptyTrayMaxHeight)
                    .padding(.horizontal, 22)
                    SeatLayerPickerPartHost(.bestAvailable) { SeatLayerBestSeatsForm() }
                        .padding(.horizontal, 12)
                } else {
                    SeatLayerPickerPartHost(.cartList) { SeatLayerPickerCartList() }
                        .frame(maxHeight: SeatLayerPickerSizeTokens.denseLineHeight * 5)
                    SeatLayerPickerPartHost(.actionError) { SeatLayerPickerActionError() }
                    SeatLayerPickerPartHost(.checkoutBar) {
                        SeatLayerPickerCheckoutBar(onCheckout: onCheckout)
                    }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                }
            }
        }
        .background(palette.surface)
        .clipShape(
            UnevenRoundedRectangleCompat(
                topLeading: SeatLayerPickerRadiusTokens.sheet,
                topTrailing: SeatLayerPickerRadiusTokens.sheet
            )
        )
        .shadow(color: .black.opacity(0.22), radius: 12, y: -2)
        .animation(
            seatLayerPickerAnimation(.sheet, reduceMotion: reduceMotion),
            value: presentation.cartSheetExpanded
        )
    }
}

public struct SeatLayerPickerCartPeek: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    private let onCheckout: SeatLayerPickerCheckoutHandler

    public init(onCheckout: @escaping SeatLayerPickerCheckoutHandler) {
        self.onCheckout = onCheckout
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        ZStack(alignment: .top) {
            Capsule()
                .fill(palette.mutedText.opacity(0.5))
                .frame(width: 32, height: 3)
                .padding(.top, 5)
            HStack(spacing: 7) {
                Button {
                    presentation.cartSheetExpanded.toggle()
                } label: {
                    Text(summary)
                        .seatLayerPickerFont(size: 13, weight: .heavy)
                        .foregroundColor(palette.text)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    presentation.cartSheetExpanded
                        ? style.strings.text(.collapseCart)
                        : style.strings.text(.expandCart)
                )
                .accessibilityIdentifier("seatlayer-cart-toggle")
                if !presentation.cartSheetExpanded,
                   !presentation.confirmedCartLines.isEmpty {
                    compactContinue(palette: palette)
                }
                Button {
                    presentation.cartSheetExpanded.toggle()
                } label: {
                    Image(systemName: "chevron.up")
                        .seatLayerPickerFont(size: 14, weight: .bold)
                        .foregroundColor(palette.mutedText)
                        .rotationEffect(.degrees(presentation.cartSheetExpanded ? 180 : 0))
                        .frame(
                            width: SeatLayerPickerSizeTokens.minimumHitTarget,
                            height: SeatLayerPickerSizeTokens.minimumHitTarget
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
            .padding(.leading, 14)
            .padding(.trailing, 4)
            .padding(.top, 6)
            .accessibilityElement(children: .contain)
        }
        .frame(minHeight: SeatLayerPickerSizeTokens.peekHeight)
    }

    private var summary: String {
        if presentation.confirmedCartLines.isEmpty {
            let cheapest = controller.snapshot?.categories
                .filter { !$0.notForSale }
                .map(\.priceMin)
                .min()
            guard let cheapest else { return style.strings.text(.chooseTickets) }
            return style.strings.fromPrice(
                seatLayerPickerMoney(
                    cheapest,
                    currency: controller.snapshot?.currency ?? "USD",
                    style: style
                )
            )
        }
        if presentation.cartSheetExpanded {
            return style.strings.ticketCount(presentation.confirmedTicketCount)
        }
        let totals = presentation.confirmedCartTotals
        guard !totals.hasMixedCurrencies, let currency = totals.currency else {
            return style.strings.ticketCount(totals.quantity)
        }
        return "\(style.strings.ticketCount(totals.quantity)) · \(seatLayerPickerMoney(totals.total, currency: currency, style: style))"
    }

    private func compactContinue(palette: SeatLayerPickerPalette) -> some View {
        Button {
            beginCheckout()
        } label: {
            Text(checkoutTitle)
            .seatLayerPickerFont(size: 13, weight: .heavy)
            .foregroundColor(palette.onAccent)
            .padding(.horizontal, 12)
            .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
            .background(palette.accent)
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
        }
        .buttonStyle(.plain)
        .disabled(!presentation.canCheckout)
        .accessibilityLabel(style.strings.text(.continueWord))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("seatlayer-checkout-compact")
    }

    private func beginCheckout() {
        Task { @MainActor in _ = try? await presentation.checkout(using: onCheckout) }
    }

    private var checkoutTitle: String {
        let totals = presentation.confirmedCartTotals
        guard !totals.hasMixedCurrencies, let currency = totals.currency else {
            return style.strings.text(.continueWord)
        }
        return style.strings.continueWithTotal(
            seatLayerPickerMoney(totals.total, currency: currency, style: style)
        )
    }
}
#endif
