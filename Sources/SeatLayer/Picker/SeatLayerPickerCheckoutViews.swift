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
