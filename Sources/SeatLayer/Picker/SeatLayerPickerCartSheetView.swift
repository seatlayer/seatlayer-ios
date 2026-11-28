import Foundation

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

private typealias Bar = SeatLayerPickerCartBar

// The total line's swell when a seat lands in the cart: 1 → 1.3 → 1.
private enum SeatLayerPickerSheetMetrics {
    static let swell: Double = 1.3
}

/// The phone ticket sheet: the cart list over one row.
///
/// Collapsed it is the row alone: the circle that opens the list, what the
/// cart holds and comes to, and the button. The list (at most 240 points) is
/// what opens and closes; the row is drawn in both states, so a buyer with
/// seats already held can always see the button that takes their money.
public struct SeatLayerPickerCartSheet: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.seatLayerPickerMapHeight) private var mapHeight

    @State private var contentHeight: Double = 0
    @State private var footHeight: Double = 0
    @State private var drag: Double?
    @State private var dragStart: SeatLayerPickerSheetDetent = .peek
    @State private var seatCount = 0

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
            cartRegion
            SeatLayerPickerCartSheetFoot(onCheckout: onCheckout)
                .gesture(sheetDrag)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: SeatLayerPickerCartFootHeightKey.self,
                            value: geometry.size.height
                        )
                    }
                }
        }
        .dynamicTypeSize(...seatLayerPickerSheetTypeCeiling)
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
        // A new seat closes the list: the buyer is choosing on the map.
        .onChange(of: presentation.confirmedCartLines.count) { count in
            defer { seatCount = count }
            if count > seatCount, presentation.sheetDetent == .open {
                presentation.sheetDetent = .peek
            }
        }
        .onAppear { seatCount = presentation.confirmedCartLines.count }
        .accessibilityIdentifier("seatlayer-cart-sheet")
    }

    // MARK: - Rungs

    private var hasTickets: Bool { !presentation.confirmedCartLines.isEmpty }

    private var chrome: Double { footHeight }

    private var detents: SeatLayerPickerSheetDetents {
        seatLayerPickerSheetDetents(
            screenHeight: seatLayerPickerScreenHeight(),
            chrome: chrome,
            // Three cards and a sliver of the fourth is a ceiling on the CART,
            // and one measure carries both what the cart asks for and what the
            // empty tray does. Capping the tray with it cut the best-seats
            // form's own row in half — its stepper and its button — which is
            // the one thing that must never be what gets cut.
            contentHeight: hasTickets
                ? min(contentHeight, SeatLayerPickerCartBar.listMaxHeight)
                : contentHeight,
            hasTickets: hasTickets
        )
    }

    private var bodyHeight: Double {
        // The open region never takes the map's top line: on a phone held
        // sideways it scrolls in what is left.
        seatLayerPickerCartRegionHeight(
            wanted: drag ?? detents.height(of: presentation.sheetDetent),
            mapHeight: mapHeight,
            rowHeight: chrome
        )
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
            // An event that has stopped selling says so where the buyer would
            // otherwise be offered seats.
            // The tray scrolls inside its box rather than being cut where the
            // map leaves it less room than it wants.
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    if controller.snapshot?.event.salesClosed == true {
                        SeatLayerPickerSalesClosedStatement()
                    } else {
                        SeatLayerPickerPartHost(.bestAvailable) { SeatLayerBestSeatsForm() }
                    }
                }
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
            }
                .seatLayerPickerBouncesOnlyWhenScrollable()
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

