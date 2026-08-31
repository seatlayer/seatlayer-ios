import XCTest
@testable import SeatLayer

final class PickerProjectionTests: XCTestCase {
    func testConfirmedCartUsesPerLineAddressing() throws {
        let lines = [
            line(key: "one", label: "same", price: 25, seatId: "seat-1"),
            line(key: "two", label: "same", price: 30, seatId: "seat-2"),
            line(key: "three", label: "same", price: 20, seatId: nil),
            line(key: "four", label: "other", price: 15, seatId: nil),
        ]
        let pending = try selectedSeat(id: "seat-2", label: "same", objectId: "row")

        let projection = SeatLayerPickerProjections.confirmedCart(lines, pending: pending)

        XCTAssertEqual(projection.items.map { $0.lineKey }, ["one", "four"])
        XCTAssertEqual(projection.totals.quantity, 2)
        XCTAssertEqual(projection.totals.total, 40)
    }

    func testMixedCurrenciesNeverProduceOneDisplayCurrency() {
        let projection = SeatLayerPickerProjections.totals([
            line(key: "ga", objectType: "ga", price: 12, currency: "EUR", quantity: 3),
            line(key: "table", objectType: "table", price: 20, currency: "USD", quantity: 4),
        ])

        XCTAssertEqual(projection.quantity, 7)
        XCTAssertEqual(projection.total, 116)
        XCTAssertNil(projection.currency)
        XCTAssertTrue(projection.hasMixedCurrencies)
    }

    func testDenseRunsFoldAdjacentSeatsAndSortMembers() throws {
        let lines = [
            line(key: "three", label: "A-3", seatNumber: "3"),
            line(key: "one", label: "A-1", seatNumber: "1"),
            line(key: "two", label: "A-2", seatNumber: "2"),
        ].map {
            SeatLayerPickerProjections.denseLine(
                $0,
                display: .init(categoryLabel: "Adult", amountText: "€25")
            )
        }

        let run = try XCTUnwrap(SeatLayerPickerProjections.denseRuns(lines).first)

        XCTAssertEqual(run.seatsLabel, "1–3")
        XCTAssertEqual(run.total, 75)
        XCTAssertEqual(
            SeatLayerPickerProjections.membersInSeatOrder(run).map(\.seatLabel),
            ["1", "2", "3"]
        )
    }

    func testSeatRunLabelsNeverInventGaps() {
        XCTAssertEqual(
            SeatLayerPickerProjections.seatRunLabel(["1", "2", "4", "5", "6"]),
            "1, 2, 4 +2"
        )
        XCTAssertEqual(SeatLayerPickerProjections.seatRunLabel(["1", "1", "2"]), "1, 1, 2")
        XCTAssertEqual(SeatLayerPickerProjections.seatRunLabel(["A", "C", "E", "G"]), "A, C, E +1")
    }

    func testUndoRequiresSuccessfulSameSessionAbsentInventory() {
        let item = line(key: "one", label: "A-1")
        XCTAssertTrue(SeatLayerPickerProjections.canUndoRemoval(
            line: item,
            phase: .undoWindow,
            sameSession: true,
            stillAbsent: true
        ))
        XCTAssertFalse(SeatLayerPickerProjections.canUndoRemoval(
            line: item,
            phase: .awaitingRemove,
            sameSession: true,
            stillAbsent: true
        ))
        XCTAssertFalse(SeatLayerPickerProjections.canUndoRemoval(
            line: item,
            phase: .undoWindow,
            sameSession: false,
            stillAbsent: true
        ))
    }

    func testStructuralSelectionIdentityMatchesNeutralJSONForm() throws {
        let seat = try selectedSeat(id: "seat-1", label: "A-1", objectId: "row-a")
        XCTAssertEqual(
            SeatLayerPickerProjections.seatIdentity(seat),
            #"["seat-1","A-1","row-a"]"#
        )
    }

    func testGeneratedLocaleCatalogAndFallback() {
        XCTAssertEqual(SeatLayerPickerStrings.supportedLocales.count, 37)
        XCTAssertEqual(
            SeatLayerPickerStrings(localeIdentifier: "de-DE").text(.continueWord),
            "Weiter"
        )
        XCTAssertEqual(
            SeatLayerPickerStrings(localeIdentifier: "zh-TW").text(.continueWord),
            "繼續"
        )
        XCTAssertEqual(
            SeatLayerPickerStrings(localeIdentifier: "xx").text(.continueWord),
            "Continue"
        )
        XCTAssertTrue(SeatLayerPickerStrings(localeIdentifier: "ar-SA").usesRightToLeftLayout)
        XCTAssertTrue(SeatLayerPickerStrings(localeIdentifier: "he").usesRightToLeftLayout)
        XCTAssertFalse(SeatLayerPickerStrings(localeIdentifier: "de-DE").usesRightToLeftLayout)
        XCTAssertEqual(
            SeatLayerPickerStrings(localeIdentifier: "es-MX").resolvedLocale.identifier
                .replacingOccurrences(of: "_", with: "-"),
            "es-MX"
        )
        XCTAssertEqual(
            SeatLayerPickerStrings(localeIdentifier: "de-DE").text(.undo),
            "Rückgängig"
        )
        XCTAssertEqual(
            SeatLayerPickerStrings(localeIdentifier: "de-DE").findBestSeats(2),
            "2 beste Plätze finden"
        )
    }

