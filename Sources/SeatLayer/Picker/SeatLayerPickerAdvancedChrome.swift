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

/// Adaptive compact floor entry point; the always-visible strip remains a
/// separate public part for layouts that have room.
public struct SeatLayerPickerFloorSelector: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style

    public init() {}

    public var body: some View {
        let floors = controller.snapshot?.map.floors ?? []
        if floors.count > 1,
           controller.snapshot?.map.buyerView == "map" {
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
        if controller.snapshot?.map.buyerView == "map" {
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
}

/// Native chrome over renderer-owned venue-3D pixels.
public struct SeatLayerVenue3D: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @State private var busy = false
    private let onBackToVenue: (() -> Void)?
    private let topInset: Double
    private let bottomInset: Double
    private let showsMapBackControl: Bool

    public init(
        onBackToVenue: (() -> Void)? = nil,
        topInset: Double = 10,
        bottomInset: Double = 10,
        showsMapBackControl: Bool = true
    ) {
        self.onBackToVenue = onBackToVenue
        self.topInset = max(0, topInset)
        self.bottomInset = max(0, bottomInset)
        self.showsMapBackControl = showsMapBackControl
    }

    public var body: some View {
        let availability = SeatLayerPickerImmersive.availability(
            snapshot: controller.snapshot,
            bundle: controller.bundleInfo,
            seatView: controller.seatView
        )
        if availability.venue3D,
           !availability.panoramaChrome,
           let snapshot = controller.snapshot {
            let palette = immersivePalette(snapshot: snapshot)
            let position = SeatLayerPickerImmersive.position(in: snapshot)
            let targeted = position.targetSeatId != nil
            VStack {
                HStack {
                    if targeted {
                        control(
                            symbol: "chevron.left",
                            label: style.strings.text(.backToVenue),
                            labelled: true,
                            enabled: !busy,
                            palette: palette
                        ) { execute(.back) }
                    } else if showsMapBackControl {
                        control(
                            symbol: "map",
                            label: style.strings.text(.mapView),
                            labelled: true,
                            enabled: !busy,
                            palette: palette
                        ) { execute(.back) }
                    }
                    Spacer()
                    if availability.navigationMode {
                        let moving = snapshot.map.view3DNavigationMode == "pan"
                        control(
                            symbol: moving
                                ? "arrow.up.and.down.and.arrow.left.and.right"
                                : "rotate.left",
                            label: style.strings.text(moving ? .moveVenue : .orbitMode),
                            enabled: !busy,
                            palette: palette
                        ) { toggleNavigation(from: snapshot) }
                    }
                }
                .padding(.top, topInset)
                Spacer()
                VStack(spacing: 8) {
                    if let caption = caption(for: position.targetSeat) {
                        Text(caption)
                            .seatLayerPickerFont(size: 12, weight: .bold)
                            .foregroundColor(palette.text)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 28)
                            .seatLayerPickerTranslucentBackground(palette.surface, opacity: 0.88)
                            .overlay { Capsule().stroke(palette.divider, lineWidth: 1) }
                            .clipShape(Capsule())
                            .accessibilityIdentifier("seatlayer-venue-3d-caption")
                    }
                    HStack(spacing: 8) {
                        if targeted {
                            control(
                                symbol: "chevron.left",
                                label: style.strings.text(.previousSeat),
                                enabled: !busy && position.previousSeatId != nil,
                                palette: palette
                            ) { execute(.previous) }
                            if availability.seatViewAction {
                                control(
                                    symbol: "eye",
                                    label: style.strings.text(.viewFromHere),
                                    labelled: true,
                                    enabled: !busy,
                                    palette: palette
                                ) { openSeatView(position.targetSeatId) }
                            }
                            control(
                                symbol: "chevron.right",
                                label: style.strings.text(.nextSeat),
                                enabled: !busy && position.nextSeatId != nil,
                                palette: palette
                            ) { execute(.next) }
                            control(
                                symbol: "scope",
                                label: style.strings.text(.recentre),
                                enabled: !busy,
                                palette: palette
                            ) { execute(.recentre) }
                        } else {
                            if availability.zoomOut {
                                control(
                                    symbol: "minus",
                                    label: style.strings.text(.zoomOut),
                                    enabled: !busy,
                                    palette: palette
                                ) { camera(.zoomOut) }
                            }
                            if availability.zoomToFit {
                                control(
                                    symbol: "viewfinder",
                                    label: style.strings.text(.fitVenue),
                                    labelled: true,
                                    enabled: !busy,
                                    palette: palette
                                ) { camera(.fit) }
                            }
                            if availability.zoomIn {
                                control(
                                    symbol: "plus",
                                    label: style.strings.text(.zoomIn),
                                    enabled: !busy,
                                    palette: palette
                                ) { camera(.zoomIn) }
                            }
                        }
                    }
                }
                .padding(.bottom, bottomInset)
            }
            .padding(.horizontal, 10)
            .accessibilityIdentifier("seatlayer-venue-3d-chrome")
            .transition(.opacity)
        }
    }

    private enum CameraAction { case zoomIn, zoomOut, fit }

    private func immersivePalette(snapshot: SeatLayerPickerSnapshot) -> SeatLayerPickerPalette {
        var immersiveStyle = style
        immersiveStyle.mode = .dark
        return resolveSeatLayerPickerPalette(
            style: immersiveStyle,
            colorScheme: .dark,
            snapshot: snapshot
        )
    }

    private func caption(for seat: SelectedSeat?) -> String? {
        guard let seat else { return nil }
        let values = [
            seat.sectionLabel,
            seat.rowLabel.map { "\(style.strings.text(.row)) \($0)" },
            (seat.seatNumber ?? seat.buyerFacingLabel).isEmpty
                ? nil
                : "\(style.strings.text(.seat)) \(seat.seatNumber ?? seat.buyerFacingLabel)",
            style.strings.text(.viewFromYourSeat),
        ].compactMap { value -> String? in
            guard let value,
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
        return values.isEmpty ? nil : values.joined(separator: " · ")
    }

    @ViewBuilder
    private func control(
        symbol: String,
        label: String,
        labelled: Bool = false,
        enabled: Bool,
        palette: SeatLayerPickerPalette,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).seatLayerPickerFont(size: 14, weight: .bold)
                if labelled {
                    Text(label).seatLayerPickerFont(size: 13, weight: .heavy).lineLimit(1)
                }
            }
            .foregroundColor(palette.text)
            .padding(.horizontal, labelled ? 12 : 8)
            .frame(minWidth: 36, minHeight: 36)
            .seatLayerPickerTranslucentBackground(palette.surface, opacity: 0.92)
            .overlay {
                RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button)
                    .stroke(palette.divider, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.48)
        .accessibilityLabel(label)
    }

    private func execute(_ action: SeatLayerPickerVenue3DAction) {
        if action == .back, let onBackToVenue {
            onBackToVenue()
            return
        }
        perform {
            guard let snapshot = controller.snapshot,
                  SeatLayerPickerImmersive.availability(
                      snapshot: snapshot,
                      bundle: controller.bundleInfo,
                      seatView: controller.seatView
                  ).venue3D,
                  let request = SeatLayerPickerImmersive.request(
                      for: action,
                      snapshot: snapshot
                  ) else { return }
            _ = try await controller.setBuyerView(
                request.view,
                flyToSeatId: request.flyToSeatId,
                resetView: request.resetView
            )
        }
    }

    private func openSeatView(_ seatId: String?) {
        perform {
            guard let seatId,
                  let snapshot = controller.snapshot,
                  snapshot.map.view3DTargetSeatId == seatId,
                  SeatLayerPickerImmersive.availability(
                      snapshot: snapshot,
                      bundle: controller.bundleInfo,
                      seatView: controller.seatView
                  ).seatViewAction else { return }
            let seat = snapshot.map.view3DTargetSeat
                ?? snapshot.selection.first { $0.id == seatId }
            _ = try await controller.openSeatView(seatId)
            if let seat { presentation.recordSeatViewOpened(seat) }
        }
    }

    private func toggleNavigation(from snapshot: SeatLayerPickerSnapshot) {
        let next = snapshot.map.view3DNavigationMode == "pan" ? "orbit" : "pan"
        perform {
            guard let current = controller.snapshot,
                  SeatLayerPickerImmersive.availability(
                      snapshot: current,
                      bundle: controller.bundleInfo,
                      seatView: controller.seatView
                  ).navigationMode else { return }
            _ = try await controller.setVenue3DNavigationMode(next)
        }
    }

    private func camera(_ action: CameraAction) {
        perform {
            let availability = SeatLayerPickerImmersive.availability(
                snapshot: controller.snapshot,
                bundle: controller.bundleInfo,
                seatView: controller.seatView
            )
            switch action {
            case .zoomIn where availability.zoomIn:
                try await controller.zoomIn()
            case .zoomOut where availability.zoomOut:
                try await controller.zoomOut()
            case .fit where availability.zoomToFit:
                try await controller.zoomToFit()
            default:
                return
            }
        }
    }

    private func perform(_ action: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do { try await action() }
            catch let error as SeatLayerError { controller.record(error) }
            catch { controller.record(.transport(error.localizedDescription)) }
        }
    }
}

