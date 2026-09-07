#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Which floor of the building the buyer is looking at.
///
/// A theatre stacked three levels deep drawn all at once is a picture of a
/// building, not a plan of one. One track, not a row of loose chips: the
/// floors are one control with a choice in it, and the pill around them is
/// what says so. It scrolls inside itself, so a venue with six levels never
/// pushes the map about.
///
/// It renders nothing unless there is a choice to make, and it is chrome that
/// stands ON the map — at the map's own top edge, stepping below the Map/3D
/// control where that shares the line.
public struct SeatLayerPickerFloorStrip: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    private let compact: Bool
    private let onFloorInfo: (@MainActor () -> Void)?

    public init(compact: Bool = false) {
        self.init(compact: compact, onFloorInfo: nil)
    }

    /// `onFloorInfo` draws the trailing information glyph. A control that
    /// opens nothing is not drawn, so the glyph exists only where a host takes
    /// the action.
    public init(compact: Bool = false, onFloorInfo: (@MainActor () -> Void)?) {
        self.compact = compact
        self.onFloorInfo = onFloorInfo
    }

    /// How tall the track is, so a layout can reserve the band it covers.
    public static func height(compact: Bool = true) -> Double {
        (compact
            ? SeatLayerPickerSizeTokens.floorChipHeight
            : SeatLayerPickerSizeTokens.floorChipHeight + 6)
            + SeatLayerPickerSizeTokens.floorRailPadding * 2
    }

    public var body: some View {
        let snapshot = controller.snapshot
        let floors = snapshot?.map.floors ?? []
        let palette = seatLayerPickerMapChromePalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: snapshot
        )
        // One floor is not a choice, and neither is none. Without
        // `floor-stack-v1` the runtime has not said it stacks at all, so the
        // list is not offered.
        if floors.count > 1,
           controller.supportsFloorStack,
           snapshot?.map.buyerView == "map" {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SeatLayerPickerSizeTokens.floorRailGap) {
                    // The All-floors chip needs BOTH halves of the runtime's
                    // word: the capability, which says it has modes, and a
                    // reported mode, which says which one it is in.
                    if snapshot?.map.floorMode != nil {
                        chip(
                            id: seatLayerAllFloors,
                            label: style.strings.text(.allFloors),
                            selected: snapshot?.map.showsAllFloors == true,
                            palette: palette
                        )
                    }
                    ForEach(floors, id: \.id) { floor in
                        chip(
                            id: floor.id,
                            label: floor.name,
                            selected: snapshot?.map.showsAllFloors != true
                                && snapshot?.map.activeFloorId == floor.id,
                            palette: palette
                        )
                    }
                    if let onFloorInfo {
                        infoGlyph(palette: palette, action: onFloorInfo)
                    }
                }
                .padding(SeatLayerPickerSizeTokens.floorRailPadding)
            }
            .frame(height: Self.height(compact: compact))
            .fixedSize(horizontal: true, vertical: false)
            .background(palette.surface.opacity(0.92))
            .overlay { Capsule().stroke(palette.divider, lineWidth: 1) }
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            .dynamicTypeSize(...DynamicTypeSize.large)
            // tokens.json gap: the rail wants a group name of its own
            // ("floors"); there is no string key for one.
            .accessibilityElement(children: .contain)
            .seatLayerPickerMapChromeRegion(SeatLayerPickerMapChromeKey.floorRail)
        }
    }

    /// Inside the track a chip is a segment, not a card: unselected it is
    /// transparent on the track's own ground and reads as muted text, and only
    /// the floor being drawn wears the accent.
    private func chip(
        id: String,
        label: String,
        selected: Bool,
        palette: SeatLayerPickerPalette
    ) -> some View {
        Button {
            runPickerAction(controller) { _ = try await controller.setFloor(id) }
        } label: {
            Text(label)
                .tracking(SeatLayerPickerSizeTokens.floorChipFontSize * 0.05)
                .seatLayerPickerFont(
                    size: compact
                        ? SeatLayerPickerSizeTokens.floorChipFontSize
                        : SeatLayerPickerSizeTokens.floorChipFontSize + 1,
                    weight: .semibold
                )
                .foregroundColor(selected ? palette.onAccent : palette.mutedText)
                .lineLimit(1)
                .padding(
                    .horizontal,
                    compact
                        ? SeatLayerPickerSizeTokens.floorChipPaddingX
                        : SeatLayerPickerSizeTokens.floorChipPaddingX + 3
                )
                .frame(
                    height: compact
                        ? SeatLayerPickerSizeTokens.floorChipHeight
                        : SeatLayerPickerSizeTokens.floorChipHeight + 6
                )
                .background(selected ? palette.accent : Color.clear)
                .clipShape(Capsule())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!controller.isReady || selected)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func infoGlyph(
        palette: SeatLayerPickerPalette,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .seatLayerPickerFont(
                    size: SeatLayerPickerSizeTokens.floorChipFontSize + 2,
                    weight: .semibold
                )
                .foregroundColor(palette.mutedText)
                .frame(
                    width: SeatLayerPickerSizeTokens.floorInfoSize,
                    height: SeatLayerPickerSizeTokens.floorInfoSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.strings.text(.viewGroupTitle))
    }
}

