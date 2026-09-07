#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The palette for chrome that sits ON the map surface.
///
/// Identical to the picker's own palette except while the immersive scene is
/// up, when it is the dark one whichever side the picker is on: white chrome
/// over a lit venue reads as a mistake, and the rail, the discs and the 3D
/// chrome all have to cap the same surface.
func seatLayerPickerMapChromePalette(
    style: SeatLayerPickerStyleEnvironment,
    colorScheme: ColorScheme,
    snapshot: SeatLayerPickerSnapshot?
) -> SeatLayerPickerPalette {
    guard snapshot?.map.isVenue3D == true else {
        return resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: snapshot
        )
    }
    var immersive = style
    immersive.mode = .dark
    return resolveSeatLayerPickerPalette(
        style: immersive,
        colorScheme: .dark,
        snapshot: snapshot
    )
}

/// The ground and edge for a control that floats ON the map.
///
/// The panel's surface and divider are not a ground for this: they are the
/// colours of a plate the map is drawn *beside*, and over the venue they
/// disappear into it — a translucent dark surface over a dark map measured
/// 1.14:1, a dark blob on dark. The two sides need different halves of the
/// fix, which is why this is two colours rather than a stronger opacity: dark
/// separates by the fill, light by the edge, since white is already as far
/// from a light map as a colour can get and still only 1.17:1 from it.
func seatLayerPickerMapChromeDisc(
    _ palette: SeatLayerPickerPalette
) -> (ground: Color, line: Color) {
    (palette.chrome, palette.chromeLine)
}

