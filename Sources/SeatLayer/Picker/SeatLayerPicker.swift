#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct SeatLayerPickerCallbacks {
    public var onReady: (@MainActor (ReadyInfo) -> Void)?
    public var onChartLoad: (@MainActor (SeatLayerChartLoad) -> Void)?
    public var onSelectionChanged: (@MainActor ([SelectedSeat]) -> Void)?
    public var onSelectionValidityChanged: (@MainActor (SelectionValidity) -> Void)?
    public var onHoldChanged: (@MainActor (SeatLayerPickerHold) -> Void)?
    public var onHoldTransition: (@MainActor (
        _ hold: SeatLayerPickerHold?,
        _ handoff: SeatLayerPickerCheckoutHandoff?
    ) -> Void)?
    public var onHoldExpired: (@MainActor () -> Void)?
    public var onAccessExpired: (@MainActor (BuyerAccessExpiredEvent) -> Void)?
    public var onAccessUnavailable: (@MainActor (BuyerAccessUnavailableEvent) -> Void)?
    public var onSelectedObjectUnavailable: (@MainActor (SelectedObjectUnavailableEvent) -> Void)?
    public var onClosed: (@MainActor (SeatLayerPickerCloseReason) -> Void)?
    public var onError: (@MainActor (SeatLayerError) -> Void)?
    public var onThemeResolved: (@MainActor (SeatLayerPickerThemeMode) -> Void)?
    public var onSectionFocused: (@MainActor (String) -> Void)?
    public var onSeatSelected: (@MainActor (SelectedSeat) -> Void)?
    public var onSeatRemoved: (@MainActor (String) -> Void)?
    public var onSeatViewOpened: (@MainActor (SelectedSeat) -> Void)?
    public var onContinue: (@MainActor (SeatLayerPickerCheckoutHandoff) -> Void)?

    public init(
        onReady: (@MainActor (ReadyInfo) -> Void)? = nil,
        onChartLoad: (@MainActor (SeatLayerChartLoad) -> Void)? = nil,
        onSelectionChanged: (@MainActor ([SelectedSeat]) -> Void)? = nil,
        onSelectionValidityChanged: (@MainActor (SelectionValidity) -> Void)? = nil,
        onHoldChanged: (@MainActor (SeatLayerPickerHold) -> Void)? = nil,
        onHoldTransition: (@MainActor (
            _ hold: SeatLayerPickerHold?,
            _ handoff: SeatLayerPickerCheckoutHandoff?
        ) -> Void)? = nil,
        onHoldExpired: (@MainActor () -> Void)? = nil,
        onAccessExpired: (@MainActor (BuyerAccessExpiredEvent) -> Void)? = nil,
        onAccessUnavailable: (@MainActor (BuyerAccessUnavailableEvent) -> Void)? = nil,
        onSelectedObjectUnavailable: (@MainActor (SelectedObjectUnavailableEvent) -> Void)? = nil,
        onClosed: (@MainActor (SeatLayerPickerCloseReason) -> Void)? = nil,
        onError: (@MainActor (SeatLayerError) -> Void)? = nil,
        onThemeResolved: (@MainActor (SeatLayerPickerThemeMode) -> Void)? = nil,
        onSectionFocused: (@MainActor (String) -> Void)? = nil,
        onSeatSelected: (@MainActor (SelectedSeat) -> Void)? = nil,
        onSeatRemoved: (@MainActor (String) -> Void)? = nil,
        onSeatViewOpened: (@MainActor (SelectedSeat) -> Void)? = nil,
        onContinue: (@MainActor (SeatLayerPickerCheckoutHandoff) -> Void)? = nil
    ) {
        self.onReady = onReady
        self.onChartLoad = onChartLoad
        self.onSelectionChanged = onSelectionChanged
        self.onSelectionValidityChanged = onSelectionValidityChanged
        self.onHoldChanged = onHoldChanged
        self.onHoldTransition = onHoldTransition
        self.onHoldExpired = onHoldExpired
        self.onAccessExpired = onAccessExpired
        self.onAccessUnavailable = onAccessUnavailable
        self.onSelectedObjectUnavailable = onSelectedObjectUnavailable
        self.onClosed = onClosed
        self.onError = onError
        self.onThemeResolved = onThemeResolved
        self.onSectionFocused = onSectionFocused
        self.onSeatSelected = onSeatSelected
        self.onSeatRemoved = onSeatRemoved
        self.onSeatViewOpened = onSeatViewOpened
        self.onContinue = onContinue
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
    private var observesScenePhase = true

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
        if mergedStrings.localeIdentifier == nil {
            mergedStrings.localeIdentifier = configuration.locale
        }
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
                onClose: onClose,
                observesScenePhase: observesScenePhase
            )
        }
    }

    /// UIKit owns application notifications because `scenePhase` is not
    /// guaranteed to advance inside an embedded `UIHostingController`.
    func lifecycleManagedByUIKit() -> Self {
        var copy = self
        copy.observesScenePhase = false
        return copy
    }
}

