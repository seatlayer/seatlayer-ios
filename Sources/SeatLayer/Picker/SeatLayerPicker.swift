#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct SeatLayerPickerCallbacks {
    public var onReady: (@MainActor (ReadyInfo) -> Void)?
    public var onChartLoad: (@MainActor (SeatLayerChartLoad) -> Void)?
    public var onSelectionChanged: (@MainActor ([SelectedSeat]) -> Void)?
    public var onHoldChanged: (@MainActor (SeatLayerPickerHold) -> Void)?
    public var onHoldExpired: (@MainActor () -> Void)?
    public var onError: (@MainActor (SeatLayerError) -> Void)?

    public init(
        onReady: (@MainActor (ReadyInfo) -> Void)? = nil,
        onChartLoad: (@MainActor (SeatLayerChartLoad) -> Void)? = nil,
        onSelectionChanged: (@MainActor ([SelectedSeat]) -> Void)? = nil,
        onHoldChanged: (@MainActor (SeatLayerPickerHold) -> Void)? = nil,
        onHoldExpired: (@MainActor () -> Void)? = nil,
        onError: (@MainActor (SeatLayerError) -> Void)? = nil
    ) {
        self.onReady = onReady
        self.onChartLoad = onChartLoad
        self.onSelectionChanged = onSelectionChanged
        self.onHoldChanged = onHoldChanged
        self.onHoldExpired = onHoldExpired
        self.onError = onError
    }
}

public typealias SeatLayerPickerCloseHandler = @MainActor () async -> Void

/// Complete native buyer picker ready to place on a SwiftUI route.
///
/// The map is the shared headless renderer; every surrounding surface is one
/// of the public native components in this module and can be recomposed inside
/// `SeatLayerPickerScope`.
public struct SeatLayerPicker: View {
    private let configuration: SeatLayerConfiguration
    private let controller: SeatLayerPickerController?
    private let presentation: SeatLayerPickerPresentationModel?
    private let options: SeatLayerPickerOptions
    private let theme: SeatLayerPickerTheme
    private let themeMode: SeatLayerPickerThemeMode
    private let strings: SeatLayerPickerStrings
    private let styles: SeatLayerPickerStyles
    private let builders: SeatLayerPickerBuilders
    private let hapticAdapter: (any SeatLayerPickerHapticAdapter)?
    private let callbacks: SeatLayerPickerCallbacks
    private let onCheckout: SeatLayerPickerCheckoutHandler
    private let onClose: SeatLayerPickerCloseHandler?

    public init(
        configuration: SeatLayerConfiguration,
        controller: SeatLayerPickerController? = nil,
        presentation: SeatLayerPickerPresentationModel? = nil,
        options: SeatLayerPickerOptions = .init(),
        theme: SeatLayerPickerTheme = .init(),
        themeMode: SeatLayerPickerThemeMode = .auto,
        strings: SeatLayerPickerStrings = .init(),
        styles: SeatLayerPickerStyles = .init(),
        builders: SeatLayerPickerBuilders = .init(),
        hapticAdapter: (any SeatLayerPickerHapticAdapter)? = nil,
        callbacks: SeatLayerPickerCallbacks = .init(),
        onCheckout: @escaping SeatLayerPickerCheckoutHandler,
        onClose: SeatLayerPickerCloseHandler? = nil
    ) {
        self.configuration = configuration
        self.controller = controller
        self.presentation = presentation
        self.options = options
        self.theme = theme
        self.themeMode = themeMode
        var mergedStrings = strings
        if let messages = configuration.messages {
            mergedStrings.overrides.merge(messages) { _, configurationValue in configurationValue }
        }
        self.strings = mergedStrings
        self.styles = styles
        self.builders = builders
        self.hapticAdapter = hapticAdapter
        self.callbacks = callbacks
        self.onCheckout = onCheckout
        self.onClose = onClose
    }

