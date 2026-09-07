import CoreGraphics
import Foundation

/// ONE drawing per seat attribute, shared with every other SeatLayer surface.
///
/// The buyer picker names twelve accommodations, three selling marks and the
/// organizer's own note, and the native chrome used to draw them with whatever
/// SF Symbol came closest — a wheelchair for every accommodation, an eye for a
/// view restriction, a filled star for premium. Apple's set is not the set the
/// map, the designer and the web popups draw, so the same seat wore a
/// different mark on every surface.
///
/// The geometry here is transcribed VERBATIM from the shared icon set in the
/// runtime (`core/render-assets/seatTypeIcons.ts`), which is itself the
/// designer's own artwork, by way of the Flutter port's `picker_seat_icons.dart`.
/// That is why the box is 20 rather than a platform 24, and why every glyph is
/// stroke-only: a row's tone (neutral, amber, gold, muted) is one colour away,
/// with no second icon set to keep in step.
///
/// Two rules make this safe to keep in step with the other ports:
///
///  * **No emoji and no platform icon.** An SF Symbol arrives in a weight,
///    baseline and optical size the system decides, and no theme can reach it.
///  * **The path data is the contract.** Every port transcribes these same
///    strings. Redrawing a glyph "close enough" is how five surfaces drifted
///    apart in the first place.

/// The square every glyph below is authored in.
public let seatLayerSeatIconViewBox: Double = 20

/// Stroke weight at the authored box size, scaled with the drawn size.
public let seatLayerSeatIconStrokeWidth: Double = 1.45

/// One glyph: the circles the web draws as `<circle>`, then its `<path>` data.
///
/// Kept apart rather than folded into one path string so the transcription can
/// be read against the web source element for element.
public struct SeatLayerSeatGlyph: Sendable, Equatable {
    /// `[cx, cy, r]` per circle, in the 20-unit box.
    public let circles: [[Double]]
    /// SVG path data, in the 20-unit box, stroked.
    public let paths: [String]
    /// SVG path data painted FILLED — the web's `fill="currentColor"` shapes.
    public let fills: [String]

    public init(
        circles: [[Double]] = [],
        paths: [String] = [],
        fills: [String] = []
    ) {
        self.circles = circles
        self.paths = paths
        self.fills = fills
    }
}

