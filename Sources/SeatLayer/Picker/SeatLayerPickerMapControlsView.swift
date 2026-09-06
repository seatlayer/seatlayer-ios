#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct SeatLayerPickerBuyerViewControl: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    private let compact: Bool

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public var body: some View {
        let snapshot = controller.snapshot
        let venue3D = snapshot?.map.isVenue3D == true
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: snapshot
        )
        if let snapshot,
           ["map", "venue3d"].contains(snapshot.map.buyerView),
           style.options.enable3D,
           style.options.chrome.map3D,
           snapshot.capabilities.contains("venue3d"),
           controller.supportsVenue3D {
            HStack(spacing: 0) {
                segment(style.strings.text(.mapView), selected: !venue3D) {
                    runPickerAction(controller) { _ = try await controller.setBuyerView("map") }
                }
                segment(style.strings.text(.venue3D), selected: venue3D) {
                    runPickerAction(controller) { _ = try await controller.setBuyerView("venue3d") }
                }
            }
            .frame(height: SeatLayerPickerChromeMetrics.compactRailHeight)
            .background {
                Capsule()
                    .fill(palette.surface.opacity(0.94))
                    .frame(height: viewModePaintHeight)
                    .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
            }
            .overlay {
                Capsule()
                    .stroke(palette.divider, lineWidth: 0.75)
                    .frame(height: viewModePaintHeight)
            }
            .dynamicTypeSize(...DynamicTypeSize.large)
        }
    }

    private func segment(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        return Button(action: action) {
            Text(label)
                .seatLayerPickerFont(size: 12, weight: .bold)
                .foregroundColor(selected ? palette.onAccent : palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, compact ? 10 : 12)
                .frame(
                    minWidth: 46,
                    minHeight: SeatLayerPickerSizeTokens.minimumHitTarget
                )
                .background {
                    if selected {
                        Capsule()
                            .fill(palette.accent)
                            .frame(height: viewModePaintHeight)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!controller.isReady)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var viewModePaintHeight: Double {
        compact
            ? SeatLayerPickerChromeMetrics.compactViewModePaintHeight
            : SeatLayerPickerChromeMetrics.regularViewModePaintHeight
    }
}

public struct SeatLayerPickerTestModeIndicator: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if isTest {
            let palette = resolveSeatLayerPickerPalette(
                style: style,
                colorScheme: colorScheme,
                snapshot: controller.snapshot
            )
            Text(style.strings.text(.testMode))
                .tracking(0.6)
                .seatLayerPickerFont(size: 10, weight: .black)
                .foregroundColor(palette.dark ? palette.warning : palette.text)
                .padding(.horizontal, 8)
                .frame(height: SeatLayerPickerChromeMetrics.compactTruthPaintHeight)
                .background(
                    palette.dark
                        ? palette.surface.opacity(0.92)
                        : palette.warning
                )
                .overlay {
                    Capsule().stroke(
                        palette.warning,
                        lineWidth: palette.dark ? 1 : 0
                    )
                }
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.16), radius: 4, y: 1)
                .dynamicTypeSize(...DynamicTypeSize.large)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(style.strings.text(.testModeDescription))
        }
    }

    private var isTest: Bool {
        guard let mode = controller.snapshot?.event.mode else { return false }
        if case .test = mode { return true }
        return false
    }
}

