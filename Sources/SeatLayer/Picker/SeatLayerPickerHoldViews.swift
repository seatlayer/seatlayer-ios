#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Buyer-facing expired-hold reconciliation and recovery action.
public struct SeatLayerHoldLapseNotice: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if let lapse = controller.holdLapse, style.options.announceHoldLapse {
            let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: controller.snapshot)
            VStack(alignment: .leading, spacing: 9) {
                Label(style.strings.text(.holdExpired), systemImage: "clock.badge.exclamationmark")
                    .seatLayerPickerFont(size: 14, weight: .heavy)
                    .foregroundColor(palette.text)
                Text(recoveryCopy(lapse))
                    .seatLayerPickerFont(size: 12, weight: .semibold)
                    .foregroundColor(palette.mutedText)
                HStack(spacing: 8) {
                    Button(style.strings.text(.dismiss)) { controller.dismissHoldLapse() }
                        .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                    if !lapse.recoverableLabels.isEmpty {
                        Button(style.strings.text(.recoverSeats)) {
                            runPickerAction(controller) {
                                _ = try await controller.reselectLapsedSeats(ttlMs: style.options.normalizedHoldTtlMs)
                            }
                        }
                        .foregroundColor(palette.onAccent)
                        .padding(.horizontal, 12)
                        .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                        .background(palette.accent)
                        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
                    }
                }
            }
            .padding(12)
            .background(palette.surface)
            .overlay { RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card).stroke(palette.warning) }
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("seatlayer-hold-lapse")
        }
    }

    private func recoveryCopy(_ lapse: SeatLayerPickerHoldLapse) -> String {
        switch lapse.recovery {
        case .all:
            return "\(style.strings.ticketCount(lapse.lapsedLabels.count)) · \(style.strings.text(.recoverSeats))"
        case .partial:
            return "\(style.strings.ticketCount(lapse.recoverableLabels.count)) · \(style.strings.text(.recoverSeats))"
        case .none: return style.strings.text(.noTicketsAvailable)
        }
    }
}

/// Truthful no-inventory state; it never replaces a loading or error surface.
public struct SeatLayerPickerEmptyView: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: controller.snapshot)
        let message = controller.snapshot?.event.salesClosed == true
            ? style.strings.text(.salesClosed)
            : style.strings.text(.noTicketsAvailable)
        VStack(spacing: 10) {
            Image(systemName: "ticket.fill").seatLayerPickerFont(size: 24).foregroundColor(palette.mutedText)
            Text(message)
                .seatLayerPickerFont(size: 14, weight: .bold)
                .foregroundColor(palette.text)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .seatLayerPickerTranslucentBackground(palette.surface, opacity: 0.96)
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("seatlayer-empty")
    }
}

/// Canonical checkout-bar spelling used by builders and custom layouts.
public struct SeatLayerPickerCheckoutBar: View {
    private let onCheckout: SeatLayerPickerCheckoutHandler

    public init(onCheckout: @escaping SeatLayerPickerCheckoutHandler) {
        self.onCheckout = onCheckout
    }

    public var body: some View {
        SeatLayerPickerCheckoutButton(onCheckout: onCheckout)
    }
}
#endif