/// Every glyph the picker can ask for, by the runtime's own key.
///
/// The twelve accommodation keys are the runtime's `accessibility[]` values;
/// `restrictedView`, `obstructedView` and `premium` are its commercial marks;
/// `note` is the organizer's free sentence; `contrast` is the accessibility
/// sheet's colour row and is deliberately not a seat attribute.
public let seatLayerSeatGlyphs: [String: SeatLayerSeatGlyph] = [
    // A seated figure over a wheel — authored as an outline so it does not
    // read as a blob beside eleven outline siblings.
    "wheelchair": SeatLayerSeatGlyph(
        circles: [[10.6, 3.7, 1.7], [9.7, 13.3, 4.7]],
        paths: ["M8.9 6.3v4.3a1.3 1.3 0 0 0 1.3 1.3h3.4l1.9 4.5h1.9"]
    ),
    "companion": SeatLayerSeatGlyph(
        circles: [[6, 6, 2], [14, 6, 2]],
        paths: [
            "M2.5 16v-3.5A3.5 3.5 0 0 1 6 9a3.5 3.5 0 0 1 3.5 3.5V16"
                + "M10.5 16v-3.5A3.5 3.5 0 0 1 14 9a3.5 3.5 0 0 1 3.5 3.5V16",
        ]
    ),
    "semi-ambulatory": SeatLayerSeatGlyph(
        circles: [[8, 4, 1.7]],
        paths: ["m8 6 2 4 3 2M10 10l-2 3-1 4M10 10l2 7M14 7l2 10"]
    ),
    "designated-aisle": SeatLayerSeatGlyph(
        paths: [
            "M3.5 5.5v7h8.5V10H6.5M5 12.5V17M11 12.5V17",
            "M13.5 6.5H19M16.5 4l2.5 2.5L16.5 9",
        ]
    ),
    "step-free": SeatLayerSeatGlyph(
        circles: [[5.5, 5, 1.7]],
        paths: ["M5.5 7v4l3 2M2.5 16.5H8l7-7h3M8 16.5h10"]
    ),
    "hearing": SeatLayerSeatGlyph(
        paths: [
            "M7 16c-1-1.2-1.5-2.4-1.5-3.8V9a5 5 0 1 1 10 0c0 2.2-1.2 3.2-2.6 4"
                + "-1.2.7-1.7 1.4-1.7 2.4A2.6 2.6 0 0 1 8.6 18",
        ]
    ),
    "cart": SeatLayerSeatGlyph(
        paths: ["M8 6.5A4 4 0 1 0 8 13M17 6.5a4 4 0 1 0 0 6.5"]
    ),
    "sign-language": SeatLayerSeatGlyph(
        paths: [
            "M6 16V8.5a1 1 0 0 1 2 0v3M8 11V5.5a1 1 0 0 1 2 0V11M10 11V4.5a1 1 0 0 "
                + "1 2 0V11M12 11V6a1 1 0 0 1 2 0v6l1-1.5a1.2 1.2 0 0 1 2 1.3L14 17H9.5"
                + "A3.5 3.5 0 0 1 6 13.5",
        ]
    ),
    "low-vision": SeatLayerSeatGlyph(
        circles: [[10, 10, 2.5]],
        paths: [
            "M2.5 10s3-5 7.5-5 7.5 5 7.5 5-3 5-7.5 5-7.5-5-7.5-5Z",
            "m15 4 .5-1.5M17 5l1.5-.8",
        ]
    ),
    "sensory-friendly": SeatLayerSeatGlyph(
        paths: [
            "M4 11v-1a6 6 0 0 1 12 0v1M4 11h2.5v5H5a1 1 0 0 1-1-1v-4ZM16 11h-2.5v5"
                + "H15a1 1 0 0 0 1-1v-4Z",
            "M8.5 11.5c.8.7 2.2.7 3 0M9 14c.6.4 1.4.4 2 0",
        ]
    ),
    "plus-size": SeatLayerSeatGlyph(
        paths: [
            "M5 9V6.5A2.5 2.5 0 0 1 7.5 4h5A2.5 2.5 0 0 1 15 6.5V9M3.5 8.5v5h13v-5"
                + "M6 13.5V17M14 13.5V17",
        ]
    ),
    "lift-armrest": SeatLayerSeatGlyph(
        paths: [
            "M5 10V6.5A2.5 2.5 0 0 1 7.5 4h4A2.5 2.5 0 0 1 14 6.5V10M4 9v4h11V9"
                + "M6 13v4M13 13v4",
            "M17 11V4M15 6l2-2 2 2",
        ]
    ),
    // An eye struck through: the view is BLOCKED, not merely poor.
    "obstructedView": SeatLayerSeatGlyph(
        paths: [
            "M2.5 10s3-5 7.5-5 7.5 5 7.5 5-3 5-7.5 5-7.5-5-7.5-5Z",
            "m4 17 12-14",
        ]
    ),
    // An eye carrying a caution mark: you can see, with a caveat.
    "restrictedView": SeatLayerSeatGlyph(
        paths: [
            "M2.5 10s3-5 7.5-5 7.5 5 7.5 5-3 5-7.5 5-7.5-5-7.5-5Z",
            "M10 7.5v3.5M10 13.5h.01",
        ]
    ),
    "premium": SeatLayerSeatGlyph(
        paths: ["m10 2.5 2.2 4.6 5 .7-3.6 3.5.9 5-4.5-2.4-4.5 2.4.9-5-3.6-3.5 5-.7Z"]
    ),
    // The organizer's own words about this seat — an ⓘ, replacing the ℹ emoji.
    "note": SeatLayerSeatGlyph(
        circles: [[10, 10, 7.5]],
        paths: ["M10 9.2v4.6M10 6.3h.01"]
    ),
    // NOT a seat attribute, and deliberately not in the shared set: the
    // accessibility sheet's colour row recolours the map rather than picking
    // seats, so it wears a contrast disc rather than an eye or a seat mark.
    "contrast": SeatLayerSeatGlyph(
        circles: [[10, 10, 7.5]],
        fills: ["M10 2.5a7.5 7.5 0 0 1 0 15Z"]
    ),
]

