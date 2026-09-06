#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

private struct SeatLayerPickerLegendOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SeatLayerPickerLegendContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private let seatLayerPickerLegendScrollSpace = "seatlayer-picker-legend"

/// What each colour on the map costs.
///
/// A band of its own between the header and the map — not chrome floated over
/// it. On a busy chart the seat numbers read through the gaps and the last
/// chip clipped under the Map/3D control, so the rail owns a row of the
/// picker's column and the map surface begins where the rail ends.
///
/// One horizontally scrolling row of chips, with the way out of a filter
/// pinned outside the scroller so it can never scroll away.
public struct SeatLayerPickerPriceLegend: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var revealed = false
    private let compact: Bool

    public init(compact: Bool = false) {
        self.compact = compact
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
        let chips = SeatLayerPickerLegendModel.chips(
            snapshot: snapshot,
            compact: compact,
            currency: snapshot?.currency ?? "USD",
            allPricesLabel: style.strings.text(.allPrices),
            amount: { amount in
                seatLayerPickerMoney(
                    amount,
                    currency: snapshot?.currency ?? "USD",
                    style: style
                )
            },
            soldOutSuffix: style.strings.text(.soldOutTitle)
        )
        if !immersive.panoramaChrome, let pinned = chips.first {
            HStack(spacing: 5) {
                chip(pinned, palette: palette, index: 0)
                scroller(Array(chips.dropFirst()), palette: palette)
            }
            .padding(.horizontal, compact ? 10 : 12)
            .frame(height: SeatLayerPickerSizeTokens.topRailHeight)
            .frame(maxWidth: .infinity)
            .background(palette.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(palette.divider).frame(height: 1)
            }
            .dynamicTypeSize(...DynamicTypeSize.large)
            // tokens.json gap: the rail wants a group name of its own
            // ("ticket prices"); there is no string key for one, and naming it
            // after the first chip would be worse than leaving the group
            // unnamed.
            .accessibilityElement(children: .contain)
            .onAppear {
                // The rail arrives once. Filtering does not re-animate it: a
                // row that restaggers on every press reads as a reload.
                guard !revealed else { return }
                revealed = true
            }
        }
    }

    private func scroller(
        _ chips: [SeatLayerPickerLegendChip],
        palette: SeatLayerPickerPalette
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(Array(chips.enumerated()), id: \.element.categoryKey) { index, entry in
                    chip(entry, palette: palette, index: index + 1)
                }
                if SeatLayerPickerLegendModel.showsUnavailableKey(compact: compact) {
                    unavailableKey(palette: palette)
                }
            }
            // One point of air, so a chip's hairline is not shaved by the
            // scroller's own edge; the rail's own margin is outside it.
            .padding(1)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: SeatLayerPickerLegendContentWidthKey.self,
                            value: geometry.size.width
                        )
                        .preference(
                            key: SeatLayerPickerLegendOffsetKey.self,
                            value: geometry
                                .frame(in: .named(seatLayerPickerLegendScrollSpace)).minX
                        )
                }
            }
        }
        .coordinateSpace(name: seatLayerPickerLegendScrollSpace)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: SeatLayerPickerLegendViewportWidthKey.self,
                    value: geometry.size.width
                )
            }
        }
        .mask { overflowMask }
        .onPreferenceChange(SeatLayerPickerLegendContentWidthKey.self) { contentWidth = $0 }
        .onPreferenceChange(SeatLayerPickerLegendViewportWidthKey.self) { viewportWidth = $0 }
        .onPreferenceChange(SeatLayerPickerLegendOffsetKey.self) { scrollOffset = $0 }
    }

    @ViewBuilder
    private func chip(
        _ entry: SeatLayerPickerLegendChip,
        palette: SeatLayerPickerPalette,
        index: Int
    ) -> some View {
        let naming = entry.colorHex != nil
        Button {
            runPickerAction(controller) {
                // `focus` on BOTH directions. Turning a band on flies to its
                // seats; turning it off is "show me everything" and has to
                // answer with the whole venue. Clearing without it left the
                // buyer inside their drill-in with the block melt running
                // under seats drawn at full strength.
                let wanted = entry.selected ? nil : entry.categoryKey
                _ = try await controller.setCategoryFilter(
                    wanted.map { [$0] } ?? [],
                    focus: true
                )
            }
        } label: {
            HStack(spacing: 5) {
                if let hex = entry.colorHex {
                    categoryDot(hex: hex, palette: palette, selected: entry.selected)
                }
                Text(entry.label)
                    .strikethrough(entry.soldOut, color: palette.mutedText)
                    .lineLimit(1)
                    .monospacedDigit()
            }
            .seatLayerPickerFont(
                size: compact ? SeatLayerPickerSizeTokens.legendChipFontSize : 12,
                // The way out is the one chip that is a word rather than a
                // number, so it is set a little lighter than the prices it
                // leads.
                weight: naming ? .heavy : .bold
            )
            .foregroundColor(
                entry.selected
                    ? palette.onAccent
                    : entry.soldOut ? palette.mutedText : palette.text
            )
            .padding(.leading, compact ? 7 : 10)
            .padding(.trailing, compact ? 9 : 10)
            .frame(height: chipInkHeight)
            .background(chipGround(entry, palette: palette, naming: naming))
            .overlay {
                Capsule().stroke(
                    entry.selected ? Color.clear : palette.divider,
                    lineWidth: 1
                )
            }
            .clipShape(Capsule())
            // The ink is the chip; the target is the whole band it sits in.
            .frame(
                minWidth: SeatLayerPickerSizeTokens.minimumHitTarget,
                minHeight: SeatLayerPickerSizeTokens.minimumHitTarget
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!controller.isReady || entry.soldOut)
        .accessibilityLabel(entry.accessibilityLabel)
        .accessibilityAddTraits(entry.selected ? .isSelected : [])
        .opacity(revealed ? 1 : 0)
        .animation(staggerAnimation(index: index), value: revealed)
    }

    private func chipGround(
        _ entry: SeatLayerPickerLegendChip,
        palette: SeatLayerPickerPalette,
        naming: Bool
    ) -> Color {
        if entry.selected { return palette.accent }
        return naming ? palette.background : palette.surface
    }

    /// The chip's colour key, drawn so it survives every ground it sits on.
    ///
    /// On a light map the categories are tinted rather than solid, and the
    /// swatch follows: a pale fill inside a full-strength ring, which is the
    /// same seat the buyer is looking for. The ring is drawn outside the dot
    /// and takes no layout room. A fixed recipe, not a token.
    private func categoryDot(
        hex: String,
        palette: SeatLayerPickerPalette,
        selected: Bool
    ) -> some View {
        let size = compact
            ? SeatLayerPickerSizeTokens.legendChipDotSize
            : SeatLayerPickerSizeTokens.legendChipDotSize + 3
        let category = Color(uiColor: UIColor(slHex: hex) ?? .systemIndigo)
        let light = !palette.dark
        let ring: Color? = selected ? palette.onAccent : (light ? category : nil)
        return Circle()
            .fill(light && !selected ? category.opacity(0.32) : category)
            .background {
                if light && !selected { Circle().fill(palette.surface) }
            }
            .frame(width: size, height: size)
            .overlay {
                if let ring {
                    Circle().stroke(ring, lineWidth: 1.5).padding(-0.75)
                }
            }
    }

    /// The one seat state the map paints that no price swatch covers.
    ///
    /// Deliberately not a chip: it filters nothing, so it wears no pill, no
    /// hairline and no press target, and it is not a toggle to assistive
    /// technology.
    private func unavailableKey(palette: SeatLayerPickerPalette) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(palette.mutedText.opacity(0.45))
                .background { Circle().fill(palette.background) }
                .frame(
                    width: SeatLayerPickerSizeTokens.legendChipDotSize + 3,
                    height: SeatLayerPickerSizeTokens.legendChipDotSize + 3
                )
            Text(style.strings.text(.notAvailable))
                .seatLayerPickerFont(size: 12, weight: .semibold)
                .foregroundColor(palette.mutedText)
                .lineLimit(1)
        }
        .padding(.leading, 4)
        .padding(.trailing, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(style.strings.text(.notAvailable))
    }

    private var chipInkHeight: Double {
        compact ? SeatLayerPickerSizeTokens.legendChipHeight : 40
    }

    private func staggerAnimation(index: Int) -> Animation? {
        // Staggered arrival has no reduced form, so it is skipped rather than
        // played instantly.
        guard !reduceMotion else { return nil }
        return seatLayerPickerAnimation(.enter, reduceMotion: false)?
            .delay(Double(index) * Double(SeatLayerPickerMotionDurationTokens.stagger) / 1_000)
    }

    /// Only the edge a chip is actually crossing is faded: a rail scrolled to
    /// its end shows the last price whole, so a hidden chip never looks like
    /// the end of the list, and a rail that fits keeps both rounded ends.
    @ViewBuilder
    private var overflowMask: some View {
        let leading = scrollOffset < -0.5
        let trailing = contentWidth + scrollOffset > viewportWidth + 0.5
        if leading || trailing, viewportWidth > 0 {
            GeometryReader { geometry in
                let fade = min(
                    SeatLayerPickerSizeTokens.legendRailEdgeFade / max(1, geometry.size.width),
                    0.5
                )
                LinearGradient(
                    stops: [
                        .init(color: leading ? .clear : .black, location: 0),
                        .init(color: .black, location: leading ? fade : 0),
                        .init(color: .black, location: trailing ? 1 - fade : 1),
                        .init(color: trailing ? .clear : .black, location: 1),
                    ],
                    startPoint: layoutDirection == .rightToLeft ? .trailing : .leading,
                    endPoint: layoutDirection == .rightToLeft ? .leading : .trailing
                )
            }
        } else {
            Rectangle().fill(Color.black)
        }
    }
}

private struct SeatLayerPickerLegendViewportWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
#endif