    func testBuyerErrorCopyNeverEchoesPrivateRuntimeOrHostDescriptions() {
        let strings = SeatLayerPickerStrings(localeIdentifier: "en")
        let opaque = "hold_private_123"
        let bridge = SeatLayerError.bridge(.init(
            code: "sold_out",
            message: "Could not transfer \(opaque)"
        ))
        let host = SeatLayerError.transport("Host rejected \(opaque)")

        XCTAssertEqual(
            seatLayerPickerBuyerErrorText(bridge, strings: strings),
            strings.text(.noTicketsAvailable)
        )
        XCTAssertEqual(
            seatLayerPickerBuyerErrorText(host, strings: strings),
            strings.text(.retry)
        )
        XCTAssertFalse(seatLayerPickerBuyerErrorText(bridge, strings: strings).contains(opaque))
        XCTAssertFalse(seatLayerPickerBuyerErrorText(host, strings: strings).contains(opaque))
    }

    func testCanonicalBuilderMatrixHasExactlyTwentyFiveUniqueParts() {
#if canImport(SwiftUI) && canImport(UIKit)
        XCTAssertEqual(SeatLayerPickerPart.allCases.count, 25)
        XCTAssertEqual(Set(SeatLayerPickerPart.allCases.map { $0.rawValue }).count, 25)
#endif
    }

    func testAdaptiveMapControlDefaultsMatchPhoneAndWideOwnership() {
        let chrome = SeatLayerPickerChromeOptions()
        XCTAssertFalse(chrome.showsOverview(wide: false))
        XCTAssertFalse(chrome.showsZoom(wide: false))
        XCTAssertFalse(chrome.showsColorblind(wide: false))
        XCTAssertTrue(chrome.showsOverview(wide: true))
        XCTAssertTrue(chrome.showsZoom(wide: true))
        XCTAssertTrue(chrome.showsColorblind(wide: true))

        let explicit = SeatLayerPickerChromeOptions(
            overview: true,
            zoom: false,
            colorblind: true,
            phoneOverview: true,
            phoneColorblind: true
        )
        XCTAssertTrue(explicit.showsOverview(wide: false))
        XCTAssertFalse(explicit.showsZoom(wide: true))
        XCTAssertTrue(explicit.showsColorblind(wide: false))
    }

    func testBridgeOptionsDropInvalidDurationsLimitsHoldsAndOversizedLanguageLists() {
        let options = SeatLayerPickerOptions(
            holdTtlMs: 0,
            initialHoldId: "  \n ",
            max3DSeats: -2,
            languages: (0..<65).map { "x-\($0)" }
        )

        XCTAssertNil(options.bridgeConfig["holdTtlMs"])
        XCTAssertNil(options.bridgeConfig["initialHoldId"])
        XCTAssertNil(options.bridgeConfig["max3DSeats"])
        XCTAssertNil(options.bridgeConfig["languages"])
        XCTAssertNil(options.normalizedHoldTtlMs)
    }

    func testBridgeOptionsNormalizeHoldAndLanguagesWithoutChangingPublicIntent() {
        let options = SeatLayerPickerOptions(
            holdTtlMs: 60_000,
            initialHoldId: "  restored-hold  ",
            max3DSeats: 4,
            languages: [" en_GB ", "EN-gb", "fr", "", String(repeating: "x", count: 129)]
        )

        XCTAssertEqual(options.bridgeConfig["holdTtlMs"]?.intValue, 60_000)
        XCTAssertEqual(options.bridgeConfig["initialHoldId"]?.stringValue, "restored-hold")
        XCTAssertEqual(options.bridgeConfig["max3DSeats"]?.intValue, 4)
        XCTAssertEqual(
            options.bridgeConfig["languages"]?.arrayValue?.compactMap(\.stringValue),
            ["en-GB", "fr"]
        )
        XCTAssertEqual(options.normalizedHoldTtlMs, 60_000)
    }

    private func line(
        key: String,
        label: String = "A-1",
        objectType: String = "seat",
        price: Double = 25,
        currency: String = "EUR",
        quantity: Int = 1,
        seatNumber: String = "1",
        seatId: String? = nil
    ) -> SeatLayerPickerCartLine {
        SeatLayerPickerCartLine(
            lineKey: key,
            label: label,
            displayLabel: nil,
            displayType: nil,
            objectId: "object-\(key)",
            objectType: objectType,
            categoryKey: "standard",
            tierId: nil,
            tierName: nil,
            unitPrice: price,
            currency: currency,
            quantity: quantity,
            seatId: seatId,
            sectionLabel: "Gallery",
            rowLabel: "A",
            seatNumber: seatNumber
        )
    }

    private func selectedSeat(id: String, label: String, objectId: String) throws -> SelectedSeat {
        try JSONDecoder().decode(
            SelectedSeat.self,
            from: Data(#"{"id":"\#(id)","label":"\#(label)","objectId":"\#(objectId)"}"#.utf8)
        )
    }
}