/// The stroked half of the glyph `key` names, in the 20-unit box, or nil where
/// this build has none.
///
/// An unknown key answers nil rather than a placeholder: a row whose drawing is
/// missing prints its words alone, which is a correct row, where a broken box
/// would be a defect the buyer can see.
public func seatLayerSeatIconPath(_ key: String) -> CGPath? {
    guard let glyph = seatLayerSeatGlyphs[key] else { return nil }
    let path = CGMutablePath()
    for circle in glyph.circles where circle.count == 3 {
        path.addEllipse(in: CGRect(
            x: circle[0] - circle[2],
            y: circle[1] - circle[2],
            width: circle[2] * 2,
            height: circle[2] * 2
        ))
    }
    for data in glyph.paths {
        path.addPath(seatLayerParseSVGPath(data))
    }
    return path.isEmpty ? nil : path.copy()
}

/// The filled half of the glyph `key` names, or nil where it has none.
public func seatLayerSeatIconFillPath(_ key: String) -> CGPath? {
    let fills = seatLayerSeatGlyphs[key]?.fills ?? []
    guard !fills.isEmpty else { return nil }
    let path = CGMutablePath()
    for data in fills {
        path.addPath(seatLayerParseSVGPath(data))
    }
    return path.copy()
}

/// The picker's own SVG path reader, for the transcribed glyph data.
///
/// Deliberately small and deliberately local: the package takes no third-party
/// dependency for seventeen drawings, and the only data it has to read is the
/// data in this file. It understands `M m L l H h V v C c S s A a Z z`, which
/// is every command the shared set uses.
///
/// Arc flags must be separated from their neighbours, as they are in the
/// authored data. The compact SVG form that glues `0 1 0` into `010` is not
/// accepted, and would be a transcription error rather than a new glyph style.
public func seatLayerParseSVGPath(_ data: String) -> CGPath {
    let path = CGMutablePath()
    var scanner = SeatLayerSVGPathScanner(data)
    var current = CGPoint.zero
    var start = CGPoint.zero
    // Where a smooth cubic reflects its control point from.
    var lastControl = CGPoint.zero
    var lastWasCubic = false
    var started = false

    while let command = scanner.command() {
        let relative = command.lowercased() == command
        switch command.uppercased() {
        case "M":
            let point = scanner.point(relative && started ? current : .zero)
            path.move(to: point)
            current = point
            start = point
            started = true
            lastWasCubic = false
            // Further pairs after a moveto are lines, per the SVG grammar.
            while scanner.hasNumber() {
                let line = scanner.point(relative ? current : .zero)
                path.addLine(to: line)
                current = line
            }
        case "L":
            while scanner.hasNumber() {
                let point = scanner.point(relative ? current : .zero)
                path.addLine(to: point)
                current = point
            }
            lastWasCubic = false
        case "H":
            while scanner.hasNumber() {
                current = CGPoint(
                    x: scanner.number() + (relative ? current.x : 0),
                    y: current.y
                )
                path.addLine(to: current)
            }
            lastWasCubic = false
        case "V":
            while scanner.hasNumber() {
                current = CGPoint(
                    x: current.x,
                    y: scanner.number() + (relative ? current.y : 0)
                )
                path.addLine(to: current)
            }
            lastWasCubic = false
        case "C":
            while scanner.hasNumber() {
                let origin = relative ? current : .zero
                let first = scanner.point(origin)
                let second = scanner.point(origin)
                let end = scanner.point(origin)
                path.addCurve(to: end, control1: first, control2: second)
                current = end
                lastControl = second
                lastWasCubic = true
            }
        case "S":
            while scanner.hasNumber() {
                let origin = relative ? current : .zero
                let second = scanner.point(origin)
                let end = scanner.point(origin)
                let first = lastWasCubic
                    ? CGPoint(
                        x: current.x * 2 - lastControl.x,
                        y: current.y * 2 - lastControl.y
                    )
                    : current
                path.addCurve(to: end, control1: first, control2: second)
                current = end
                lastControl = second
                lastWasCubic = true
            }
        case "A":
            while scanner.hasNumber() {
                let rx = scanner.number()
                let ry = scanner.number()
                let rotation = scanner.number()
                let largeArc = scanner.number() != 0
                let sweep = scanner.number() != 0
                let end = scanner.point(relative ? current : .zero)
                seatLayerAppendArc(
                    to: path,
                    from: current,
                    to: end,
                    rx: rx,
                    ry: ry,
                    rotationDegrees: rotation,
                    largeArc: largeArc,
                    sweep: sweep
                )
                current = end
            }
            lastWasCubic = false
        case "Z":
            path.closeSubpath()
            current = start
            lastWasCubic = false
        default:
            // Unsupported data is a transcription error, not a drawing style.
            // Returning what has been read so far keeps a buyer's card up.
            return path.copy() ?? path
        }
    }
    return path.copy() ?? path
}

