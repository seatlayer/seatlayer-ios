import Foundation

/// Fixed chrome band heights the ready layout reserves above and below the map.
enum SeatLayerPickerReadyMetrics {
    static let topRailHeight = 44.0
    static let floorRailHeight = 44.0
    static let truthBandHeight = 26.0
    static let immersiveControlBandHeight = 52.0
    static let attributionControlInset = SeatLayerPickerSizeTokens.attributionHeight + 14
    static let mapControlColumnInset = 56.0
    static let accessibilityColumnInset = 56.0
    static let accessibilityDockBarHeight = 72.0
    static let wideRailWidth = 320.0
    static let accessibilityWideRailWidth = 380.0
}

/// Every immutable fact the ready layout needs in order to decide what the
/// picker shows. Kept free of SwiftUI so the decisions can be exercised by the
/// macOS unit suite, which never compiles a view file.
/// How long the venue may be held back waiting to be framed.
///
/// The insets normally settle on the frame after the first snapshot; this is
/// the backstop for a runtime that never answers.
public let seatLayerPickerMapFramingGraceMs = 700

struct SeatLayerPickerLayoutContext: Sendable, Equatable {
    var snapshot: SeatLayerPickerSnapshot?
    var bundle: BundleInfo?
    var seatView: SeatLayerSeatView?
    var phase: SeatLayerPickerPhase
    var supportsVenue3D: Bool
    var options: SeatLayerPickerOptions
    var pendingSeatId: String?
    var hasActivePrompt: Bool
    var isRegularWidth: Bool
    var isAccessibilityTypeSize: Bool
    var phoneCartHeight: Double
    /// The picker's OWN measured container width, never the device or the
    /// window. Nil before the first layout pass, where the size class is the
    /// only reading there is.
    var containerWidth: Double?
    /// The bottom safe inset, absorbed once by whichever surface owns the
    /// bottom edge.
    var bottomSafeInset: Double

    init(
        snapshot: SeatLayerPickerSnapshot?,
        bundle: BundleInfo?,
        seatView: SeatLayerSeatView?,
        phase: SeatLayerPickerPhase,
        supportsVenue3D: Bool,
        options: SeatLayerPickerOptions,
        pendingSeatId: String?,
        hasActivePrompt: Bool,
        isRegularWidth: Bool,
        isAccessibilityTypeSize: Bool,
        phoneCartHeight: Double,
        containerWidth: Double? = nil,
        bottomSafeInset: Double = 0
    ) {
        self.snapshot = snapshot
        self.bundle = bundle
        self.seatView = seatView
        self.phase = phase
        self.supportsVenue3D = supportsVenue3D
        self.options = options
        self.pendingSeatId = pendingSeatId
        self.hasActivePrompt = hasActivePrompt
        self.isRegularWidth = isRegularWidth
        self.isAccessibilityTypeSize = isAccessibilityTypeSize
        self.phoneCartHeight = phoneCartHeight
        self.containerWidth = containerWidth
        self.bottomSafeInset = max(0, bottomSafeInset)
    }
}

/// Read-only layout facts derived once per body pass. Views read these; no
/// view recomputes them, so a component can be moved between files without
/// carrying layout arithmetic with it.
struct SeatLayerPickerLayoutDecision: Sendable, Equatable {
    let chromeVisibility: SeatLayerPickerChromeVisibility
    let accessibilityAvailability: SeatLayerPickerAccessibilityAvailability
    let usesWideLayout: Bool
    let wideRailWidth: Double
    let isTestMode: Bool
    let priceLegendVisible: Bool
    let showsBuyerViewControl: Bool
    let topRailVisible: Bool
    let floorRailVisible: Bool
    let truthBandVisibleAtTop: Bool
    let primaryChromeHeight: Double
    let topChromeHeight: Double
    let bottomChromeHeight: Double
    let viewportInsets: SeatLayerPickerViewportInsets
    let viewportInsetKey: String
    let attributionVisible: Bool
    let bottomAttributionOverlayVisible: Bool
    let bottomOverlayControlInset: Double
    let decisionVisible: Bool
    let decisionTruthTopReserve: Double
    let immersiveInspectionVisible: Bool
    let inventoryStatus: SeatLayerPickerInventoryStatus
    let statusOverlayVisible: Bool
    let interactionBlocked: Bool
    /// Whether a host opted into the section dock AND it is drawn right now.
    let dockMounted: Bool
    /// What the map's anchor regions measure against.
    let anchorPlan: SeatLayerPickerAnchorPlan

