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
#endif