/// Append the elliptical arc SVG's `A` describes, as cubic segments.
///
/// The endpoint-to-centre conversion of the SVG specification, then at most
/// four cubics per arc — the standard approximation, whose error at a quarter
/// turn is far below one drawn pixel at these sizes.
func seatLayerAppendArc(
    to path: CGMutablePath,
    from: CGPoint,
    to end: CGPoint,
    rx: Double,
    ry: Double,
    rotationDegrees: Double,
    largeArc: Bool,
    sweep: Bool
) {
    if rx == 0 || ry == 0 || from == end {
        path.addLine(to: end)
        return
    }
    var radiusX = abs(rx)
    var radiusY = abs(ry)
    let phi = rotationDegrees * .pi / 180
    let cosPhi = cos(phi)
    let sinPhi = sin(phi)
    let dx2 = (from.x - end.x) / 2
    let dy2 = (from.y - end.y) / 2
    let x1 = cosPhi * dx2 + sinPhi * dy2
    let y1 = -sinPhi * dx2 + cosPhi * dy2

    // An arc too small for its radii is grown until it fits, exactly as the
    // specification says, rather than dropped.
    let lambda = (x1 * x1) / (radiusX * radiusX) + (y1 * y1) / (radiusY * radiusY)
    if lambda > 1 {
        let scale = lambda.squareRoot()
        radiusX *= scale
        radiusY *= scale
    }

    let sign: Double = largeArc == sweep ? -1 : 1
    let numerator = max(
        0,
        radiusX * radiusX * radiusY * radiusY
            - radiusX * radiusX * y1 * y1
            - radiusY * radiusY * x1 * x1
    )
    let denominator = radiusX * radiusX * y1 * y1 + radiusY * radiusY * x1 * x1
    guard denominator > 0 else {
        path.addLine(to: end)
        return
    }
    let coefficient = sign * (numerator / denominator).squareRoot()
    let cx1 = coefficient * radiusX * y1 / radiusY
    let cy1 = -coefficient * radiusY * x1 / radiusX
    let centre = CGPoint(
        x: cosPhi * cx1 - sinPhi * cy1 + (from.x + end.x) / 2,
        y: sinPhi * cx1 + cosPhi * cy1 + (from.y + end.y) / 2
    )

    func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
        let dot = ux * vx + uy * vy
        let length = (ux * ux + uy * uy).squareRoot() * (vx * vx + vy * vy).squareRoot()
        guard length > 0 else { return 0 }
        let value = acos(min(1, max(-1, dot / length)))
        return ux * vy - uy * vx < 0 ? -value : value
    }

    let startAngle = angle(1, 0, (x1 - cx1) / radiusX, (y1 - cy1) / radiusY)
    var sweepAngle = angle(
        (x1 - cx1) / radiusX,
        (y1 - cy1) / radiusY,
        (-x1 - cx1) / radiusX,
        (-y1 - cy1) / radiusY
    )
    if !sweep, sweepAngle > 0 {
        sweepAngle -= 2 * .pi
    } else if sweep, sweepAngle < 0 {
        sweepAngle += 2 * .pi
    }

    let segments = max(1, Int((abs(sweepAngle) / (Double.pi / 2)).rounded(.up)))
    let delta = sweepAngle / Double(segments)
    let handle = 4.0 / 3.0 * tan(delta / 4)
    var theta = startAngle
    for _ in 0..<segments {
        let next = theta + delta
        func onArc(_ t: Double) -> CGPoint {
            CGPoint(
                x: centre.x + radiusX * cos(t) * cosPhi - radiusY * sin(t) * sinPhi,
                y: centre.y + radiusX * cos(t) * sinPhi + radiusY * sin(t) * cosPhi
            )
        }
        func derivative(_ t: Double) -> CGPoint {
            CGPoint(
                x: -radiusX * sin(t) * cosPhi - radiusY * cos(t) * sinPhi,
                y: -radiusX * sin(t) * sinPhi + radiusY * cos(t) * cosPhi
            )
        }
        let startPoint = onArc(theta)
        let endPoint = onArc(next)
        let firstSlope = derivative(theta)
        let secondSlope = derivative(next)
        path.addCurve(
            to: endPoint,
            control1: CGPoint(
                x: startPoint.x + firstSlope.x * handle,
                y: startPoint.y + firstSlope.y * handle
            ),
            control2: CGPoint(
                x: endPoint.x - secondSlope.x * handle,
                y: endPoint.y - secondSlope.y * handle
            )
        )
        theta = next
    }
}