private struct SeatLayerPickerReadyLayout: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let configuration: SeatLayerConfiguration
    let callbacks: SeatLayerPickerCallbacks
    let onCheckout: SeatLayerPickerCheckoutHandler
    let onClose: SeatLayerPickerCloseHandler?
    let observesScenePhase: Bool
    @State private var reloadGeneration = 0
    @State private var reportedTheme: SeatLayerPickerThemeMode?
    @State private var reportedReady: ReadyInfo?
    @State private var reportedHold: SeatLayerPickerHold?
    @State private var phoneCartHeight = SeatLayerPickerSizeTokens.peekHeight

    var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        VStack(spacing: 0) {
            if style.options.chrome.header {
                SeatLayerPickerPartHost(.header) {
                    SeatLayerPickerHeader(
                        onClose: onClose == nil ? nil : requestClose,
                        compact: !usesWideLayout
                    )
                }
                // Identity remains readable at larger text sizes without
                // allowing global chrome to consume the compact viewport.
                // Decision surfaces below keep the user's full Dynamic Type.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                .allowsHitTesting(!interactionBlocked)
                .accessibilityHidden(interactionBlocked)

                chrome(palette: palette)
                    .padding(.trailing, usesWideLayout ? wideRailWidth : 0)
                    .allowsHitTesting(!interactionBlocked)
                    .accessibilityHidden(interactionBlocked)

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
                    decisionSurface {
                        SeatLayerPickerPartHost(usesWideLayout ? .seatConfirmation : .confirmCard) {
                            if usesWideLayout {
                                SeatLayerPickerSeatConfirmation()
                            } else {
                                SeatLayerConfirmCard()
                            }
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
                    decisionSurface {
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
                    }
                    .transition(.scale(scale: 0.965).combined(with: .opacity))
                }

                if chromeVisibility.venue3D, style.options.chrome.venue3D {
                    SeatLayerPickerPartHost(.venue3D) {
                        SeatLayerVenue3D(
                            topInset: primaryChromeHeight
                                + (truthBandVisibleAtTop
                                    ? SeatLayerPickerReadyMetrics.truthBandHeight
                                    : 0)
                                + 6,
                            bottomInset: bottomOverlayControlInset,
                            showsMapBackControl: !showsBuyerViewControl
                        )
                    }
                    .allowsHitTesting(!interactionBlocked)
                    .accessibilityHidden(interactionBlocked)
                    .opacity(decisionVisible ? 0 : 1)
                }
                if chromeVisibility.panorama, style.options.chrome.seatViewChrome {
                    SeatLayerPickerPartHost(.seatViewChrome) {
                        SeatLayerSeatViewChrome(
                            topInset: 10,
                            bottomInset: bottomOverlayControlInset
                        )
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(interactionBlocked)
                    .opacity(decisionVisible ? 0 : 1)
                }

                VStack {
                    Spacer()
                    SeatLayerPickerPartHost(.holdLapse) { SeatLayerHoldLapseNotice() }
                        .padding(.horizontal, 10)
                        .padding(.bottom, bottomOverlayControlInset)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                }
                .opacity(decisionVisible ? 0 : 1)

                requiredTruthChrome
                    .dynamicTypeSize(...DynamicTypeSize.large)

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
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .opacity(decisionVisible ? 0 : 1)
                }

                statusOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .allowsHitTesting(statusOverlayVisible)
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
        .onChange(of: controller.phase, perform: reportReady)
        .onReceive(controller.chartLoads) { load in
            callbacks.onChartLoad?(load)
        }
        .onReceive(controller.selectionValidityChanges) { validity in
            callbacks.onSelectionValidityChanged?(validity)
        }
        .onReceive(controller.accessExpirations) { event in
            callbacks.onAccessExpired?(event)
        }
        .onReceive(controller.accessUnavailability) { event in
            callbacks.onAccessUnavailable?(event)
        }
        .onReceive(controller.selectedObjectUnavailability) { event in
            callbacks.onSelectedObjectUnavailable?(event)
        }
        .onReceive(presentation.seatSelections) { seat in
            callbacks.onSeatSelected?(seat)
        }
        .onReceive(presentation.seatRemovals) { label in
            callbacks.onSeatRemoved?(label)
        }
        .onReceive(presentation.seatViewOpenings) { seat in
            callbacks.onSeatViewOpened?(seat)
        }
        .onReceive(presentation.checkoutContinuations) { handoff in
            callbacks.onHoldTransition?(
                controller.snapshot?.hold.active == true ? controller.snapshot?.hold : nil,
                handoff
            )
            callbacks.onContinue?(handoff)
        }
        .onReceive(presentation.closures) { reason in
            callbacks.onClosed?(reason)
        }
        .onChange(of: controller.snapshot?.selection) { selection in
            if let selection { callbacks.onSelectionChanged?(selection) }
        }
        .onChange(of: controller.snapshot?.map.focusedSectionId) { sectionId in
            if let sectionId { callbacks.onSectionFocused?(sectionId) }
        }
        .onChange(of: controller.snapshot?.hold) { hold in
            reportHold(hold)
        }
        .onReceive(controller.holdExpirations) { _ in
            callbacks.onHoldExpired?()
        }
        .onChange(of: controller.lastError) { error in
            if let error { callbacks.onError?(error) }
        }
        .onAppear {
            reportReady(controller.phase)
            reportTheme(dark: palette.dark)
        }
        .onChange(of: palette.dark) { dark in reportTheme(dark: dark) }
        .onChange(of: scenePhase) { phase in
            guard observesScenePhase, controller.isReady else { return }
            let foreground: Bool
            switch phase {
            case .active: foreground = true
            case .background: foreground = false
            case .inactive: return
            @unknown default: return
            }
            Task { @MainActor in
                await controller.reconcileApplicationLifecycle(
                    foreground: foreground,
                    refreshOnResume: style.options.refreshOnResume
                )
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
            if topRailVisible {
                HStack(spacing: 8) {
                    if priceLegendVisible {
                        SeatLayerPickerPartHost(.legend) {
                            SeatLayerPickerPriceLegend(compact: !usesWideLayout)
                        }
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)
                    } else {
                        Spacer(minLength: 0)
                    }
                    if showsBuyerViewControl {
                        SeatLayerPickerBuyerViewControl(compact: !usesWideLayout)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.trailing, 8)
                    }
                }
                .frame(height: SeatLayerPickerReadyMetrics.topRailHeight)
                .dynamicTypeSize(...DynamicTypeSize.large)
            }
            if floorRailVisible {
                SeatLayerPickerPartHost(.floorStrip) {
                    SeatLayerPickerFloorStrip(compact: !usesWideLayout)
                }
                .dynamicTypeSize(...DynamicTypeSize.large)
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
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: SeatLayerPickerCartHeightPreferenceKey.self,
                            value: geometry.size.height
                        )
                    }
                }
                .onPreferenceChange(SeatLayerPickerCartHeightPreferenceKey.self) { height in
                    guard height.isFinite, height > 0 else { return }
                    phoneCartHeight = height
                }
            }
        }

        if style.options.chrome.mapControls, chromeVisibility.mapControls {
            SeatLayerPickerPartHost(.mapControls) {
                SeatLayerPickerMapControls(
                    bottomInset: bottomOverlayControlInset,
                    includeBuyerViewControl: false
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
                if attributionVisible {
                    HStack {
                        Spacer(minLength: 0)
                        SeatLayerPickerAttribution()
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                }
            }
            .frame(width: wideRailWidth)
            .background(palette.surface)
            .overlay(alignment: .leading) {
                Rectangle().fill(palette.divider).frame(width: 1)
            }
        }
        .accessibilityHidden(interactionBlocked)
        .allowsHitTesting(!interactionBlocked)
    }

    @ViewBuilder
    private var requiredTruthChrome: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        ZStack {
            if isTestMode {
                if chromeVisibility.panorama {
                    VStack {
                        Spacer(minLength: 0)
                        HStack {
                            SeatLayerPickerTestModeIndicator()
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, bottomChromeHeight + 6)
                    }
                } else {
                    VStack {
                        HStack {
                            SeatLayerPickerTestModeIndicator()
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, primaryChromeHeight + 4)
                        Spacer(minLength: 0)
                    }
                }
            }

            if bottomAttributionOverlayVisible {
                VStack {
                    Spacer(minLength: 0)
                    HStack {
                        Spacer(minLength: 0)
                        SeatLayerPickerAttribution()
                            .seatLayerPickerTranslucentBackground(
                                palette.surface,
                                opacity: 0.94
                            )
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, bottomChromeHeight + 6)
                }
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
            if inventoryStatus != .availableOrUnknown {
                SeatLayerPickerPartHost(.empty) { SeatLayerPickerEmptyView() }
            }
        case .destroyed:
            EmptyView()
        }
    }

    private var topChromeHeight: Double {
        var value = primaryChromeHeight
        if chromeVisibility.venue3D, style.options.chrome.venue3D {
            if truthBandVisibleAtTop {
                value += SeatLayerPickerReadyMetrics.truthBandHeight
            }
            value += SeatLayerPickerReadyMetrics.immersiveControlBandHeight
        } else if truthBandVisibleAtTop {
            value += SeatLayerPickerReadyMetrics.truthBandHeight
        }
        return value
    }

    private var primaryChromeHeight: Double {
        var value = topRailVisible ? SeatLayerPickerReadyMetrics.topRailHeight : 0
        if floorRailVisible { value += SeatLayerPickerReadyMetrics.floorRailHeight }
        return value
    }

    private var bottomChromeHeight: Double {
        var value = style.options.chrome.cartSheet
            && !usesWideLayout
            ? max(SeatLayerPickerSizeTokens.peekHeight, phoneCartHeight)
            : 0
        if chromeVisibility.dock,
           style.options.chrome.dock,
           controller.snapshot?.map.rung == "seats",
           controller.snapshot?.map.focusedSectionId != nil {
            value += dynamicTypeSize.isAccessibilitySize
                ? 72
                : SeatLayerPickerSizeTokens.dockBarHeight
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
              !chromeVisibility.panorama,
              let snapshot = controller.snapshot else { return false }
        return ["map", "venue3d"].contains(snapshot.map.buyerView)
            && snapshot.capabilities.contains("venue3d")
            && controller.supportsVenue3D
    }

    private var priceLegendVisible: Bool {
        style.options.chrome.priceLegend
            && chromeVisibility.priceLegend
            && !(controller.snapshot?.categories.filter { !$0.notForSale }.isEmpty ?? true)
    }

    private var topRailVisible: Bool {
        priceLegendVisible || showsBuyerViewControl
    }

    private var floorRailVisible: Bool {
        style.options.chrome.floorStrip
            && chromeVisibility.floors
            && (controller.snapshot?.map.floors.count ?? 0) > 1
    }

    private var isTestMode: Bool {
        guard let mode = controller.snapshot?.event.mode else { return false }
        if case .test = mode { return true }
        return false
    }

    private var attributionVisible: Bool {
        seatLayerPickerAttributionVisible(in: controller.snapshot)
    }

    private var truthBandVisibleAtTop: Bool {
        guard !chromeVisibility.panorama else { return false }
        return isTestMode
    }

    private var bottomAttributionOverlayVisible: Bool {
        attributionVisible && (!usesWideLayout || decisionVisible)
    }

    private var bottomOverlayControlInset: Double {
        bottomChromeHeight + (bottomAttributionOverlayVisible
            ? SeatLayerPickerReadyMetrics.attributionControlInset
            : 10)
    }

    private var decisionVisible: Bool {
        (presentation.pendingSeat != nil && !immersiveInspectionVisible)
            || presentation.activePrompt != nil
    }

    private var statusOverlayVisible: Bool {
        switch controller.phase {
        case .idle, .loading, .failed, .destroyed:
            return true
        case .ready:
            return inventoryStatus != .availableOrUnknown
        }
    }

    private var interactionBlocked: Bool {
        decisionVisible || statusOverlayVisible
    }

    private var immersiveInspectionVisible: Bool {
        guard let pending = presentation.pendingSeat else { return false }
        if controller.snapshot?.map.buyerView == "venue3d" { return true }
        return controller.seatView?.hasContent == true
            && controller.seatView?.seatId == pending.id
    }

    private var inventoryStatus: SeatLayerPickerInventoryStatus {
        guard let snapshot = controller.snapshot else { return .availableOrUnknown }
        return seatLayerPickerInventoryStatus(snapshot)
    }

    private var usesWideLayout: Bool {
        switch style.options.layout {
        case .wide: return true
        case .phone: return false
        case .adaptive: return horizontalSizeClass == .regular
        }
    }

    private var wideRailWidth: Double {
        dynamicTypeSize.isAccessibilitySize ? 380 : 320
    }

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
            await presentation.back(using: onClose, closeReason: .closeButton)
        }
    }

    private func decisionSurface<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GeometryReader { geometry in
            if dynamicTypeSize.isAccessibilitySize {
                content()
                    .padding(
                        .top,
                        decisionTruthTopReserve
                    )
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    content()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geometry.size.height)
                }
            }
        }
    }

    private var decisionTruthTopReserve: Double {
        truthBandVisibleAtTop
            ? primaryChromeHeight + SeatLayerPickerReadyMetrics.truthBandHeight + 8
            : primaryChromeHeight + 8
    }

    private func reportTheme(dark: Bool) {
        let mode: SeatLayerPickerThemeMode = dark ? .dark : .light
        guard reportedTheme != mode else { return }
        reportedTheme = mode
        callbacks.onThemeResolved?(mode)
    }

    private func reportHold(_ hold: SeatLayerPickerHold?) {
        guard hold != reportedHold else { return }
        reportedHold = hold
        if let hold { callbacks.onHoldChanged?(hold) }
        callbacks.onHoldTransition?(hold?.active == true ? hold : nil, nil)
    }

    private func reportReady(_ phase: SeatLayerPickerPhase) {
        guard case .ready(let info) = phase else {
            reportedReady = nil
            return
        }
        guard reportedReady == nil else { return }
        reportedReady = info
        callbacks.onReady?(info)
    }
}

private enum SeatLayerPickerReadyMetrics {
    static let topRailHeight = 44.0
    static let floorRailHeight = 44.0
    static let truthBandHeight = 26.0
    static let immersiveControlBandHeight = 52.0
    static let attributionControlInset = SeatLayerPickerSizeTokens.attributionHeight + 14
}

private struct SeatLayerPickerCartHeightPreferenceKey: PreferenceKey {
    static var defaultValue: Double = SeatLayerPickerSizeTokens.peekHeight

    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = max(value, nextValue())
    }
}
#endif
