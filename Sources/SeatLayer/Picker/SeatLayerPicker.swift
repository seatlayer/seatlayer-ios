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
    @State private var containerWidth: Double?
    @State private var bottomSafeInset: Double = 0
    @State private var previousRung: String?

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
            // A row of the column rather than chrome on the map: the prices
            // are the key to what the buyer is looking at, so they never sit
            // on top of it.
            if priceLegendVisible {
                SeatLayerPickerPartHost(.legend) {
                    SeatLayerPickerPriceLegend(compact: !usesWideLayout)
                }
                .dynamicTypeSize(...DynamicTypeSize.large)
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
                .accessibilityHidden(interactionBlocked)

                if floorRailVisible {
                    VStack(spacing: 0) {
                        SeatLayerPickerPartHost(.floorStrip) {
                            SeatLayerPickerFloorStrip(compact: !usesWideLayout)
                        }
                        .padding(.top, decision.anchorPlan.leadingRailTop)
                        .dynamicTypeSize(...DynamicTypeSize.large)
                        Spacer(minLength: 0)
                    }
                    .padding(.trailing, usesWideLayout ? wideRailWidth : 0)
                    .allowsHitTesting(!interactionBlocked)
                    .accessibilityHidden(interactionBlocked)
                }

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

                SeatLayerPickerToastBand(
                    bottomInset: bottomChromeHeight,
                    lifted: decisionVisible
                )

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

                // A decision surface takes the whole map: its scrim covers the
                // page, and on iOS the tap that dismisses it reaches the page
                // as well unless the runtime is standing guard first.
                SeatLayerPickerMapCover(key: "decision", active: decisionVisible)
            }
            .clipped()
            .seatLayerPickerBlockedRegions(interactionEnabled: !interactionBlocked)
        }
        .background(palette.background)
        .seatLayerPickerContainerMetrics(
            width: $containerWidth,
            bottomSafeInset: $bottomSafeInset
        )
        .seatLayerPickerToastFeed()
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
        .onChange(of: controller.snapshot?.map.rung) { rung in
            let previous = previousRung
            previousRung = rung
            collapseSheetIfMapTakesOver(previousRung: previous, rung: rung)
        }
        .onChange(of: presentation.pendingSeat?.id) { _ in
            collapseSheetIfMapTakesOver(previousRung: previousRung, rung: previousRung)
        }
        .onChange(of: presentation.candidateSeat?.id) { _ in
            collapseSheetIfMapTakesOver(previousRung: previousRung, rung: previousRung)
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

        // One column, and the accessibility disc is its head: the filters, the
        // camera and the way back are one subject in one place rather than a
        // stack in one corner and a lone disc in the other.
        if style.options.chrome.mapControls, chromeVisibility.mapControls {
            SeatLayerPickerPartHost(.mapControls) {
                SeatLayerPickerMapControls(
                    bottomInset: decision.anchorPlan.bottomLift,
                    includeBuyerViewControl: showsBuyerViewControl
                )
            }
            .opacity(decisionVisible ? 0 : 1)
            .allowsHitTesting(!decisionVisible)
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

            if bottomAttributionOverlayVisible, !phoneCartSheetVisible {
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

    /// Immutable inputs for the layout decisions. Everything the ready layout
    /// needs to lay itself out arrives through this one value.
    private var layoutContext: SeatLayerPickerLayoutContext {
        SeatLayerPickerLayoutContext(
            snapshot: controller.snapshot,
            bundle: controller.bundleInfo,
            seatView: controller.seatView,
            phase: controller.phase,
            supportsVenue3D: controller.supportsVenue3D,
            options: style.options,
            pendingSeatId: presentation.pendingSeat?.id,
            hasActivePrompt: presentation.activePrompt != nil,
            isRegularWidth: horizontalSizeClass == .regular,
            isAccessibilityTypeSize: dynamicTypeSize.isAccessibilitySize,
            phoneCartHeight: phoneCartHeight,
            containerWidth: containerWidth,
            bottomSafeInset: bottomSafeInset
        )
    }

    private var decision: SeatLayerPickerLayoutDecision {
        SeatLayerPickerLayoutDecision(layoutContext)
    }

    private var topChromeHeight: Double { decision.topChromeHeight }

    private var primaryChromeHeight: Double { decision.primaryChromeHeight }

    private var bottomChromeHeight: Double { decision.bottomChromeHeight }

    private var viewportInsets: SeatLayerPickerViewportInsets { decision.viewportInsets }

    private var viewportInsetKey: String { decision.viewportInsetKey }

    private var chromeVisibility: SeatLayerPickerChromeVisibility { decision.chromeVisibility }

    private var accessibilityAvailability: SeatLayerPickerAccessibilityAvailability {
        decision.accessibilityAvailability
    }

    private var showsBuyerViewControl: Bool { decision.showsBuyerViewControl }

    private var priceLegendVisible: Bool { decision.priceLegendVisible }

    private var floorRailVisible: Bool { decision.floorRailVisible }

    private var isTestMode: Bool { decision.isTestMode }

    private var attributionVisible: Bool { decision.attributionVisible }

    private var truthBandVisibleAtTop: Bool { decision.truthBandVisibleAtTop }

    private var bottomAttributionOverlayVisible: Bool { decision.bottomAttributionOverlayVisible }

    private var bottomOverlayControlInset: Double { decision.bottomOverlayControlInset }

    private var decisionVisible: Bool { decision.decisionVisible }

    /// Whether the phone's ticket sheet is drawn. Its foot carries the credit,
    /// so the floating one would be the same mark twice.
    private var phoneCartSheetVisible: Bool {
        style.options.chrome.cartSheet && chromeVisibility.cart && !usesWideLayout
    }

    /// The sheet never opens itself and it gives the map back the moment the
    /// buyer goes back to it.
    private func collapseSheetIfMapTakesOver(previousRung: String?, rung: String?) {
        guard seatLayerPickerSheetShouldCollapse(
            detent: presentation.sheetDetent,
            cardIsUp: presentation.pendingSeat != nil || presentation.candidateSeat != nil,
            previousRung: previousRung,
            rung: rung
        ) else { return }
        presentation.sheetDetent = .peek
    }

    private var statusOverlayVisible: Bool { decision.statusOverlayVisible }

    private var interactionBlocked: Bool { decision.interactionBlocked }

    private var immersiveInspectionVisible: Bool { decision.immersiveInspectionVisible }

    private var inventoryStatus: SeatLayerPickerInventoryStatus { decision.inventoryStatus }

    private var usesWideLayout: Bool { decision.usesWideLayout }

    private var wideRailWidth: Double { decision.wideRailWidth }

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

    private var decisionTruthTopReserve: Double { decision.decisionTruthTopReserve }

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

private struct SeatLayerPickerCartHeightPreferenceKey: PreferenceKey {
    static var defaultValue: Double = SeatLayerPickerSizeTokens.peekHeight

    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = max(value, nextValue())
    }
}
#endif
