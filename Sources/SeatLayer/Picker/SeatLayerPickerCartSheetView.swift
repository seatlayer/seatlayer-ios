#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

// tokens.json gap: the collapsed seat line's own type and hint are Dart-local
// in `picker_cart_sheet.dart` — 12 / w600, a 16 pt unfold hint, a 6 pt gap and
// 3 pt of air above; the total line's swell is 1 → 1.3 → 1.
private enum SeatLayerPickerSheetMetrics {
    static let seatLineSize: Double = 12
    static let seatLineHintSize: Double = 16
    static let seatLineGap: Double = 6
    static let seatLinePadTop: Double = 3
    static let chevronSize: Double = 16
    static let handleShadowRadius: Double = 5
    static let handleShadowY: Double = 2
    static let swell: Double = 1.3
}

/// The phone ticket sheet: one surface, from the handle disc on its top edge
/// to the attribution at its foot.
///
/// Collapsed IS the footer. The cart's cards are what open and close; the
/// summary, the button and the credit are drawn in both states, so a buyer
/// with seats already held can always see the button that takes their money.
public struct SeatLayerPickerCartSheet: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var contentHeight: Double = 0
    @State private var footHeight: Double = 0
    @State private var drag: Double?
    @State private var dragStart: SeatLayerPickerSheetDetent = .peek

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
            head(palette: palette)
            cartRegion
            SeatLayerPickerCartSheetFoot(onCheckout: onCheckout)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: SeatLayerPickerCartFootHeightKey.self,
                            value: geometry.size.height
                        )
                    }
                }
        }
        // One surface: the sheet's ground is the panel ground, so the cart's
        // cards have something to sit on.
        .background(palette.background)
        .clipShape(
            UnevenRoundedRectangleCompat(
                topLeading: SeatLayerPickerRadiusTokens.sheet,
                topTrailing: SeatLayerPickerRadiusTokens.sheet
            )
        )
        // The top hairline is the sheet's own edge — the map runs up to it.
        .overlay(alignment: .top) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
        // `0 -8 26 -20` at 72 % black: SwiftUI has no negative spread, so the
        // alpha carries the tightening the spread does in the design source.
        .shadow(
            color: .black.opacity(0.18),
            radius: SeatLayerPickerElevationTokens.sheet * 0.75,
            y: -8
        )
        .overlay(alignment: .top) { handle(palette: palette) }
        .offset(y: detents.surfaceOffset(of: presentation.sheetDetent))
        .onPreferenceChange(SeatLayerPickerCartFootHeightKey.self) { value in
            guard value.isFinite, value > 0 else { return }
            footHeight = value
        }
        .onPreferenceChange(SeatLayerPickerCartContentHeightKey.self) { value in
            guard value.isFinite else { return }
            contentHeight = value
        }
        .animation(
            seatLayerPickerAnimation(.sheet, reduceMotion: reduceMotion, curve: .spring),
            value: presentation.sheetDetent
        )
        .accessibilityIdentifier("seatlayer-cart-sheet")
    }

    // MARK: - Rungs

    private var hasTickets: Bool { !presentation.confirmedCartLines.isEmpty }

    private var chrome: Double {
        SeatLayerPickerSizeTokens.sheetHeadHeight + footHeight
    }

    private var detents: SeatLayerPickerSheetDetents {
        seatLayerPickerSheetDetents(
            screenHeight: seatLayerPickerScreenHeight(),
            chrome: chrome,
            contentHeight: min(contentHeight, SeatLayerPickerSizeTokens.cartPeekMaxHeight),
            hasTickets: hasTickets
        )
    }

    private var bodyHeight: Double {
        drag ?? detents.height(of: presentation.sheetDetent)
    }

    // MARK: - Head

    private func head(palette: SeatLayerPickerPalette) -> some View {
        Color.clear
            .frame(height: SeatLayerPickerSizeTokens.sheetHeadHeight)
            .contentShape(Rectangle())
            .gesture(sheetDrag)
    }

    /// The one named toggle for the sheet, and the only one: a 44 pt disc
    /// straddling the top edge, half of it over the map.
    @ViewBuilder
    private func handle(palette: SeatLayerPickerPalette) -> some View {
        if presentation.candidateSeat == nil, presentation.pendingSeat == nil {
            Button {
                presentation.sheetDetent = presentation.sheetDetent == .open ? .peek : .open
            } label: {
                ZStack {
                    Circle()
                        .fill(palette.background)
                        .shadow(
                            color: .black.opacity(0.2),
                            radius: SeatLayerPickerSheetMetrics.handleShadowRadius,
                            y: SeatLayerPickerSheetMetrics.handleShadowY
                        )
                    Image(systemName: "chevron.up")
                        .seatLayerPickerFont(
                            size: SeatLayerPickerSheetMetrics.chevronSize,
                            weight: .semibold
                        )
                        .foregroundColor(palette.mutedText)
                        .rotationEffect(
                            .degrees(presentation.sheetDetent == .open ? 180 : 0)
                        )
                        .animation(
                            seatLayerPickerAnimation(.chevron, reduceMotion: reduceMotion),
                            value: presentation.sheetDetent
                        )
                }
                .frame(
                    width: SeatLayerPickerSizeTokens.sheetHandleWidth,
                    height: SeatLayerPickerSizeTokens.sheetHandleHeight
                )
            }
            .buttonStyle(.plain)
            .offset(y: -SeatLayerPickerSizeTokens.sheetHandleOverhang)
            .gesture(sheetDrag)
            .accessibilityLabel(
                presentation.sheetDetent == .open
                    ? style.strings.text(.collapseCart)
                    : style.strings.text(.expandCart)
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(
                presentation.sheetDetent == .open
                    ? style.strings.text(.collapseCart)
                    : style.strings.text(.expandCart)
            )
            .accessibilityIdentifier("seatlayer-cart-toggle")
        }
    }

    /// Up grows the sheet 1:1, both ends give rather than stop, and a release
    /// settles onto a rung — the nearest one, or the next one along when the
    /// finger was still moving fast enough to mean it.
    private var sheetDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if drag == nil {
                    dragStart = presentation.sheetDetent
                }
                let base = detents.height(of: dragStart)
                drag = seatLayerPickerRubberBand(
                    base - value.translation.height,
                    0,
                    detents.top
                )
            }
            .onEnded { value in
                let base = detents.height(of: dragStart)
                let height = base - value.translation.height
                let velocity = -value.predictedEndTranslation.height
                    + value.translation.height
                var settled = detents.settle(height: height, velocity: velocity * 4)
                let travel = -value.translation.height
                if settled == dragStart, abs(travel) >= seatLayerPickerSheetDragThreshold {
                    settled = seatLayerPickerSheetStep(
                        from: dragStart,
                        travel: travel,
                        in: detents
                    )
                }
                drag = nil
                presentation.sheetDetent = settled
            }
    }

    // MARK: - Cart region

    /// The cards, and — only when the cart is empty — the way to fill it.
    @ViewBuilder
    private var cartRegion: some View {
        if hasTickets {
            SeatLayerPickerPartHost(.cartList) { SeatLayerPickerCartList() }
                .frame(height: max(0, bodyHeight), alignment: .top)
                .clipped()
        } else {
            SeatLayerPickerPartHost(.bestAvailable) { SeatLayerBestSeatsForm() }
                .padding(.horizontal, SeatLayerPickerSizeTokens.cartTrayPadX)
                .padding(.top, SeatLayerPickerSizeTokens.cartTrayPadTop)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: SeatLayerPickerCartContentHeightKey.self,
                            value: geometry.size.height
                                + SeatLayerPickerSizeTokens.cartTrayPadTop
                        )
                    }
                }
                .frame(height: max(0, bodyHeight), alignment: .top)
                .clipped()
        }
    }
}

