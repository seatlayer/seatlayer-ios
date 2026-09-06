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
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
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
        if presentation.actionInFlight { return style.strings.text(.openingCheckout) }
        let totals = presentation.confirmedCartTotals
        guard !totals.hasMixedCurrencies, let currency = totals.currency else {
            return style.strings.text(.continueWord)
        }
        return style.strings.continueWithTotal(
            seatLayerPickerMoney(totals.total, currency: currency, style: style)
        )
    }
}

/// The inline bar under the cart.
///
/// Three of the runtime's refusals are not failures at all — they are the
/// state of a hold that now belongs to checkout — so those are said as a state
/// with a way forward, and everything else keeps the plain error line.
public struct SeatLayerPickerActionError: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @State private var releasing = false

    public init() {}

    public var body: some View {
        if let error = presentation.lastActionError {
            let palette = resolveSeatLayerPickerPalette(
                style: style,
                colorScheme: colorScheme,
                snapshot: controller.snapshot
            )
            let notice = seatLayerPickerHoldStateNotice(
                code: error.code,
                hasHandoff: presentation.checkoutHandoff != nil
            )
            if let notice {
                holdState(notice, palette: palette)
            } else {
                plain(error, palette: palette)
            }
        }
    }

    @ViewBuilder
    private func holdState(
        _ notice: SeatLayerPickerHoldStateNotice,
        palette: SeatLayerPickerPalette
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(style.strings.text(notice.title))
                .seatLayerPickerFont(size: 13, weight: .heavy)
                .foregroundColor(palette.text)
            Text(style.strings.text(notice.body))
                .seatLayerPickerFont(size: 12, weight: .medium)
                .foregroundColor(palette.mutedText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if notice.releases, let handoff = presentation.checkoutHandoff {
                    Button(style.strings.text(.releaseAndChangeSeats)) {
                        release(handoff)
                    }
                    .seatLayerPickerFont(size: 13, weight: .heavy)
                    .foregroundColor(palette.onAccent)
                    .padding(.horizontal, 12)
                    .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                    .background(palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
                    .disabled(releasing)
                }
                Button(style.strings.text(.close)) { presentation.dismissActionError() }
                    .seatLayerPickerFont(size: 13, weight: .bold)
                    .foregroundColor(palette.mutedText)
                    .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("seatlayer-hold-state")
    }

    @ViewBuilder
    private func plain(
        _ error: SeatLayerError,
        palette: SeatLayerPickerPalette
    ) -> some View {
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
            .accessibilityLabel(style.strings.text(.close))
        }
        .foregroundColor(palette.error)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    /// Gives the seats back on sale, and clears the notice when it lands.
    private func release(_ handoff: SeatLayerPickerCheckoutHandoff) {
        guard !releasing else { return }
        releasing = true
        Task { @MainActor in
            defer { releasing = false }
            do {
                _ = try await controller.rejectHandoff(handoff.holdId)
                presentation.dismissActionError()
                presentation.resumeAfterCheckout()
            } catch let error as SeatLayerError {
                controller.record(error)
            } catch {
                controller.record(.transport(error.localizedDescription))
            }
        }
    }
}
#endif
