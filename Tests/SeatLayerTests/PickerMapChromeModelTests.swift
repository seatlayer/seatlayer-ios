import XCTest
@testable import SeatLayer

/// The chrome that stands on the map never compiles under `swift test`, so
/// every rule it follows is decided here instead.
final class PickerMapChromeModelTests: XCTestCase {
    // MARK: - Anchor regions

    func testEveryFloatingControlBelongsToOneOfSevenRegions() {
        XCTAssertEqual(SeatLayerPickerMapAnchorRegion.allCases.count, 7)
    }

    func testAnchorRegionsSitAtTheTokenInsetAndLiftOnlyForAMountedDock() {
        let bare = SeatLayerPickerAnchorPlan()
        XCTAssertEqual(
            bare.insets(for: .bottomTrailing).bottom,
            SeatLayerPickerSizeTokens.mapAnchorInset
        )
        XCTAssertEqual(
            bare.insets(for: .bottomTrailing).trailing,
            SeatLayerPickerSizeTokens.mapAnchorInset
        )
        XCTAssertNil(bare.insets(for: .bottomTrailing).top)

        let docked = SeatLayerPickerAnchorPlan(bottomLift: 52 + 34)
        XCTAssertEqual(
            docked.insets(for: .bottomLeading).bottom,
            SeatLayerPickerSizeTokens.mapAnchorInset + 86
        )
    }

    func testTheControlColumnIsTighterThanTheMapsOwnGap() {
        let plan = SeatLayerPickerAnchorPlan()
        XCTAssertEqual(
            plan.gap(for: .bottomTrailing),
            SeatLayerPickerSizeTokens.zoomColumnGap
        )
        XCTAssertEqual(
            plan.gap(for: .bottomLeading),
            SeatLayerPickerSizeTokens.mapAnchorGap
        )
    }

    func testTheTestChipStepsDownOnlyWhileTheBackPillIsDrawn() {
        let flat = SeatLayerPickerAnchorPlan()
        XCTAssertEqual(flat.testChipTop, SeatLayerPickerSizeTokens.mapAnchorInset)

        let immersive = SeatLayerPickerAnchorPlan(backPillHeight: 44)
        XCTAssertEqual(
            immersive.testChipTop,
            SeatLayerPickerSizeTokens.mapAnchorInset + 44 + SeatLayerPickerSizeTokens.mapAnchorGap
        )
    }

    func testTheFloorRailStepsBelowTheMapAnd3DControlOnTheSameLine() {
        let alone = SeatLayerPickerAnchorPlan()
        XCTAssertEqual(alone.leadingRailTop, SeatLayerPickerSizeTokens.mapAnchorInset)

        let shared = SeatLayerPickerAnchorPlan(
            topTrailingControlHeight: SeatLayerPickerSizeTokens.viewModeControlHeight
        )
        XCTAssertEqual(
            shared.leadingRailTop,
            SeatLayerPickerSizeTokens.mapAnchorInset
                + SeatLayerPickerSizeTokens.viewModeControlHeight
                + SeatLayerPickerSizeTokens.mapAnchorGap
        )
    }

    // MARK: - Test-chip ink

    func testWarnPillInkKeepsTheHueWhereItAlreadyReads() {
        let warning = SeatLayerPickerRGB(hex: "#F4B740")!
        let dark = SeatLayerPickerRGB(hex: "#10151F")!
        let ink = seatLayerPickerWarnPillInk(
            warning: warning,
            text: SeatLayerPickerRGB(hex: "#EEF1F8")!,
            surface: dark
        )

        XCTAssertEqual(ink, warning)
    }

    func testWarnPillInkIsMeasuredAgainstTheWashAndClearsTheFloor() {
        let warning = SeatLayerPickerRGB(hex: "#F4B740")!
        let text = SeatLayerPickerRGB(hex: "#172033")!
        let surface = SeatLayerPickerRGB(hex: "#FFFFFF")!
        let ground = seatLayerPickerWarnPillGround(warning: warning, surface: surface)
        let ink = seatLayerPickerWarnPillInk(warning: warning, text: text, surface: surface)

        XCTAssertNotEqual(ink, warning, "amber on its own wash cannot clear 4.5:1")
        XCTAssertGreaterThanOrEqual(
            ink.contrast(against: ground),
            seatLayerPickerTextContrastFloor
        )
    }

