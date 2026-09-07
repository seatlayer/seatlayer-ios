import XCTest
@testable import SeatLayer

/// The toast the picker says things with, and the one shake the error tone
/// arrives on.
final class PickerToastTests: XCTestCase {
    func testAToastStandsStillAtEitherEndOfTheShake() {
        XCTAssertEqual(seatLayerPickerToastShakeOffset(progress: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(seatLayerPickerToastShakeOffset(progress: 1), 0, accuracy: 0.0001)
        // A progress outside the run is clamped rather than extrapolated: a
        // spring that overshoots must not throw the card off the band.
        XCTAssertEqual(seatLayerPickerToastShakeOffset(progress: -3), 0, accuracy: 0.0001)
        XCTAssertEqual(seatLayerPickerToastShakeOffset(progress: 4), 0, accuracy: 0.0001)
    }

    func testTheShakeCrossesCentreAndDamps() {
        // Three passes means six half-cycles, so the extremes sit at the odd
        // twelfths of the run.
        let first = seatLayerPickerToastShakeOffset(progress: 1.0 / 12)
        let last = seatLayerPickerToastShakeOffset(progress: 11.0 / 12)
        XCTAssertGreaterThan(first, 0)
        XCTAssertLessThan(abs(last), abs(first), "the shake must settle, not sustain")
        XCTAssertLessThan(
            seatLayerPickerToastShakeOffset(progress: 3.0 / 12),
            0,
            "it has to cross centre to read as a shake"
        )
        // It never travels further than it says it does.
        for step in 0...100 {
            let offset = seatLayerPickerToastShakeOffset(progress: Double(step) / 100)
            XCTAssertLessThanOrEqual(
                abs(offset),
                SeatLayerPickerToastShake.amplitude
            )
        }
    }

    func testOnlyTheBorderChangesBetweenTones() {
        // Every tone is one object with one thing to say, and at most one to do.
        for tone in SeatLayerPickerToastTone.allCases {
            let toast = SeatLayerPickerToast("Seat taken", tone: tone)
            XCTAssertFalse(toast.hasAction)
            XCTAssertEqual(toast.message, "Seat taken")
        }
        let taken = SeatLayerPickerToast("Seat taken", tone: .error)
        XCTAssertTrue(taken.saysTheSameAs(SeatLayerPickerToast("Seat taken", tone: .error)))
        XCTAssertFalse(taken.saysTheSameAs(SeatLayerPickerToast("Seat taken", tone: .warning)))
    }
}
