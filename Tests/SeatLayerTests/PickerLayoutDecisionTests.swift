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

    func testHeldSidewaysTheLevelsShareTheTopLineWhereTheyFit() throws {
        let decision = SeatLayerPickerLayoutDecision(makeContext(
            snapshot: try makeSnapshot(mode: "test", floors: ["Stalls", "Circle"]),
            isRegularHeight: false,
            containerWidth: 852,
            containerHeight: 393,
            levelsFitTopLine: true
        ))

        XCTAssertTrue(decision.levelsOnTopLine)
        // The levels' own line is given back to the map.
        XCTAssertEqual(decision.primaryChromeHeight, SeatLayerPickerReadyMetrics.topRailHeight)
        XCTAssertEqual(
            decision.topChromeHeight,
            SeatLayerPickerReadyMetrics.topRailHeight + SeatLayerPickerReadyMetrics.truthBandHeight
        )
    }

    func testTheLevelsKeepTheirOwnLineUprightWideOrWhenTheyDoNotFit() throws {
        let floors = try makeSnapshot(floors: ["Stalls", "Circle"])
        let cases: [(String, SeatLayerPickerLayoutContext)] = [
            ("upright", makeContext(
                snapshot: floors, containerWidth: 393, containerHeight: 852, levelsFitTopLine: true
            )),
            ("sideways, too wide", makeContext(
                snapshot: floors, isRegularHeight: false,
                containerWidth: 852, containerHeight: 393, levelsFitTopLine: false
            )),
            ("tablet", makeContext(
                snapshot: floors, isRegularWidth: true,
                containerWidth: 1180, containerHeight: 820, levelsFitTopLine: true
            )),
        ]
        for (name, context) in cases {
            let decision = SeatLayerPickerLayoutDecision(context)
            XCTAssertFalse(decision.levelsOnTopLine, name)
            XCTAssertEqual(
                decision.primaryChromeHeight,
                SeatLayerPickerReadyMetrics.topRailHeight + SeatLayerPickerReadyMetrics.floorRailHeight,
                name
            )
        }
    }

    func testTheLevelsOnTheTopLineStandInTheMiddleOfTheSwitchesLine() {
        let strip = 34.0
        let withSwitch = SeatLayerPickerAnchorPlan(
            topTrailingControlHeight: SeatLayerPickerSizeTokens.viewModeControlHeight
        )
        XCTAssertEqual(
            withSwitch.topLineLevelsTop(stripHeight: strip),
            SeatLayerPickerSizeTokens.mapAnchorInset
                + (SeatLayerPickerSizeTokens.viewModeControlHeight - strip) / 2
        )
        XCTAssertEqual(
            SeatLayerPickerAnchorPlan().topLineLevelsTop(stripHeight: strip),
            SeatLayerPickerSizeTokens.mapAnchorInset
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
            containerWidth: SeatLayerPickerSizeTokens.wideBreakpoint,
            containerHeight: SeatLayerPickerSizeTokens.tabletShortestSide
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

    func testAPhoneHeldSidewaysKeepsThePhoneLayout() throws {
        // Every iPhone held sideways is shorter than `tabletShortestSide`, and
        // the larger ones are wider than `wideBreakpoint`: the box the picker
        // measures, safe areas included. Plus and Pro Max are also regular in
        // width. The 320-point SE (1st generation) runs the iOS 15 floor.
        let sideways: [(String, Double, Double, Bool)] = [
            ("iPhone SE (1st generation)", 568, 320, false),
            ("iPhone SE", 667, 375, false),
            ("iPhone 16", 852, 393, false),
            ("iPhone 16 Pro", 874, 402, false),
            ("iPhone 16 Plus", 932, 430, true),
            ("iPhone 16 Pro Max", 956, 440, true),
        ]
        for (name, width, height, regularWidth) in sideways {
            let decision = SeatLayerPickerLayoutDecision(makeContext(
                snapshot: try makeSnapshot(),
                isRegularWidth: regularWidth,
                isRegularHeight: false,
                containerWidth: width,
                containerHeight: height
            ))
            XCTAssertFalse(decision.usesWideLayout, name)
            XCTAssertGreaterThan(decision.bottomChromeHeight, 0, "\(name) keeps the one-row cart")
            XCTAssertLessThan(
                decision.viewportInsets.right,
                SeatLayerPickerReadyMetrics.wideRailWidth,
                "\(name) has no rail"
            )
        }
    }

    func testATabletBoxStillTakesTheWideLayout() throws {
        let tablets: [(String, Double, Double)] = [
            ("iPad mini landscape", 1133, 744),
            ("iPad Air 11 landscape", 1180, 820),
            ("iPad Pro 13 landscape", 1376, 1032),
            ("iPad Pro 13 portrait", 1032, 1376),
        ]
        for (name, width, height) in tablets {
            let decision = SeatLayerPickerLayoutDecision(makeContext(
                snapshot: try makeSnapshot(),
                isRegularWidth: true,
                containerWidth: width,
                containerHeight: height
            ))
            XCTAssertTrue(decision.usesWideLayout, name)
        }
        // Upright on the smaller iPads the box is under `wideBreakpoint`.
        let upright = SeatLayerPickerLayoutDecision(makeContext(
            snapshot: try makeSnapshot(),
            isRegularWidth: true,
            containerWidth: 820,
            containerHeight: 1180
        ))
        XCTAssertFalse(upright.usesWideLayout)
    }

    func testAWideButShortBoxIsLaidOutAsAPhone() throws {
        let decision = SeatLayerPickerLayoutDecision(makeContext(
            snapshot: try makeSnapshot(),
            isRegularWidth: true,
            containerWidth: 1000,
            containerHeight: SeatLayerPickerSizeTokens.tabletShortestSide - 1
        ))
        XCTAssertFalse(decision.usesWideLayout)
    }

    func testAnAppThatAsksForTheWideLayoutGetsItSideways() throws {
        var options = SeatLayerPickerOptions()
        options.layout = .wide
        let decision = SeatLayerPickerLayoutDecision(makeContext(
            snapshot: try makeSnapshot(),
            isRegularWidth: false,
            isRegularHeight: false,
            options: options,
            containerWidth: 852,
            containerHeight: 393
        ))
        XCTAssertTrue(decision.usesWideLayout)
    }

    func testBeforeTheFirstMeasureASidewaysPhoneIsAPhone() throws {
        // Plus and Pro Max held sideways are regular in width, compact in height.
        let sideways = SeatLayerPickerLayoutDecision(makeContext(
            snapshot: try makeSnapshot(),
            isRegularWidth: true,
            isRegularHeight: false,
            containerWidth: nil
        ))
        XCTAssertFalse(sideways.usesWideLayout)
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
        isRegularHeight: Bool = true,
        isAccessibilityTypeSize: Bool = false,
        phoneCartHeight: Double = SeatLayerPickerSizeTokens.peekHeight,
        options: SeatLayerPickerOptions = SeatLayerPickerOptions(),
        containerWidth: Double? = nil,
        containerHeight: Double? = nil,
        levelsFitTopLine: Bool = false,
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
            isRegularHeight: isRegularHeight,
            isAccessibilityTypeSize: isAccessibilityTypeSize,
            phoneCartHeight: phoneCartHeight,
            containerWidth: containerWidth,
            containerHeight: containerHeight,
            levelsFitTopLine: levelsFitTopLine,
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
