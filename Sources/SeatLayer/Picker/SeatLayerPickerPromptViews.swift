#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Compact confirmation-card spelling used by the canonical builder matrix.
public struct SeatLayerConfirmCard: View {
    private let onAction: ((SeatLayerPickerConfirmationAction, SelectedSeat) -> Void)?

    public init(
        onAction: ((SeatLayerPickerConfirmationAction, SelectedSeat) -> Void)? = nil
    ) {
        self.onAction = onAction
    }

    public var body: some View {
        SeatLayerPickerSeatConfirmation(onAction: onAction)
    }
}

/// Quantity and optional tier decision for a tapped general-admission area.
public struct SeatLayerPickerGeneralAdmissionPrompt: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let suppliedArea: GAArea?
    @State private var quantity = 1
    @State private var tierId: String?
    @State private var busy = false

    public init(area: GAArea? = nil) {
        suppliedArea = area
    }

    public var body: some View {
        if presentation.canMutateInventory,
           let area = suppliedArea ?? controller.generalAdmissionCandidate {
            promptFrame(
                eyebrow: style.strings.text(.generalAdmission),
                title: area.label ?? style.strings.text(.generalAdmission),
                subtitle: style.strings.text(
                    .placesAvailable,
                    replacing: ["count": String(max(0, area.available ?? 0))]
                ),
                dismiss: { controller.dismissGeneralAdmissionCandidate() }
            ) {
                if let tiers = area.tiers, !tiers.isEmpty {
                    Text(style.strings.text(.ticketType))
                        .seatLayerPickerFont(size: 12, weight: .bold)
                        .foregroundColor(paletteForPrompt.mutedText)
                    ScrollView {
                        SeatLayerPickerTicketTierChoices(
                            tiers: tiers,
                            fallbackCurrency: area.currency
                                ?? controller.snapshot?.currency
                                ?? "USD",
                            selection: $tierId,
                            enabled: !busy
                        )
                    }
                    .frame(maxHeight: Double(SeatLayerPickerSizeTokens.confirmActionHeight * 5))
                }
                quantityPicker(
                    minimum: 1,
                    maximum: maximum(for: area),
                    fewer: style.strings.text(.fewerTickets),
                    more: style.strings.text(.moreTickets)
                )
                totalRow(for: area)
                actionRow(
                    cancelTitle: style.strings.text(.removeWord),
                    confirmTitle: confirmTitle(for: area),
                    confirmEnabled: maximum(for: area) > 0 && tierIsReady(for: area)
                ) {
                    controller.dismissGeneralAdmissionCandidate()
                } confirm: {
                    busy = true
                    Task { @MainActor in
                        defer { busy = false }
                        do {
                            if let selected = selectedTierId(for: area) {
                                _ = try await controller.holdGeneralAdmission(
                                    areaId: area.id,
                                    quantity: quantity,
                                    tierId: .some(selected),
                                    ttlMs: style.options.normalizedHoldTtlMs
                                )
                            } else {
                                _ = try await controller.holdGeneralAdmission(
                                    areaId: area.id,
                                    quantity: quantity,
                                    ttlMs: style.options.normalizedHoldTtlMs
                                )
                            }
                            controller.dismissGeneralAdmissionCandidate()
                        } catch let error as SeatLayerError { controller.record(error) }
                        catch { controller.record(.transport(error.localizedDescription)) }
                    }
                }
            }
            .id(area.id)
        }
    }

    private func maximum(for area: GAArea) -> Int {
        let room = max(0, (controller.snapshot?.maxSelection ?? 10) - (controller.snapshot?.ticketCount ?? 0))
        return max(0, min(area.available ?? room, room))
    }

    private var paletteForPrompt: SeatLayerPickerPalette {
        resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
    }

    private func selectedTierId(for area: GAArea) -> String? {
        let tiers = area.tiers ?? []
        if let tierId, tiers.contains(where: { $0.id == tierId }) { return tierId }
        return tiers.first?.id
    }

    private func tierIsReady(for area: GAArea) -> Bool {
        guard area.tiers?.isEmpty == false else { return true }
        return selectedTierId(for: area) != nil
    }

    /// The area's own price, where the runtime reports one.
    @ViewBuilder
    private func totalRow(for area: GAArea) -> some View {
        if let money = totalMoney(for: area) {
            HStack {
                Text(style.strings.ticketCount(quantity))
                    .foregroundColor(paletteForPrompt.mutedText)
                Spacer(minLength: 0)
                Text(money).foregroundColor(paletteForPrompt.text)
            }
            .seatLayerPickerFont(size: 13, weight: .heavy)
        }
    }

    private func unitPrice(for area: GAArea) -> (Double, String)? {
        if let tierId = selectedTierId(for: area),
           let tier = area.tiers?.first(where: { $0.id == tierId }) {
            return (
                tier.price,
                tier.currency ?? area.currency ?? controller.snapshot?.currency ?? "USD"
            )
        }
        guard let price = area.price else { return nil }
        return (price, area.currency ?? controller.snapshot?.currency ?? "USD")
    }

    private func totalMoney(for area: GAArea) -> String? {
        guard let (price, currency) = unitPrice(for: area) else { return nil }
        return seatLayerPickerMoney(price * Double(quantity), currency: currency, style: style)
    }

    /// The action names the total where one is known, and says what it adds
    /// where it is not.
    private func confirmTitle(for area: GAArea) -> String {
        guard let money = totalMoney(for: area) else {
            return style.strings.text(.addTickets)
        }
        return style.strings.continueWithTotal(money)
    }

    /// A bottom sheet on a phone: rounded top corners, hard against the bottom
    /// edge, with the safe inset absorbed by the action pair.
    @ViewBuilder
    private func promptFrame<Content: View>(
        eyebrow: String,
        title: String,
        subtitle: String,
        dismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: controller.snapshot)
        VStack {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(eyebrow.uppercased(with: style.strings.resolvedLocale))
                            .seatLayerPickerFont(size: 11, weight: .bold)
                            .modifier(SeatLayerPickerLetterSpacing(amount: 0.6))
                            .foregroundColor(palette.mutedText)
                            .lineLimit(1)
                        Text(title)
                            .seatLayerPickerFont(size: 19, weight: .heavy)
                            .foregroundColor(palette.text)
                        Text(subtitle)
                            .seatLayerPickerFont(size: 13, weight: .semibold)
                            .foregroundColor(palette.mutedText)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    Button(action: dismiss) {
                        Image(systemName: "xmark")
                            .seatLayerPickerFont(size: 14, weight: .bold)
                            .foregroundColor(palette.mutedText)
                            .frame(
                                width: SeatLayerPickerSizeTokens.minimumHitTarget,
                                height: SeatLayerPickerSizeTokens.minimumHitTarget
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(style.strings.text(.close))
                }
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface)
            .clipShape(UnevenRoundedRectangleCompat(
                topLeading: SeatLayerPickerRadiusTokens.sheet,
                topTrailing: SeatLayerPickerRadiusTokens.sheet
            ))
            .shadow(color: .black.opacity(0.24), radius: 18, y: -4)
        }
        .frame(maxWidth: SeatLayerPickerSizeTokens.confirmCardMaxWidth)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("seatlayer-ga-prompt")
    }

    private func quantityPicker(
        minimum: Int,
        maximum: Int,
        fewer: String,
        more: String
    ) -> some View {
        let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: controller.snapshot)
        return HStack(spacing: 16) {
            quantityButton("minus", label: fewer, enabled: quantity > minimum) { quantity -= 1 }
            Text("\(quantity)")
                .seatLayerPickerFont(size: 24, weight: .heavy, design: .rounded)
                .foregroundColor(palette.text)
                .monospacedDigit()
                .frame(minWidth: 64)
            quantityButton("plus", label: more, enabled: quantity < maximum) { quantity += 1 }
        }
        .frame(maxWidth: .infinity)
    }

    private func quantityButton(
        _ symbol: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: controller.snapshot)
        return Button(action: action) {
            Image(systemName: symbol)
                .seatLayerPickerFont(size: 15, weight: .bold)
                .foregroundColor(palette.text)
                .frame(width: 44, height: 44)
                .background(palette.background)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled || busy)
        .accessibilityLabel(label)
    }

    private func actionRow(
        cancelTitle: String,
        confirmTitle: String,
        confirmEnabled: Bool,
        cancel: @escaping () -> Void,
        confirm: @escaping () -> Void
    ) -> some View {
        let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: controller.snapshot)
        return HStack(spacing: 10) {
            Button(cancelTitle, action: cancel)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundColor(palette.text)
                .background(palette.background)
                .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
            Button(action: confirm) {
                HStack(spacing: 7) {
                    if busy { ProgressView().tint(palette.onAccent) }
                    Text(confirmTitle)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .foregroundColor(palette.onAccent)
            .background(palette.accent)
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
            .disabled(!confirmEnabled || busy)
        }
        .seatLayerPickerFont(size: 14, weight: .heavy)
        // The action pair owns the bottom edge, so it absorbs the safe inset.
        .padding(.bottom, 4)
    }
}

