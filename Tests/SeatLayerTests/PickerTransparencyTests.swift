import XCTest
@testable import SeatLayer

final class PickerTransparencyTests: XCTestCase {
    func testSurfaceBecomesOpaqueWhenReduceTransparencyIsEnabled() {
        XCTAssertEqual(
            SeatLayerPickerTransparency.surfaceOpacity(
                requested: 0.88,
                reduceTransparency: false
            ),
            0.88
        )
        XCTAssertEqual(
            SeatLayerPickerTransparency.surfaceOpacity(
                requested: 0.88,
                reduceTransparency: true
            ),
            1
        )
    }

    func testScrimStrengthensWithoutExceedingValidOpacity() {
        XCTAssertEqual(
            SeatLayerPickerTransparency.scrimOpacity(
                requested: 0.48,
                reduceTransparency: true
            ),
            0.72
        )
        XCTAssertEqual(
            SeatLayerPickerTransparency.scrimOpacity(
                requested: 2,
                reduceTransparency: false
            ),
            1
        )
    }
}
