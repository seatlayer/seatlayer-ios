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
                title: area.label ?? style.strings.text(.generalAdmission),
                subtitle: style.strings.text(
                    .placesAvailable,
                    replacing: ["count": String(max(0, area.available ?? 0))]
                )
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
                quantityPicker(minimum: 1, maximum: maximum(for: area))
                actionRow(
                    cancelTitle: style.strings.text(.cancel),
                    confirmTitle: style.strings.text(.addTickets),
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

    @ViewBuilder
    private func promptFrame<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: controller.snapshot)
        VStack(alignment: .leading, spacing: 14) {
            Text(title).seatLayerPickerFont(size: 19, weight: .heavy).foregroundColor(palette.text)
            Text(subtitle).seatLayerPickerFont(size: 13, weight: .semibold).foregroundColor(palette.mutedText)
            content()
        }
        .padding(18)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card).stroke(palette.divider) }
        .shadow(color: .black.opacity(0.24), radius: 18, y: 8)
        .frame(maxWidth: SeatLayerPickerSizeTokens.confirmCardMaxWidth)
        .padding(SeatLayerPickerSizeTokens.confirmCardGutter)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("seatlayer-ga-prompt")
    }

    private func quantityPicker(minimum: Int, maximum: Int) -> some View {
        let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: controller.snapshot)
        return HStack(spacing: 16) {
            quantityButton("minus", enabled: quantity > minimum) { quantity -= 1 }
            Text("\(quantity)")
                .seatLayerPickerFont(size: 24, weight: .heavy, design: .rounded)
                .foregroundColor(palette.text)
                .monospacedDigit()
                .frame(minWidth: 64)
            quantityButton("plus", enabled: quantity < maximum) { quantity += 1 }
        }
        .frame(maxWidth: .infinity)
    }

    private func quantityButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
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
    }
}

/// Guest-count decision for a variable-capacity table.
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
           let table = suppliedTable ?? presentation.pendingTable {
            let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: controller.snapshot)
            VStack(alignment: .leading, spacing: 14) {
                Text(table.buyerFacingLabel)
                    .seatLayerPickerFont(size: 19, weight: .heavy)
                    .foregroundColor(palette.text)
                Text(style.strings.text(.chooseGuests))
                    .seatLayerPickerFont(size: 13, weight: .semibold)
                    .foregroundColor(palette.mutedText)
                Stepper(value: $quantity, in: bounds(for: table)) {
                    Text("\(quantity)")
                        .seatLayerPickerFont(size: 22, weight: .heavy, design: .rounded)
                        .foregroundColor(palette.text)
                        .monospacedDigit()
                }
                .frame(minHeight: 44)
                HStack(spacing: 10) {
                    Button(style.strings.text(.removeTable)) {
                        Task { @MainActor in _ = await presentation.cancelTable() }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundColor(palette.text)
                    .background(palette.background)
                    .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
                    Button(style.strings.text(.confirmTable)) {
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
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundColor(palette.onAccent)
                    .background(palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
                    .disabled(busy)
                }
                .seatLayerPickerFont(size: 14, weight: .heavy)
            }
            .padding(18)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card).stroke(palette.divider) }
            .shadow(color: .black.opacity(0.24), radius: 18, y: 8)
            .frame(maxWidth: SeatLayerPickerSizeTokens.confirmCardMaxWidth)
            .padding(SeatLayerPickerSizeTokens.confirmCardGutter)
            .id(table.id)
            .onAppear { quantity = bounds(for: table).lowerBound }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("seatlayer-table-prompt")
        }
    }

    private func bounds(for table: SelectedSeat) -> ClosedRange<Int> {
        let minimum = max(1, table.minOccupancy ?? table.quantity ?? 1)
        let maximum = max(minimum, table.maxOccupancy ?? table.capacity ?? minimum)
        return minimum...maximum
    }
}
#endif
