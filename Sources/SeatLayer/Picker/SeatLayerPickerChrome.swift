#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

private enum SeatLayerPickerChromeMetrics {
    static let compactRailHeight = 44.0
    static let compactLegendPaintHeight = 30.0
    static let regularLegendPaintHeight = 40.0
    static let compactViewModePaintHeight = 32.0
    static let regularViewModePaintHeight = 40.0
    static let compactFloorPaintHeight = 30.0
    static let regularFloorPaintHeight = 36.0
    static let compactTruthPaintHeight = 20.0
}

private struct SeatLayerPickerLegendContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SeatLayerPickerLegendViewportWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Event identity, hold countdown, and optional close control.
public struct SeatLayerPickerHeader: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    private let onClose: (() -> Void)?
    private let compact: Bool

    public init(onClose: (() -> Void)? = nil, compact: Bool = false) {
        self.onClose = onClose
        self.compact = compact
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        HStack(spacing: 10) {
            SeatLayerPickerLogo()
                .fixedSize()
            if !style.options.hideEventDetails {
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.snapshot?.event.name ?? style.strings.text(.chooseSeats))
                        .seatLayerPickerFont(size: compact ? 14 : 16, weight: .bold)
                        .foregroundColor(palette.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if !compact,
                       let venue = controller.snapshot?.event.venue,
                       !venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(venue)
                            .seatLayerPickerFont(size: 11, weight: .medium)
                            .foregroundColor(palette.mutedText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            } else {
                Spacer(minLength: 0)
            }
            if style.options.chrome.holdPill,
               let expiry = controller.snapshot?.hold.expiresAt,
               controller.snapshot?.hold.active == true,
               controller.holdLapse == nil {
                SeatLayerPickerPartHost(.holdCountdown) {
                    SeatLayerPickerHoldCountdown(expiresAt: expiry)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .seatLayerPickerFont(size: 15, weight: .bold)
                        .frame(
                            width: SeatLayerPickerSizeTokens.minimumHitTarget,
                            height: SeatLayerPickerSizeTokens.minimumHitTarget
                        )
                }
                .foregroundColor(palette.text)
                .buttonStyle(.plain)
                .accessibilityLabel(style.strings.text(.close))
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, compact ? 0 : 6)
        .frame(minHeight: SeatLayerPickerSizeTokens.headerHeight)
        .background(palette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }
}

public struct SeatLayerPickerLogo: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        Group {
            if let raw = controller.snapshot?.branding.logoURL,
               let url = URL(string: raw) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView().tint(palette.onAccent)
                }
            } else {
                Image(systemName: "chair.lounge.fill")
                    .seatLayerPickerFont(size: 15, weight: .bold)
                    .foregroundColor(palette.onAccent)
            }
        }
        .frame(
            width: SeatLayerPickerSizeTokens.headerLogoSize,
            height: SeatLayerPickerSizeTokens.headerLogoSize
        )
        .background(palette.accent)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityHidden(true)
    }
}

public struct SeatLayerPickerHoldCountdown: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    private let expiresAt: Double

    public init(expiresAt: Double) {
        self.expiresAt = expiresAt
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(expiryDate.timeIntervalSince(context.date)))
            HStack(spacing: 5) {
                Image(systemName: "timer")
                Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                    .monospacedDigit()
            }
            .seatLayerPickerFont(size: 12, weight: .bold)
            .foregroundColor(palette.text)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(palette.background)
            .clipShape(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(style.strings.text(
                .heldFor,
                replacing: ["clock": String(format: "%d:%02d", remaining / 60, remaining % 60)]
            ))
        }
    }

    private var expiryDate: Date {
        Date(timeIntervalSince1970: expiresAt > 10_000_000_000 ? expiresAt / 1_000 : expiresAt)
    }
}

