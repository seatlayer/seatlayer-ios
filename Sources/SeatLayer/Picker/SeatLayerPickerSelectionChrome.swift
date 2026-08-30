#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public enum SeatLayerPickerConfirmationAction: Sendable, Equatable {
    case confirm
    case cancel
    case seatView
    case venue3D
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
    let seat: SelectedSeat
    let onAction: ((SeatLayerPickerConfirmationAction, SelectedSeat) -> Void)?
    @State private var tierId: String?
    @State private var localBusy = false

    init(
        seat: SelectedSeat,
        onAction: ((SeatLayerPickerConfirmationAction, SelectedSeat) -> Void)?
    ) {
        self.seat = seat
        self.onAction = onAction
        _tierId = State(initialValue: seat.tierId ?? seat.tiers?.first?.id)
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
            uiColor: UIColor(slHex: category?.color ?? "") ?? UIColor(slHex: "#5B4B8A")!
        )

        VStack(spacing: 0) {
            identityRow(palette: palette)
            HStack(spacing: 10) {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 13, height: 13)
                    .overlay { Circle().stroke(palette.text.opacity(0.28), lineWidth: 1) }
                Text(category?.label ?? seat.categoryKey ?? style.strings.text(.ticket))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(palette.text)
                    .lineLimit(1)
                Spacer()
                if let amount = selectedPrice {
                    Text(seatLayerMoney(amount, currency: seat.currency ?? snapshot?.currency ?? "USD"))
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(palette.text)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(categoryColor.opacity(0.10))
            .overlay(alignment: .top) { Rectangle().fill(palette.divider).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(palette.divider).frame(height: 1) }

            VStack(alignment: .leading, spacing: 12) {
                if let tiers = seat.tiers, tiers.count > 1 {
                    Text(style.strings.text(.ticketType))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(palette.mutedText)
                    Picker(style.strings.text(.selectTicketTier), selection: $tierId) {
                        ForEach(tiers, id: \.id) { tier in
                            Text("\(tier.name) · \(seatLayerMoney(tier.price, currency: seat.currency ?? snapshot?.currency ?? "USD"))")
                                .tag(Optional(tier.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(palette.accent)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 10)
                    .background(palette.background)
                    .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
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
                .font(.system(size: 14, weight: .heavy))
                .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
            }
            .padding(16)
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

    private var selectedPrice: Double? {
        if let tierId,
           let tier = seat.tiers?.first(where: { $0.id == tierId }) { return tier.price }
        return seat.price
    }

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

        return HStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 2) {
                    Text(value.0.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(palette.mutedText)
                    Text(value.1)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(palette.text)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: SeatLayerPickerSizeTokens.confirmIdentityHeight)
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
        .frame(height: SeatLayerPickerSizeTokens.confirmIdentityHeight)
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
                        presentation.confirmPending()
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
                        presentation.confirmPending()
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
                .font(.system(size: 12, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 42)
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
                Text(title).font(.system(size: 12, weight: .bold))
                Text(message).font(.system(size: 12)).foregroundColor(palette.mutedText)
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
        do {
            if let tierId, tierId != seat.tierId {
                _ = try await controller.setSeatTier(seatId: seat.id, tierId: tierId)
            }
            presentation.confirmPending()
            onAction?(.confirm, seat)
        } catch let error as SeatLayerError {
            controller.record(error)
        } catch {
            controller.record(.transport(error.localizedDescription))
        }
    }
}

/// Phone ticket panel. Its collapsed and expanded states read only confirmed
/// cart projections so an unanswered seat never appears committed.
public struct SeatLayerPickerCartSheet: View {
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
            SeatLayerPickerCartPeek(onCheckout: onCheckout)
            if presentation.cartSheetExpanded {
                if presentation.confirmedCartLines.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "ticket")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(palette.mutedText)
                        Text(style.strings.text(.emptyTrayHint))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(palette.mutedText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: SeatLayerPickerSizeTokens.emptyTrayMaxHeight)
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
            UIAccessibility.isReduceMotionEnabled ? nil : .easeOut(duration: 0.30),
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
                        .font(.system(size: 13, weight: .heavy))
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
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(palette.mutedText)
                        .rotationEffect(.degrees(presentation.cartSheetExpanded ? 180 : 0))
                        .frame(width: 32, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
            .padding(.leading, 14)
            .padding(.trailing, 4)
            .padding(.top, 6)
            .accessibilityElement(children: .contain)
        }
        .frame(height: SeatLayerPickerSizeTokens.peekHeight)
    }

    private var summary: String {
        if presentation.confirmedCartLines.isEmpty {
            let cheapest = controller.snapshot?.categories
                .filter { !$0.notForSale }
                .map(\.priceMin)
                .min()
            guard let cheapest else { return style.strings.text(.chooseTickets) }
            return style.strings.fromPrice(
                seatLayerMoney(cheapest, currency: controller.snapshot?.currency ?? "USD")
            )
        }
        if presentation.cartSheetExpanded {
            return style.strings.ticketCount(presentation.confirmedTicketCount)
        }
        return "\(style.strings.ticketCount(presentation.confirmedTicketCount)) · \(seatLayerMoney(presentation.confirmedCartTotal, currency: controller.snapshot?.currency ?? "USD"))"
    }

    private func compactContinue(palette: SeatLayerPickerPalette) -> some View {
        Button {
            beginCheckout()
        } label: {
            Text(style.strings.continueWithTotal(
                seatLayerMoney(
                    presentation.confirmedCartTotal,
                    currency: controller.snapshot?.currency ?? "USD"
                )
            ))
            .font(.system(size: 13, weight: .heavy))
            .foregroundColor(palette.onAccent)
            .padding(.horizontal, 12)
            .frame(height: 34)
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
}

public struct SeatLayerPickerCartList: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
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
                    categoryLabel: category?.label,
                    amountText: seatLayerMoney(line.total, currency: line.currency)
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
    let run: SeatLayerPickerDenseRun

    var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        let ordered = SeatLayerPickerProjections.membersInSeatOrder(run)
        HStack(spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(run.members.first?.section ?? "") · \(run.members.first?.rowLabel ?? "")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(palette.text)
                    .lineLimit(1)
                Text("\(style.strings.ticketCount(run.quantity)) · \(run.seatsLabel)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(palette.mutedText)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(seatLayerMoney(
                run.total,
                currency: run.members.first?.item.currency ?? controller.snapshot?.currency ?? "USD"
            ))
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(palette.text)
            Button {
                let labels = ordered.compactMap(\.identity.removalLabel)
                runPickerAction(controller) { _ = try await controller.deselectObjects(labels) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 36, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundColor(palette.mutedText)
            .disabled(presentation.actionInFlight)
            .accessibilityLabel(style.strings.text(.removeSeat))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: SeatLayerPickerSizeTokens.denseLineHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.divider).frame(height: 1).padding(.leading, 30)
        }
    }
}

private struct SeatLayerPickerCartLineView: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    let line: SeatLayerPickerCartLine

    var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        HStack(spacing: 9) {
            Circle()
                .fill(categoryColor(fallback: palette.accent))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(line.displayLabel ?? line.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(palette.text)
                    .lineLimit(1)
                let detail = [line.sectionLabel, line.rowLabel, line.seatNumber]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(palette.mutedText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if line.objectType == "table" {
                quantityButton("minus", delta: -1, palette: palette)
                Text("\(line.quantity)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(palette.text)
                    .frame(minWidth: 20)
                quantityButton("plus", delta: 1, palette: palette)
            }
            Text(seatLayerMoney(line.total, currency: line.currency))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(palette.text)
            Button {
                runPickerAction(controller) { _ = try await controller.removeCartLine(label: line.label) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 36, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundColor(palette.mutedText)
            .disabled(presentation.actionInFlight)
            .accessibilityLabel(style.strings.text(.removeSeat))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: SeatLayerPickerSizeTokens.denseLineHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.divider).frame(height: 1).padding(.leading, 30)
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
                _ = try await controller.setTableQuantity(label: line.label, quantity: next)
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 28, height: 36)
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
                Text(style.strings.continueWithTotal(
                    seatLayerMoney(
                        presentation.confirmedCartTotal,
                        currency: controller.snapshot?.currency ?? "USD"
                    )
                ))
            }
            .font(.system(size: 15, weight: .heavy))
            .foregroundColor(palette.onAccent)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(palette.accent)
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
        }
        .buttonStyle(.plain)
        .disabled(!presentation.canCheckout)
        .accessibilityIdentifier("seatlayer-checkout")
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
                Text(error.errorDescription ?? error.code)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    presentation.dismissActionError()
                } label: {
                    Image(systemName: "xmark").frame(width: 32, height: 32)
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