    func testWarnPillInkGivesUpTheHueOnAMidToneGround() {
        let warning = SeatLayerPickerRGB(hex: "#F4B740")!
        // A mid-tone ink over a mid-tone ground: no mix of the two clears the
        // floor, and the walk has to fall through to a neutral rather than
        // returning the ground's own colour.
        let ink = seatLayerPickerWarnPillInk(
            warning: warning,
            text: SeatLayerPickerRGB(hex: "#8A8F98")!,
            surface: SeatLayerPickerRGB(hex: "#6E7480")!
        )
        let ground = seatLayerPickerWarnPillGround(
            warning: warning,
            surface: SeatLayerPickerRGB(hex: "#6E7480")!
        )

        XCTAssertTrue(
            ink == SeatLayerPickerNeutralInk.dark || ink == SeatLayerPickerNeutralInk.light,
            "the walk runs out and a neutral is the honest answer"
        )
        XCTAssertGreaterThan(
            ink.contrast(against: ground),
            warning.contrast(against: ground),
            "the fallback is the best ink available, even where the floor is out of reach"
        )
    }

    func testTokenColoursParseInBothCanonicalForms() {
        XCTAssertEqual(
            SeatLayerPickerRGB(hex: SeatLayerPickerLightColorTokens.chromeLine)?.hex,
            SeatLayerPickerRGB(hex: "#172033")?.hex
        )
        XCTAssertNil(SeatLayerPickerRGB(hex: "not-a-colour"))
    }

    // MARK: - Price rail

    func testAllPricesIsPinnedFirstAndSelectedWithNoFilter() throws {
        let chips = SeatLayerPickerLegendModel.chips(
            snapshot: try makeSnapshot(),
            compact: true,
            currency: "EUR",
            allPricesLabel: "All prices",
            amount: { "€\(Int($0))" },
            soldOutSuffix: "Sold out"
        )

        XCTAssertEqual(chips.first?.categoryKey, nil)
        XCTAssertEqual(chips.first?.label, "All prices")
        XCTAssertTrue(try XCTUnwrap(chips.first).selected)
    }

    func testTheAmountRulePrintsASinglePriceAndFloorsASpread() throws {
        let chips = SeatLayerPickerLegendModel.chips(
            snapshot: try makeSnapshot(),
            compact: true,
            currency: "EUR",
            allPricesLabel: "All prices",
            amount: { "€\(Int($0))" },
            soldOutSuffix: "Sold out"
        )

        XCTAssertEqual(chips[1].label, "€30")
        XCTAssertEqual(chips[2].label, "€45+")
        // No configured price is a real chart state, and a chip that is only a
        // dot says nothing — so it wears its name.
        XCTAssertEqual(chips[3].label, "Guest list")
    }

    func testTheWideRailNamesTheCategoryBesideTheAmountAndKeepsTheKey() throws {
        let chips = SeatLayerPickerLegendModel.chips(
            snapshot: try makeSnapshot(),
            compact: false,
            currency: "EUR",
            allPricesLabel: "All prices",
            amount: { "€\(Int($0))" },
            soldOutSuffix: "Sold out"
        )

        XCTAssertEqual(chips[1].label, "Standard · €30")
        XCTAssertTrue(SeatLayerPickerLegendModel.showsUnavailableKey(compact: false))
        XCTAssertFalse(SeatLayerPickerLegendModel.showsUnavailableKey(compact: true))
    }

    func testSoldOutNeedsPositiveEvidenceAndAnAbsentCountIsUnknown() throws {
        let chips = SeatLayerPickerLegendModel.chips(
            snapshot: try makeSnapshot(),
            compact: true,
            currency: "EUR",
            allPricesLabel: "All prices",
            amount: { "€\(Int($0))" },
            soldOutSuffix: "Sold out"
        )

        XCTAssertTrue(chips[2].soldOut, "a reported zero is sold out")
        XCTAssertTrue(chips[2].accessibilityLabel.hasSuffix("Sold out"))
        XCTAssertFalse(chips[3].soldOut, "an unreported count is unknown, never zero")
    }

