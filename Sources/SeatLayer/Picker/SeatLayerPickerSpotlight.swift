#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The glass the seat card stands on.
///
/// A veil over the whole map with one feathered hole punched in it, centred on
/// the seat the card is asking about. The hole is the point of it: on a map of
/// several thousand seats the buyer has to be able to find the ring they just
/// tapped, and a flat wash over everything makes the map quieter without making
/// that one seat easier to see.
///
/// **Drawn, not blurred.** SwiftUI's materials cannot blur a hosted web view —
/// they sample the SwiftUI layer tree, and the map is not in it — so a
/// `.ultraThinMaterial` here would be a rectangle of nothing over a map that
/// stayed exactly as sharp as before. The veil is a real fill with a real
/// punched hole rather than a blur that does not happen.
struct SeatLayerPickerSpotlight: View {
    /// Where the seat sits on screen, in the spotlight's own coordinates, or
    /// nil when the runtime reports no screen point.
    let seatPoint: CGPoint?
    /// The pan the map has made since the snapshot that reported the point.
    ///
    /// `picker.frameSeat` publishes no revision — it is camera only — so a
    /// seat's reported point is where it sat before the lift. Without this the
    /// hole lands a whole lift band away from the seat.
    let anchorDy: Double
    let reduceTransparency: Bool
    /// The host's own scrim colour, where it named one.
    let tint: Color?
    let onPress: () -> Void

    var body: some View {
        GeometryReader { geometry in
            // The veil is `opacity.confirmScrim`, and a viewer who asked for
            // less transparency gets at least `confirmScrimFlat` — the shared
            // token — but never less than this platform's own reduced-
            // transparency floor, which is deeper still.
            let opacity = reduceTransparency
                ? max(
                    SeatLayerPickerOpacityTokens.confirmScrimFlat,
                    SeatLayerPickerTransparency.scrimOpacity(
                        requested: SeatLayerPickerOpacityTokens.confirmScrim,
                        reduceTransparency: true
                    )
                )
                : SeatLayerPickerOpacityTokens.confirmScrim
            (tint ?? .black)
                .opacity(opacity)
                .mask { mask(in: geometry.size) }
                .contentShape(Rectangle())
                .onTapGesture(perform: onPress)
        }
        .ignoresSafeArea()
        // The map behind it is already inert while a decision is up, and the
        // veil is decoration over that: everything it could announce, the card
        // in front of it says.
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func mask(in size: CGSize) -> some View {
        if let seatPoint, !reduceTransparency {
            let centre = CGPoint(x: seatPoint.x, y: seatPoint.y + anchorDy)
            let clear = SeatLayerPickerSizeTokens.confirmScrimClearRadius
            let feather = SeatLayerPickerSizeTokens.confirmScrimFeatherRadius
            RadialGradient(
                stops: [
                    // Wholly clear out to the seat's own ring, then feathered
                    // to full: a hard edge would read as a hole cut in paper.
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: min(0.99, clear / max(1, feather))),
                    .init(color: .black, location: 1),
                ],
                center: UnitPoint(
                    x: centre.x / max(1, size.width),
                    y: centre.y / max(1, size.height)
                ),
                startRadius: 0,
                endRadius: feather
            )
        } else {
            // No screen point, or a viewer who asked for less transparency:
            // the veil is honest and flat rather than pretending to a hole it
            // cannot place.
            Rectangle()
        }
    }
}
#endif
