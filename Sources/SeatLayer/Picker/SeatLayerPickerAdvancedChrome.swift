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
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    private let suppliedArea: GAArea?
    @State private var quantity = 1
    @State private var tierId: String?
    @State private var busy = false

    public init(area: GAArea? = nil) {
        suppliedArea = area
    }

    public var body: some View {
        if let area = suppliedArea ?? controller.generalAdmissionCandidate {
            promptFrame(
                title: area.label ?? style.strings.text(.generalAdmission),
                subtitle: style.strings.text(
                    .placesAvailable,
                    replacing: ["count": String(max(0, area.available ?? 0))]
                )
            ) {
                if let tiers = area.tiers, !tiers.isEmpty {
                    Picker(
                        style.strings.text(.ticketType),
                        selection: Binding(
                            get: { tierId ?? tiers.first?.id },
                            set: { tierId = $0 }
                        )
                    ) {
                        ForEach(tiers, id: \.id) { tier in
                            Text("\(tier.name) · \(seatLayerMoney(tier.price, currency: area.currency ?? controller.snapshot?.currency ?? "USD"))")
                                .tag(Optional(tier.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                quantityPicker(minimum: 1, maximum: maximum(for: area))
                actionRow(
                    cancelTitle: style.strings.text(.cancel),
                    confirmTitle: style.strings.text(.addTickets),
                    confirmEnabled: maximum(for: area) > 0
                ) {
                    controller.dismissGeneralAdmissionCandidate()
                } confirm: {
                    busy = true
                    Task { @MainActor in
                        defer { busy = false }
                        do {
                            if let selected = tierId ?? area.tiers?.first?.id {
                                _ = try await controller.holdGeneralAdmission(
                                    areaId: area.id,
                                    quantity: quantity,
                                    tierId: .some(selected),
                                    ttlMs: style.options.holdTtlMs
                                )
                            } else {
                                _ = try await controller.holdGeneralAdmission(
                                    areaId: area.id,
                                    quantity: quantity,
                                    ttlMs: style.options.holdTtlMs
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

    @ViewBuilder
    private func promptFrame<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: controller.snapshot)
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 19, weight: .heavy)).foregroundColor(palette.text)
            Text(subtitle).font(.system(size: 13, weight: .semibold)).foregroundColor(palette.mutedText)
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
                .font(.system(size: 24, weight: .heavy, design: .rounded))
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
                .font(.system(size: 15, weight: .bold))
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
        .font(.system(size: 14, weight: .heavy))
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
        if let table = suppliedTable ?? presentation.pendingTable {
            let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: controller.snapshot)
            VStack(alignment: .leading, spacing: 14) {
                Text(table.buyerFacingLabel)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundColor(palette.text)
                Text(style.strings.text(.chooseGuests))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(palette.mutedText)
                Stepper(value: $quantity, in: bounds(for: table)) {
                    Text("\(quantity)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
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
                                _ = try await controller.setTableQuantity(label: table.label, quantity: quantity)
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
                .font(.system(size: 14, weight: .heavy))
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

/// Best-available selection form for empty and expanded carts.
public struct SeatLayerBestSeatsForm: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @State private var quantity = 2
    @State private var categoryKey: String?
    @State private var zoneId: String?
    @State private var busy = false

    public init() {}

    public var body: some View {
        if style.options.enableBestAvailable, controller.supports(command: "picker.bestAvailable") {
            let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: controller.snapshot)
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Stepper(value: $quantity, in: 1...max(1, controller.snapshot?.maxSelection ?? 10)) {
                        Text("\(quantity)").monospacedDigit()
                    }
                    .frame(minHeight: 44)
                    Menu(categoryLabel) {
                        Button(style.strings.text(.anyTicketType)) { categoryKey = nil }
                        ForEach(controller.snapshot?.categories.filter { !$0.notForSale } ?? [], id: \.key) { category in
                            Button(category.label) { categoryKey = category.key }
                        }
                    }
                    .frame(minHeight: 44)
                }
                Button {
                    busy = true
                    runPickerAction(controller) {
                        defer { busy = false }
                        _ = try await controller.bestAvailable(
                            quantity: quantity,
                            categoryKey: categoryKey,
                            zoneId: zoneId,
                            ttlMs: style.options.holdTtlMs
                        )
                    }
                } label: {
                    HStack(spacing: 7) {
                        if busy { ProgressView().tint(palette.onAccent) }
                        Image(systemName: "sparkles")
                        Text(style.strings.text(.bestSeats))
                    }
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(palette.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
                }
                .buttonStyle(.plain)
                .disabled(busy || quantity < 1)
            }
        }
    }

    private var categoryLabel: String {
        controller.snapshot?.categories.first { $0.key == categoryKey }?.label
            ?? style.strings.text(.anyTicketType)
    }
}

/// Adaptive compact floor entry point; the always-visible strip remains a
/// separate public part for layouts that have room.
public struct SeatLayerPickerFloorSelector: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style

    public init() {}

    public var body: some View {
        let floors = controller.snapshot?.map.floors ?? []
        if floors.count > 1 {
            Menu(activeLabel(floors)) {
                if controller.supportsFloorStack {
                    Button(style.strings.text(.allFloors)) {
                        runPickerAction(controller) { _ = try await controller.showAllFloors() }
                    }
                }
                ForEach(floors, id: \.id) { floor in
                    Button(floor.name) {
                        runPickerAction(controller) { _ = try await controller.setFloor(floor.id) }
                    }
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("seatlayer-floor-selector")
        }
    }

    private func activeLabel(_ floors: [SeatLayerPickerFloorInfo]) -> String {
        if controller.snapshot?.map.showsAllFloors == true { return style.strings.text(.allFloors) }
        return floors.first { $0.id == controller.snapshot?.map.activeFloorId }?.name
            ?? floors.first?.name
            ?? style.strings.text(.allFloors)
    }
}

/// Scrollable section list for wide or host-owned layouts.
public struct SeatLayerPickerSectionNavigator: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style

    public init() {}

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                Button(style.strings.text(.overview)) {
                    runPickerAction(controller) { _ = try await controller.overview() }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                ForEach(controller.snapshot?.sections ?? [], id: \.id) { section in
                    Button {
                        runPickerAction(controller) { _ = try await controller.focusSection(section.id) }
                    } label: {
                        HStack {
                            Text(section.displayLabel ?? section.label).lineLimit(1)
                            Spacer()
                            if let count = section.seatsLeft {
                                Text(style.strings.seatsLeft(count)).font(.caption)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        controller.snapshot?.map.focusedSectionId == section.id ? .isSelected : []
                    )
                }
            }
        }
    }
}

/// Native chrome over renderer-owned venue-3D pixels.
public struct SeatLayerVenue3D: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if controller.snapshot?.map.isVenue3D == true {
            let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: .dark, snapshot: controller.snapshot)
            VStack {
                HStack {
                    Button {
                        runPickerAction(controller) { _ = try await controller.setBuyerView("map") }
                    } label: {
                        Label(style.strings.text(.backToVenue), systemImage: "chevron.left")
                            .font(.system(size: 13, weight: .heavy))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(palette.surface.opacity(0.92))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(palette.text)
                    Spacer()
                }
                Spacer()
            }
            .padding(10)
            .accessibilityIdentifier("seatlayer-venue-3d-chrome")
        }
    }
}

/// Native title/caption/actions over renderer-owned seat panorama pixels.
public struct SeatLayerSeatViewChrome: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if let seatView = controller.seatView {
            let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: .dark, snapshot: controller.snapshot)
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(seatView.title ?? style.strings.text(.viewFromHere)).font(.headline)
                        if let caption = seatView.caption { Text(caption).font(.caption) }
                    }
                    Spacer()
                    Button(style.strings.text(.close)) {
                        runPickerAction(controller) { _ = try await controller.setBuyerView("map") }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .foregroundColor(palette.text)
                .padding(12)
                .background(palette.surface.opacity(0.92))
            }
            .accessibilityIdentifier("seatlayer-seat-view-chrome")
        }
    }
}

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
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(palette.text)
                Text(recoveryCopy(lapse))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(palette.mutedText)
                HStack(spacing: 8) {
                    Button(style.strings.text(.dismiss)) { controller.dismissHoldLapse() }
                    if !lapse.recoverableLabels.isEmpty {
                        Button(style.strings.text(.recoverSeats)) {
                            runPickerAction(controller) {
                                _ = try await controller.reselectLapsedSeats(ttlMs: style.options.holdTtlMs)
                            }
                        }
                        .foregroundColor(palette.onAccent)
                        .padding(.horizontal, 12)
                        .background(palette.accent)
                        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
                    }
                }
                .frame(minHeight: 44)
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
        VStack(spacing: 10) {
            Image(systemName: "ticket.fill").font(.system(size: 24)).foregroundColor(palette.mutedText)
            Text(style.strings.text(.noTicketsAvailable))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(palette.text)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(palette.surface.opacity(0.96))
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