/// The phone's cart row: the circle that opens the list, what is in the cart
/// and what it comes to, and the way on, on one line. News about the buyer's
/// own seats (a lapsed hold, a refusal) stands over it.
public struct SeatLayerPickerCartSheetFoot: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerBuilders) private var builders
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var width: Double = 393

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
        let closed = seatLayerPickerSalesClosedWithNoHold(controller.snapshot)
        // An app's own part in the button's place keeps the full width, under the words.
        let custom = builders[.checkoutBar] != nil
        let plan = buttonPlan
        let under = !closed && (custom || plan.under)
        let besideDisc = max(0, width - Bar.padX * 2 - Bar.disc - Bar.gap)
        let room = closed || custom || plan.under ? besideDisc : plan.wordsWidth
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                SeatLayerPickerPartHost(.holdLapse) { SeatLayerHoldLapseNotice() }
                SeatLayerPickerPartHost(.actionError) { SeatLayerPickerActionError() }
            }
            .padding(.horizontal, Bar.padX)
            Group {
                if under {
                    VStack(alignment: .leading, spacing: Bar.underGap) {
                        words(palette: palette, room: room)
                        button(plan: plan, under: true)
                    }
                } else {
                    HStack(spacing: Bar.gap) {
                        words(palette: palette, room: room)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !closed { button(plan: plan, under: false) }
                    }
                }
            }
            .padding(.horizontal, Bar.padX)
            .padding(.vertical, Bar.padY)
            .opacity(asking ? Bar.askingOpacity : 1)
            .allowsHitTesting(!asking)
            // The row's words grow with the buyer's text size only as far as
            // the sheet's clamp; its rulers measure at the same size.
            .dynamicTypeSize(...seatLayerPickerSheetTypeCeiling)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { width = geometry.size.width }
                        .onChange(of: geometry.size.width) { width = $0 }
                }
            }
            .accessibilityIdentifier("seatlayer-cart-row")
        }
        .overlay(alignment: .top) {
            if presentation.sheetDetent == .open {
                Rectangle().fill(palette.divider).frame(height: 1)
            }
        }
    }

    /// A seat card is asking: nothing in the row can be pressed until it is
    /// answered.
    private var asking: Bool {
        presentation.pendingSeat != nil || presentation.candidateSeat != nil
    }

    private func toggle() {
        presentation.sheetDetent = presentation.sheetDetent == .open ? .peek : .open
    }

    @ViewBuilder
    private func words(palette: SeatLayerPickerPalette, room: Double) -> some View {
        HStack(spacing: SeatLayerPickerCartBar.gap) {
            Button(action: toggle) {
                ZStack {
                    Circle().fill(palette.surface)
                    Circle().stroke(palette.divider, lineWidth: 1)
                    Image(systemName: "chevron.up")
                        .seatLayerPickerFont(size: SeatLayerPickerCartBar.chevron * 0.75, weight: .bold)
                        .foregroundColor(palette.text)
                        .rotationEffect(.degrees(presentation.sheetDetent == .open ? 180 : 0))
                        .animation(
                            seatLayerPickerAnimation(.chevron, reduceMotion: reduceMotion),
                            value: presentation.sheetDetent
                        )
                }
                .frame(width: SeatLayerPickerCartBar.disc, height: SeatLayerPickerCartBar.disc)
                // Drawn at 28, pressed over 44.
                .frame(
                    width: SeatLayerPickerSizeTokens.minimumHitTarget,
                    height: SeatLayerPickerSizeTokens.minimumHitTarget
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -(SeatLayerPickerSizeTokens.minimumHitTarget - SeatLayerPickerCartBar.disc) / 2)
            .accessibilityLabel(style.strings.text(
                presentation.sheetDetent == .open ? .collapseCart : .expandCart
            ))
            .accessibilityIdentifier("seatlayer-cart-toggle")
            // The words open the list as the circle does; a screen reader is
            // given the circle for it, and reads these as a line.
            Button(action: toggle) {
                SeatLayerPickerCartTotalLine(room: room)
                    .frame(maxWidth: .infinity, minHeight: SeatLayerPickerCartBar.minHeight, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityRemoveTraits(.isButton)
        }
        .frame(minHeight: SeatLayerPickerCartBar.minHeight)
    }

    @ViewBuilder
    private func button(plan: SeatLayerPickerCartBarPlan, under: Bool) -> some View {
        SeatLayerPickerPartHost(.checkoutBar) {
            SeatLayerPickerCheckoutBar(onCheckout: onCheckout)
                .environment(\.seatLayerPickerCartBarButton, .init(
                    letters: SeatLayerPickerCartBar.letters[min(plan.letters, SeatLayerPickerCartBar.letters.count - 1)],
                    textWidth: plan.textWidth
                ))
                .frame(width: under ? nil : plan.buttonWidth)
        }
        .frame(maxWidth: under ? .infinity : nil)
    }

    /// Where the button stands, from the widths of its words at this text size.
    private var buttonPlan: SeatLayerPickerCartBarPlan {
        let category = UIContentSizeCategory(min(dynamicTypeSize, seatLayerPickerSheetTypeCeiling))
        let token = SeatLayerPickerTypeTokens.bookButton
        let weight = SeatLayerPickerCartBarRuler.weight(token.weight)
        let own = [
            style.strings.text(.findBestSeatsCta),
            style.strings.text(.holdAndCheckout),
            style.strings.text(.continueToCheckout),
        ]
        let label = seatLayerCheckoutCtaState(
            seatLayerPickerCheckoutCtaInput(presentation: presentation, controller: controller, style: style),
            strings: style.strings
        ).label
        return seatLayerPickerCartBarPlan(
            width: width,
            own: own.map {
                SeatLayerPickerCartBarRuler.widths($0, size: SeatLayerPickerCartBar.buttonFont, weight: weight, category: category)
            },
            label: SeatLayerPickerCartBar.letters.map {
                SeatLayerPickerCartBarRuler.widths(label, size: $0, weight: weight, category: category)
            },
            labelIsOwn: own.contains(label)
        )
    }
}

/// The count and the total, and under them the seats, or the event's date
/// when sales have closed.
public struct SeatLayerPickerCartTotalLine: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swollen = false
    private let room: Double?

    public init() { self.room = nil }

    init(room: Double) { self.room = room }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        let ink = swollen ? palette.accent : palette.text
        let fit = totalFit
        VStack(alignment: .leading, spacing: 1) {
            if fit.beside {
                HStack(spacing: Bar.totalGap) {
                    count(ink)
                    if let money = totalText { total(money, ink: ink, scale: 1) }
                }
            } else {
                count(ink)
                if let money = totalText { total(money, ink: ink, scale: fit.scale) }
            }
            if let under = underLine {
                Text(under)
                    .seatLayerPickerFont(size: Bar.namesFont, weight: .regular)
                    .foregroundColor(palette.mutedText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityIdentifier("seatlayer-cart-seat-line")
            }
        }
        .scaleEffect(swollen ? SeatLayerPickerSheetMetrics.swell : 1, anchor: .leading)
        .animation(seatLayerPickerAnimation(.bump, reduceMotion: reduceMotion), value: swollen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("seatlayer-cart-total-line")
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

    private func count(_ ink: Color) -> some View {
        Text(summary)
            .seatLayerPickerFont(size: SeatLayerPickerCartBar.countFont, weight: .semibold)
            .foregroundColor(ink)
            .lineLimit(presentation.confirmedCartTotals.quantity == 0 && !closed ? 2 : 1)
    }

    private func total(_ money: String, ink: Color, scale: Double) -> some View {
        Text(money)
            .seatLayerPickerFont(size: SeatLayerPickerCartBar.totalFont * scale, weight: .heavy)
            .foregroundColor(ink)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
    }

    /// Whether the count and the total share a line, and the total's scale.
    private var totalFit: (beside: Bool, scale: Double) {
        guard let money = totalText else { return (true, 1) }
        let category = UIContentSizeCategory(min(dynamicTypeSize, seatLayerPickerSheetTypeCeiling))
        let space = room ?? .infinity
        return seatLayerPickerCartBarTotal(
            count: SeatLayerPickerCartBarRuler.width(
                summary, size: SeatLayerPickerCartBar.countFont, weight: .semibold, category: category
            ),
            total: SeatLayerPickerCartBarRuler.width(
                money, size: SeatLayerPickerCartBar.totalFont, weight: .heavy, category: category
            ),
            room: space
        )
    }

    private var closed: Bool { seatLayerPickerSalesClosedWithNoHold(controller.snapshot) }

    private var summary: String {
        if closed { return style.strings.text(.salesClosed) }
        let totals = presentation.confirmedCartTotals
        guard totals.quantity > 0 else { return style.strings.text(.noSeatsSelected) }
        return style.strings.ticketCount(totals.quantity)
    }

    private var totalText: String? {
        if closed { return nil }
        let totals = presentation.confirmedCartTotals
        guard totals.quantity > 0,
              !totals.hasMixedCurrencies,
              let currency = totals.currency else { return nil }
        return seatLayerPickerMoney(totals.total, currency: currency, style: style)
    }

    /// The seats, as the map writes them; with sales closed, the event's date.
    private var underLine: String? {
        if closed {
            return controller.snapshot.flatMap {
                seatLayerPickerEventDateLine($0.event, locale: style.strings.resolvedLocale)
            }
        }
        let line = seatLayerPickerCartSeatsLine(presentation.confirmedCartLines)
        return line.isEmpty ? nil : line
    }
}

/// How the checkout button inside the cart row sets its words: the letter
/// size and the width of its balanced lines. Absent elsewhere.
struct SeatLayerPickerCartBarButtonLayout: Equatable {
    var letters: Double
    var textWidth: Double
}

private struct SeatLayerPickerCartBarButtonKey: EnvironmentKey {
    static let defaultValue: SeatLayerPickerCartBarButtonLayout? = nil
}

extension EnvironmentValues {
    var seatLayerPickerCartBarButton: SeatLayerPickerCartBarButtonLayout? {
        get { self[SeatLayerPickerCartBarButtonKey.self] }
        set { self[SeatLayerPickerCartBarButtonKey.self] = newValue }
    }
}
/// The cart sheet's Dynamic Type ceiling, as `type.scaleClamp.sheet` names it.
var seatLayerPickerSheetTypeCeiling: DynamicTypeSize {
    seatLayerPickerTypeCeiling(SeatLayerPickerTypeScaleTokens.sheet)
}

#endif

/// Sales have closed and the buyer holds nothing: the cart row says so and
/// offers no button. Seats already held can still go to checkout.
func seatLayerPickerSalesClosedWithNoHold(_ snapshot: SeatLayerPickerSnapshot?) -> Bool {
    guard let snapshot else { return false }
    return snapshot.event.salesClosed && !snapshot.hold.active
}

/// The event's date: the page's own `startsAtLabel` where it sent one, else
/// the start in the buyer's locale and the event's time zone.
func seatLayerPickerEventDateLine(
    _ event: SeatLayerPickerEventDetails,
    locale: Locale
) -> String? {
    if let label = event.startsAtLabel { return label }
    guard let startsAt = event.startsAt else { return nil }
    let seconds = startsAt > 10_000_000_000 ? startsAt / 1_000 : startsAt
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.dateStyle = .long
    formatter.timeStyle = .short
    if let timezone = event.timezone, let zone = TimeZone(identifier: timezone) {
        formatter.timeZone = zone
    }
    return formatter.string(from: Date(timeIntervalSince1970: seconds))
}
