#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The non-blocking telling of a lapsed hold, and the way back to the seats.
///
/// Flutter — and every porting SDK — deliberately does NOT answer an expiry
/// with a blocking interrupt card. The buyer has usually just come back from
/// somewhere else, and a modal is a second thing to dismiss before they can
/// see whether their seats are still there, over a map that is still entirely
/// usable and a lapse that is often fully recoverable. The same sentence is
/// said twice — here, and as a persistent line in the cart sheet — and blocks
/// neither.
public struct SeatLayerHoldLapseNotice: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if let lapse = controller.holdLapse, style.options.announceHoldLapse {
            let palette = resolveSeatLayerPickerPalette(
                style: style,
                colorScheme: colorScheme,
                snapshot: controller.snapshot
            )
            let telling = seatLayerPickerHoldLapseTelling(lapse)
            let tone = telling.tone == .error ? palette.error : palette.warning
            VStack(alignment: .leading, spacing: 9) {
                Text(style.strings.text(
                    telling.message,
                    replacing: ["count": String(telling.messageCount)]
                ))
                .seatLayerPickerFont(size: 13, weight: .heavy)
                .foregroundColor(palette.text)
                .fixedSize(horizontal: false, vertical: true)
                if lapse.unrecoverableCount > 0, telling.tone == .warning {
                    Text(style.strings.text(
                        .seatsNotRecovered,
                        replacing: ["n": String(lapse.unrecoverableCount)]
                    ))
                    .seatLayerPickerFont(size: 12, weight: .semibold)
                    .foregroundColor(palette.mutedText)
                }
                HStack(spacing: 8) {
                    Button(style.strings.text(.close)) { controller.dismissHoldLapse() }
                        .foregroundColor(palette.mutedText)
                        .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                    if let action = telling.action {
                        Button(style.strings.text(
                            action,
                            replacing: ["count": String(telling.actionCount)]
                        )) {
                            runPickerAction(controller) {
                                _ = try await controller.reselectLapsedSeats(
                                    ttlMs: style.options.normalizedHoldTtlMs
                                )
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
            .seatLayerPickerFont(size: 13, weight: .bold)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.warning.opacity(toneWash))
            .overlay {
                RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card).stroke(tone)
            }
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("seatlayer-hold-lapse")
        }
    }

    // tokens.json gap: how much of the warning colour the ground takes.
    private let toneWash = 0.12
}

/// Truthful no-inventory state; it never replaces a loading or error surface.
///
/// Two different answers, said two different ways: a venue with nothing left
/// gets the sold-out veil, and an event that has stopped selling gets the
/// tray's own statement. Both are read from the live snapshot, so both clear
/// themselves.
public struct SeatLayerPickerEmptyView: View {
    @EnvironmentObject private var controller: SeatLayerPickerController

    public init() {}

    public var body: some View {
        switch controller.snapshot.map(seatLayerPickerInventoryStatus) {
        case .soldOut:
            SeatLayerPickerSoldOutOverlay()
        case .salesClosed:
            SeatLayerPickerSalesClosedStatement()
                .frame(maxWidth: emptyStatementMaxWidth)
                .padding(20)
        case .availableOrUnknown, .none:
            EmptyView()
        }
    }

    // tokens.json gap: the width the tray statement takes when it stands in
    // the middle of the map rather than in the sheet.
    private let emptyStatementMaxWidth = 360.0
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