/// How tall the sheet's foot measured, so the rung table knows what the sheet
/// draws in every state.
struct SeatLayerPickerCartFootHeightKey: PreferenceKey {
    static var defaultValue: Double = 0
    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = max(value, nextValue())
    }
}

/// The foot: the inline action error, the total line, the checkout button and
/// the credit. Drawn in both sheet states.
public struct SeatLayerPickerCartSheetFoot: View {
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
        VStack(spacing: 0) {
            SeatLayerPickerPartHost(.actionError) { SeatLayerPickerActionError() }
            SeatLayerPickerCartTotalLine()
            SeatLayerPickerPartHost(.checkoutBar) {
                SeatLayerPickerCheckoutBar(onCheckout: onCheckout)
            }
            .padding(.top, SeatLayerPickerSizeTokens.footTotalGap)
            if seatLayerPickerAttributionVisible(in: controller.snapshot) {
                SeatLayerPickerAttribution()
                    .padding(.top, SeatLayerPickerSizeTokens.footPadTop)
            }
        }
        .padding(.horizontal, SeatLayerPickerSizeTokens.footPadX)
        .padding(.top, SeatLayerPickerSizeTokens.footPadTop)
        .padding(.bottom, SeatLayerPickerSizeTokens.footPadBottom)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }
}

