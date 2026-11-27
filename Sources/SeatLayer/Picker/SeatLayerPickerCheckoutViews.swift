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
    @Environment(\.seatLayerPickerCartBarButton) private var inRow
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
            let radius = inRow == nil
                ? SeatLayerPickerRadiusTokens.button
                : SeatLayerPickerCartBar.buttonRadius
            Group {
                if let inRow {
                    // In the cart row: up to two balanced lines, at the size
                    // the row chose.
                    HStack(spacing: 6) {
                        if cta.busy { ProgressView().tint(ink(cta, palette: palette)) }
                        Text(cta.label)
                            .seatLayerPickerFont(
                                size: inRow.letters,
                                weight: .seatLayerPickerWeight(SeatLayerPickerTypeTokens.bookButton.weight)
                            )
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: inRow.textWidth)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, SeatLayerPickerCartBar.buttonPadX)
                    .padding(.vertical, SeatLayerPickerCartBar.buttonPadY)
                    .frame(maxWidth: .infinity, minHeight: SeatLayerPickerCartBar.minHeight)
                } else {
                    HStack(spacing: 8) {
                        if cta.busy { ProgressView().tint(ink(cta, palette: palette)) }
                        Text(cta.label).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .seatLayerPickerFont(SeatLayerPickerTypeTokens.bookButton)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: SeatLayerPickerSizeTokens.checkoutButtonHeight
                    )
                }
            }
            .foregroundColor(ink(cta, palette: palette))
            .background(cta.enabled ? palette.accent : palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            // A designed disabled state: the button keeps its shape and takes
            // an inset hairline, rather than becoming a grey system rectangle.
            .overlay {
                if !cta.enabled {
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(palette.divider, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!cta.enabled)
        .accessibilityLabel(cta.label)
        .accessibilityIdentifier("seatlayer-checkout")
        .onAppear {
            // "Couldn’t reach checkout." offers Try again through this same path.
            seatLayerPickerPressWatch(for: controller).retry = { [presentation, onCheckout] in
                Task { @MainActor in _ = try? await presentation.checkout(using: onCheckout) }
            }
        }
    }

    private func ink(
        _ cta: SeatLayerPickerCheckoutCta,
        palette: SeatLayerPickerPalette
    ) -> Color {
        cta.enabled ? palette.onAccent : palette.mutedText
    }

    private var ctaInput: SeatLayerPickerCheckoutCtaInput {
        seatLayerPickerCheckoutCtaInput(presentation: presentation, controller: controller, style: style)
    }
}

/// What the checkout button says depends on: shared by the button and the
/// cart row that measures its words.
@MainActor
func seatLayerPickerCheckoutCtaInput(
    presentation: SeatLayerPickerPresentationModel,
    controller: SeatLayerPickerController,
    style: SeatLayerPickerStyleEnvironment
) -> SeatLayerPickerCheckoutCtaInput {
    let snapshot = controller.snapshot
    return SeatLayerPickerCheckoutCtaInput(
        label: style.strings.text(.holdAndCheckout),
        canCheckout: presentation.canCheckout,
        salesClosed: snapshot?.event.salesClosed == true,
        promptOpen: presentation.activePrompt != nil,
        seatCardOpen: presentation.pendingSeat != nil
            || presentation.candidateSeat != nil,
        creatingHold: presentation.actionInFlight && !presentation.handoffInFlight,
        handoffInFlight: presentation.handoffInFlight,
        ticketCount: presentation.confirmedTicketCount,
        pendingCount: presentation.pendingCount,
        holdActive: snapshot?.hold.active == true,
        canOfferFind: seatLayerPickerOffersFinder(snapshot, controller: controller, style: style),
        validity: snapshot?.selectionValidity
    )
}

/// The empty cart's door into the finder, gated as the tray's own card is.
/// A sold-out or closed event, a hold already made (or the app's own) and a
/// selection the event will not take offer no finder: the button says
/// "Select seats" instead.
@MainActor
func seatLayerPickerOffersFinder(
    _ snapshot: SeatLayerPickerSnapshot?,
    controller: SeatLayerPickerController,
    style: SeatLayerPickerStyleEnvironment
) -> Bool {
    guard style.options.enableBestAvailable,
          !style.options.readOnly,
          controller.supports(command: "picker.bestAvailable") else { return false }
    return seatLayerPickerFinderAllowed(snapshot)
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
        // A lost line is told by the small message instead, and a page that
        // did not load by its own panel (§3.4.2).
        if let error = presentation.lastActionError,
           !controller.pageFailed,
           !seatLayerPickerToldAsMessage(error, failure: controller.failure(for: error)) {
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
            let words = seatLayerPickerErrorWords(
                error,
                failure: controller.failure(for: error),
                strings: style.strings
            )
            Image(systemName: "exclamationmark.circle.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(words.message)
                    .seatLayerPickerFont(size: 12, weight: .semibold)
                if let detail = words.detail {
                    Text(detail)
                        .seatLayerPickerFont(size: 12, weight: .medium)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
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