/// Reads commands and numbers out of SVG path data.
struct SeatLayerSVGPathScanner {
    private let data: [UInt8]
    private var index = 0

    init(_ data: String) {
        self.data = Array(data.utf8)
    }

    private mutating func skipSeparators() {
        while index < data.count {
            let code = data[index]
            // Space, tab, carriage return, newline, comma.
            if code == 0x20 || code == 0x09 || code == 0x0d
                || code == 0x0a || code == 0x2c {
                index += 1
            } else {
                return
            }
        }
    }

    /// Whether a number follows, which is how a repeated command is detected.
    mutating func hasNumber() -> Bool {
        skipSeparators()
        guard index < data.count else { return false }
        let code = data[index]
        return (code >= 0x30 && code <= 0x39)
            || code == 0x2d || code == 0x2b || code == 0x2e
    }

    /// The next command letter, or nil at the end of the data.
    mutating func command() -> String? {
        skipSeparators()
        guard index < data.count, !hasNumber() else { return nil }
        let character = String(UnicodeScalar(data[index]))
        index += 1
        return character
    }

    /// The next number.
    mutating func number() -> Double {
        skipSeparators()
        let start = index
        if index < data.count, data[index] == 0x2d || data[index] == 0x2b {
            index += 1
        }
        var seenDot = false
        while index < data.count {
            let code = data[index]
            if code >= 0x30 && code <= 0x39 {
                index += 1
            } else if code == 0x2e, !seenDot {
                // A second dot starts the NEXT number: `2.2.7` is two of them.
                seenDot = true
                index += 1
            } else {
                break
            }
        }
        let text = String(decoding: data[start..<index], as: UTF8.self)
        return Double(text) ?? 0
    }

    /// The next coordinate pair, offset by `origin` for a relative command.
    mutating func point(_ origin: CGPoint) -> CGPoint {
        let x = number()
        let y = number()
        return CGPoint(x: origin.x + x, y: origin.y + y)
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// One attribute glyph, stroked in the row's own ink.
///
/// Sized in the caller's points and scaled from the authored 20-unit box, so a
/// row can ask for 17 on a card and 15 on the compact one without a second
/// drawing. Hidden from screen readers: every caller prints the same fact in
/// words beside it, and announcing it twice is all this could add.
public struct SeatLayerPickerSeatIcon: View {
    private let iconKey: String
    private let color: Color
    private let size: Double

    public init(
        iconKey: String,
        color: Color,
        size: Double = SeatLayerPickerSizeTokens.noteIconSize
    ) {
        self.iconKey = iconKey
        self.color = color
        self.size = size
    }

    public var body: some View {
        let scale = size / seatLayerSeatIconViewBox
        ZStack {
            if let fill = seatLayerSeatIconFillPath(iconKey) {
                Path(fill)
                    .scale(scale, anchor: .topLeading)
                    .fill(color)
            }
            if let stroke = seatLayerSeatIconPath(iconKey) {
                Path(stroke)
                    .scale(scale, anchor: .topLeading)
                    .stroke(
                        color,
                        style: StrokeStyle(
                            // The stroke scales with the box, so the drawing
                            // keeps its authored weight at every size.
                            lineWidth: seatLayerSeatIconStrokeWidth * scale,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
#endif