/// "N tickets · total", or "No seats selected", with the cart's own seats
/// underneath it.
public struct SeatLayerPickerCartTotalLine: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swollen = false

    public init() {}

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: SeatLayerPickerSheetMetrics.seatLineGap) {
                Text(summary)
                    .seatLayerPickerFont(SeatLayerPickerTypeTokens.footTotalLabel)
                    .foregroundColor(swollen ? palette.accent : palette.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let money = totalText {
                    Text(money)
                        .seatLayerPickerFont(SeatLayerPickerTypeTokens.footTotalAmount)
                        .foregroundColor(swollen ? palette.accent : palette.text)
                        .monospacedDigit()
                }
            }
            .scaleEffect(swollen ? SeatLayerPickerSheetMetrics.swell : 1, anchor: .leading)
            .animation(
                seatLayerPickerAnimation(.bump, reduceMotion: reduceMotion),
                value: swollen
            )
            if !seatLine.isEmpty {
                Button {
                    presentation.sheetDetent = .open
                } label: {
                    HStack(spacing: SeatLayerPickerSheetMetrics.seatLineGap) {
                        Text(seatLine)
                            .seatLayerPickerFont(
                                size: SeatLayerPickerSheetMetrics.seatLineSize,
                                weight: .semibold
                            )
                            .foregroundColor(palette.mutedText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.up.chevron.down")
                            .seatLayerPickerFont(
                                size: SeatLayerPickerSheetMetrics.seatLineHintSize * 0.7,
                                weight: .semibold
                            )
                            .foregroundColor(palette.mutedText)
                    }
                    .padding(.top, SeatLayerPickerSheetMetrics.seatLinePadTop)
                    .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.strings.text(.expandCart))
                .accessibilityIdentifier("seatlayer-cart-seat-line")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.updatesFrequently)
        .onChange(of: presentation.cartLanding) { landing in
            guard landing == .mapMayMove, !reduceMotion else { return }
            swollen = true
            Task { @MainActor in
                try? await Task.sleep(
                    nanoseconds: UInt64(SeatLayerPickerMotionDurationTokens.bump) * 1_000_000
                )
                swollen = false
            }
        }
    }

    private var summary: String {
        let totals = presentation.confirmedCartTotals
        guard totals.quantity > 0 else { return style.strings.text(.noSeatsSelected) }
        return style.strings.ticketCount(totals.quantity)
    }

    private var totalText: String? {
        let totals = presentation.confirmedCartTotals
        guard totals.quantity > 0,
              !totals.hasMixedCurrencies,
              let currency = totals.currency else { return nil }
        return seatLayerPickerMoney(totals.total, currency: currency, style: style)
    }

    /// "204 · Q · 7,  204 · Q · 8" — the cart's own labels, muted, on one line.
    private var seatLine: String {
        presentation.confirmedCartLines
            .map { line in
                (line.displayLabel ?? line.label)
                    .replacingOccurrences(of: "-", with: " · ")
            }
            .joined(separator: ",  ")
    }
}
#endif