/// Horizontally scrollable authoritative category and price rail.
public struct SeatLayerPickerPriceLegend: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    private let compact: Bool

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public var body: some View {
        let snapshot = controller.snapshot
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: snapshot
        )
        let immersive = SeatLayerPickerImmersive.availability(
            snapshot: snapshot,
            bundle: controller.bundleInfo,
            seatView: controller.seatView
        )
        let categories = snapshot?.categories.filter { !$0.notForSale } ?? []
        if !immersive.panoramaChrome, !categories.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: compact ? 5 : 6) {
                    ForEach(categories, id: \.key) { category in
                        let selected = snapshot?.map.categoryFilter.contains(category.key) == true
                        Button {
                            runPickerAction(controller) {
                                _ = try await controller.setCategoryFilter(selected ? [] : [category.key])
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(uiColor: UIColor(slHex: category.color) ?? .systemIndigo))
                                    .frame(width: compact ? 8 : 10, height: compact ? 8 : 10)
                                Text(priceLabel(category, currency: snapshot?.currency ?? "USD"))
                                    .lineLimit(1)
                            }
                            .seatLayerPickerFont(size: compact ? 11 : 12, weight: .bold)
                            .foregroundColor(selected ? palette.onAccent : palette.text)
                            .padding(.horizontal, compact ? 8 : 10)
                            .frame(height: legendPaintHeight)
                            .background(
                                selected
                                    ? palette.accent
                                    : palette.surface.opacity(0.94)
                            )
                            .overlay {
                                Capsule().stroke(
                                    selected ? palette.accent : palette.divider,
                                    lineWidth: selected ? 1 : 0.75
                                )
                            }
                            .clipShape(Capsule())
                            .frame(
                                minWidth: SeatLayerPickerSizeTokens.minimumHitTarget,
                                minHeight: SeatLayerPickerSizeTokens.minimumHitTarget
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!controller.isReady)
                        .accessibilityLabel("\(category.label), \(priceLabel(category, currency: snapshot?.currency ?? "USD"))")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.leading, compact ? 8 : 12)
                .padding(.trailing, 20)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: SeatLayerPickerLegendContentWidthKey.self,
                            value: geometry.size.width
                        )
                    }
                }
            }
            .frame(height: SeatLayerPickerChromeMetrics.compactRailHeight)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: SeatLayerPickerLegendViewportWidthKey.self,
                        value: geometry.size.width
                    )
                }
            }
            .mask { legendOverflowMask }
            .onPreferenceChange(SeatLayerPickerLegendContentWidthKey.self) {
                contentWidth = $0
            }
            .onPreferenceChange(SeatLayerPickerLegendViewportWidthKey.self) {
                viewportWidth = $0
            }
        }
    }

    private var legendPaintHeight: Double {
        compact
            ? SeatLayerPickerChromeMetrics.compactLegendPaintHeight
            : SeatLayerPickerChromeMetrics.regularLegendPaintHeight
    }

    @ViewBuilder
    private var legendOverflowMask: some View {
        if contentWidth > viewportWidth + 1, viewportWidth > 0 {
            GeometryReader { geometry in
                let fade = min(18 / max(1, geometry.size.width), 0.35)
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 1 - fade),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: layoutDirection == .rightToLeft ? .trailing : .leading,
                    endPoint: layoutDirection == .rightToLeft ? .leading : .trailing
                )
            }
        } else {
            Rectangle().fill(Color.black)
        }
    }

    private func priceLabel(_ category: SeatLayerPickerCategory, currency: String) -> String {
        let amount = category.priceMin
        if category.priceMax > amount {
            return style.strings.fromPrice(
                seatLayerPickerMoney(amount, currency: currency, style: style)
            )
        }
        return seatLayerPickerMoney(amount, currency: currency, style: style)
    }
}

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

public struct SeatLayerPickerAccessibilityFilters: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @State private var initial = SeatLayerPickerAccessibilityDraft()
    @State private var draft = SeatLayerPickerAccessibilityDraft()
    @State private var sessionId: String?
    @State private var busy = false

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
            NavigationView {
                Form {
                    let needs = SeatLayerPickerAccessibility.needs(
                        snapshot: controller.snapshot,
                        availability: availability
                    )
                    if !needs.isEmpty {
                        Section {
                            ForEach(needs, id: \.key) { need in
                                needRow(need, palette: palette)
                            }
                        }
                    }
                    if availability.limitedView {
                        Toggle(
                            style.strings.text(.hideLimitedView),
                            isOn: $draft.hideLimitedView
                        )
                        .disabled(busy)
                    }
                    if availability.colorblind {
                        Toggle(
                            style.strings.text(.colorblindSafe),
                            isOn: $draft.colorblindSafe
                        )
                        .disabled(busy)
                    }
                    Section {
                        Button {
                            apply()
                        } label: {
                            HStack {
                                Spacer()
                                if busy { ProgressView().tint(palette.onAccent) }
                                Text(style.strings.text(.applyFilters))
                                    .seatLayerPickerFont(size: 15, weight: .heavy)
                                Spacer()
                            }
                            .frame(minHeight: 44)
                        }
                        .listRowBackground(palette.accent)
                        .foregroundColor(palette.onAccent)
                        .disabled(busy)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(style.strings.text(.cancel)) { dismiss() }
                            .disabled(busy)
                    }
                    ToolbarItem(placement: .principal) {
                        Text(style.strings.text(.accessibilityTitle))
                            .seatLayerPickerFont(size: 16, weight: .bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .accentColor(palette.accent)
            }
            .onAppear(perform: resetDraft)
            .onChange(of: controller.snapshot?.sessionId) { _ in
                resetDraft()
            }
        }
    }

    private func needRow(
        _ need: SeatLayerPickerAccessNeed,
        palette: SeatLayerPickerPalette
    ) -> some View {
        let selected = draft.types.contains(need.key)
        let enabled = !busy && need.count > 0
        return Button {
            draft.toggle(need.key)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? palette.accent : palette.mutedText)
                Text(style.strings.accessNeed(
                    need.key,
                    count: need.count
                ))
                Spacer()
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundColor(enabled ? palette.text : palette.mutedText)
        .disabled(!enabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("seatlayer-access-need-\(need.key)")
    }

    private func resetDraft() {
        let value = SeatLayerPickerAccessibility.draft(from: controller.snapshot)
        initial = value
        draft = value
        sessionId = controller.snapshot?.sessionId
    }

    private func apply() {
        guard !busy, sessionId == controller.snapshot?.sessionId else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                if try await controller.applyAccessibilityFilters(draft, from: initial) {
                    dismiss()
                }
            } catch let error as SeatLayerError {
                controller.record(error)
            } catch {
                controller.record(.transport(error.localizedDescription))
            }
        }
    }
}

