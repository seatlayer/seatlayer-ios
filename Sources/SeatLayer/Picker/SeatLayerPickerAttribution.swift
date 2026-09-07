#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The SeatLayer credit, centred at the foot of the ticket sheet — where a
/// phone's rounded corner cannot clip it.
///
/// Drawn only when the organizer entitlement asks for it. A white-label
/// event turns `branding.attributionRequired` off, and nothing is drawn.
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
            HStack(spacing: 5) {
                SeatLayerPickerPoweredMark(
                    background: palette.text,
                    ink: palette.surface
                )
                Text(style.strings.text(.poweredBy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .seatLayerPickerFont(SeatLayerPickerTypeTokens.attribution)
            .foregroundColor(palette.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .frame(
                maxWidth: .infinity,
                minHeight: SeatLayerPickerSizeTokens.attributionHeight
            )
            .dynamicTypeSize(...DynamicTypeSize.large)
            .opacity(0.72)
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

#endif
