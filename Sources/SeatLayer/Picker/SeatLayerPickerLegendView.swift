#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

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
#endif