    func testAChartWithNoSellableCategoryDrawsNoRail() throws {
        XCTAssertTrue(SeatLayerPickerLegendModel.chips(
            snapshot: try makeSnapshot(sellable: false),
            compact: true,
            currency: "EUR",
            allPricesLabel: "All prices",
            amount: { "€\(Int($0))" },
            soldOutSuffix: "Sold out"
        ).isEmpty)
    }

    // MARK: - Control column

    func testThePhoneColumnIsAccessibilityPlusAndTheWholeVenue() throws {
        let plan = SeatLayerPickerMapControlModel.plan(
            map: try XCTUnwrap(makeSnapshot().map),
            chrome: SeatLayerPickerChromeOptions(),
            wide: false,
            onMap: true,
            offersVenue3D: true,
            offersColorblind: true,
            offersAccessibility: true
        )

        XCTAssertEqual(plan.controls, [.accessibility, .zoomIn, .wholeVenue])
        XCTAssertFalse(plan.isRetired(.zoomIn))
        XCTAssertFalse(plan.showsBackToVenue)
    }

    func testThePlusDiscRetiresAmongTheSeatsAndKeepsItsSlot() throws {
        let plan = SeatLayerPickerMapControlModel.plan(
            map: try makeSnapshot(rung: "seats", focusedSection: "s-1").map,
            chrome: SeatLayerPickerChromeOptions(),
            wide: false,
            onMap: true,
            offersVenue3D: false,
            offersColorblind: false,
            offersAccessibility: true
        )

        XCTAssertTrue(plan.controls.contains(.zoomIn), "the slot stays")
        XCTAssertTrue(plan.isRetired(.zoomIn))
        XCTAssertFalse(
            plan.showsBackToVenue,
            "the phone reaches the venue through the column's own disc"
        )
    }

    func testTheWideRailAddsMinusAndCarriesNoFitControlOfItsOwn() throws {
        let plan = SeatLayerPickerMapControlModel.plan(
            map: try makeSnapshot(rung: "seats", focusedSection: "s-1").map,
            chrome: SeatLayerPickerChromeOptions(),
            wide: true,
            onMap: true,
            offersVenue3D: true,
            offersColorblind: true,
            offersAccessibility: true
        )

        XCTAssertTrue(plan.controls.contains(.zoomOut))
        XCTAssertFalse(plan.controls.contains(.wholeVenue))
        XCTAssertTrue(plan.controls.contains(.viewMode))
        XCTAssertTrue(plan.controls.contains(.colorblind))
        XCTAssertTrue(plan.showsBackToVenue, "the wide layout keeps the corner disc")
    }

    func testTheImmersiveSceneUnmountsTheWholeColumn() throws {
        let plan = SeatLayerPickerMapControlModel.plan(
            map: try makeSnapshot().map,
            chrome: SeatLayerPickerChromeOptions(),
            wide: false,
            onMap: false,
            offersVenue3D: true,
            offersColorblind: true,
            offersAccessibility: true
        )

        XCTAssertTrue(plan.controls.isEmpty)
        XCTAssertFalse(plan.showsBackToVenue)
    }

    func testTheStepBackLadderPrefersTheFitPoseAndFallsBackToZoomOut() throws {
        let framed = try makeSnapshot(rung: "seats", focusedSection: "s-1").map
        XCTAssertTrue(SeatLayerPickerMapControlModel.canStepBack(framed))

        let fitted = try makeSnapshot(atVenueFit: true).map
        XCTAssertFalse(SeatLayerPickerMapControlModel.canStepBack(fitted))

        // A camera a pinch left between the venue and the seats: the coarse
        // reading is the only one an older runtime offers, and it must not be
        // read as "already home".
        let pinched = try makeSnapshot(canZoomOut: true).map
        XCTAssertTrue(SeatLayerPickerMapControlModel.canStepBack(pinched))

        // A runtime that reports no pose at all has said nothing, which must
        // not be read as "already home".
        let silent = try makeSnapshot(atVenueFit: nil, canZoomOut: true).map
        XCTAssertNil(silent.atVenueFit)
        XCTAssertTrue(SeatLayerPickerMapControlModel.canStepBack(silent))
    }

    // MARK: - Section dock