/// Map or 3D, as one segmented control.
///
/// Two labelled halves say what the other state is; a single icon button only
/// says that something will change.
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
        let palette = seatLayerPickerMapChromePalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: snapshot
        )
        let disc = seatLayerPickerMapChromeDisc(palette)
        if let snapshot,
           ["map", "venue3d"].contains(snapshot.map.buyerView),
           style.options.enable3D,
           style.options.chrome.map3D,
           snapshot.capabilities.contains("venue3d"),
           controller.supportsVenue3D {
            HStack(spacing: 2) {
                segment(
                    style.strings.text(.mapView),
                    name: style.strings.text(.flat2dMap),
                    selected: !venue3D,
                    palette: palette
                ) {
                    _ = try await controller.setBuyerView("map")
                }
                segment(
                    style.strings.text(.venue3D),
                    name: style.strings.text(.interactive3dVenueView),
                    selected: venue3D,
                    palette: palette
                ) {
                    _ = try await controller.setBuyerView("venue3d")
                }
            }
            // The bed is INSIDE the track's own line, the way a border-box is
            // on the web, so the pair stands exactly as tall as the layout
            // reserves for it.
            .padding(3)
            .frame(minHeight: SeatLayerPickerSizeTokens.viewModeControlHeight)
            .background(disc.ground)
            .overlay { Capsule().stroke(disc.line, lineWidth: 1) }
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
            .dynamicTypeSize(...DynamicTypeSize.large)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(style.strings.text(.venueView))
            .seatLayerPickerMapChromeRegion(SeatLayerPickerMapChromeKey.viewMode)
        }
    }

    private func segment(
        _ label: String,
        name: String,
        selected: Bool,
        palette: SeatLayerPickerPalette,
        action: @escaping @MainActor () async throws -> Void
    ) -> some View {
        Button {
            runPickerAction(controller, action)
        } label: {
            Text(label)
                .tracking(SeatLayerPickerSizeTokens.viewModeLabelFontSize * 0.04)
                .seatLayerPickerFont(
                    size: SeatLayerPickerSizeTokens.viewModeLabelFontSize,
                    weight: .heavy
                )
                .foregroundColor(selected ? palette.onAccent : palette.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(
                    minWidth: SeatLayerPickerSizeTokens.viewModeButtonMinWidth,
                    minHeight: SeatLayerPickerSizeTokens.viewModeButtonHeight
                )
                .background { if selected { Capsule().fill(palette.accent) } }
                .clipShape(Capsule())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!controller.isReady || selected)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Required chrome for a test event. It has no host switch, and exactly one
/// may render.
public struct SeatLayerPickerTestModeIndicator: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if isTest {
            let palette = seatLayerPickerMapChromePalette(
                style: style,
                colorScheme: colorScheme,
                snapshot: controller.snapshot
            )
            // ONE recipe in both themes. The chip is not painted on the
            // surface; it is painted on a warning wash over it, which is a
            // different and always-warmer colour — so the ink is resolved
            // against the wash. A fixed blend measured against the bare
            // surface produced a 2.3:1 chip on a light host theme over a chart
            // saved dark.
            let ink = warningInk(palette)
            HStack(spacing: 7) {
                Circle()
                    .fill(palette.warning)
                    .frame(
                        width: SeatLayerPickerSizeTokens.testChipDotSize,
                        height: SeatLayerPickerSizeTokens.testChipDotSize
                    )
                    // A hard halo, drawn with no blur: a status light, not a glow.
                    .overlay {
                        Circle().stroke(palette.warning.opacity(0.22), lineWidth: 3)
                            .padding(-1.5)
                    }
                Text(style.strings.text(.testMode))
                    .tracking(SeatLayerPickerSizeTokens.testChipFontSize * 0.01)
                    .seatLayerPickerFont(
                        size: SeatLayerPickerSizeTokens.testChipFontSize,
                        weight: .bold
                    )
                    .foregroundColor(ink)
                    .lineLimit(1)
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .frame(height: SeatLayerPickerSizeTokens.testChipHeight)
            .background(
                palette.warning.opacity(SeatLayerPickerOpacityTokens.warnPillWash)
                    .background(palette.surface)
            )
            .overlay { Capsule().stroke(palette.warning.opacity(0.5), lineWidth: 1) }
            .clipShape(Capsule())
            .dynamicTypeSize(...DynamicTypeSize.large)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(style.strings.text(.testModeLong))
            .accessibilityHint(style.strings.text(.testModeExplained))
            .seatLayerPickerMapChromeRegion(SeatLayerPickerMapChromeKey.testChip)
        }
    }

    private func warningInk(_ palette: SeatLayerPickerPalette) -> Color {
        let hexes = palette.dark ? SeatLayerPickerDarkColorTokens.all : SeatLayerPickerLightColorTokens.all
        guard let warning = SeatLayerPickerRGB(hex: hexes["warning"] ?? ""),
              let text = SeatLayerPickerRGB(hex: hexes["text"] ?? ""),
              let surface = SeatLayerPickerRGB(hex: hexes["surface"] ?? "") else {
            return palette.text
        }
        return pickerColor(
            seatLayerPickerWarnPillInk(warning: warning, text: text, surface: surface).hex
        )
    }

    private var isTest: Bool {
        guard let mode = controller.snapshot?.event.mode else { return false }
        if case .test = mode { return true }
        return false
    }
}

/// The keys the map's own chrome registers its rectangles under.
enum SeatLayerPickerMapChromeKey {
    static let viewMode = "seatlayer.viewMode"
    static let testChip = "seatlayer.testChip"
    static let floorRail = "seatlayer.floorRail"
    static let dockBar = "seatlayer.dockBar"
    static let controlColumn = "seatlayer.controlColumn"
    static let backToVenue = "seatlayer.backToVenue"
    static let bottomLeading = "seatlayer.bottomLeading"
}

/// The controls that stand on the map.
///
/// One column at the bottom-trailing anchor on both compositions, headed by
/// the accessibility disc: a control about who can sit where does not belong
/// below the controls about how close the camera is, and it stood alone in the
/// opposite corner — one control facing a stack of them — until that was
/// retired.
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
        topInset: Double = SeatLayerPickerSizeTokens.mapAnchorInset,
        bottomInset: Double = 0,
        edgeInset: Double = SeatLayerPickerSizeTokens.mapAnchorInset,
        includeBuyerViewControl: Bool = true
    ) {
        self.topInset = max(0, topInset)
        self.bottomInset = max(0, bottomInset)
        self.edgeInset = max(0, edgeInset)
        self.includeBuyerViewControl = includeBuyerViewControl
    }

    public var body: some View {
        let snapshot = controller.snapshot
        let palette = seatLayerPickerMapChromePalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: snapshot
        )
        let immersive = SeatLayerPickerImmersive.availability(
            snapshot: snapshot,
            bundle: controller.bundleInfo,
            seatView: controller.seatView
        )
        let access = SeatLayerPickerAccessibility.availability(
            snapshot: snapshot,
            bundle: controller.bundleInfo
        )
        // Inside the immersive scene there is no flat map to fit, filter or
        // pan, and the scene owns that corner. Only the way back stays.
        let onMap = snapshot?.map.isVenue3D != true && !immersive.panoramaChrome
        let plan = SeatLayerPickerMapControlModel.plan(
            map: snapshot?.map,
            chrome: style.options.chrome,
            wide: usesWideLayout,
            onMap: onMap,
            offersVenue3D: style.options.enable3D
                && snapshot?.capabilities.contains("venue3d") == true
                && controller.supportsVenue3D,
            offersColorblind: access.colorblind,
            offersAccessibility: access.any
        )
        if snapshot != nil, !immersive.panoramaChrome {
            ZStack {
                if includeBuyerViewControl {
                    anchored(.topTrailing) {
                        SeatLayerPickerBuyerViewControl(compact: !usesWideLayout)
                    }
                }
                if plan.showsBackToVenue {
                    anchored(.topLeading) {
                        disc(
                            "arrow.backward",
                            label: style.strings.text(.backToVenue),
                            palette: palette
                        ) { _ = try await controller.overview() }
                        .seatLayerPickerMapChromeRegion(SeatLayerPickerMapChromeKey.backToVenue)
                    }
                }
                if plan.controls.contains(.colorblind), !usesWideLayout {
                    anchored(.bottomLeading) {
                        colorblindDisc(palette: palette)
                            .seatLayerPickerMapChromeRegion(
                                SeatLayerPickerMapChromeKey.bottomLeading
                            )
                    }
                }
                if !column(plan).isEmpty {
                    anchored(.bottomTrailing) {
                        VStack(alignment: .trailing, spacing: anchorPlan.gap(for: .bottomTrailing)) {
                            ForEach(column(plan), id: \.self) { control in
                                self.control(control, plan: plan, palette: palette)
                            }
                        }
                        .seatLayerPickerMapChromeRegion(
                            SeatLayerPickerMapChromeKey.controlColumn
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func column(_ plan: SeatLayerPickerControlColumnPlan) -> [SeatLayerPickerMapControl] {
        plan.controls.filter { control in
            // The colourblind disc has its own anchor on the phone; on wide it
            // rides at the foot of the column with the rest.
            !(control == .colorblind && !usesWideLayout)
        }
    }

    @ViewBuilder
    private func control(
        _ control: SeatLayerPickerMapControl,
        plan: SeatLayerPickerControlColumnPlan,
        palette: SeatLayerPickerPalette
    ) -> some View {
        switch control {
        case .accessibility:
            // The stepper that walks the sections holding matching spaces
            // rides beside the disc rather than above it: they are one
            // subject. It draws nothing at all until a filter is on and the
            // runtime answers the tour.
            HStack(spacing: SeatLayerPickerSizeTokens.accessStepGap) {
                SeatLayerPickerAccessibleStepper()
                SeatLayerPickerAccessibilityButton()
            }
        case .zoomIn:
            disc(
                "plus",
                label: style.strings.text(.zoomIn),
                palette: palette,
                retired: plan.isRetired(.zoomIn)
            ) { try await controller.zoomIn() }
        case .zoomOut:
            disc(
                "minus",
                label: style.strings.text(.zoomOut),
                palette: palette,
                retired: plan.isRetired(.zoomOut)
            ) { try await controller.zoomOut() }
        case .wholeVenue:
            // ALWAYS live, and it sends `picker.overview` rather than
            // `picker.zoomToFit`, so a framed section is released by the same
            // press that fits the chart. The camera facts in the snapshot are
            // only as fresh as the last state change and a pinch changes no
            // state, so dimming this on a stale "already home" reading
            // stranded a buyer with nothing left to press.
            disc(
                "dot.viewfinder",
                label: style.strings.text(.fitWholeVenue),
                palette: palette
            ) { _ = try await controller.overview() }
        case .viewMode:
            SeatLayerPickerBuyerViewControl(compact: false)
        case .colorblind:
            colorblindDisc(palette: palette)
        }
    }

    private func colorblindDisc(palette: SeatLayerPickerPalette) -> some View {
        let selected = controller.snapshot?.map.colorblindSafe == true
        return disc(
            "eye",
            label: style.strings.text(.colorblindSafe),
            palette: palette,
            active: selected
        ) {
            _ = try await controller.setColorblindSafe(!selected)
        }
    }

    /// One disc of the map's chrome, in all three of its states.
    ///
    /// A retired disc has to LOOK retired: these dim in place rather than
    /// disappearing, which only works as an answer — "you are already looking
    /// at everything" — if the buyer can see that it is one. The ground never
    /// washes; the glyph, the ring and the shadow carry it.
    private func disc(
        _ symbol: String,
        label: String,
        palette: SeatLayerPickerPalette,
        active: Bool = false,
        retired: Bool = false,
        action: @escaping @MainActor () async throws -> Void
    ) -> some View {
        let chrome = seatLayerPickerMapChromeDisc(palette)
        let disabled = retired || !controller.isReady
        return Button {
            runPickerAction(controller, action)
        } label: {
            Image(systemName: symbol)
                .seatLayerPickerFont(size: 20, weight: .semibold)
                .foregroundColor(
                    active
                        ? palette.accent
                        : disabled ? palette.mutedText.opacity(0.55) : palette.text
                )
                .frame(
                    width: SeatLayerPickerSizeTokens.mapControlSize,
                    height: SeatLayerPickerSizeTokens.mapControlSize
                )
                .background(
                    active
                        ? palette.accent.opacity(0.13).background(chrome.ground)
                        : chrome.ground.opacity(1).background(chrome.ground)
                )
                .overlay {
                    Circle().stroke(
                        active
                            ? palette.accent.opacity(0.52)
                            : disabled ? chrome.line.opacity(0.6) : chrome.line,
                        lineWidth: 1
                    )
                }
                .clipShape(Circle())
                .shadow(
                    color: .black.opacity(disabled ? 0 : 0.15),
                    radius: disabled ? 0 : 8,
                    y: disabled ? 0 : 3
                )
                .frame(
                    width: SeatLayerPickerSizeTokens.minimumHitTarget,
                    height: SeatLayerPickerSizeTokens.minimumHitTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// The map's own anchor regions. Nothing here free-floats.
    private var anchorPlan: SeatLayerPickerAnchorPlan {
        SeatLayerPickerAnchorPlan(inset: edgeInset, bottomLift: bottomInset)
    }

    @ViewBuilder
    private func anchored<Content: View>(
        _ region: SeatLayerPickerMapAnchorRegion,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let insets = anchorPlan.insets(for: region)
        VStack(spacing: 0) {
            if insets.top == nil { Spacer(minLength: 0) }
            HStack(spacing: 0) {
                if insets.leading == nil { Spacer(minLength: 0) }
                content()
                if insets.trailing == nil { Spacer(minLength: 0) }
            }
            if insets.bottom == nil { Spacer(minLength: 0) }
        }
        .padding(.top, region == .topLeading ? topInset : (insets.top ?? 0))
        .padding(.leading, insets.leading ?? 0)
        .padding(.bottom, insets.bottom ?? 0)
        .padding(.trailing, insets.trailing ?? 0)
    }

    private var usesWideLayout: Bool {
        switch style.options.layout {
        case .wide: return true
        case .phone: return false
        case .adaptive: return horizontalSizeClass == .regular
        }
    }
}

/// A standalone colourblind-safe control for custom SwiftUI compositions.
///
/// On the phone this lives inside the accessibility sheet rather than on the
/// map, which is where a buyer who needs it goes looking.
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
        let palette = seatLayerPickerMapChromePalette(
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
#endif
