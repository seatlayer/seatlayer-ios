#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The one checkout call to action, wherever it is drawn.
///
/// It carries its own label only — the total is on the line above it — and it
/// says why it cannot be pressed rather than going quietly grey.
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
        let cta = seatLayerCheckoutCtaState(ctaInput, strings: style.strings)
        Button {
            if cta.findsBestSeats {
                presentation.sheetDetent = .open
            } else {
                Task { @MainActor in _ = try? await presentation.checkout(using: onCheckout) }
            }
        } label: {
            HStack(spacing: 8) {
                if cta.busy { ProgressView().tint(ink(cta, palette: palette)) }
                Text(cta.label).lineLimit(1).minimumScaleFactor(0.7)
            }
            .seatLayerPickerFont(SeatLayerPickerTypeTokens.bookButton)
            .foregroundColor(ink(cta, palette: palette))
            .frame(
                maxWidth: .infinity,
                minHeight: SeatLayerPickerSizeTokens.checkoutButtonHeight
            )
            .background(cta.enabled ? palette.accent : palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
            // A designed disabled state: the button keeps its shape and takes
            // an inset hairline, rather than becoming a grey system rectangle.
            .overlay {
                if !cta.enabled {
                    RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button)
                        .stroke(palette.divider, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!cta.enabled)
        .accessibilityLabel(cta.label)
        .accessibilityIdentifier("seatlayer-checkout")
    }

    private func ink(
        _ cta: SeatLayerPickerCheckoutCta,
        palette: SeatLayerPickerPalette
    ) -> Color {
        cta.enabled ? palette.onAccent : palette.mutedText
    }

    private var ctaInput: SeatLayerPickerCheckoutCtaInput {
        let snapshot = controller.snapshot
        return SeatLayerPickerCheckoutCtaInput(
            label: style.strings.text(.holdAndCheckout),
            canCheckout: presentation.canCheckout,
            salesClosed: snapshot?.event.salesClosed == true,
            promptOpen: presentation.activePrompt != nil,
            seatCardOpen: presentation.pendingSeat != nil
                || presentation.candidateSeat != nil,
            creatingHold: presentation.actionInFlight,
            handoffInFlight: false,
            ticketCount: presentation.confirmedTicketCount,
            pendingCount: 0,
            holdActive: snapshot?.hold.active == true,
            canOfferFind: canOfferFind,
            validity: snapshot?.selectionValidity
        )
    }

    /// The empty cart's door into the finder, gated exactly as the tray's own
    /// card is.
    private var canOfferFind: Bool {
        style.options.enableBestAvailable
            && !style.options.readOnly
            && controller.supports(command: "picker.bestAvailable")
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
                .accessibilityLabel(style.strings.text(.close))
            }
            .foregroundColor(palette.error)
            .padding(.vertical, 7)
        }
    }
}
#endif