    func testTheMatchingSpacesSuffixNeedsACapabilityAFilterAndACount() {
        let counted = section(accessibleFree: 4)
        XCTAssertEqual(
            SeatLayerPickerDockModel.accessibleSuffix(
                section: counted,
                filter: ["wheelchair"],
                supportsCounts: true
            ),
            "· ♿ 4"
        )
        XCTAssertNil(SeatLayerPickerDockModel.accessibleSuffix(
            section: counted,
            filter: [],
            supportsCounts: true
        ))
        XCTAssertNil(SeatLayerPickerDockModel.accessibleSuffix(
            section: counted,
            filter: ["wheelchair"],
            supportsCounts: false
        ))
        XCTAssertNil(
            SeatLayerPickerDockModel.accessibleSuffix(
                section: section(accessibleFree: nil),
                filter: ["wheelchair"],
                supportsCounts: true
            ),
            "absent is not zero"
        )
    }

    func testTheCountLadderDegradesFullToShortToHidden() {
        func text(_ step: SeatLayerPickerDockCountStep) -> String? {
            SeatLayerPickerDockModel.countText(
                step: step,
                seatsLeft: 12,
                sectionLabel: "406",
                inSection: { "\($0) seats left in \($1)" },
                plain: { "\($0) left" }
            )
        }

        XCTAssertEqual(text(.full), "12 seats left in 406")
        XCTAssertEqual(text(SeatLayerPickerDockModel.degrade(.full)), "12 left")
        XCTAssertNil(text(SeatLayerPickerDockModel.degrade(.short)))
        XCTAssertNil(SeatLayerPickerDockModel.countText(
            step: .full,
            seatsLeft: nil,
            sectionLabel: "406",
            inSection: { "\($0) \($1)" },
            plain: { "\($0)" }
        ))
    }

    func testTheWidestRungThatFitsIsChosenAndTheCountIsNeverClipped() {
        let candidates: [(step: SeatLayerPickerDockCountStep, width: Double)] = [
            (.full, 180),
            (.short, 70),
        ]

        XCTAssertEqual(SeatLayerPickerDockModel.fit(candidates, budget: 200), .full)
        XCTAssertEqual(SeatLayerPickerDockModel.fit(candidates, budget: 120), .short)
        XCTAssertEqual(SeatLayerPickerDockModel.fit(candidates, budget: 40), .hidden)
        XCTAssertEqual(SeatLayerPickerDockModel.fit([], budget: 400), .hidden)
    }

    // MARK: - Fixtures

    private func section(accessibleFree: Int?) -> SeatLayerPickerSectionSummary {
        SeatLayerPickerSectionSummary(
            id: "s-1",
            label: "406",
            displayLabel: nil,
            zoneId: nil,
            zoneLabel: nil,
            entrance: nil,
            color: nil,
            dominantCategoryKey: nil,
            seatsLeft: 12,
            accessibleFree: accessibleFree,
            priceMin: nil,
            priceMax: nil
        )
    }

    private func makeSnapshot(
        rung: String = "zones",
        focusedSection: String? = nil,
        atVenueFit: Bool? = false,
        canZoomOut: Bool = false,
        sellable: Bool = true
    ) throws -> SeatLayerPickerSnapshot {
        var map: [String: JSONValue] = [
            "rung": .string(rung),
            "buyerView": "map",
            "canZoomIn": true,
            "canZoomOut": .bool(canZoomOut),
        ]
        if let atVenueFit { map["atVenueFit"] = .bool(atVenueFit) }
        if let focusedSection { map["focusedSectionId"] = .string(focusedSection) }
        let categories: [JSONValue] = sellable
            ? [
                .object(["key": "standard", "label": "Standard", "price": 30, "available": 4]),
                .object([
                    "key": "premium",
                    "label": "Premium",
                    "priceMin": 45,
                    "priceMax": 90,
                    "available": 0,
                ]),
                .object(["key": "guest", "label": "Guest list", "price": 0]),
            ]
            : [.object(["key": "hidden", "label": "Hidden", "notForSale": true])]
        return try XCTUnwrap(decodeSeatLayerPickerSnapshot([
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": "chrome-session",
            "revision": 1,
            "event": ["key": "event", "currency": "EUR"],
            "map": .object(map),
            "catalog": ["categories": .array(categories)],
        ]))
    }
}
