import CoreGraphics
import XCTest
@testable import SeatLayer

final class PickerConnectionPlaceTests: XCTestCase {
    private let chip = CGRect(x: 10, y: 60, width: 90, height: 26)
    private let viewMode = CGRect(x: 280, y: 55, width: 100, height: 36)

    func testStandsAfterTheChipEndingShortOfTheSwitch() {
        let place = seatLayerPickerConnectionPlace(
            mapWidth: 390, testChip: chip, viewMode: viewMode,
            fallbackTop: 60, wide: false, naturalWidth: 140
        )
        XCTAssertFalse(place.below)
        XCTAssertEqual(place.x, 108)
        XCTAssertEqual(place.width, 140)
        XCTAssertEqual(place.y, 73 - 18, "centred on the chip's line")
        XCTAssertLessThanOrEqual(place.x + place.width, 272, "8 short of the switch")
    }

    func testGoesUnderTheLineAtTheWholeWidthWhenTheWordsDoNotFit() {
        let place = seatLayerPickerConnectionPlace(
            mapWidth: 390, testChip: chip, viewMode: viewMode,
            fallbackTop: 60, wide: false, naturalWidth: 170
        )
        XCTAssertTrue(place.below)
        XCTAssertEqual(place.x, 10)
        XCTAssertEqual(place.width, 370)
        XCTAssertEqual(place.y, 91 + 8)
    }

    func testWithoutAChipItStartsAtTheInset() {
        let place = seatLayerPickerConnectionPlace(
            mapWidth: 390, testChip: nil, viewMode: viewMode,
            fallbackTop: 60, wide: false, naturalWidth: 140
        )
        XCTAssertEqual(place.x, 10)
        XCTAssertEqual(place.y, 73 - 18, "on the switch's line")
    }

    func testOnAWideMapItIsAtMost360Wide() {
        let beside = seatLayerPickerConnectionPlace(
            mapWidth: 900, testChip: chip, viewMode: nil,
            fallbackTop: 60, wide: true, naturalWidth: 361
        )
        XCTAssertTrue(beside.below)
        XCTAssertEqual(beside.width, 360)
    }

    func testRightToLeftReadsFramesFromTheTrailingEdge() {
        let frame = seatLayerPickerLeadingFrame(
            CGRect(x: 290, y: 60, width: 90, height: 26),
            mapWidth: 390, rightToLeft: true
        )
        XCTAssertEqual(frame.minX, 10)
        XCTAssertEqual(frame.maxX, 100)
    }

    func testTheHeldLineNeedsAConfirmedHoldWithTimeLeft() {
        let held = SeatLayerPickerHold(active: true, expiresAt: 1_000, owner: "picker")
        XCTAssertTrue(seatLayerPickerConnectionSaysStillHeld(shown: .offline, hold: held, now: 900))
        XCTAssertFalse(seatLayerPickerConnectionSaysStillHeld(shown: .offline, hold: held, now: 1_000), "ends at 0:00")
        XCTAssertFalse(seatLayerPickerConnectionSaysStillHeld(shown: .updating, hold: held, now: 900))
        XCTAssertFalse(seatLayerPickerConnectionSaysStillHeld(
            shown: .offline,
            hold: SeatLayerPickerHold(active: false, expiresAt: 1_000, owner: nil),
            now: 900
        ))
    }
}
