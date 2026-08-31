#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public enum SeatLayerPickerConfirmationAction: Sendable, Equatable {
    case confirm
    case cancel
    case seatView
    case venue3D
}

/// Compact mutually-exclusive ticket choices used by reserved-seat and
/// general-admission decisions. Choosing a row updates native price state;
/// the owning prompt decides when to send the runtime mutation.
public struct SeatLayerPickerTicketTierChoices: View {
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let tiers: [CategoryTier]
    private let fallbackCurrency: String
    private let enabled: Bool
    @Binding private var selection: String?

    public init(
        tiers: [CategoryTier],
        fallbackCurrency: String,
        selection: Binding<String?>,
        enabled: Bool = true
    ) {
        self.tiers = tiers
        self.fallbackCurrency = fallbackCurrency
        self.enabled = enabled
        _selection = selection
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: nil
        )
        VStack(spacing: 7) {
            ForEach(tiers, id: \.id) { tier in
                let selected = selection == tier.id
                let guidance = SeatLayerPickerTiering.guidance(
                    for: tier,
                    companionFallback: style.strings.text(.tierCompanionGuidance)
                )
                let quote = SeatLayerPickerTiering.quote(
                    for: tier,
                    fallbackCurrency: fallbackCurrency
                )
                Button {
                    selection = tier.id
                } label: {
                    tierLabel(
                        tier,
                        selected: selected,
                        guidance: guidance,
                        quote: quote,
                        palette: palette
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(selected ? palette.accent.opacity(0.10) : Color.clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button)
                            .stroke(
                                selected ? palette.accent : palette.divider,
                                lineWidth: selected ? 1.5 : 1
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: tier, guidance: guidance))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("seatlayer-tier-\(tier.id)")
            }
        }
        .onAppear(perform: normalizeSelection)
        .onChange(of: tierSignature) { _ in normalizeSelection() }
    }