    init(_ context: SeatLayerPickerLayoutContext) {
        let snapshot = context.snapshot
        let options = context.options
        let chrome = options.chrome

        let visibility = SeatLayerPickerImmersive.chromeVisibility(
            SeatLayerPickerImmersive.availability(
                snapshot: snapshot,
                bundle: context.bundle,
                seatView: context.seatView
            )
        )
        chromeVisibility = visibility

        let access = SeatLayerPickerAccessibility.availability(
            snapshot: snapshot,
            bundle: context.bundle
        )
        accessibilityAvailability = access

        switch options.layout {
        case .wide: usesWideLayout = true
        case .phone: usesWideLayout = false
        case .adaptive:
            // The PICKER'S OWN container, not the device and not the window: a
            // picker in a split view, a sheet or an iPad sidebar is exactly as
            // wide as the box it was given, and a size class describes the
            // window. Below `phoneBreakpoint` is compact, at or above
            // `wideBreakpoint` is wide, and between the two the compact
            // composition holds. The size class only decides before the first
            // layout pass has measured anything.
            if let width = context.containerWidth, width > 0 {
                usesWideLayout = width >= SeatLayerPickerSizeTokens.wideBreakpoint
            } else {
                usesWideLayout = context.isRegularWidth
            }
        }
        wideRailWidth = context.isAccessibilityTypeSize
            ? SeatLayerPickerReadyMetrics.accessibilityWideRailWidth
            : SeatLayerPickerReadyMetrics.wideRailWidth

        var testMode = false
        if let mode = snapshot?.event.mode, case .test = mode { testMode = true }
        isTestMode = testMode

        priceLegendVisible = chrome.priceLegend
            && visibility.priceLegend
            && !(snapshot?.categories.filter { !$0.notForSale }.isEmpty ?? true)

        var buyerViewControl = false
        if chrome.mapControls,
           chrome.map3D,
           options.enable3D,
           !visibility.panorama,
           let snapshot {
            buyerViewControl = ["map", "venue3d"].contains(snapshot.map.buyerView)
                && snapshot.capabilities.contains("venue3d")
                && context.supportsVenue3D
        }
        showsBuyerViewControl = buyerViewControl

        topRailVisible = priceLegendVisible || buyerViewControl
        floorRailVisible = chrome.floorStrip
            && visibility.floors
            && (snapshot?.map.floors.count ?? 0) > 1
        truthBandVisibleAtTop = !visibility.panorama && testMode

        var primary = topRailVisible ? SeatLayerPickerReadyMetrics.topRailHeight : 0
        if floorRailVisible { primary += SeatLayerPickerReadyMetrics.floorRailHeight }
        primaryChromeHeight = primary

        var top = primary
        if visibility.venue3D, chrome.venue3D {
            if truthBandVisibleAtTop { top += SeatLayerPickerReadyMetrics.truthBandHeight }
            top += SeatLayerPickerReadyMetrics.immersiveControlBandHeight
        } else if truthBandVisibleAtTop {
            top += SeatLayerPickerReadyMetrics.truthBandHeight
        }
        topChromeHeight = top

        // ONE surface absorbs the bottom safe inset (§2.5). The cart sheet's
        // own container carries it where the sheet is drawn; the dock carries
        // it where a host mounted one; with neither, the bottom anchors sit at
        // the map's own edge and nothing is reported.
        var bottom = chrome.cartSheet && !usesWideLayout
            ? max(SeatLayerPickerSizeTokens.peekHeight, context.phoneCartHeight)
            : 0
        if visibility.dock,
           chrome.dock,
           snapshot?.map.rung == "seats",
           snapshot?.map.focusedSectionId != nil {
            bottom += (context.isAccessibilityTypeSize
                ? SeatLayerPickerReadyMetrics.accessibilityDockBarHeight
                : SeatLayerPickerSizeTokens.dockBarHeight) + context.bottomSafeInset
            dockMounted = true
        } else {
            dockMounted = false
        }
        bottomChromeHeight = bottom

        let insets = SeatLayerPickerViewportInsets(
            top: top,
            right: (usesWideLayout ? wideRailWidth : 0)
                + (chrome.mapControls && visibility.mapControls
                    ? SeatLayerPickerReadyMetrics.mapControlColumnInset
                    : 0),
            bottom: bottom,
            left: chrome.accessibility && visibility.accessibility && access.any
                ? SeatLayerPickerReadyMetrics.accessibilityColumnInset
                : 0
        )
        viewportInsets = insets
        // Never include the snapshot revision here. `setViewportInsets` may
        // itself publish a newer snapshot, so revision-keying the task that
        // reads this forms a native→runtime→snapshot feedback loop.
        viewportInsetKey = "\(snapshot?.sessionId ?? "-")"
            + ":\(Int(insets.top)):\(Int(insets.right))"
            + ":\(Int(insets.bottom)):\(Int(insets.left))"

        var inspection = false
        if let pendingSeatId = context.pendingSeatId {
            if snapshot?.map.buyerView == "venue3d" {
                inspection = true
            } else {
                inspection = context.seatView?.hasContent == true
                    && context.seatView?.seatId == pendingSeatId
            }
        }
        immersiveInspectionVisible = inspection

        decisionVisible = (context.pendingSeatId != nil && !inspection)
            || context.hasActivePrompt

        attributionVisible = seatLayerPickerAttributionVisible(in: snapshot)
        bottomAttributionOverlayVisible = attributionVisible
            && (!usesWideLayout || decisionVisible)
        bottomOverlayControlInset = bottom + (bottomAttributionOverlayVisible
            ? SeatLayerPickerReadyMetrics.attributionControlInset
            : 10)

        decisionTruthTopReserve = truthBandVisibleAtTop
            ? primary + SeatLayerPickerReadyMetrics.truthBandHeight + 8
            : primary + 8

        let status = snapshot.map(seatLayerPickerInventoryStatus) ?? .availableOrUnknown
        inventoryStatus = status

        switch context.phase {
        case .idle, .loading, .failed, .destroyed:
            statusOverlayVisible = true
        case .ready:
            statusOverlayVisible = status != .availableOrUnknown
        }
        interactionBlocked = decisionVisible || statusOverlayVisible

        // Only a mounted dock lifts the bottom anchors, and it lifts them by
        // its own height plus the same safe inset it absorbed. With no dock —
        // the default at every width — they sit at `mapAnchorInset` from the
        // map's own bottom edge.
        anchorPlan = SeatLayerPickerAnchorPlan(
            bottomLift: dockMounted
                ? (context.isAccessibilityTypeSize
                    ? SeatLayerPickerReadyMetrics.accessibilityDockBarHeight
                    : SeatLayerPickerSizeTokens.dockBarHeight) + context.bottomSafeInset
                : 0,
            topTrailingControlHeight: buyerViewControl && !usesWideLayout
                ? SeatLayerPickerSizeTokens.viewModeControlHeight
                : 0,
            backPillHeight: visibility.venue3D && chrome.venue3D
                ? SeatLayerPickerSizeTokens.immersiveBackPillHeight
                : 0
        )
    }
}
