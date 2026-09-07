#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The one dark glass every immersive surface wears.
///
/// All 3D and seat-view chrome floats over a rendered venue, so it is dark
/// whatever the resolved mode is — and it gets there by reading the dark
/// palette's own `immersive*` colours, never by forcing the picker into dark
/// mode, which used to drag the picker's whole surface and divider set along
/// with it. Captions wear the deeper of the two grounds.
///
/// One helper draws it, so no surface re-mixes it.
struct SeatLayerPickerImmersiveGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let deep: Bool
    let radius: Double

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .opacity(reduceTransparency ? 0 : 1)
                    .overlay { shape.fill(ground) }
            }
            .overlay { shape.stroke(border, lineWidth: 1) }
            .clipShape(shape)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    private var ground: Color {
        let base = deep
            ? SeatLayerPickerPalette.immersiveCaption
            : SeatLayerPickerPalette.immersiveGlass
        // Reduce Transparency asks for a solid ground rather than a blur, and
        // the glass tokens carry their own alpha, so the colour is stacked on
        // the venue's darkest ink instead of being drawn over live pixels.
        return reduceTransparency ? base.opacity(1) : base
    }

    private var border: Color {
        deep
            ? SeatLayerPickerPalette.immersiveCaptionBorder
            : SeatLayerPickerPalette.immersiveGlassBorder
    }
}

extension View {
    /// Chrome glass: pills, chips and control discs over the scene.
    func seatLayerImmersiveGlass(radius: Double) -> some View {
        modifier(SeatLayerPickerImmersiveGlass(deep: false, radius: radius))
    }

    /// Caption glass: the deeper ground the naming strips wear.
    func seatLayerImmersiveCaptionGlass(radius: Double) -> some View {
        modifier(SeatLayerPickerImmersiveGlass(deep: true, radius: radius))
    }
}
#endif