    public var body: some View {
        SeatLayerPickerScope(
            controller: controller,
            presentation: presentation,
            options: options,
            theme: theme,
            themeMode: themeMode,
            strings: strings,
            styles: styles,
            builders: builders,
            hapticAdapter: hapticAdapter
        ) { _ in
            SeatLayerPickerReadyLayout(
                configuration: configuration,
                callbacks: callbacks,
                onCheckout: onCheckout,
                onClose: onClose
            )
        }
    }
}

private struct SeatLayerPickerReadyLayout: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let configuration: SeatLayerConfiguration
    let callbacks: SeatLayerPickerCallbacks
    let onCheckout: SeatLayerPickerCheckoutHandler
    let onClose: SeatLayerPickerCloseHandler?
    @State private var reloadGeneration = 0

    var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        VStack(spacing: 0) {
            if style.options.chrome.header {
                SeatLayerPickerPartHost(.header) {
                    SeatLayerPickerHeader(onClose: onClose == nil ? nil : requestClose)
                }
            }
            ZStack {
                SeatLayerPickerPartHost(.map) {
                    SeatLayerPickerMap(
                        configuration: configuration,
                        options: style.options,
                        controller: controller,
                        themeMode: palette.dark ? .dark : .light,
                        mapTheme: palette.mapTheme
                    )
                }
                .id(reloadGeneration)
                .padding(.trailing, usesWideLayout ? wideRailWidth : 0)
                .background(palette.mapBackground)
                .accessibilityIdentifier("seatlayer-map")
                .allowsHitTesting(!decisionVisible)
                .accessibilityHidden(decisionVisible)

                chrome(palette: palette)
                    .padding(.trailing, usesWideLayout ? wideRailWidth : 0)
                    .allowsHitTesting(!decisionVisible)
                    .accessibilityHidden(decisionVisible)

                if presentation.pendingSeat != nil,
                   !immersiveInspectionVisible,
                   style.options.chrome.confirmCard {
                    palette.background.opacity(SeatLayerPickerTransparency.scrimOpacity(
                        requested: 0.48,
                        reduceTransparency: reduceTransparency
                    ))
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                    SeatLayerPickerPartHost(usesWideLayout ? .seatConfirmation : .confirmCard) {
                        if usesWideLayout {
                            SeatLayerPickerSeatConfirmation()
                        } else {
                            SeatLayerConfirmCard()
                        }
                    }
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                        .accessibilitySortPriority(100)
                }

                if let prompt = presentation.activePrompt {
                    palette.background.opacity(SeatLayerPickerTransparency.scrimOpacity(
                        requested: 0.48,
                        reduceTransparency: reduceTransparency
                    ))
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                    Group {
                        switch prompt {
                        case .generalAdmission(let area):
                            SeatLayerPickerPartHost(.generalAdmissionPrompt) {
                                SeatLayerPickerGeneralAdmissionPrompt(area: area)
                            }
                        case .table(let table):
                            SeatLayerPickerPartHost(.tablePrompt) {
                                SeatLayerPickerTablePrompt(table: table)
                            }
                        }
                    }
                    .transition(.scale(scale: 0.965).combined(with: .opacity))
                }

                if chromeVisibility.venue3D {
                    SeatLayerPickerPartHost(.venue3D) {
                        SeatLayerVenue3D(
                            topInset: topChromeHeight + 8,
                            bottomInset: bottomChromeHeight + 10
                        )
                    }
                    .allowsHitTesting(!decisionVisible)
                    .accessibilityHidden(decisionVisible)
                    .opacity(decisionVisible ? 0 : 1)
                }
                if chromeVisibility.panorama {
                    SeatLayerPickerPartHost(.seatViewChrome) {
                        SeatLayerSeatViewChrome(
                            topInset: 10,
                            bottomInset: bottomChromeHeight + 10
                        )
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(decisionVisible)
                    .opacity(decisionVisible ? 0 : 1)
                }

                VStack {
                    Spacer()
                    SeatLayerPickerPartHost(.holdLapse) { SeatLayerHoldLapseNotice() }
                        .padding(.horizontal, 10)
                        .padding(.bottom, bottomChromeHeight + 8)
                }
                .opacity(decisionVisible ? 0 : 1)

                requiredTruthChrome

                if let flight = presentation.selectionFlight,
                   let flightColor = selectionFlightColor(flight, palette: palette) {
                    SeatLayerPickerSelectionFlightOverlay(
                        moment: flight,
                        color: flightColor,
                        layout: usesWideLayout ? .wide : .phone,
                        reduceMotion: reduceMotion
                    )
                    .id(flight.id)
                }

                if usesWideLayout {
                    wideRail(palette: palette)
                        .opacity(decisionVisible ? 0 : 1)
                }

                statusOverlay
            }
            .clipped()
        }
        .background(palette.background)
        .animation(
            seatLayerPickerAnimation(.enter, reduceMotion: reduceMotion),
            value: presentation.pendingSeat?.id
        )
        .animation(
            seatLayerPickerAnimation(.enter, reduceMotion: reduceMotion),
            value: presentation.activePrompt
        )
        .animation(
            seatLayerPickerAnimation(.dock, reduceMotion: reduceMotion),
            value: controller.snapshot?.map.focusedSectionId
        )
        .animation(
            seatLayerPickerAnimation(.immersive, reduceMotion: reduceMotion),
            value: chromeVisibility
        )
        .onChange(of: controller.phase) { phase in
            if case .ready(let info) = phase { callbacks.onReady?(info) }
        }
        .onReceive(controller.chartLoads) { load in
            callbacks.onChartLoad?(load)
        }
        .onChange(of: controller.snapshot?.selection) { selection in
            if let selection { callbacks.onSelectionChanged?(selection) }
        }
        .onChange(of: controller.snapshot?.hold) { hold in
            if let hold { callbacks.onHoldChanged?(hold) }
        }
        .onReceive(controller.holdExpirations) { _ in
            callbacks.onHoldExpired?()
        }
        .onChange(of: controller.lastError) { error in
            if let error { callbacks.onError?(error) }
        }
        .onChange(of: scenePhase) { phase in
            guard controller.isReady else { return }
            Task { @MainActor in
                do {
                    let foreground = phase == .active
                    let lifecycle = try await controller.lifecycle(
                        foreground ? "foreground" : "background"
                    )
                    guard foreground else { return }
                    if style.options.refreshOnResume, lifecycle?.outcome == nil {
                        _ = await controller.refreshAvailability()
                    }
                    _ = try? await controller.synchronize()
                } catch let error as SeatLayerError {
                    controller.record(error)
                } catch {
                    controller.record(.transport(error.localizedDescription))
                }
            }
        }
        .task(id: viewportInsetKey) {
            guard controller.isReady else { return }
            try? await controller.setViewportInsets(viewportInsets)
        }
    }

    @ViewBuilder
    private func chrome(palette: SeatLayerPickerPalette) -> some View {
        VStack(spacing: 0) {
            if style.options.chrome.priceLegend, chromeVisibility.priceLegend {
                SeatLayerPickerPartHost(.legend) { SeatLayerPickerPriceLegend() }
                    .padding(.trailing, showsBuyerViewControl ? 144 : 0)
            }
            if style.options.chrome.floorStrip, chromeVisibility.floors {
                SeatLayerPickerPartHost(.floorStrip) { SeatLayerPickerFloorStrip() }
            }
            Spacer(minLength: 0)
            if style.options.chrome.dock, chromeVisibility.dock {
                SeatLayerPickerPartHost(.dockBar) { SeatLayerPickerDockBar() }
            }
            if style.options.chrome.cartSheet,
               chromeVisibility.cart,
               !usesWideLayout {
                SeatLayerPickerPartHost(.cartSheet) {
                    SeatLayerPickerCartSheet(onCheckout: onCheckout)
                }
            }
        }

        if style.options.chrome.mapControls, chromeVisibility.mapControls {
            SeatLayerPickerPartHost(.mapControls) {
                SeatLayerPickerMapControls(
                    topInset: style.options.chrome.priceLegend
                        && chromeVisibility.priceLegend ? 3 : topChromeHeight + 8,
                    bottomInset: bottomChromeHeight + 10
                )
            }
        }

        if style.options.chrome.accessibility,
           chromeVisibility.accessibility,
           accessibilityAvailability.any {
            VStack {
                Spacer()
                HStack {
                    SeatLayerPickerAccessibilityButton()
                    Spacer()
                }
                .padding(.leading, 10)
                .padding(.bottom, bottomChromeHeight + 10)
            }
        }

    }

    private func wideRail(palette: SeatLayerPickerPalette) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                if !chromeVisibility.immersive {
                    if style.options.chrome.floorSelector {
                        SeatLayerPickerPartHost(.floorSelector) { SeatLayerPickerFloorSelector() }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    SeatLayerPickerPartHost(.sectionNavigator) {
                        SeatLayerPickerSectionNavigator()
                    }
                    .padding(.horizontal, 12)
                    .frame(maxHeight: 190)
                    Rectangle().fill(palette.divider).frame(height: 1)
                }
                if !presentation.confirmedCartLines.isEmpty {
                    SeatLayerPickerPartHost(.cartList) { SeatLayerPickerCartList() }
                    SeatLayerPickerPartHost(.actionError) { SeatLayerPickerActionError() }
                    SeatLayerPickerPartHost(.checkoutBar) {
                        SeatLayerPickerCheckoutBar(onCheckout: onCheckout)
                    }
                    .padding(12)
                } else if !chromeVisibility.immersive {
                    SeatLayerPickerPartHost(.bestAvailable) { SeatLayerBestSeatsForm() }
                        .padding(12)
                }
                Spacer(minLength: 0)
                SeatLayerPickerAttribution()
            }
            .frame(width: wideRailWidth)
            .background(palette.surface)
            .overlay(alignment: .leading) {
                Rectangle().fill(palette.divider).frame(width: 1)
            }
        }
        .accessibilityHidden(decisionVisible)
        .allowsHitTesting(!decisionVisible)
    }

    private var requiredTruthChrome: some View {
        VStack {
            HStack {
                SeatLayerPickerTestModeIndicator()
                Spacer()
            }
            .padding(.leading, 10)
            .padding(.top, topChromeHeight + 8)
            Spacer()
            if !usesWideLayout {
                HStack {
                    Spacer()
                    SeatLayerPickerAttribution()
                }
                .padding(.trailing, 10)
                .padding(.bottom, max(4, bottomChromeHeight + 4))
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch controller.phase {
        case .idle, .loading:
            SeatLayerPickerLoadingView()
        case .failed:
            SeatLayerPickerErrorView { reloadGeneration += 1 }
        case .ready:
            if inventoryIsEmpty {
                SeatLayerPickerPartHost(.empty) { SeatLayerPickerEmptyView() }
            }
        case .destroyed:
            EmptyView()
        }
    }

    private var topChromeHeight: Double {
        var value = style.options.chrome.priceLegend && chromeVisibility.priceLegend ? 50.0 : 0
        if chromeVisibility.floors,
           style.options.chrome.floorStrip,
           (controller.snapshot?.map.floors.count ?? 0) > 1 { value += 46 }
        return value
    }

    private var bottomChromeHeight: Double {
        var value = style.options.chrome.cartSheet
            && !usesWideLayout
            ? (presentation.cartSheetExpanded ? 260.0 : SeatLayerPickerSizeTokens.peekHeight)
            : 0
        if chromeVisibility.dock,
           style.options.chrome.dock,
           controller.snapshot?.map.rung == "seats",
           controller.snapshot?.map.focusedSectionId != nil {
            value += SeatLayerPickerSizeTokens.dockBarHeight
        }
        return value
    }

    private var viewportInsets: SeatLayerPickerViewportInsets {
        SeatLayerPickerViewportInsets(
            top: topChromeHeight,
            right: (usesWideLayout ? wideRailWidth : 0)
                + (style.options.chrome.mapControls && chromeVisibility.mapControls ? 56 : 0),
            bottom: bottomChromeHeight,
            left: style.options.chrome.accessibility
                && chromeVisibility.accessibility
                && accessibilityAvailability.any ? 56 : 0
        )
    }

    private var viewportInsetKey: String {
        // Never include the snapshot revision here. `setViewportInsets` may
        // itself publish a newer snapshot, so revision-keying this task forms
        // a native→runtime→snapshot feedback loop.
        let insets = viewportInsets
        return "\(controller.snapshot?.sessionId ?? "-"):\(Int(insets.top)):\(Int(insets.right)):\(Int(insets.bottom)):\(Int(insets.left))"
    }

    private var chromeVisibility: SeatLayerPickerChromeVisibility {
        SeatLayerPickerImmersive.chromeVisibility(
            SeatLayerPickerImmersive.availability(
                snapshot: controller.snapshot,
                bundle: controller.bundleInfo,
                seatView: controller.seatView
            )
        )
    }

    private var accessibilityAvailability: SeatLayerPickerAccessibilityAvailability {
        SeatLayerPickerAccessibility.availability(
            snapshot: controller.snapshot,
            bundle: controller.bundleInfo
        )
    }

    private var showsBuyerViewControl: Bool {
        guard style.options.chrome.mapControls,
              style.options.chrome.map3D,
              style.options.enable3D,
              chromeVisibility.mapControls,
              let snapshot = controller.snapshot else { return false }
        return snapshot.map.buyerView == "map"
            && snapshot.capabilities.contains("venue3d")
            && controller.supportsVenue3D
    }

    private var decisionVisible: Bool {
        (presentation.pendingSeat != nil && !immersiveInspectionVisible)
            || presentation.activePrompt != nil
    }

    private var immersiveInspectionVisible: Bool {
        guard let pending = presentation.pendingSeat else { return false }
        if controller.snapshot?.map.buyerView == "venue3d" { return true }
        return controller.seatView?.hasContent == true
            && controller.seatView?.seatId == pending.id
    }

    private var inventoryIsEmpty: Bool {
        guard let snapshot = controller.snapshot else { return false }
        if snapshot.event.salesClosed { return true }
        let categoryEvidence = snapshot.categories.filter { !$0.notForSale }
        let gaEvidence = snapshot.generalAdmissionAreas
        guard !categoryEvidence.isEmpty || !gaEvidence.isEmpty else { return false }
        let categoryAvailable = categoryEvidence.contains { $0.available > 0 }
        let gaAvailable = gaEvidence.contains { ($0.available ?? 0) > 0 }
        return !categoryAvailable && !gaAvailable
    }

    private var usesWideLayout: Bool {
        switch style.options.layout {
        case .wide: return true
        case .phone: return false
        case .adaptive: return horizontalSizeClass == .regular
        }
    }

    private var wideRailWidth: Double { 320 }

    private func selectionFlightColor(
        _ flight: SeatLayerPickerSelectionFlightMoment,
        palette: SeatLayerPickerPalette
    ) -> Color? {
        guard !reduceMotion else { return nil }
        let hex = controller.snapshot?.categories.first {
            $0.key == flight.categoryKey
        }?.color
        return hex.flatMap(UIColor.init(slHex:)).map(Color.init(uiColor:)) ?? palette.accent
    }

    private func requestClose() {
        Task { @MainActor in
            await presentation.back(using: onClose)
        }
    }
}
#endif
