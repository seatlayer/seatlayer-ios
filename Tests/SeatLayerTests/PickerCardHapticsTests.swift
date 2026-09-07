import XCTest
@testable import SeatLayer

/// The cues the seat card announces for itself, and the one cue that is not
/// an impact at all.
final class PickerCardHapticsTests: XCTestCase {
    func testTheNineSharedCuesAreAllNamed() {
        XCTAssertEqual(
            Set(SeatLayerPickerHapticCue.allCases.map(\.rawValue)),
            Set(SeatLayerPickerHapticNameTokens.all.keys)
        )
    }

    func testCardCuesFireTheStrengthsTheSharedTokensName() {
        XCTAssertEqual(SeatLayerPickerHaptics.strength(for: .cardArrived), .light)
        XCTAssertEqual(SeatLayerPickerHaptics.strength(for: .seatConfirmed), .medium)
        XCTAssertEqual(SeatLayerPickerHaptics.strength(for: .cardCancelled), .selection)
        XCTAssertEqual(SeatLayerPickerHaptics.strength(for: .ticketRemoved), .light)
    }

    /// A warning has to be told apart from the taps the buyer has been feeling
    /// all along, so it is the platform's notification rhythm rather than the
    /// heaviest knock available.
    func testHoldEndingIsAWarningRatherThanAnImpact() {
        XCTAssertEqual(SeatLayerPickerHaptics.strength(for: .holdEnding), .warning)
        XCTAssertEqual(SeatLayerPickerHapticTokens.strength(named: "warning"), .warning)
    }

    /// The seeding rule governs only the cues the policy has to deduce. The
    /// card's own four are pressed, never inferred, so a first snapshot that
    /// arrives with a resumed hold still fires nothing.
    func testOnlyTheDeducedCuesAreSubjectToTheSeedingRule() {
        XCTAssertEqual(
            SeatLayerPickerHaptics.deducedFromSnapshots,
            [.selectionAdded, .sectionFocused, .holdCreated, .holdExpired]
        )
        let seeded = SeatLayerPickerHaptics.reduce(
            SeatLayerPickerHaptics.initialState,
            snapshot: .init(selectionCount: 3, focusedSectionId: "204", hasHold: true)
        )
        XCTAssertTrue(seeded.cues.isEmpty)
        for cue in seeded.cues {
            XCTAssertTrue(SeatLayerPickerHaptics.deducedFromSnapshots.contains(cue))
        }
    }
}