public struct SeatLayerPickerFloorStrip: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    private let compact: Bool

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public var body: some View {
        let floors = controller.snapshot?.map.floors ?? []
        if floors.count > 1,
           controller.snapshot?.map.buyerView == "map" {
            let palette = resolveSeatLayerPickerPalette(
                style: style,
                colorScheme: colorScheme,
                snapshot: controller.snapshot
            )
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    if controller.supportsFloorStack {
                        floorButton(
                            id: seatLayerAllFloors,
                            label: style.strings.text(.allFloors),
                            selected: controller.snapshot?.map.showsAllFloors == true
                        )
                    }
                    ForEach(floors, id: \.id) { floor in
                        floorButton(
                            id: floor.id,
                            label: floor.name,
                            selected: controller.snapshot?.map.activeFloorId == floor.id
                        )
                    }
                }
                .padding(.horizontal, compact ? 8 : 12)
            }
            .frame(height: SeatLayerPickerChromeMetrics.compactRailHeight)
        }
    }

    private func floorButton(id: String, label: String, selected: Bool) -> some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        return Button {
            runPickerAction(controller) { _ = try await controller.setFloor(id) }
        } label: {
            Text(label)
                .seatLayerPickerFont(size: compact ? 11 : 12, weight: .bold)
                .foregroundColor(selected ? palette.onAccent : palette.text)
                .lineLimit(1)
                .padding(.horizontal, compact ? 10 : 12)
                .frame(height: floorPaintHeight)
                .background(
                    selected
                        ? palette.accent
                        : palette.surface.opacity(0.94)
                )
                .overlay {
                    Capsule().stroke(
                        selected ? palette.accent : palette.divider,
                        lineWidth: selected ? 1 : 0.75
                    )
                }
                .clipShape(Capsule())
                .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var floorPaintHeight: Double {
        compact
            ? SeatLayerPickerChromeMetrics.compactFloorPaintHeight
            : SeatLayerPickerChromeMetrics.regularFloorPaintHeight
    }
}