    @ViewBuilder
    private func tierLabel(
        _ tier: CategoryTier,
        selected: Bool,
        guidance: String?,
        quote: SeatLayerPickerTierQuote?,
        palette: SeatLayerPickerPalette
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    tierSelectionImage(selected: selected, palette: palette)
                    Text(tier.name)
                        .seatLayerPickerFont(size: 14, weight: .heavy)
                        .foregroundColor(palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let guidance {
                    Text(guidance)
                        .seatLayerPickerFont(size: 11, weight: .semibold)
                        .foregroundColor(palette.mutedText)
                        .multilineTextAlignment(.leading)
                }
                if let quote {
                    tierPrice(quote, palette: palette)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        } else {
            HStack(spacing: 10) {
                tierSelectionImage(selected: selected, palette: palette)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.name)
                        .seatLayerPickerFont(size: 14, weight: .heavy)
                        .foregroundColor(palette.text)
                    if let guidance {
                        Text(guidance)
                            .seatLayerPickerFont(size: 11, weight: .semibold)
                            .foregroundColor(palette.mutedText)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                if let quote { tierPrice(quote, palette: palette) }
            }
        }
    }

    private func tierSelectionImage(
        selected: Bool,
        palette: SeatLayerPickerPalette
    ) -> some View {
        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
            .font(.system(
                size: dynamicTypeSize.isAccessibilitySize ? 24 : 18,
                weight: .semibold
            ))
            .foregroundColor(selected ? palette.accent : palette.mutedText)
    }

    private func tierPrice(
        _ quote: SeatLayerPickerTierQuote,
        palette: SeatLayerPickerPalette
    ) -> some View {
        Text(seatLayerPickerMoney(
            quote.amount,
            currency: quote.currency ?? fallbackCurrency,
            style: style
        ))
        .seatLayerPickerFont(size: 13, weight: .heavy)
        .foregroundColor(palette.text)
    }

    private var tierSignature: String { tiers.map(\.id).joined(separator: "\u{1f}") }

    private func normalizeSelection() {
        guard !tiers.isEmpty,
              !tiers.contains(where: { $0.id == selection }) else { return }
        selection = tiers[0].id
    }

    private func accessibilityLabel(for tier: CategoryTier, guidance: String?) -> String {
        let quote = SeatLayerPickerTiering.quote(
            for: tier,
            fallbackCurrency: fallbackCurrency
        )
        return [
            tier.name,
            quote.map {
                seatLayerPickerMoney(
                    $0.amount,
                    currency: $0.currency ?? fallbackCurrency,
                    style: style
                )
            },
            guidance,
        ].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Native confirmation card for the latest unanswered reserved seat.
public struct SeatLayerPickerSeatConfirmation: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    private let onAction: ((SeatLayerPickerConfirmationAction, SelectedSeat) -> Void)?

    public init(
        onAction: ((SeatLayerPickerConfirmationAction, SelectedSeat) -> Void)? = nil
    ) {
        self.onAction = onAction
    }

    public var body: some View {
        if let seat = presentation.pendingSeat {
            SeatLayerPickerConfirmationCard(seat: seat, onAction: onAction)
                .id("\(seat.id):\(seat.label)")
        }
    }
}

private struct SeatLayerPickerConfirmationCard: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let seat: SelectedSeat
    let onAction: ((SeatLayerPickerConfirmationAction, SelectedSeat) -> Void)?
    @State private var localBusy = false

    init(
        seat: SelectedSeat,
        onAction: ((SeatLayerPickerConfirmationAction, SelectedSeat) -> Void)?
    ) {
        self.seat = seat
        self.onAction = onAction
    }

    var body: some View {
        let snapshot = controller.snapshot
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: snapshot
        )
        let category = snapshot?.categories.first { $0.key == seat.categoryKey }
        let categoryColor = Color(
            uiColor: UIColor(slHex: category?.color ?? "") ?? .systemIndigo
        )

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                confirmationContent(
                    palette: palette,
                    categoryColor: categoryColor,
                    categoryLabel: category?.label
                        ?? seat.categoryKey
                        ?? style.strings.text(.ticket),
                    fallbackCurrency: snapshot?.currency ?? "USD"
                )
                .frame(maxHeight: .infinity)
            } else {
                confirmationContent(
                    palette: palette,
                    categoryColor: categoryColor,
                    categoryLabel: category?.label
                        ?? seat.categoryKey
                        ?? style.strings.text(.ticket),
                    fallbackCurrency: snapshot?.currency ?? "USD"
                )
            }
        }
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card, style: .continuous)
                .stroke(palette.divider, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.26), radius: 18, y: 8)
        .frame(maxWidth: SeatLayerPickerSizeTokens.confirmCardMaxWidth)
        .padding(SeatLayerPickerSizeTokens.confirmCardGutter)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("seatlayer-confirmation")
    }

    private func confirmationContent(
        palette: SeatLayerPickerPalette,
        categoryColor: Color,
        categoryLabel: String,
        fallbackCurrency: String
    ) -> some View {
        VStack(spacing: 0) {
            identityRow(palette: palette)
            HStack(spacing: 10) {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 13, height: 13)
                    .overlay { Circle().stroke(palette.text.opacity(0.28), lineWidth: 1) }
                Text(categoryLabel)
                    .seatLayerPickerFont(size: 15, weight: .heavy)
                    .foregroundColor(palette.text)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                Spacer()
                if let quote = selectedQuote {
                    Text(seatLayerPickerMoney(
                        quote.amount,
                        currency: quote.currency ?? fallbackCurrency,
                        style: style
                    ))
                    .seatLayerPickerFont(size: 18, weight: .heavy)
                    .foregroundColor(palette.text)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(categoryColor.opacity(0.10))
            .overlay(alignment: .top) { Rectangle().fill(palette.divider).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(palette.divider).frame(height: 1) }

            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: true) {
                    confirmationDetails(palette: palette, fallbackCurrency: fallbackCurrency)
                        .padding(16)
                }
                confirmationActions(palette: palette)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .padding(.top, 8)
                    .background(palette.surface)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    confirmationDetails(palette: palette, fallbackCurrency: fallbackCurrency)
                    confirmationActions(palette: palette)
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private func confirmationDetails(
        palette: SeatLayerPickerPalette,
        fallbackCurrency: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let tiers = seat.tiers, tiers.count > 1 {
                Text(style.strings.text(.ticketType))
                    .seatLayerPickerFont(size: 12, weight: .bold)
                    .foregroundColor(palette.mutedText)
                SeatLayerPickerTicketTierChoices(
                    tiers: tiers,
                    fallbackCurrency: seat.currency ?? fallbackCurrency,
                    selection: tierSelection,
                    enabled: !localBusy && !presentation.actionInFlight
                )
            } else if let tier = seat.tiers?.first,
                      let guidance = SeatLayerPickerTiering.guidance(
                          for: tier,
                          companionFallback: style.strings.text(.tierCompanionGuidance)
                      ) {
                Text(guidance)
                    .seatLayerPickerFont(size: 12, weight: .semibold)
                    .foregroundColor(palette.mutedText)
            }

            if seat.commercial?.restrictedView == true || seat.commercial?.obstructedView == true {
                notice(
                    symbol: "eye.slash.fill",
                    title: style.strings.text(.viewInformation),
                    message: seat.commercial?.note ?? style.strings.text(.limitedViewNotice),
                    color: palette.warning,
                    palette: palette
                )
            }
            if seat.wheelchairSpaceType != nil ||
                seat.accessibility?.contains(where: { $0.lowercased().contains("wheelchair") }) == true {
                notice(
                    symbol: "figure.roll",
                    title: style.strings.text(.accessiblePlace),
                    message: seat.wheelchairSpaceType == "no-seat"
                        ? style.strings.text(.wheelchairSpaceNoFixedChair)
                        : style.strings.text(.wheelchairAccessibleSeating),
                    color: palette.accent,
                    palette: palette
                )
            }

            inspectionActions(palette: palette)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func confirmationActions(palette: SeatLayerPickerPalette) -> some View {
        HStack(spacing: 0) {
            Button {
                Task { @MainActor in
                    localBusy = true
                    let cancelled = await presentation.cancelPending()
                    localBusy = false
                    if cancelled { onAction?(.cancel, seat) }
                }
            } label: {
                Text(style.strings.text(.cancel))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .foregroundColor(palette.text)
            .background(palette.background)
            .disabled(localBusy || presentation.actionInFlight)
            .accessibilityLabel(style.strings.text(.cancel))
            .accessibilityIdentifier("seatlayer-confirm-cancel")

            Button {
                Task { @MainActor in await confirm() }
            } label: {
                HStack(spacing: 7) {
                    if localBusy { ProgressView().tint(palette.onAccent) }
                    Image(systemName: "checkmark")
                    Text(style.strings.text(.select))
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .foregroundColor(palette.onAccent)
            .background(palette.accent)
            .disabled(localBusy || presentation.actionInFlight)
            .accessibilityLabel(style.strings.text(.select))
            .accessibilityIdentifier("seatlayer-confirm-select")
        }
        .seatLayerPickerFont(size: 14, weight: .heavy)
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
    }

    private var selectedQuote: SeatLayerPickerTierQuote? {
        SeatLayerPickerTiering.quote(
            for: seat,
            preferred: presentation.pendingTierId,
            fallbackCurrency: controller.snapshot?.currency
        )
    }

    private var tierSelection: Binding<String?> {
        Binding(
            get: { presentation.pendingTierId },
            set: { presentation.choosePendingTier($0) }
        )
    }

    @ViewBuilder
    private func identityRow(palette: SeatLayerPickerPalette) -> some View {
        let values: [(String, String)] = [
            (style.strings.text(.section), seat.sectionLabel ?? ""),
            (seat.displayType ?? seat.rowType ?? style.strings.text(.row), seat.rowLabel ?? ""),
            (
                seat.objectType?.rawValue == "booth"
                    ? style.strings.text(.place)
                    : style.strings.text(.seat),
                seat.seatNumber ?? seat.buyerFacingLabel
            ),
        ].filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(value.0.uppercased())
                            .seatLayerPickerFont(size: 9, weight: .bold)
                            .foregroundColor(palette.mutedText)
                        Spacer(minLength: 8)
                        Text(value.1)
                            .seatLayerPickerFont(size: 14, weight: .heavy)
                            .foregroundColor(palette.text)
                            .multilineTextAlignment(.trailing)
                    }
                    .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                    if index != values.count - 1 {
                        Rectangle().fill(palette.divider).frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 16)
        } else {
            HStack(spacing: 0) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 2) {
                        Text(value.0.uppercased())
                            .seatLayerPickerFont(size: 9, weight: .bold)
                            .foregroundColor(palette.mutedText)
                        Text(value.1)
                            .seatLayerPickerFont(size: 14, weight: .heavy)
                            .foregroundColor(palette.text)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: SeatLayerPickerSizeTokens.confirmIdentityHeight)
                    if index != values.count - 1 {
                        Rectangle()
                            .fill(palette.divider)
                            .frame(
                                width: 1,
                                height: SeatLayerPickerSizeTokens.confirmIdentityHeight
                            )
                    }
                }
            }
            .frame(minHeight: SeatLayerPickerSizeTokens.confirmIdentityHeight)
        }
    }

    @ViewBuilder
    private func inspectionActions(palette: SeatLayerPickerPalette) -> some View {
        let canSeatView = style.options.enableSeatView
            && controller.supportsSeatView
            && controller.snapshot?.capabilities.contains("seatView") == true
        let canVenue3D = style.options.enable3D
            && controller.supportsVenue3D
            && controller.snapshot?.capabilities.contains("venue3d") == true
        if canSeatView || canVenue3D {
            HStack(spacing: 8) {
                if canSeatView {
                    inspectionButton(
                        title: style.strings.text(.viewFromHere),
                        symbol: "binoculars.fill",
                        palette: palette
                    ) {
                        _ = try await controller.openSeatView(seat.id)
                        presentation.recordSeatViewOpened(seat)
                        onAction?(.seatView, seat)
                    }
                }
                if canVenue3D {
                    inspectionButton(
                        title: style.strings.text(.venue3D),
                        symbol: "cube.transparent",
                        palette: palette
                    ) {
                        _ = try await controller.setBuyerView("venue3d", flyToSeatId: seat.id)
                        presentation.recordSeatViewOpened(seat)
                        onAction?(.venue3D, seat)
                    }
                }
            }
        }
    }

    private func inspectionButton(
        title: String,
        symbol: String,
        palette: SeatLayerPickerPalette,
        action: @escaping @MainActor () async throws -> Void
    ) -> some View {
        Button {
            localBusy = true
            Task { @MainActor in
                defer { localBusy = false }
                do { try await action() }
                catch let error as SeatLayerError { controller.record(error) }
                catch { controller.record(.transport(error.localizedDescription)) }
            }
        } label: {
            Label(title, systemImage: symbol)
                .seatLayerPickerFont(size: 12, weight: .bold)
                .frame(
                    maxWidth: .infinity,
                    minHeight: SeatLayerPickerSizeTokens.minimumHitTarget
                )
                .background(palette.background)
                .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
        }
        .buttonStyle(.plain)
        .foregroundColor(palette.text)
        .disabled(localBusy)
    }

    private func notice(
        symbol: String,
        title: String,
        message: String,
        color: Color,
        palette: SeatLayerPickerPalette
    ) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol).foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).seatLayerPickerFont(size: 12, weight: .bold)
                Text(message).seatLayerPickerFont(size: 12).foregroundColor(palette.mutedText)
            }
            Spacer(minLength: 0)
        }
        .foregroundColor(palette.text)
        .padding(10)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
    }

    @MainActor
    private func confirm() async {
        localBusy = true
        defer { localBusy = false }
        let tierId = presentation.pendingTierId
        guard await presentation.confirmPending(tierId: tierId) else { return }
        var confirmed = seat
        let quote = SeatLayerPickerTiering.quote(
            for: seat,
            preferred: tierId,
            fallbackCurrency: controller.snapshot?.currency
        )
        confirmed.tierId = quote?.tierId
        confirmed.price = quote?.amount ?? confirmed.price
        confirmed.currency = quote?.currency ?? confirmed.currency
        onAction?(.confirm, confirmed)
    }
}

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

