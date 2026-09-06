#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct SeatLayerPickerCheckoutButton: View {
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
        Button {
            Task { @MainActor in _ = try? await presentation.checkout(using: onCheckout) }
        } label: {
            HStack(spacing: 8) {
                if presentation.actionInFlight { ProgressView().tint(palette.onAccent) }
                Text(checkoutTitle)
            }
            .seatLayerPickerFont(size: 15, weight: .heavy)
            .foregroundColor(palette.onAccent)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(palette.accent)
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
        }
        .buttonStyle(.plain)
        .disabled(!presentation.canCheckout)
        .accessibilityIdentifier("seatlayer-checkout")
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

public struct SeatLayerPickerActionError: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if let error = presentation.lastActionError {
            let palette = resolveSeatLayerPickerPalette(
                style: style,
                colorScheme: colorScheme,
                snapshot: controller.snapshot
            )
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                Text(seatLayerPickerBuyerErrorText(error, strings: style.strings))
                    .seatLayerPickerFont(size: 12, weight: .semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    presentation.dismissActionError()
                } label: {
                    Image(systemName: "xmark").frame(
                        width: SeatLayerPickerSizeTokens.minimumHitTarget,
                        height: SeatLayerPickerSizeTokens.minimumHitTarget
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.strings.text(.dismiss))
            }
            .foregroundColor(palette.error)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
    }
}
#endif
