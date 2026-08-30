import Foundation
#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
#endif

/// Pure accessibility policy for chrome layered above renderer-owned pixels.
public enum SeatLayerPickerTransparency {
    public static func surfaceOpacity(
        requested: Double,
        reduceTransparency: Bool
    ) -> Double {
        reduceTransparency ? 1 : min(1, max(0, requested))
    }

    public static func scrimOpacity(
        requested: Double,
        reduceTransparency: Bool
    ) -> Double {
        let clamped = min(1, max(0, requested))
        return reduceTransparency ? max(0.72, clamped) : clamped
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
private struct SeatLayerPickerTranslucentBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let color: Color
    let opacity: Double

    func body(content: Content) -> some View {
        content.background(color.opacity(SeatLayerPickerTransparency.surfaceOpacity(
            requested: opacity,
            reduceTransparency: reduceTransparency
        )))
    }
}

extension View {
    func seatLayerPickerTranslucentBackground(
        _ color: Color,
        opacity: Double
    ) -> some View {
        modifier(SeatLayerPickerTranslucentBackground(color: color, opacity: opacity))
    }
}
#endif