public struct SeatLayerPickerCartList: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(denseRuns, id: \.id) { run in
                        if run.isGroup {
                            SeatLayerPickerCartRunView(run: run)
                        } else if let line = run.members.first?.item {
                            SeatLayerPickerCartLineView(line: line)
                        }
                    }
                }
            }
            if presentation.removalUndo != nil {
                SeatLayerPickerCartUndoView()
            }
        }
        .background(resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        ).surface)
    }

    private var denseRuns: [SeatLayerPickerDenseRun] {
        let lines = presentation.confirmedCartLines.map { line in
            let category = controller.snapshot?.categories.first { $0.key == line.categoryKey }
            return SeatLayerPickerProjections.denseLine(
                line,
                selection: controller.snapshot?.selection ?? [],
                display: .init(
                    categoryLabel: line.tierName ?? category?.label,
                    amountText: seatLayerPickerMoney(
                        line.total,
                        currency: line.currency,
                        style: style
                    )
                ),
                held: controller.snapshot?.hold.active == true
            )
        }
        return SeatLayerPickerProjections.denseRuns(lines)
    }
}

private struct SeatLayerPickerCartRunView: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var expanded = false
    let run: SeatLayerPickerDenseRun

    var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        VStack(spacing: 0) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        expandButton(palette: palette)
                        HStack(spacing: 8) {
                            runAmount(palette: palette)
                            Spacer(minLength: 4)
                            removeButton(palette: palette)
                        }
                    }
                } else {
                    HStack(spacing: 9) {
                        expandButton(palette: palette)
                        Spacer(minLength: 4)
                        runAmount(palette: palette)
                        removeButton(palette: palette)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 4 : 0)
            .frame(minHeight: SeatLayerPickerSizeTokens.denseLineHeight)
            .overlay(alignment: .bottom) {
                Rectangle().fill(palette.divider).frame(height: 1).padding(.leading, 30)
            }
            if expanded {
                ForEach(orderedMembers, id: \.item.lineKey) { line in
                    SeatLayerPickerCartLineView(line: line.item)
                }
            }
        }
    }

    private var orderedMembers: [SeatLayerPickerDenseLine] {
        SeatLayerPickerProjections.membersInSeatOrder(run)
    }

    private func expandButton(palette: SeatLayerPickerPalette) -> some View {
        Button { expanded.toggle() } label: {
            HStack(spacing: 7) {
                Image(systemName: "chevron.right")
                    .seatLayerPickerFont(size: 11, weight: .bold)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                VStack(alignment: .leading, spacing: 2) {
                    Text(runHeading)
                        .seatLayerPickerFont(size: 13, weight: .semibold)
                        .foregroundColor(palette.text)
                    Text(runSummary)
                        .seatLayerPickerFont(size: 10, weight: .medium)
                        .foregroundColor(palette.mutedText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: SeatLayerPickerSizeTokens.minimumHitTarget, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundColor(palette.mutedText)
        .accessibilityLabel([runHeading, runSummary].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityValue(expanded ? style.strings.text(.showLess) : style.strings.text(.moreTickets))
    }

    private func runAmount(palette: SeatLayerPickerPalette) -> some View {
        Text(seatLayerPickerMoney(
            run.total,
            currency: run.members.first?.item.currency ?? controller.snapshot?.currency ?? "USD",
            style: style
        ))
        .seatLayerPickerFont(size: 12, weight: .bold)
        .foregroundColor(palette.text)
    }

    @ViewBuilder
    private func removeButton(palette: SeatLayerPickerPalette) -> some View {
        if presentation.canMutateCart, let first = orderedMembers.first {
            Button {
                runPickerAction(controller) {
                    try await presentation.removeCartLine(first.item.label)
                }
            } label: {
                Image(systemName: "xmark")
                    .seatLayerPickerFont(size: 12, weight: .bold)
                    .frame(
                        width: SeatLayerPickerSizeTokens.minimumHitTarget,
                        height: SeatLayerPickerSizeTokens.minimumHitTarget
                    )
            }
            .buttonStyle(.plain)
            .foregroundColor(palette.mutedText)
            .accessibilityLabel(style.strings.text(.removeSeat))
        }
    }

    private var runHeading: String {
        [run.members.first?.section, run.members.first?.rowLabel]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var runSummary: String {
        [
            style.strings.ticketCount(run.quantity),
            run.seatsLabel,
            run.members.first?.categoryLabel ?? "",
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }
}

private struct SeatLayerPickerCartUndoView: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        HStack(spacing: 10) {
            Text(style.strings.text(.seatRemoved))
                .seatLayerPickerFont(size: 13, weight: .semibold)
                .foregroundColor(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(style.strings.text(.undo)) {
                runPickerAction(controller) { _ = try await presentation.undoRemoval() }
            }
            .seatLayerPickerFont(size: 13, weight: .bold)
            .foregroundColor(palette.accent)
            .frame(minWidth: SeatLayerPickerSizeTokens.minimumHitTarget)
            .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
            .disabled(!presentation.canUndoRemoval)
        }
        .padding(.horizontal, 12)
        .background(palette.surface)
        .overlay(alignment: .top) { Rectangle().fill(palette.divider).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("seatlayer-cart-undo")
    }
}

private struct SeatLayerPickerCartLineView: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let line: SeatLayerPickerCartLine

    var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    identity(palette: palette)
                    HStack(spacing: 6) {
                        tableQuantityControls(palette: palette)
                        Spacer(minLength: 4)
                        amount(palette: palette)
                        removeButton(palette: palette)
                    }
                }
            } else {
                HStack(spacing: 9) {
                    identity(palette: palette)
                    Spacer(minLength: 4)
                    tableQuantityControls(palette: palette)
                    amount(palette: palette)
                    removeButton(palette: palette)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 4 : 0)
        .frame(minHeight: SeatLayerPickerSizeTokens.denseLineHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.divider).frame(height: 1).padding(.leading, 30)
        }
    }

    private func identity(palette: SeatLayerPickerPalette) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(categoryColor(fallback: palette.accent))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(line.displayLabel ?? line.label)
                    .seatLayerPickerFont(size: 13, weight: .semibold)
                    .foregroundColor(palette.text)
                let detail = [ticketTypeLabel, line.sectionLabel, line.rowLabel, line.seatNumber]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail)
                        .seatLayerPickerFont(size: 10, weight: .medium)
                        .foregroundColor(palette.mutedText)
                }
            }
        }
    }

    @ViewBuilder
    private func tableQuantityControls(palette: SeatLayerPickerPalette) -> some View {
        if line.objectType == "table" {
            if presentation.canMutateCart {
                quantityButton("minus", delta: -1, palette: palette)
            }
            Text("\(line.quantity)")
                .seatLayerPickerFont(size: 12, weight: .bold)
                .foregroundColor(palette.text)
                .frame(minWidth: 20)
            if presentation.canMutateCart {
                quantityButton("plus", delta: 1, palette: palette)
            }
        }
    }

    private func amount(palette: SeatLayerPickerPalette) -> some View {
        Text(seatLayerPickerMoney(line.total, currency: line.currency, style: style))
            .seatLayerPickerFont(size: 12, weight: .bold)
            .foregroundColor(palette.text)
    }

    @ViewBuilder
    private func removeButton(palette: SeatLayerPickerPalette) -> some View {
        if presentation.canMutateCart {
            Button {
                runPickerAction(controller) { try await presentation.removeCartLine(line.label) }
            } label: {
                Image(systemName: "xmark")
                    .seatLayerPickerFont(size: 12, weight: .bold)
                    .frame(
                        width: SeatLayerPickerSizeTokens.minimumHitTarget,
                        height: SeatLayerPickerSizeTokens.minimumHitTarget
                    )
            }
            .buttonStyle(.plain)
            .foregroundColor(palette.mutedText)
            .accessibilityLabel(style.strings.text(.removeSeat))
        }
    }

    private func quantityButton(
        _ symbol: String,
        delta: Int,
        palette: SeatLayerPickerPalette
    ) -> some View {
        Button {
            let next = line.quantity + delta
            guard next > 0 else { return }
            runPickerAction(controller) {
                _ = try await presentation.setTableQuantity(label: line.label, quantity: next)
            }
        } label: {
            Image(systemName: symbol)
                .seatLayerPickerFont(size: 10, weight: .bold)
                .frame(
                    width: SeatLayerPickerSizeTokens.minimumHitTarget,
                    height: SeatLayerPickerSizeTokens.minimumHitTarget
                )
        }
        .buttonStyle(.plain)
        .foregroundColor(palette.text)
        .disabled(line.quantity + delta <= 0 || presentation.actionInFlight)
    }

    private func categoryColor(fallback: Color) -> Color {
        guard let raw = controller.snapshot?.categories
            .first(where: { $0.key == line.categoryKey })?.color,
              let color = UIColor(slHex: raw) else { return fallback }
        return Color(uiColor: color)
    }

    private var ticketTypeLabel: String? {
        line.tierName ?? controller.snapshot?.categories
            .first(where: { $0.key == line.categoryKey })?.label
    }
}

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

/// iOS 15-compatible top-corner shape used by the bottom ticket panel.
private struct UnevenRoundedRectangleCompat: Shape {
    let topLeading: CGFloat
    let topTrailing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeading))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topLeading, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topTrailing, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + topTrailing),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
#endif
