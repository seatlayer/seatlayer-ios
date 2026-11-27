import CoreGraphics
import Foundation

/// Where the connection status stands on the map, in leading-edge terms: `x`
/// from the map's leading edge, `y` from its top.
struct SeatLayerPickerConnectionPlace: Equatable {
    var x: Double
    var y: Double
    var width: Double
    /// Under the top line at the map's whole width, because its words did
    /// not fit beside the chip on one line each.
    var below: Bool
}

/// The longest a status may run on a wide map.
let seatLayerPickerConnectionWideMaxWidth: Double = 360

/// Places the status on the map's top line, after the test chip and short of
/// the Map / 3D switch by `size.connectionStatusSwitchGap`. When its words
/// (`naturalWidth`, one line each) do not fit there, it goes under the chip
/// and the switch and takes the map's whole width between the insets. On a
/// wide map it is at most 360 wide.
///
/// `testChip` and `viewMode` are the controls' frames in leading-edge terms;
/// either may be absent. `fallbackTop` is where the top line starts when
/// neither is drawn.
func seatLayerPickerConnectionPlace(
    mapWidth: Double,
    inset: Double = 10,
    testChip: CGRect?,
    viewMode: CGRect?,
    fallbackTop: Double,
    wide: Bool,
    naturalWidth: Double,
    height: Double = SeatLayerPickerSizeTokens.connectionStatusHeight
) -> SeatLayerPickerConnectionPlace {
    let gap = SeatLayerPickerSizeTokens.connectionStatusSwitchGap
    let lineMiddle: Double = testChip.map { Double($0.midY) }
        ?? viewMode.map { Double($0.midY) }
        ?? (fallbackTop + height / 2)
    let start = testChip.map { Double($0.maxX) + gap } ?? inset
    let end = viewMode.map { Double($0.minX) - gap } ?? (mapWidth - inset)
    var room = end - start
    if wide { room = min(room, seatLayerPickerConnectionWideMaxWidth) }
    if naturalWidth <= room {
        return SeatLayerPickerConnectionPlace(
            x: start,
            y: lineMiddle - height / 2,
            width: naturalWidth,
            below: false
        )
    }
    let lineBottom = max(
        testChip.map { Double($0.maxY) } ?? fallbackTop,
        viewMode.map { Double($0.maxY) } ?? fallbackTop
    )
    var width = max(0, mapWidth - inset * 2)
    if wide { width = min(width, seatLayerPickerConnectionWideMaxWidth) }
    return SeatLayerPickerConnectionPlace(x: inset, y: lineBottom + gap, width: width, below: true)
}

/// `frame` measured from the map's left edge, turned to leading-edge terms.
func seatLayerPickerLeadingFrame(_ frame: CGRect, mapWidth: Double, rightToLeft: Bool) -> CGRect {
    guard rightToLeft else { return frame }
    return CGRect(
        x: mapWidth - Double(frame.maxX),
        y: frame.minY,
        width: frame.width,
        height: frame.height
    )
}

/// Whether the status's second line, "Your seats are still held.", is said:
/// a hold the server confirmed, with time left on its clock.
func seatLayerPickerConnectionSaysStillHeld(
    shown: SeatLayerConnectionShown,
    hold: SeatLayerPickerHold?,
    now: TimeInterval
) -> Bool {
    guard shown == .offline, let hold, hold.active, let expiresAt = hold.expiresAt else { return false }
    return seatLayerPickerHoldSecondsRemaining(expiresAt: expiresAt, now: now) > 0
}
