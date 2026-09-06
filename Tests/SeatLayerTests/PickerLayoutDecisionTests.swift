import XCTest
@testable import SeatLayer

/// The layout decisions are the one part of the ready layout that can be
/// exercised without a simulator, so they carry the arithmetic every chrome
/// component depends on.
final class PickerLayoutDecisionTests: XCTestCase {
    func testPhoneLayoutReservesRailsAndPeekingSheet() throws {
        let decision = SeatLayerPickerLayoutDecision(
            makeContext(snapshot: try makeSnapshot())
        )

        XCTAssertFalse(decision.usesWideLayout)
        XCTAssertTrue(decision.priceLegendVisible)
        XCTAssertTrue(decision.topRailVisible)
        XCTAssertFalse(decision.floorRailVisible)
        XCTAssertEqual(decision.primaryChromeHeight, SeatLayerPickerReadyMetrics.topRailHeight)
        XCTAssertEqual(decision.topChromeHeight, decision.primaryChromeHeight)
        XCTAssertEqual(decision.bottomChromeHeight, SeatLayerPickerSizeTokens.peekHeight)
        XCTAssertEqual(decision.viewportInsets.top, decision.topChromeHeight)
        XCTAssertEqual(decision.viewportInsets.bottom, decision.bottomChromeHeight)
        XCTAssertEqual(
            decision.viewportInsets.right,
            SeatLayerPickerReadyMetrics.mapControlColumnInset
        )
        XCTAssertEqual(decision.viewportInsets.left, 0)
        XCTAssertFalse(decision.decisionVisible)
        XCTAssertFalse(decision.interactionBlocked)
        XCTAssertEqual(decision.inventoryStatus, .availableOrUnknown)
    }

    func testWideLayoutAddsRailWidthAndDropsPhoneSheet() throws {
        let phone = SeatLayerPickerLayoutDecision(
            makeContext(snapshot: try makeSnapshot())
        )
        let wide = SeatLayerPickerLayoutDecision(
            makeContext(snapshot: try makeSnapshot(), isRegularWidth: true)
        )

        XCTAssertTrue(wide.usesWideLayout)
        XCTAssertEqual(wide.bottomChromeHeight, 0)
        XCTAssertEqual(
            wide.viewportInsets.right,
            wide.wideRailWidth + SeatLayerPickerReadyMetrics.mapControlColumnInset
        )
        XCTAssertNotEqual(wide.viewportInsetKey, phone.viewportInsetKey)
    }

    func testCardUpBlocksInteractionWithoutImmersiveInspection() throws {
        let decision = SeatLayerPickerLayoutDecision(
            makeContext(snapshot: try makeSnapshot(), pendingSeatId: "seat-1")
        )

        XCTAssertTrue(decision.decisionVisible)
        XCTAssertFalse(decision.immersiveInspectionVisible)
        XCTAssertTrue(decision.interactionBlocked)
        XCTAssertFalse(decision.statusOverlayVisible)
        XCTAssertEqual(
            decision.decisionTruthTopReserve,
            decision.primaryChromeHeight + 8
        )
    }

    func testExpandedSheetHeightFlowsIntoBottomInsets() throws {
        let expanded = SeatLayerPickerLayoutDecision(
            makeContext(snapshot: try makeSnapshot(), phoneCartHeight: 420)
        )

        XCTAssertEqual(expanded.bottomChromeHeight, 420)
        XCTAssertEqual(expanded.viewportInsets.bottom, 420)
        XCTAssertEqual(
            expanded.bottomOverlayControlInset,
            420 + SeatLayerPickerReadyMetrics.attributionControlInset
        )
    }

    func testTestModeReservesTruthBandAboveTheMap() throws {
        let decision = SeatLayerPickerLayoutDecision(
            makeContext(snapshot: try makeSnapshot(mode: "test"))
        )

        XCTAssertTrue(decision.isTestMode)
        XCTAssertTrue(decision.truthBandVisibleAtTop)
        XCTAssertEqual(
            decision.topChromeHeight,
            decision.primaryChromeHeight + SeatLayerPickerReadyMetrics.truthBandHeight
        )
    }

    func testMultipleFloorsAddTheFloorRail() throws {
        let decision = SeatLayerPickerLayoutDecision(
            makeContext(snapshot: try makeSnapshot(floors: ["Stalls", "Circle"]))
        )

        XCTAssertTrue(decision.floorRailVisible)
        XCTAssertEqual(
            decision.primaryChromeHeight,
            SeatLayerPickerReadyMetrics.topRailHeight
                + SeatLayerPickerReadyMetrics.floorRailHeight
        )
    }

    func testLoadingPhaseAlwaysShowsTheStatusOverlay() throws {
        let decision = SeatLayerPickerLayoutDecision(
            makeContext(snapshot: nil, phase: .loading)
        )

        XCTAssertTrue(decision.statusOverlayVisible)
        XCTAssertTrue(decision.interactionBlocked)
        XCTAssertFalse(decision.priceLegendVisible)
        XCTAssertEqual(decision.viewportInsetKey.hasPrefix("-:"), true)
    }

