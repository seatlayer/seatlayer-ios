import XCTest
@testable import SeatLayer

final class PickerSystemAppearanceTests: XCTestCase {
    func testThemeAndSystemAppearanceResolveStatusBarContrast() {
        XCTAssertFalse(SeatLayerPickerSystemAppearance.prefersLightForeground(
            themeMode: .light,
            systemIsDark: true,
            immersive: false
        ))
        XCTAssertTrue(SeatLayerPickerSystemAppearance.prefersLightForeground(
            themeMode: .dark,
            systemIsDark: false,
            immersive: false
        ))
        XCTAssertTrue(SeatLayerPickerSystemAppearance.prefersLightForeground(
            themeMode: .auto,
            systemIsDark: true,
            immersive: false
        ))
        XCTAssertFalse(SeatLayerPickerSystemAppearance.prefersLightForeground(
            themeMode: .auto,
            systemIsDark: false,
            immersive: false
        ))
    }

    func testImmersiveSurfaceAlwaysUsesLightSystemForeground() {
        for mode in SeatLayerPickerThemeMode.allCases {
            XCTAssertTrue(SeatLayerPickerSystemAppearance.prefersLightForeground(
                themeMode: mode,
                systemIsDark: false,
                immersive: true
            ))
        }
    }
}
