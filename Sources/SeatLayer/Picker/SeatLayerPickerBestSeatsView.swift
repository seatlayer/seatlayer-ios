#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Best-available selection form for empty and expanded carts.
public struct SeatLayerBestSeatsForm: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var quantity = 2
    @State private var categoryKey: String?
    @State private var zoneId: String?
    @State private var sessionId: String?
    @State private var busy = false

    public init() {}

    public var body: some View {
        if style.options.enableBestAvailable, controller.supports(command: "picker.bestAvailable") {
            let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: controller.snapshot)
            VStack(spacing: 10) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 8) {
                        categoryMenu(palette: palette)
                        zoneMenu(palette: palette)
                    }
                } else {
                    HStack(spacing: 8) {
                        categoryMenu(palette: palette)
                        zoneMenu(palette: palette)
                    }
                }
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 8) {
                        quantityStepper
                        findSeatsButton(palette: palette)
                    }
                } else {
                    HStack(spacing: 8) {
                        quantityStepper
                        findSeatsButton(palette: palette)
                    }
                }
            }
            .onAppear { adoptSession() }
            .onChange(of: controller.snapshot?.sessionId) { _ in adoptSession() }
        }
    }

    private var maximum: Int {
        max(1, controller.snapshot?.maxSelection ?? 10)
    }

    private var enabled: Bool {
        presentation.canUseBestAvailable && !busy
    }

    private func categoryMenu(palette: SeatLayerPickerPalette) -> some View {
        Menu {
            Button(style.strings.text(.anyTicketType)) { categoryKey = nil }
            ForEach(controller.snapshot?.categories.filter { !$0.notForSale } ?? [], id: \.key) { category in
                Button(category.label) { categoryKey = category.key }
            }
        } label: {
            pickerMenuLabel(categoryLabel, palette: palette)
        }
        .disabled(!enabled)
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func zoneMenu(palette: SeatLayerPickerPalette) -> some View {
        Menu {
            Button(style.strings.text(.anyVenueZone)) { zoneId = nil }
            ForEach(controller.snapshot?.bestAvailableZones ?? [], id: \.id) { zone in
                Button(zone.label) { zoneId = zone.id }
            }
        } label: {
            pickerMenuLabel(zoneLabel, palette: palette)
        }
        .disabled(!enabled)
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private var quantityStepper: some View {
        Stepper(value: $quantity, in: 1...maximum) {
            Text("\(quantity)").monospacedDigit()
        }
        .disabled(!enabled)
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func findSeatsButton(palette: SeatLayerPickerPalette) -> some View {
        Button {
            busy = true
            runPickerAction(controller) {
                defer { busy = false }
                _ = try await controller.bestAvailable(
                    quantity: quantity,
                    categoryKey: categoryKey,
                    zoneId: zoneId,
                    ttlMs: style.options.normalizedHoldTtlMs
                )
            }
        } label: {
            HStack(spacing: 7) {
                if busy { ProgressView().tint(palette.onAccent) }
                Image(systemName: "sparkles")
                Text(style.strings.findBestSeats(quantity))
                    .lineLimit(2)
            }
            .seatLayerPickerFont(size: 14, weight: .heavy)
            .foregroundColor(palette.onAccent)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(palette.accent)
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
        }
        .buttonStyle(.plain)
        .disabled(!enabled || quantity < 1)
    }

    private var categoryLabel: String {
        controller.snapshot?.categories.first { $0.key == categoryKey }?.label
            ?? style.strings.text(.anyTicketType)
    }

    private var zoneLabel: String {
        controller.snapshot?.bestAvailableZones.first { $0.id == zoneId }?.label
            ?? style.strings.text(.anyVenueZone)
    }

    private func pickerMenuLabel(
        _ text: String,
        palette: SeatLayerPickerPalette
    ) -> some View {
        HStack(spacing: 5) {
            Text(text).lineLimit(1)
            Image(systemName: "chevron.down")
                .seatLayerPickerFont(size: 10, weight: .bold)
        }
        .seatLayerPickerFont(size: 13, weight: .semibold)
        .foregroundColor(enabled ? palette.text : palette.mutedText)
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, 10)
        .background(palette.background)
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
    }

    private func adoptSession() {
        guard sessionId != controller.snapshot?.sessionId else { return }
        sessionId = controller.snapshot?.sessionId
        quantity = min(2, maximum)
        let filter = controller.snapshot?.map.categoryFilter ?? []
        categoryKey = filter.count == 1
            && controller.snapshot?.categories.contains { $0.key == filter[0] } == true
            ? filter[0]
            : nil
        let focusedZone = controller.snapshot?.map.focusedSection?.zoneId
        zoneId = controller.snapshot?.bestAvailableZones.contains { $0.id == focusedZone } == true
            ? focusedZone
            : nil
    }
}
#endif