    func testTheCompositionIsKeyedOffThePickersOwnContainerWidth() throws {
        // A regular size class describes the WINDOW. A picker handed a narrow
        // box inside it — a split view, a sheet, an iPad sidebar — is a phone.
        let narrow = SeatLayerPickerLayoutDecision(makeContext(
            snapshot: try makeSnapshot(),
            isRegularWidth: true,
            containerWidth: 420
        ))
        XCTAssertFalse(narrow.usesWideLayout)

        let wide = SeatLayerPickerLayoutDecision(makeContext(
            snapshot: try makeSnapshot(),
            isRegularWidth: false,
            containerWidth: SeatLayerPickerSizeTokens.wideBreakpoint
        ))
        XCTAssertTrue(wide.usesWideLayout)

        // Between the two breakpoints the compact composition holds.
        let between = SeatLayerPickerLayoutDecision(makeContext(
            snapshot: try makeSnapshot(),
            isRegularWidth: true,
            containerWidth: SeatLayerPickerSizeTokens.phoneBreakpoint + 1
        ))
        XCTAssertFalse(between.usesWideLayout)
    }

    func testAnUnmeasuredContainerStillFallsBackToTheSizeClass() throws {
        let decision = SeatLayerPickerLayoutDecision(makeContext(
            snapshot: try makeSnapshot(),
            isRegularWidth: true,
            containerWidth: nil
        ))

        XCTAssertTrue(decision.usesWideLayout)
    }

    func testWithNoDockTheBottomAnchorsSitAtTheMapsOwnEdge() throws {
        let decision = SeatLayerPickerLayoutDecision(makeContext(
            snapshot: try makeSnapshot(),
            bottomSafeInset: 34
        ))

        XCTAssertFalse(decision.dockMounted)
        XCTAssertEqual(decision.anchorPlan.bottomLift, 0)
        XCTAssertEqual(
            decision.anchorPlan.insets(for: .bottomTrailing).bottom,
            SeatLayerPickerSizeTokens.mapAnchorInset
        )
    }

    func testAMountedDockAbsorbsTheSafeInsetOnceAndLiftsTheAnchors() throws {
        var options = SeatLayerPickerOptions()
        options.chrome.dock = true
        let decision = SeatLayerPickerLayoutDecision(makeContext(
            snapshot: try makeSnapshot(rung: "seats", focusedSection: "s-1"),
            options: options,
            bottomSafeInset: 34
        ))

        XCTAssertTrue(decision.dockMounted)
        XCTAssertEqual(
            decision.anchorPlan.bottomLift,
            SeatLayerPickerSizeTokens.dockBarHeight + 34
        )
        XCTAssertEqual(
            decision.bottomChromeHeight,
            SeatLayerPickerSizeTokens.peekHeight + SeatLayerPickerSizeTokens.dockBarHeight + 34
        )
    }

    // MARK: - Fixtures

    private func makeContext(
        snapshot: SeatLayerPickerSnapshot?,
        phase: SeatLayerPickerPhase = .ready(ReadyInfo(nil)),
        pendingSeatId: String? = nil,
        hasActivePrompt: Bool = false,
        isRegularWidth: Bool = false,
        isAccessibilityTypeSize: Bool = false,
        phoneCartHeight: Double = SeatLayerPickerSizeTokens.peekHeight,
        options: SeatLayerPickerOptions = SeatLayerPickerOptions(),
        containerWidth: Double? = nil,
        bottomSafeInset: Double = 0
    ) -> SeatLayerPickerLayoutContext {
        SeatLayerPickerLayoutContext(
            snapshot: snapshot,
            bundle: makeBundle(),
            seatView: nil,
            phase: phase,
            supportsVenue3D: false,
            options: options,
            pendingSeatId: pendingSeatId,
            hasActivePrompt: hasActivePrompt,
            isRegularWidth: isRegularWidth,
            isAccessibilityTypeSize: isAccessibilityTypeSize,
            phoneCartHeight: phoneCartHeight,
            containerWidth: containerWidth,
            bottomSafeInset: bottomSafeInset
        )
    }

    private func makeBundle() -> BundleInfo {
        BundleInfo([
            "bundle": "test",
            "protocol": ["min": 2, "max": 2],
            "capabilities": .array(["native-chrome-contract-v1"].map(JSONValue.string)),
            "commands": .array(["picker.setViewportInsets"].map(JSONValue.string)),
            "events": .array(["picker.snapshot"].map(JSONValue.string)),
        ])
    }

    private func makeSnapshot(
        mode: String = "live",
        floors: [String] = [],
        rung: String = "zones",
        focusedSection: String? = nil
    ) throws -> SeatLayerPickerSnapshot {
        var map: [String: JSONValue] = [
            "rung": .string(rung),
            "buyerView": "map",
        ]
        if let focusedSection { map["focusedSectionId"] = .string(focusedSection) }
        if !floors.isEmpty {
            map["floors"] = .array(floors.enumerated().map { index, label in
                .object(["id": .string("floor-\(index)"), "name": .string(label)])
            })
        }
        return try XCTUnwrap(decodeSeatLayerPickerSnapshot([
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": "layout-session",
            "revision": 1,
            "event": ["key": "event", "currency": "EUR", "mode": .string(mode)],
            "map": .object(map),
            "catalog": ["categories": .array([
                .object([
                    "key": "standard",
                    "label": "Standard",
                    "price": 30,
                    "available": 12,
                ]),
            ])],
        ]))
    }
}
