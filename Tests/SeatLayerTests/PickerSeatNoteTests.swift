import XCTest
@testable import SeatLayer

/// The one list of what a seat's own attributes say, and the colours it says
/// them in.
final class PickerSeatNoteTests: XCTestCase {
    private let strings = SeatLayerPickerStrings()

    private func rows(
        accessibility: [String]? = nil,
        wheelchairSpaceType: String? = nil,
        commercial: SeatCommercialAttributes? = nil
    ) -> [SeatLayerSeatNote] {
        seatLayerSeatNoteRows(
            strings: strings,
            accessibility: accessibility,
            wheelchairSpaceType: wheelchairSpaceType,
            commercial: commercial
        )
    }

    func testEveryAttributeInOneFixedReadingOrder() {
        let list = rows(
            accessibility: ["hearing", "companion"],
            wheelchairSpaceType: "no-seat",
            commercial: .init(
                restrictedView: true,
                obstructedView: true,
                premium: true,
                note: nil
            )
        )
        XCTAssertEqual(list.map(\.key), [
            "access:hearing",
            "access:companion",
            "wheelchair:no-seat",
            "mark:restrictedView",
            "mark:obstructedView",
            "mark:premium",
        ])
    }

    /// A seat behind both a rail and a pillar used to be told about the rail
    /// and never about the pillar.
    func testRestrictedAndObstructedEachGetARow() {
        let list = rows(commercial: .init(
            restrictedView: true,
            obstructedView: true,
            premium: nil,
            note: nil
        ))
        XCTAssertEqual(list.count, 2)
        XCTAssertTrue(list.allSatisfy { $0.tone == .warn })
        XCTAssertNotEqual(list[0].title, list[1].title)
    }

    /// "Empty wheelchair space" already says everything "wheelchair" would,
    /// and more precisely; listing both is one seat explained twice.
    func testTheProvisionReplacesTheAccommodationRatherThanJoiningIt() {
        let list = rows(accessibility: ["wheelchair"], wheelchairSpaceType: "no-seat")
        XCTAssertEqual(list.map(\.key), ["wheelchair:no-seat"])
        XCTAssertEqual(list[0].iconKey, "wheelchair")

        let seated = rows(accessibility: ["wheelchair"], wheelchairSpaceType: "seat-present")
        XCTAssertEqual(seated.map(\.key), ["wheelchair:seat-present"])

        // With no provision the accommodation stands on its own.
        XCTAssertEqual(rows(accessibility: ["wheelchair"]).map(\.key), ["access:wheelchair"])
    }

    /// An organizer writing "pillar at the aisle end" is explaining the
    /// restriction, not adding a second unrelated fact.
    func testTheOrganizersSentenceHangsOnTheMarkItExplains() {
        let explained = rows(commercial: .init(
            restrictedView: true,
            obstructedView: nil,
            premium: nil,
            note: "  Pillar at the aisle end  "
        ))
        XCTAssertEqual(explained.count, 1)
        XCTAssertEqual(explained[0].key, "mark:restrictedView")
        XCTAssertEqual(explained[0].note, "Pillar at the aisle end")

        let alone = rows(commercial: .init(
            restrictedView: nil,
            obstructedView: nil,
            premium: nil,
            note: "Bring a coat"
        ))
        XCTAssertEqual(alone.map(\.key), ["note"])
        XCTAssertEqual(alone[0].tone, .note)
        XCTAssertNil(rows(commercial: .init(
            restrictedView: nil, obstructedView: nil, premium: nil, note: "   "
        )).first)
    }

    /// A row whose drawing is missing prints its words alone, so every key the
    /// model can emit has to name a drawing this build actually has.
    func testEveryRowNamesADrawingThisBuildHas() {
        let list = rows(
            accessibility: [
                "wheelchair", "companion", "semi-ambulatory", "designated-aisle",
                "step-free", "hearing", "cart", "sign-language", "low-vision",
                "sensory-friendly", "plus-size", "lift-armrest",
            ],
            commercial: .init(
                restrictedView: true,
                obstructedView: true,
                premium: true,
                note: nil
            )
        )
        XCTAssertEqual(list.count, 15)
        for row in list {
            XCTAssertNotNil(seatLayerSeatIconPath(row.iconKey), row.key)
        }
        XCTAssertNotNil(seatLayerSeatIconPath("note"))
    }

    /// The contrast gate. Measured against the ground the band ACTUALLY paints
    /// on — the wash composited over the surface — rather than against the
    /// surface the tint is mixed from, which is how a 1.8:1 amber shipped.
    func testEveryTitleClears45To1OnItsOwnBandInBothThemes() {
        for dark in [false, true] {
            let palette = SeatLayerSeatNoteInkPalette.tokens(dark: dark)
            for tone in SeatLayerSeatNoteTone.allCases {
                let resolved = seatLayerSeatNoteInk(palette, tone)
                let title = SeatLayerPickerInk.contrastRatio(resolved.ink, resolved.ground)
                XCTAssertGreaterThanOrEqual(
                    title, 4.5,
                    "title \(tone.rawValue) \(dark ? "dark" : "light")"
                )
                let body = SeatLayerPickerInk.contrastRatio(resolved.bodyInk, resolved.ground)
                XCTAssertGreaterThanOrEqual(
                    body, 4.5,
                    "body \(tone.rawValue) \(dark ? "dark" : "light")"
                )
            }
        }
    }

    /// A category band is the organizer's own hex, so its ink is measured
    /// rather than picked by theme.
    func testTheCategoryBandChoosesItsInkByMeasurement() {
        let paleYellow = try? XCTUnwrap(SeatLayerPickerInkColor(hex: "#F4E08A"))
        let deepBlue = try? XCTUnwrap(SeatLayerPickerInkColor(hex: "#1F2E6B"))
        XCTAssertEqual(SeatLayerPickerInk.bandInk(paleYellow!), .bandDarkInk)
        XCTAssertEqual(SeatLayerPickerInk.bandInk(deepBlue!), .white)
        // Never pure black: one true black on an otherwise navy-inked card
        // reads as a printing error.
        XCTAssertGreaterThan(SeatLayerPickerInkColor.bandDarkInk.blue, 0)
    }

    func testAWashIsMeasuredAfterItIsComposited() {
        let ground = SeatLayerPickerInk.blend(
            SeatLayerPickerInkColor(hex: "#F4B740")!,
            SeatLayerPickerOpacityTokens.noteToneWash,
            over: SeatLayerPickerInkColor(hex: "#F6F7FB")!
        )
        // A 10 % amber over the light surface is still very nearly the
        // surface — the figure the ink has to clear.
        XCTAssertGreaterThan(SeatLayerPickerInk.relativeLuminance(ground), 0.8)
        XCTAssertLessThan(
            SeatLayerPickerInk.relativeLuminance(ground),
            SeatLayerPickerInk.relativeLuminance(SeatLayerPickerInkColor(hex: "#F6F7FB")!)
        )
    }
}