/// Focused-section context and venue return action shown at the seat rung.
public struct SeatLayerPickerDockBar: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if let section = focusedSection,
           controller.snapshot?.map.rung == "seats",
           controller.snapshot?.map.buyerView == "map" {
            let palette = resolveSeatLayerPickerPalette(
                style: style,
                colorScheme: colorScheme,
                snapshot: controller.snapshot
            )
            HStack(spacing: 8) {
                Circle()
                    .fill(sectionColor(section, fallback: palette.accent))
                    .frame(width: 10, height: 10)
                Text(section.displayLabel ?? section.label)
                    .seatLayerPickerFont(size: 14, weight: .heavy)
                    .lineLimit(1)
                if let count = section.seatsLeft {
                    Text("· \(style.strings.seatsLeft(count))")
                        .seatLayerPickerFont(size: 13, weight: .semibold)
                        .foregroundColor(palette.mutedText)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
                stepButton("chevron.left", label: style.strings.text(.previousSection), section: adjacent(-1))
                stepButton("chevron.right", label: style.strings.text(.nextSection), section: adjacent(1))
                Button {
                    runPickerAction(controller) { _ = try await controller.overview() }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                        Text(style.strings.text(.overview))
                    }
                    .seatLayerPickerFont(size: 13, weight: .heavy)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(palette.text)
            .padding(.horizontal, 12)
            .frame(minHeight: SeatLayerPickerSizeTokens.dockBarHeight)
            .background(palette.surface)
            .overlay(alignment: .top) { Rectangle().fill(palette.divider).frame(height: 1) }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var focusedSection: SeatLayerPickerSectionSummary? {
        if let focused = controller.snapshot?.map.focusedSection { return focused }
        guard let id = controller.snapshot?.map.focusedSectionId else { return nil }
        return controller.snapshot?.sections.first { $0.id == id }
    }

    private func adjacent(_ offset: Int) -> SeatLayerPickerSectionSummary? {
        guard let focusedSection,
              let sections = controller.snapshot?.sections,
              let index = sections.firstIndex(where: { $0.id == focusedSection.id }) else { return nil }
        let next = index + offset
        return sections.indices.contains(next) ? sections[next] : nil
    }

    private func stepButton(
        _ symbol: String,
        label: String,
        section: SeatLayerPickerSectionSummary?
    ) -> some View {
        Button {
            guard let section else { return }
            runPickerAction(controller) { _ = try await controller.focusSection(section.id) }
        } label: {
            Image(systemName: symbol)
                .seatLayerPickerFont(size: 15, weight: .bold)
                .frame(
                    width: SeatLayerPickerSizeTokens.minimumHitTarget,
                    height: SeatLayerPickerSizeTokens.minimumHitTarget
                )
        }
        .buttonStyle(.plain)
        .disabled(section == nil)
        .accessibilityLabel(label)
    }

    private func sectionColor(
        _ section: SeatLayerPickerSectionSummary,
        fallback: Color
    ) -> Color {
        let raw = section.color
            ?? controller.snapshot?.categories.first { $0.key == section.dominantCategoryKey }?.color
        guard let raw, let color = UIColor(slHex: raw) else { return fallback }
        return Color(uiColor: color)
    }
}

public struct SeatLayerPickerAttribution: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if seatLayerPickerAttributionVisible(in: controller.snapshot) {
            let palette = resolveSeatLayerPickerPalette(
                style: style,
                colorScheme: colorScheme,
                snapshot: controller.snapshot
            )
            HStack(spacing: 4) {
                SeatLayerPickerPoweredMark(
                    background: palette.text,
                    ink: palette.surface
                )
                Text(style.strings.text(.poweredBy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .seatLayerPickerFont(size: 10, weight: .semibold)
            .foregroundColor(palette.text)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .frame(minHeight: SeatLayerPickerSizeTokens.attributionHeight)
            .dynamicTypeSize(...DynamicTypeSize.large)
            .opacity(0.64)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(style.strings.text(.poweredBy))
        }
    }
}

private struct SeatLayerPickerPoweredMark: View {
    let background: Color
    let ink: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            bar(width: 8)
            bar(width: 5.5)
            bar(width: 3)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .frame(width: 12, height: 12, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .accessibilityHidden(true)
    }

    private func bar(width: Double) -> some View {
        Capsule()
            .fill(ink)
            .frame(width: width, height: 2)
    }
}

public struct SeatLayerPickerLoadingView: View {
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: nil)
        VStack(spacing: 12) {
            ProgressView().tint(palette.accent)
            Text(style.strings.text(.loading))
                .seatLayerPickerFont(size: 14, weight: .semibold)
                .foregroundColor(palette.mutedText)
        }
        .padding(24)
        .seatLayerPickerTranslucentBackground(palette.surface, opacity: 0.96)
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.base))
        .accessibilityElement(children: .combine)
    }
}

public struct SeatLayerPickerErrorView: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    private let retry: () -> Void

    public init(retry: @escaping () -> Void) {
        self.retry = retry
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .seatLayerPickerFont(size: 26)
                .foregroundColor(palette.error)
            Text(style.strings.text(.errorMessage))
                .seatLayerPickerFont(size: 15, weight: .bold)
                .foregroundColor(palette.text)
            if let error = controller.lastError {
                Text(seatLayerPickerBuyerErrorText(error, strings: style.strings))
                    .seatLayerPickerFont(size: 12)
                    .foregroundColor(palette.mutedText)
                    .multilineTextAlignment(.center)
            }
            if controller.lastError?.isRetryable != false {
                Button(style.strings.text(.retry), action: retry)
                    .seatLayerPickerFont(size: 14, weight: .bold)
                    .foregroundColor(palette.onAccent)
                    .padding(.horizontal, 18)
                    .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                    .background(palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
            }
        }
        .padding(24)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card))
        .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
        .padding(20)
    }
}

@MainActor
func runPickerAction(
    _ controller: SeatLayerPickerController,
    _ action: @escaping @MainActor () async throws -> Void
) {
    Task { @MainActor in
        do {
            try await action()
        } catch let error as SeatLayerError {
            controller.record(error)
        } catch {
            controller.record(.transport(error.localizedDescription))
        }
    }
}
#endif