/// Native title/caption/actions over renderer-owned seat panorama pixels.
public struct SeatLayerSeatViewChrome: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    private let topInset: Double
    private let bottomInset: Double
    private let showDragHint: Bool

    public init(
        topInset: Double = 10,
        bottomInset: Double = 10,
        showDragHint: Bool = true
    ) {
        self.topInset = max(0, topInset)
        self.bottomInset = max(0, bottomInset)
        self.showDragHint = showDragHint
    }

    public var body: some View {
        let availability = SeatLayerPickerImmersive.availability(
            snapshot: controller.snapshot,
            bundle: controller.bundleInfo,
            seatView: controller.seatView
        )
        if availability.panoramaChrome,
           let seatView = controller.seatView {
            let wording = SeatLayerPickerImmersive.panoramaWording(seatView)
            let palette = immersivePalette
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            if let title = wording.title {
                                Text(title).seatLayerPickerFont(size: 14, weight: .heavy).lineLimit(2)
                            }
                            if let caption = wording.caption {
                                Text(caption)
                                    .seatLayerPickerFont(size: 12, weight: .semibold)
                                    .foregroundColor(palette.mutedText)
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 0)
                        if let badge = wording.badge {
                            Text(badge)
                                .seatLayerPickerFont(size: 12, weight: .heavy)
                                .foregroundColor(seatView.real ? palette.onAccent : palette.text)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    seatView.real
                                        ? palette.accent
                                        : palette.text.opacity(0.14)
                                )
                                .clipShape(Capsule())
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(palette.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .seatLayerPickerTranslucentBackground(palette.surface, opacity: 0.92)
                    .overlay {
                        RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button)
                            .stroke(palette.divider, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
                    if showDragHint, let hint = wording.dragHint {
                        Text(hint)
                            .seatLayerPickerFont(size: 12, weight: .semibold)
                            .foregroundColor(palette.mutedText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .seatLayerPickerTranslucentBackground(palette.surface, opacity: 0.80)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, topInset)
                .padding(.bottom, bottomInset)
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(wording.summary ?? style.strings.text(.viewFromYourSeat))
            .accessibilityIdentifier("seatlayer-seat-view-chrome")
            .transition(.opacity)
        }
    }

    private var immersivePalette: SeatLayerPickerPalette {
        var immersiveStyle = style
        immersiveStyle.mode = .dark
        return resolveSeatLayerPickerPalette(
            style: immersiveStyle,
            colorScheme: .dark,
            snapshot: controller.snapshot
        )
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
                    .seatLayerPickerFont(size: 14, weight: .heavy)
                    .foregroundColor(palette.text)
                Text(recoveryCopy(lapse))
                    .seatLayerPickerFont(size: 12, weight: .semibold)
                    .foregroundColor(palette.mutedText)
                HStack(spacing: 8) {
                    Button(style.strings.text(.dismiss)) { controller.dismissHoldLapse() }
                        .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                    if !lapse.recoverableLabels.isEmpty {
                        Button(style.strings.text(.recoverSeats)) {
                            runPickerAction(controller) {
                                _ = try await controller.reselectLapsedSeats(ttlMs: style.options.normalizedHoldTtlMs)
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
        let message = controller.snapshot?.event.salesClosed == true
            ? style.strings.text(.salesClosed)
            : style.strings.text(.noTicketsAvailable)
        VStack(spacing: 10) {
            Image(systemName: "ticket.fill").seatLayerPickerFont(size: 24).foregroundColor(palette.mutedText)
            Text(message)
                .seatLayerPickerFont(size: 14, weight: .bold)
                .foregroundColor(palette.text)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .seatLayerPickerTranslucentBackground(palette.surface, opacity: 0.96)
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
