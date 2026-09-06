#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

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
#endif
