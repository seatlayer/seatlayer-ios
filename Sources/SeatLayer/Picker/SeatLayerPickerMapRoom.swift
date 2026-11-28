import Foundation

/// The map's line of controls at its top edge and the room around it: the
/// Map | 3D control and the map's inset above and below it. An open cart
/// list always leaves the map this line, and the column of map controls
/// stands under it.
let seatLayerPickerMapTopLine: Double = SeatLayerPickerSizeTokens.mapAnchorInset * 2
    + SeatLayerPickerSizeTokens.viewModeControlHeight

/// How tall the open cart region may be on a map `mapHeight` tall, under a
/// row `rowHeight` tall: what it wants, never more than leaves the map its
/// top line. Without a measured map it gets what it wants.
func seatLayerPickerCartRegionHeight(wanted: Double, mapHeight: Double?, rowHeight: Double) -> Double {
    guard let mapHeight, mapHeight > 0 else { return max(0, wanted) }
    return max(0, min(wanted, mapHeight - rowHeight - seatLayerPickerMapTopLine))
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

private struct SeatLayerPickerMapHeightEnvironmentKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

private struct SeatLayerPickerWideLayoutKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension View {
    /// A scroll view that bounces only when its content is taller than it.
    @ViewBuilder
    func seatLayerPickerBouncesOnlyWhenScrollable() -> some View {
        if #available(iOS 16.4, *) {
            scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }
}

extension EnvironmentValues {
    /// The height of the picker's map, set by the picker for the chrome it
    /// stands on it. Nil where a part is placed outside a picker.
    var seatLayerPickerMapHeight: Double? {
        get { self[SeatLayerPickerMapHeightEnvironmentKey.self] }
        set { self[SeatLayerPickerMapHeightEnvironmentKey.self] = newValue }
    }

    /// The composition the picker chose, so its parts follow it rather than
    /// the size class: an iPhone held sideways is regular in width and still
    /// laid out as a phone. Nil where a part is placed outside a picker.
    var seatLayerPickerWideLayout: Bool? {
        get { self[SeatLayerPickerWideLayoutKey.self] }
        set { self[SeatLayerPickerWideLayoutKey.self] = newValue }
    }
}
#endif
