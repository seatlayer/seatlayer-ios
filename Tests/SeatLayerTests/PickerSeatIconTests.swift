import CoreGraphics
import XCTest
@testable import SeatLayer

/// The seventeen shared drawings, and the small SVG reader behind them.
///
/// The path data is the contract between the ports, so these assert that every
/// key the note rows can name resolves to a real drawing inside the authored
/// 20-unit box — not that the curves look a particular way, which is what the
/// goldens are for.
final class PickerSeatIconTests: XCTestCase {
    private let accommodations = [
        "wheelchair", "companion", "semi-ambulatory", "designated-aisle",
        "step-free", "hearing", "cart", "sign-language", "low-vision",
        "sensory-friendly", "plus-size", "lift-armrest",
    ]

    func testTheTwelveAccommodationsAndFiveChromeMarksAreAllDrawn() {
        for key in accommodations + ["restrictedView", "obstructedView", "premium", "note", "contrast"] {
            XCTAssertNotNil(seatLayerSeatIconPath(key), key)
        }
        XCTAssertEqual(seatLayerSeatGlyphs.count, 17)
    }

    /// A row whose drawing this build has no name for prints its words alone.
    /// A placeholder box would be a defect the buyer can see.
    func testAnUnknownKeyDrawsNothingRatherThanAPlaceholder() {
        XCTAssertNil(seatLayerSeatIconPath("no-such-attribute"))
        XCTAssertNil(seatLayerSeatIconFillPath("wheelchair"))
        XCTAssertNotNil(seatLayerSeatIconFillPath("contrast"))
    }

    func testEveryGlyphStaysInsideTheAuthoredViewBox() {
        for (key, _) in seatLayerSeatGlyphs {
            var box = CGRect.null
            if let stroke = seatLayerSeatIconPath(key) {
                box = box.union(stroke.boundingBoxOfPath)
            }
            if let fill = seatLayerSeatIconFillPath(key) {
                box = box.union(fill.boundingBoxOfPath)
            }
            XCTAssertFalse(box.isNull, key)
            // A half-unit of slack for the stroke's own round caps, which the
            // authored artwork centres on the edge of the box.
            XCTAssertGreaterThanOrEqual(box.minX, -0.5, key)
            XCTAssertGreaterThanOrEqual(box.minY, -0.5, key)
            XCTAssertLessThanOrEqual(box.maxX, seatLayerSeatIconViewBox + 0.5, key)
            XCTAssertLessThanOrEqual(box.maxY, seatLayerSeatIconViewBox + 0.5, key)
        }
    }

    /// Every command the shared set actually uses, read the way the authored
    /// data spells it — arc flags separated, relative commands repeated.
    func testThePathReaderUnderstandsTheCommandsTheSharedSetUses() {
        let line = seatLayerParseSVGPath("M2 2H8V8Z")
        XCTAssertEqual(line.boundingBoxOfPath, CGRect(x: 2, y: 2, width: 6, height: 6))

        // Relative moveto followed by implicit linetos.
        let relative = seatLayerParseSVGPath("m4 4 2 0 0 2")
        XCTAssertEqual(relative.boundingBoxOfPath, CGRect(x: 4, y: 4, width: 2, height: 2))

        // A half-turn arc, the `cart` glyph's own form: the flags are read
        // as three separate numbers, so it lands on its stated endpoint and
        // bulges to the LEFT of the chord rather than to the right.
        let arc = seatLayerParseSVGPath("M8 6.5A4 4 0 1 0 8 13")
        XCTAssertEqual(arc.currentPoint.x, 8, accuracy: 0.02)
        XCTAssertEqual(arc.currentPoint.y, 13, accuracy: 0.02)
        XCTAssertLessThan(arc.boundingBoxOfPath.minX, 8)

        // `2.2.7` is two numbers, not one — the compact SVG decimal form.
        let compact = seatLayerParseSVGPath("M0 0L2.2.7")
        XCTAssertEqual(compact.currentPoint.x, 2.2, accuracy: 0.001)
        XCTAssertEqual(compact.currentPoint.y, 0.7, accuracy: 0.001)
    }

    /// Unsupported data is a transcription error, not a drawing style: the
    /// reader keeps what it has read rather than taking a buyer's card down.
    func testUnreadableDataStopsRatherThanThrows() {
        let path = seatLayerParseSVGPath("M1 1L5 5Q9 9 3 3")
        XCTAssertEqual(path.boundingBoxOfPath, CGRect(x: 1, y: 1, width: 4, height: 4))
    }
}