/// Compact zoom, fit, overview, and accessibility controls over the map.
public struct SeatLayerPickerMapControls: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let topInset: Double
    private let bottomInset: Double
    private let edgeInset: Double
    private let includeBuyerViewControl: Bool

    public init(
        topInset: Double = 10,
        bottomInset: Double = 10,
        edgeInset: Double = 10,
        includeBuyerViewControl: Bool = true
    ) {
        self.topInset = max(0, topInset)
        self.bottomInset = max(0, bottomInset)
        self.edgeInset = max(0, edgeInset)
        self.includeBuyerViewControl = includeBuyerViewControl
    }

    public var body: some View {
        let snapshot = controller.snapshot
        let availability = SeatLayerPickerImmersive.availability(
            snapshot: snapshot,
            bundle: controller.bundleInfo,
            seatView: controller.seatView
        )
        if snapshot?.map.buyerView == "map", !availability.panoramaChrome {
            ZStack {
                if includeBuyerViewControl {
                    VStack {
                        HStack {
                            Spacer()
                            SeatLayerPickerBuyerViewControl(compact: !usesWideLayout)
                        }
                        .padding(.top, topInset)
                        .padding(.trailing, edgeInset)
                        Spacer()
                    }
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            if style.options.chrome.showsOverview(wide: usesWideLayout),
                               snapshot?.map.rung == "seats",
                               snapshot?.map.focusedSectionId != nil {
                                control("square.grid.2x2", label: style.strings.text(.overview)) {
                                    _ = try await controller.overview()
                                }
                            }
                            if style.options.chrome.showsZoom(wide: usesWideLayout) {
                                control("plus", label: style.strings.text(.zoomIn), enabled: snapshot?.map.canZoomIn != false) {
                                    try await controller.zoomIn()
                                }
                                control("minus", label: style.strings.text(.zoomOut), enabled: snapshot?.map.canZoomOut != false) {
                                    try await controller.zoomOut()
                                }
                            }
                            if style.options.chrome.fit {
                                control("viewfinder", label: style.strings.text(.fitVenue)) {
                                    try await controller.zoomToFit()
                                }
                            }
                            if style.options.chrome.showsColorblind(wide: usesWideLayout),
                               SeatLayerPickerAccessibility.availability(
                                   snapshot: snapshot,
                                   bundle: controller.bundleInfo
                               ).colorblind {
                                control(
                                    "eye",
                                    label: style.strings.text(.colorblindSafe),
                                    selected: snapshot?.map.colorblindSafe == true
                                ) {
                                    _ = try await controller.setColorblindSafe(
                                        snapshot?.map.colorblindSafe != true
                                    )
                                }
                            }
                        }
                    }
                    .padding(.trailing, edgeInset)
                    .padding(.bottom, bottomInset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func control(
        _ symbol: String,
        label: String,
        enabled: Bool = true,
        selected: Bool = false,
        action: @escaping @MainActor () async throws -> Void
    ) -> some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        return Button {
            runPickerAction(controller, action)
        } label: {
            Image(systemName: symbol)
                .seatLayerPickerFont(size: 15, weight: .bold)
                .foregroundColor(palette.text)
                .frame(
                    width: SeatLayerPickerSizeTokens.mapControlSize,
                    height: SeatLayerPickerSizeTokens.mapControlSize
                )
                .seatLayerPickerTranslucentBackground(palette.surface, opacity: 0.94)
                .overlay {
                    Circle().stroke(palette.divider, lineWidth: 1)
                }
                .clipShape(Circle())
                .frame(
                    width: SeatLayerPickerSizeTokens.minimumHitTarget,
                    height: SeatLayerPickerSizeTokens.minimumHitTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!controller.isReady || !enabled)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var usesWideLayout: Bool {
        switch style.options.layout {
        case .wide: return true
        case .phone: return false
        case .adaptive: return horizontalSizeClass == .regular
        }
    }
}

/// Standalone colourblind-safe control for custom SwiftUI compositions.
public struct SeatLayerPickerColorblindButton: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        let selected = controller.snapshot?.map.colorblindSafe == true
        let available = SeatLayerPickerAccessibility.availability(
            snapshot: controller.snapshot,
            bundle: controller.bundleInfo
        ).colorblind
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        Button {
            runPickerAction(controller) {
                _ = try await controller.setColorblindSafe(!selected)
            }
        } label: {
            Label(style.strings.text(.colorblindSafe), systemImage: "eye")
                .seatLayerPickerFont(size: 13, weight: .bold)
                .foregroundColor(selected ? palette.onAccent : palette.text)
                .padding(.horizontal, 12)
                .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                .background(selected ? palette.accent : palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
        }
        .buttonStyle(.plain)
        .disabled(!controller.isReady || !available)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

public struct SeatLayerPickerAccessibilityButton: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingFilters = false

    public init() {}

    public var body: some View {
        let availability = SeatLayerPickerAccessibility.availability(
            snapshot: controller.snapshot,
            bundle: controller.bundleInfo
        )
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        if availability.any,
           controller.snapshot?.map.buyerView == "map" {
            let activeCount = SeatLayerPickerAccessibility.activeCount(
                controller.snapshot,
                availability: availability
            )
            Button { showingFilters = true } label: {
                Image(systemName: "figure.roll")
                    .seatLayerPickerFont(size: 18, weight: .bold)
                    .foregroundColor(activeCount > 0 ? palette.accent : palette.text)
                    .frame(
                        width: SeatLayerPickerSizeTokens.minimumHitTarget,
                        height: SeatLayerPickerSizeTokens.minimumHitTarget
                    )
                    .seatLayerPickerTranslucentBackground(palette.surface, opacity: 0.94)
                    .overlay { Circle().stroke(palette.divider, lineWidth: 1) }
                    .clipShape(Circle())
                    .overlay(alignment: .topTrailing) {
                        if activeCount > 0 {
                            Text(String(activeCount))
                                .seatLayerPickerFont(size: 9, weight: .heavy)
                                .foregroundColor(palette.onAccent)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(palette.accent)
                                .clipShape(Circle())
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(!controller.isReady)
            .accessibilityLabel(style.strings.text(.accessibility))
            .accessibilityValue(activeCount == 0 ? "" : String(activeCount))
            .sheet(isPresented: $showingFilters) {
                SeatLayerPickerPartHost(.accessibilityFilters) {
                    SeatLayerPickerAccessibilityFilters()
                }
                .environmentObject(controller)
                .environment(\.seatLayerPickerStyle, style)
                // SwiftUI sheets otherwise resolve their system Form surface
                // independently from an explicitly light/dark picker. Keep
                // native controls and the picker palette on the same side of
                // the contrast boundary.
                .preferredColorScheme(palette.dark ? .dark : .light)
            }
        }
    }
}
#endif
