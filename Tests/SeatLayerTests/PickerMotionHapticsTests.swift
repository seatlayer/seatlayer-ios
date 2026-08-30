import Combine
import XCTest
@testable import SeatLayer

final class PickerMotionHapticsTests: XCTestCase {
    func testGeneratedMotionStaysWithinBudgetAndCollapsesForReduceMotion() {
        XCTAssertTrue(SeatLayerPickerMotionTokens.allDurations.values.allSatisfy {
            $0 <= SeatLayerPickerMotionTokens.budgetMilliseconds
        })
        XCTAssertGreaterThan(
            SeatLayerPickerMotionTokens.undoWindowMilliseconds,
            SeatLayerPickerMotionTokens.budgetMilliseconds
        )

        for effect in SeatLayerPickerMotionEffect.allCases {
            let normal = SeatLayerPickerMotion.resolve(effect, reduceMotion: false)
            XCTAssertEqual(
                normal.durationMilliseconds,
                SeatLayerPickerMotionTokens.duration(effect)
            )
            XCTAssertFalse(normal.skipped)

            let reduced = SeatLayerPickerMotion.resolve(effect, reduceMotion: true)
            XCTAssertEqual(reduced.durationMilliseconds, 0)
            XCTAssertEqual(reduced.skipped, effect == .fly || effect == .stagger)
        }
    }

    func testHapticPolicySeedsSilentlyAndSignalsOnlyForwardTransitions() {
        var state = SeatLayerPickerHaptics.initialState
        var result = SeatLayerPickerHaptics.reduce(
            state,
            snapshot: .init(
                selectionCount: 2,
                focusedSectionId: "section-a",
                hasHold: true
            )
        )
        XCTAssertTrue(result.cues.isEmpty)
        state = result.state

        result = SeatLayerPickerHaptics.reduce(
            state,
            snapshot: .init(
                selectionCount: 3,
                focusedSectionId: "section-b",
                hasHold: true
            )
        )
        XCTAssertEqual(result.cues, [.selectionAdded, .sectionFocused])
        state = result.state

        result = SeatLayerPickerHaptics.reduce(
            state,
            snapshot: .init(selectionCount: 1, focusedSectionId: nil, hasHold: false)
        )
        XCTAssertTrue(result.cues.isEmpty)
        state = result.state

        result = SeatLayerPickerHaptics.reduce(
            state,
            snapshot: .init(selectionCount: 1, focusedSectionId: nil, hasHold: true)
        )
        XCTAssertEqual(result.cues, [.holdCreated])
    }

    func testExplicitHoldExpiryDeduplicatesAndRearmsAfterInactiveThenActive() {
        var state = SeatLayerPickerHaptics.reduce(
            SeatLayerPickerHaptics.initialState,
            snapshot: .init(hasHold: true)
        ).state

        var result = SeatLayerPickerHaptics.signalHoldExpired(state)
        XCTAssertEqual(result.cues, [.holdExpired])
        state = result.state

        result = SeatLayerPickerHaptics.signalHoldExpired(state)
        XCTAssertTrue(result.cues.isEmpty)
        state = SeatLayerPickerHaptics.reduce(
            result.state,
            snapshot: .init(hasHold: false)
        ).state
        result = SeatLayerPickerHaptics.reduce(
            state,
            snapshot: .init(hasHold: true)
        )
        XCTAssertEqual(result.cues, [.holdCreated])
    }

    func testHapticStrengthsMatchTheSharedTokenVocabulary() {
        XCTAssertEqual(SeatLayerPickerHaptics.strength(for: .selectionAdded), .selection)
        XCTAssertEqual(SeatLayerPickerHaptics.strength(for: .sectionFocused), .light)
        XCTAssertEqual(SeatLayerPickerHaptics.strength(for: .holdCreated), .medium)
        XCTAssertEqual(SeatLayerPickerHaptics.strength(for: .holdExpired), .heavy)
    }
}

