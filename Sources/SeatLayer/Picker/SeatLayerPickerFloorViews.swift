#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

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
#endif