/// Focused-section context and the way back, for a host that asked for one.
///
/// OFF by default at every width. Focusing a section used to dock this bar
/// onto the map's bottom edge, and it bought a two-tap version of a gesture
/// the finger does better while pushing every bottom-corner control up the
/// screen to make room for it.
public struct SeatLayerPickerDockBar: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @State private var countStep = SeatLayerPickerDockCountStep.full

    public init() {}

    public var body: some View {
        let snapshot = controller.snapshot
        if let section = focusedSection,
           snapshot?.map.rung == "seats",
           snapshot?.map.buyerView == "map" {
            let palette = resolveSeatLayerPickerPalette(
                style: style,
                colorScheme: colorScheme,
                snapshot: snapshot
            )
            let suffix = SeatLayerPickerDockModel.accessibleSuffix(
                section: section,
                filter: snapshot?.map.accessibilityFilter ?? [],
                supportsCounts: controller.supportsSectionAccessCounts
            )
            let name = section.displayLabel ?? section.label
            HStack(spacing: 8) {
                Circle()
                    .fill(sectionColor(section, fallback: palette.accent))
                    .frame(
                        width: SeatLayerPickerSizeTokens.dockDotSize,
                        height: SeatLayerPickerSizeTokens.dockDotSize
                    )
                Text(name)
                    .seatLayerPickerFont(
                        size: SeatLayerPickerSizeTokens.dockNameFontSize,
                        weight: .heavy
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let count = countText(step: countStep, section: section, suffix: suffix) {
                    Text("· \(count)")
                        .seatLayerPickerFont(
                            size: SeatLayerPickerSizeTokens.dockCountFontSize,
                            weight: .semibold
                        )
                        .foregroundColor(palette.mutedText)
                        // The count collapses before the name does and may
                        // never be clipped.
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                }
                Spacer(minLength: 2)
                step("chevron.left", label: style.strings.text(.previousSection), section: adjacent(-1))
                step("chevron.right", label: style.strings.text(.nextSection), section: adjacent(1))
                backOut(palette: palette)
            }
            .foregroundColor(palette.text)
            .padding(.leading, SeatLayerPickerSizeTokens.dockLeadingInset)
            .padding(.trailing, SeatLayerPickerSizeTokens.dockTrailingInset)
            .frame(minHeight: SeatLayerPickerSizeTokens.dockBarHeight)
            .frame(maxWidth: .infinity)
            .background(palette.surface)
            .overlay(alignment: .top) { Rectangle().fill(palette.divider).frame(height: 1) }
            // A light bar on a light map has no edge of its own, so it carries
            // a real separating shadow there.
            .shadow(
                color: .black.opacity(palette.dark ? 0 : 0.14),
                radius: SeatLayerPickerElevationTokens.dockBar,
                y: -2
            )
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: SeatLayerPickerDockWidthKey.self,
                        value: geometry.size.width
                    )
                }
            }
            .onPreferenceChange(SeatLayerPickerDockWidthKey.self) { width in
                countStep = fit(width: width, name: name, section: section, suffix: suffix)
            }
            // The bar keeps the whole sentence whatever the visible ladder
            // chose.
            .accessibilityElement(children: .contain)
            .accessibilityLabel([
                name,
                countText(step: .full, section: section, suffix: suffix) ?? "",
            ].filter { !$0.isEmpty }.joined(separator: ", "))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .seatLayerPickerMapChromeRegion(SeatLayerPickerMapChromeKey.dockBar)
        }
    }

    private func countText(
        step: SeatLayerPickerDockCountStep,
        section: SeatLayerPickerSectionSummary,
        suffix: String?
    ) -> String? {
        guard let text = SeatLayerPickerDockModel.countText(
            step: step,
            seatsLeft: section.seatsLeft,
            sectionLabel: section.displayLabel ?? section.label,
            inSection: { count, label in
                style.strings.text(
                    SeatLayerPickerPluralKeys.seatsLeftInSection.form(count),
                    replacing: ["count": String(count), "section": label]
                )
            },
            plain: { style.strings.text(.seatsLeft, replacing: ["count": String($0)]) }
        ) else { return nil }
        // The suffix rides on both rungs, so it is measured with the count
        // rather than discovered after layout.
        return suffix.map { "\(text) \($0)" } ?? text
    }

    /// The measured ladder: full, then short, then nothing.
    private func fit(
        width: Double,
        name: String,
        section: SeatLayerPickerSectionSummary,
        suffix: String?
    ) -> SeatLayerPickerDockCountStep {
        guard width > 0 else { return .full }
        let fixed = SeatLayerPickerSizeTokens.dockLeadingInset
            + SeatLayerPickerSizeTokens.dockTrailingInset
            + SeatLayerPickerSizeTokens.dockDotSize
            + SeatLayerPickerSizeTokens.dockNavWidth * 2
            + SeatLayerPickerSizeTokens.dockNavGap
            + SeatLayerPickerSizeTokens.minimumHitTarget * 2
            + measure(name, size: SeatLayerPickerSizeTokens.dockNameFontSize, weight: .heavy)
        let budget = width - fixed
        let rungs: [SeatLayerPickerDockCountStep] = [.full, .short]
        let candidates: [(step: SeatLayerPickerDockCountStep, width: Double)] =
            rungs.compactMap { step in
                guard let text = countText(step: step, section: section, suffix: suffix) else {
                    return nil
                }
                return (
                    step,
                    measure(
                        "· \(text)",
                        size: SeatLayerPickerSizeTokens.dockCountFontSize,
                        weight: .semibold
                    )
                )
            }
        return SeatLayerPickerDockModel.fit(candidates, budget: budget)
    }

    private func measure(_ text: String, size: Double, weight: UIFont.Weight) -> Double {
        Double((text as NSString).size(withAttributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
        ]).width) + 8
    }

    private func backOut(palette: SeatLayerPickerPalette) -> some View {
        Button {
            runPickerAction(controller) { _ = try await controller.overview() }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .seatLayerPickerFont(
                        size: SeatLayerPickerSizeTokens.dockBackChevronSize,
                        weight: .bold
                    )
                Text(style.strings.text(.overview))
                    .seatLayerPickerFont(
                        size: SeatLayerPickerSizeTokens.dockBackFontSize,
                        weight: .heavy
                    )
            }
            .foregroundColor(palette.accent)
            .padding(.horizontal, 10)
            .frame(height: SeatLayerPickerSizeTokens.dockBackHeight)
            .background(palette.surface)
            .overlay {
                // The hairline is the accent mixed into the divider on its way
                // out, so the control reads as a way back rather than a chip.
                Capsule().stroke(palette.accent.opacity(0.35), lineWidth: 1)
            }
            .clipShape(Capsule())
            .frame(minWidth: SeatLayerPickerSizeTokens.minimumHitTarget, minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private func step(
        _ symbol: String,
        label: String,
        section: SeatLayerPickerSectionSummary?
    ) -> some View {
        Button {
            guard let section else { return }
            runPickerAction(controller) { _ = try await controller.focusSection(section.id) }
        } label: {
            Image(systemName: symbol)
                .seatLayerPickerFont(
                    size: SeatLayerPickerSizeTokens.dockNavIconSize,
                    weight: .bold
                )
                .frame(
                    width: SeatLayerPickerSizeTokens.dockNavWidth,
                    height: SeatLayerPickerSizeTokens.dockNavHeight
                )
                .overlay { Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1) }
                .frame(
                    width: SeatLayerPickerSizeTokens.minimumHitTarget,
                    height: SeatLayerPickerSizeTokens.minimumHitTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(section == nil)
        .accessibilityLabel(label)
    }

    /// The dot is painted from `dominantCategoryKey` in preference to a copied
    /// colour: the key survives a colourblind-safe palette and a recolour.
    private func sectionColor(
        _ section: SeatLayerPickerSectionSummary,
        fallback: Color
    ) -> Color {
        let raw = controller.snapshot?.categories
            .first { $0.key == section.dominantCategoryKey }?.color
            ?? section.color
        guard let raw, let color = UIColor(slHex: raw) else { return fallback }
        return Color(uiColor: color)
    }
}

private struct SeatLayerPickerDockWidthKey: PreferenceKey {
    static var defaultValue: Double = 0
    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = max(value, nextValue())
    }
}
#endif
