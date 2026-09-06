#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Native chrome over renderer-owned venue-3D pixels.
///
/// The back pill is the way out of a SEAT, not out of the scene, so it is drawn
/// only while the buyer is sitting in an exact one. The deck scrolls
/// horizontally, so a venue with one more action never pushes a chip off a
/// narrow phone.
public struct SeatLayerVenue3D: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var busy = false
    @State private var recentreSpin = 0.0
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
            let position = SeatLayerPickerImmersive.position(in: snapshot)
            let targeted = position.targetSeatId != nil
            VStack(spacing: 0) {
                topRow(availability: availability, snapshot: snapshot, targeted: targeted)
                    .padding(.top, topInset)
                Spacer(minLength: 0)
                deck(availability: availability, position: position, targeted: targeted)
                    .padding(.bottom, bottomInset)
            }
            .padding(.horizontal, SeatLayerPickerSizeTokens.mapAnchorInset)
            .accessibilityIdentifier("seatlayer-venue-3d-chrome")
            .transition(.opacity)
            .animation(
                seatLayerPickerAnimation(.immersive, reduceMotion: reduceMotion),
                value: targeted
            )
        }
    }

    // MARK: - Top row

    @ViewBuilder
    private func topRow(
        availability: SeatLayerPickerImmersiveAvailability,
        snapshot: SeatLayerPickerSnapshot,
        targeted: Bool
    ) -> some View {
        HStack(spacing: SeatLayerPickerSizeTokens.mapAnchorGap) {
            if targeted {
                backPill()
            } else if showsMapBackControl {
                chip(
                    symbol: "map",
                    label: style.strings.text(.mapView),
                    labelled: true,
                    enabled: !busy
                ) { execute(.back) }
            }
            Spacer(minLength: 0)
            if availability.navigationMode {
                let panning = snapshot.map.view3DNavigationMode == "pan"
                // The control names the mode it is IN; its hint names the drag
                // that mode gives the buyer.
                chip(
                    symbol: panning
                        ? "arrow.up.and.down.and.arrow.left.and.right"
                        : "rotate.left",
                    label: style.strings.text(panning ? .panMode : .orbitMode),
                    hint: style.strings.text(panning ? .moveVenue : .rotateVenue),
                    enabled: !busy
                ) { toggleNavigation(from: snapshot) }
            }
        }
    }

    /// Top-left, only while sitting in an exact seat.
    private func backPill() -> some View {
        Button { execute(.back) } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .seatLayerPickerFont(
                        size: SeatLayerPickerSizeTokens.immersiveBackIconSize,
                        weight: .bold
                    )
                Text(style.strings.text(.backToVenue))
                    .seatLayerPickerFont(
                        size: SeatLayerPickerSizeTokens.immersiveBackFontSize,
                        weight: .heavy
                    )
                    .lineLimit(1)
            }
            .foregroundColor(SeatLayerPickerPalette.immersiveGlassInk)
            .padding(.horizontal, SeatLayerPickerSizeTokens.immersiveNavChipPaddingX)
            .frame(minHeight: SeatLayerPickerSizeTokens.immersiveBackPillHeight)
            .seatLayerImmersiveGlass(radius: SeatLayerPickerRadiusTokens.pill)
            .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(style.strings.text(.backToVenue))
        .accessibilityIdentifier("seatlayer-venue-3d-back")
    }

    // MARK: - Deck

    @ViewBuilder
    private func deck(
        availability: SeatLayerPickerImmersiveAvailability,
        position: SeatLayerPickerVenue3DPosition,
        targeted: Bool
    ) -> some View {
        VStack(spacing: SeatLayerPickerSizeTokens.mapAnchorGap) {
            if let caption = caption(for: position.targetSeat) {
                Text(caption)
                    .seatLayerPickerFont(
                        size: SeatLayerPickerSizeTokens.immersiveCaptionFontSize,
                        weight: .bold
                    )
                    .foregroundColor(SeatLayerPickerPalette.immersiveCaptionInk)
                    .lineLimit(1)
                    .padding(.horizontal, SeatLayerPickerSizeTokens.immersiveNavChipPaddingX)
                    .frame(minHeight: SeatLayerPickerSizeTokens.immersiveNavChipHeight)
                    .seatLayerImmersiveCaptionGlass(radius: SeatLayerPickerRadiusTokens.chip)
                    .accessibilityIdentifier("seatlayer-venue-3d-caption")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SeatLayerPickerSizeTokens.mapAnchorGap) {
                    if targeted {
                        chip(
                            symbol: "chevron.left",
                            label: style.strings.text(.previousSeat),
                            enabled: !busy && position.previousSeatId != nil
                        ) { execute(.previous) }
                        if availability.seatViewAction {
                            chip(
                                symbol: "view.3d",
                                label: style.strings.text(.openVenue360),
                                labelled: true,
                                enabled: !busy
                            ) { openSeatView(position.targetSeatId) }
                        }
                        chip(
                            symbol: "chevron.right",
                            label: style.strings.text(.nextSeat),
                            enabled: !busy && position.nextSeatId != nil
                        ) { execute(.next) }
                        chip(
                            symbol: "scope",
                            label: style.strings.text(.recentre),
                            enabled: !busy,
                            spin: recentreSpin
                        ) { recentre() }
                    } else {
                        // The stepper is disabled in venue mode; the camera
                        // controls take its place.
                        if availability.zoomOut {
                            chip(
                                symbol: "minus",
                                label: style.strings.text(.zoomOut),
                                enabled: !busy
                            ) { camera(.zoomOut) }
                        }
                        if availability.zoomToFit {
                            chip(
                                symbol: "viewfinder",
                                label: style.strings.text(.fitWholeVenue),
                                labelled: true,
                                enabled: !busy
                            ) { camera(.fit) }
                        }
                        if availability.zoomIn {
                            chip(
                                symbol: "plus",
                                label: style.strings.text(.zoomIn),
                                enabled: !busy
                            ) { camera(.zoomIn) }
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: - One chip

    @ViewBuilder
    private func chip(
        symbol: String,
        label: String,
        hint: String? = nil,
        labelled: Bool = false,
        enabled: Bool,
        spin: Double = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .seatLayerPickerFont(
                        size: SeatLayerPickerSizeTokens.immersiveNavChipFontSize,
                        weight: .bold
                    )
                    .rotationEffect(.degrees(spin))
                if labelled {
                    Text(label)
                        .seatLayerPickerFont(
                            size: SeatLayerPickerSizeTokens.immersiveNavChipFontSize,
                            weight: .heavy
                        )
                        .lineLimit(1)
                }
            }
            .foregroundColor(SeatLayerPickerPalette.immersiveGlassInk)
            .padding(
                .horizontal,
                labelled
                    ? SeatLayerPickerSizeTokens.immersiveNavChipPaddingX
                    : 0
            )
            .frame(
                minWidth: labelled ? 0 : SeatLayerPickerSizeTokens.immersiveNavCloseSize,
                minHeight: SeatLayerPickerSizeTokens.immersiveNavChipHeight
            )
            .seatLayerImmersiveGlass(radius: SeatLayerPickerRadiusTokens.pill)
            .frame(
                minWidth: SeatLayerPickerSizeTokens.minimumHitTarget,
                minHeight: SeatLayerPickerSizeTokens.minimumHitTarget
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : SeatLayerPickerOpacityTokens.mapControlDisabled)
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
    }

    private enum CameraAction { case zoomIn, zoomOut, fit }

    private func caption(for seat: SelectedSeat?) -> String? {
        guard let seat else { return nil }
        let seatNumber = seat.seatNumber ?? seat.buyerFacingLabel
        let values = [
            seat.sectionLabel,
            seat.rowLabel.map { "\(style.strings.text(.rowWord)) \($0)" },
            seatNumber.isEmpty ? nil : "\(style.strings.text(.seatWord)) \(seatNumber)",
            style.strings.text(.viewFromYourSeat),
        ].compactMap { value -> String? in
            guard let value,
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
        return values.isEmpty ? nil : values.joined(separator: " · ")
    }

    // MARK: - Commands

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

    /// Recentre arrives with a single spring spin.
    private func recentre() {
        if !reduceMotion {
            withAnimation(seatLayerPickerAnimation(.pop, reduceMotion: false)) {
                recentreSpin += 360
            }
        }
        execute(.recentre)
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
#endif