@MainActor
final class PickerHapticControllerTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testControllerPlaysDeduplicatedSnapshotAndExpiryCues() throws {
        let adapter = RecordingPickerHapticAdapter()
        let controller = SeatLayerPickerController(
            transport: PickerHapticTransport(),
            bundleInfo: BundleInfo([
                "bundle": "0.71.5",
                "protocol": ["min": 2, "max": 2],
                "capabilities": .array([]),
                "commands": .array([]),
                "events": .array(["picker.snapshot", "hold.expired"]),
            ])
        )
        controller.configureHaptics(enabled: true, adapter: adapter)
        controller.markReady(
            ReadyInfo(["protocol": 2, "transport": "ios"]),
            payload: nil
        )
        var expirations = 0
        controller.holdExpirations
            .sink { expirations += 1 }
            .store(in: &cancellables)

        controller.accept(snapshot: try XCTUnwrap(snapshot(revision: 1)))
        controller.accept(snapshot: try XCTUnwrap(snapshot(
            revision: 2,
            selectionCount: 1,
            focusedSectionId: "section-a",
            hasHold: true
        )))
        controller.acceptHoldExpired()
        controller.acceptHoldExpired()
        controller.accept(snapshot: try XCTUnwrap(snapshot(
            revision: 3,
            selectionCount: 1,
            focusedSectionId: "section-a",
            hasHold: false
        )))
        controller.accept(snapshot: try XCTUnwrap(snapshot(
            revision: 4,
            selectionCount: 1,
            focusedSectionId: "section-a",
            hasHold: true
        )))

        XCTAssertEqual(adapter.strengths, [.selection, .light, .medium, .heavy, .medium])
        XCTAssertEqual(expirations, 1)
    }

    func testDisabledHapticsTrackStateWithoutReplayingItWhenEnabled() throws {
        let adapter = RecordingPickerHapticAdapter()
        let controller = SeatLayerPickerController(
            transport: PickerHapticTransport(),
            bundleInfo: BundleInfo([
                "bundle": "0.71.5",
                "protocol": ["min": 2, "max": 2],
                "events": .array(["picker.snapshot", "hold.expired"]),
            ])
        )
        controller.configureHaptics(enabled: false, adapter: nil)
        controller.markReady(ReadyInfo(["protocol": 2]), payload: nil)
        controller.accept(snapshot: try XCTUnwrap(snapshot(revision: 1)))
        controller.accept(snapshot: try XCTUnwrap(snapshot(revision: 2, selectionCount: 1)))

        controller.configureHaptics(enabled: true, adapter: adapter)
        controller.accept(snapshot: try XCTUnwrap(snapshot(revision: 3, selectionCount: 1)))
        XCTAssertTrue(adapter.strengths.isEmpty)

        controller.accept(snapshot: try XCTUnwrap(snapshot(revision: 4, selectionCount: 2)))
        XCTAssertEqual(adapter.strengths, [.selection])
    }

    private func snapshot(
        revision: Int,
        selectionCount: Int = 0,
        focusedSectionId: String? = nil,
        hasHold: Bool = false
    ) -> SeatLayerPickerSnapshot? {
        var map: [String: JSONValue] = ["rung": "zones"]
        if let focusedSectionId { map["focusedSectionId"] = .string(focusedSectionId) }
        let seats: [JSONValue] = (0..<selectionCount).map { index in
            ["id": .string("seat-\(index)"), "label": .string("A-\(index)")]
        }
        return decodeSeatLayerPickerSnapshot([
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": "session-1",
            "revision": .int(revision),
            "event": ["key": "ev_picker", "currency": "EUR"],
            "map": .object(map),
            "selection": ["seats": .array(seats)],
            "hold": ["active": .bool(hasHold), "ownership": "picker"],
        ])
    }
}

@MainActor
private final class RecordingPickerHapticAdapter: SeatLayerPickerHapticAdapter {
    private(set) var strengths: [SeatLayerPickerHapticStrength] = []

    func play(_ strength: SeatLayerPickerHapticStrength) {
        strengths.append(strength)
    }
}

private actor PickerHapticTransport: SeatLayerPickerCommandTransport {
    func command(_ name: String, payload: JSONValue?) async throws -> JSONValue {
        .object([:])
    }
}