/// Guest-count decision for a variable-capacity table.
///
/// The same bottom-sheet shape as the general-admission prompt, gated on
/// `table-quantity-v1`: a runtime that cannot carry a guest count is not asked
/// for one, and the prompt is withheld rather than degraded.
public struct SeatLayerPickerTablePrompt: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    private let suppliedTable: SelectedSeat?
    @State private var quantity = 1
    @State private var busy = false

    public init(table: SelectedSeat? = nil) {
        suppliedTable = table
    }

    public var body: some View {
        if presentation.canMutateInventory,
           supportsTableQuantity,
           let table = suppliedTable ?? presentation.pendingTable {
            let palette = resolveSeatLayerPickerPalette(
                style: style,
                colorScheme: colorScheme,
                snapshot: controller.snapshot
            )
            let range = bounds(for: table)
            VStack {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 14) {
                    head(table, palette: palette)
                    summary(table, palette: palette, range: range)
                    Text(style.strings.text(.numberOfGuests))
                        .seatLayerPickerFont(size: 12, weight: .bold)
                        .foregroundColor(palette.mutedText)
                    stepper(range: range, palette: palette)
                    Text(style.strings.text(
                        .chooseMinMaxGuests,
                        replacing: [
                            "min": String(range.lowerBound),
                            "max": String(range.upperBound),
                        ]
                    ))
                    .seatLayerPickerFont(size: 12, weight: .medium)
                    .foregroundColor(palette.mutedText)
                    actions(table, palette: palette)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surface)
                .clipShape(UnevenRoundedRectangleCompat(
                    topLeading: SeatLayerPickerRadiusTokens.sheet,
                    topTrailing: SeatLayerPickerRadiusTokens.sheet
                ))
                .shadow(color: .black.opacity(0.24), radius: 18, y: -4)
            }
            .frame(maxWidth: SeatLayerPickerSizeTokens.confirmCardMaxWidth)
            .id(table.id)
            .onAppear { quantity = min(max(quantity, range.lowerBound), range.upperBound) }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityLabel(style.strings.text(.chooseTableGuests))
            .accessibilityIdentifier("seatlayer-table-prompt")
        }
    }

    @ViewBuilder
    private func head(
        _ table: SelectedSeat,
        palette: SeatLayerPickerPalette
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(style.strings.text(.chooseTableGuests)
                .uppercased(with: style.strings.resolvedLocale))
                .seatLayerPickerFont(size: 11, weight: .bold)
                .modifier(SeatLayerPickerLetterSpacing(amount: 0.6))
                .foregroundColor(palette.mutedText)
                .lineLimit(1)
            Text(table.buyerFacingLabel)
                .seatLayerPickerFont(size: 19, weight: .heavy)
                .foregroundColor(palette.text)
            Text(style.strings.text(.chooseGuestsCopy))
                .seatLayerPickerFont(size: 13, weight: .semibold)
                .foregroundColor(palette.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// What the buyer is choosing for, at a glance.
    @ViewBuilder
    private func summary(
        _ table: SelectedSeat,
        palette: SeatLayerPickerPalette,
        range: ClosedRange<Int>
    ) -> some View {
        HStack(spacing: 0) {
            cell(
                key: style.strings.text(.sectionWord),
                value: table.sectionLabel ?? "—",
                palette: palette
            )
            cell(
                key: style.strings.text(.numberOfGuests),
                value: String(quantity),
                palette: palette
            )
            cell(
                key: style.strings.text(.seatWord),
                value: style.strings.text(
                    SeatLayerPickerPluralKeys.seatsFree,
                    count: range.upperBound
                ),
                palette: palette
            )
        }
        .padding(.vertical, 8)
        .background(palette.background)
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
    }

    private func cell(
        key: String,
        value: String,
        palette: SeatLayerPickerPalette
    ) -> some View {
        VStack(spacing: 2) {
            Text(key)
                .seatLayerPickerFont(size: 10, weight: .semibold)
                .foregroundColor(palette.mutedText)
                .lineLimit(1)
            Text(value)
                .seatLayerPickerFont(size: 14, weight: .heavy)
                .foregroundColor(palette.text)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    /// A wide stepper, not the platform's: the figure is the point of the
    /// prompt and has to be readable from arm's length.
    private func stepper(
        range: ClosedRange<Int>,
        palette: SeatLayerPickerPalette
    ) -> some View {
        HStack(spacing: 16) {
            stepButton(
                "minus",
                label: style.strings.text(.fewerGuests),
                enabled: quantity > range.lowerBound,
                palette: palette
            ) { quantity -= 1 }
            Text("\(quantity)")
                .seatLayerPickerFont(size: 24, weight: .heavy, design: .rounded)
                .foregroundColor(palette.text)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
            stepButton(
                "plus",
                label: style.strings.text(.moreGuests),
                enabled: quantity < range.upperBound,
                palette: palette
            ) { quantity += 1 }
        }
        .frame(minHeight: SeatLayerPickerSizeTokens.bestSeatsStepperWidth)
    }

    private func stepButton(
        _ symbol: String,
        label: String,
        enabled: Bool,
        palette: SeatLayerPickerPalette,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .seatLayerPickerFont(size: 15, weight: .bold)
                .foregroundColor(palette.text)
                .frame(
                    width: SeatLayerPickerSizeTokens.minimumHitTarget,
                    height: SeatLayerPickerSizeTokens.minimumHitTarget
                )
                .background(palette.background)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled || busy)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func actions(
        _ table: SelectedSeat,
        palette: SeatLayerPickerPalette
    ) -> some View {
        HStack(spacing: 10) {
            Button(style.strings.text(.cancel)) {
                Task { @MainActor in _ = await presentation.cancelTable() }
            }
            .frame(maxWidth: .infinity, minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
            .foregroundColor(palette.text)
            .background(palette.background)
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
            Button(style.strings.text(alreadySeated(table) ? .updateTable : .selectTable)) {
                commit(table)
            }
            .frame(maxWidth: .infinity, minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
            .foregroundColor(palette.onAccent)
            .background(palette.accent)
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
            .disabled(busy)
        }
        .seatLayerPickerFont(size: 14, weight: .heavy)
        .padding(.bottom, 4)
    }

    private func commit(_ table: SelectedSeat) {
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                _ = try await presentation.setTableQuantity(
                    label: table.label,
                    quantity: quantity
                )
                presentation.confirmTable(table)
            } catch let error as SeatLayerError { controller.record(error) }
            catch { controller.record(.transport(error.localizedDescription)) }
        }
    }

    /// A table already carrying guests is being changed, not chosen.
    private func alreadySeated(_ table: SelectedSeat) -> Bool {
        (table.quantity ?? 0) > 0
    }

    private var supportsTableQuantity: Bool {
        controller.supports(capability: "table-quantity-v1")
            && controller.supports(command: "picker.setTableQuantity")
    }

    private func bounds(for table: SelectedSeat) -> ClosedRange<Int> {
        let minimum = max(1, table.minOccupancy ?? table.quantity ?? 1)
        let maximum = max(minimum, table.maxOccupancy ?? table.capacity ?? minimum)
        return minimum...maximum
    }
}
#endif
