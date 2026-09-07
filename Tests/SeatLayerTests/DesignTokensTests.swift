import XCTest
@testable import SeatLayer

/// Proves the generated Swift constants equal the canonical design document.
///
/// The point of the generator is that no number is transcribed. That claim is
/// only worth anything if something reads the JSON back off disk and compares,
/// so this suite does exactly that — it never restates a value inline.
final class DesignTokensTests: XCTestCase {
    private static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func document() throws -> [String: Any] {
        let url = Self.packageRoot
            .appendingPathComponent("Design")
            .appendingPathComponent("tokens.json")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    private func group(_ trail: String...) throws -> [String: Any] {
        var node: [String: Any] = try document()
        for step in trail {
            node = try XCTUnwrap(node[step] as? [String: Any], "tokens.\(step)")
        }
        return node
    }

    private func numbers(_ trail: String...) throws -> [String: Double] {
        var node: [String: Any] = try document()
        for step in trail {
            node = try XCTUnwrap(node[step] as? [String: Any], "tokens.\(step)")
        }
        return node.compactMapValues { $0 as? Double }
    }

    private func assertEqual(
        _ generated: [String: Double],
        _ source: [String: Double],
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            Set(generated.keys),
            Set(source.keys),
            "\(label) key sets differ",
            file: file,
            line: line
        )
        for (key, value) in source {
            XCTAssertEqual(
                generated[key],
                value,
                "\(label).\(key)",
                file: file,
                line: line
            )
        }
    }

    func testTokenDocumentVersionMatches() throws {
        let version = try XCTUnwrap(document()["version"] as? Int)
        XCTAssertEqual(seatLayerPickerTokensVersion, version)
    }

    func testLightAndDarkPalettesMatchTheDocument() throws {
        let light = try group("color", "light").compactMapValues { $0 as? String }
        let dark = try group("color", "dark").compactMapValues { $0 as? String }
        XCTAssertEqual(SeatLayerPickerLightColorTokens.all, light)
        XCTAssertEqual(SeatLayerPickerDarkColorTokens.all, dark)
        XCTAssertFalse(light.isEmpty)
        XCTAssertFalse(dark.isEmpty)
    }

    func testMeasuredGroupsMatchTheDocument() throws {
        assertEqual(SeatLayerPickerSizeTokens.all, try numbers("size"), "size")
        assertEqual(SeatLayerPickerRadiusTokens.all, try numbers("radius"), "radius")
        assertEqual(
            SeatLayerPickerElevationTokens.all,
            try numbers("elevation"),
            "elevation"
        )
        assertEqual(
            SeatLayerPickerOpacityTokens.all,
            try numbers("opacity"),
            "opacity"
        )
        assertEqual(
            SeatLayerPickerTypeScaleTokens.all,
            try numbers("type", "scaleClamp"),
            "type.scaleClamp"
        )
    }

    func testRadiiKeepTheirDocumentedRelationships() {
        XCTAssertLessThan(
            SeatLayerPickerRadiusTokens.button,
            SeatLayerPickerRadiusTokens.base
        )
        XCTAssertEqual(SeatLayerPickerRadiusTokens.pill, 999)
        XCTAssertEqual(SeatLayerPickerRadiusTokens.chip, 999)
    }

    func testTypeRampMatchesTheDocument() throws {
        let roles = try group("type").compactMapValues { $0 as? [String: Any] }
            .filter { $0.value["size"] != nil }
        XCTAssertEqual(Set(SeatLayerPickerTypeTokens.all.keys), Set(roles.keys))
        for (key, role) in roles {
            let token = try XCTUnwrap(SeatLayerPickerTypeTokens.all[key])
            XCTAssertEqual(token.size, role["size"] as? Double, "type.\(key).size")
            XCTAssertEqual(
                token.weight,
                role["weight"] as? Double,
                "type.\(key).weight"
            )
        }
    }

    func testMotionCatalogMatchesTheDocumentAndItsBudget() throws {
        let durations = try numbers("motion", "duration")
        let outside = try numbers("motion", "durationOutsideBudget")
        let budget = try XCTUnwrap(group("motion")["budgetMs"] as? Double)

        XCTAssertEqual(
            SeatLayerPickerMotionDurationTokens.budgetMs,
            Int(budget)
        )
        assertEqual(
            SeatLayerPickerMotionDurationTokens.inBudget.mapValues(Double.init),
            durations,
            "motion.duration"
        )
        assertEqual(
            SeatLayerPickerMotionDurationTokens.outsideBudget
                .mapValues(Double.init),
            outside,
            "motion.durationOutsideBudget"
        )
        for (key, value) in SeatLayerPickerMotionDurationTokens.inBudget {
            XCTAssertLessThanOrEqual(
                value,
                SeatLayerPickerMotionDurationTokens.budgetMs,
                "motion.duration.\(key) exceeds the budget"
            )
        }
        assertEqual(
            SeatLayerPickerPhysicsTokens.all,
            try numbers("motion", "physics"),
            "motion.physics"
        )
    }

    func testEveryMotionEffectResolvesToItsTokenDuration() throws {
        let durations = try numbers("motion", "duration")
        for effect in SeatLayerPickerMotionEffect.allCases {
            let expected = try XCTUnwrap(
                durations[effect.rawValue],
                "motion.duration.\(effect.rawValue) is missing"
            )
            XCTAssertEqual(
                Double(SeatLayerPickerMotionTokens.duration(effect)),
                expected
            )
            XCTAssertEqual(
                SeatLayerPickerMotion
                    .resolve(effect, reduceMotion: true)
                    .durationMilliseconds,
                0
            )
        }
    }

    func testCurvesMatchTheDocument() throws {
        let curves = try group("motion", "curve")
        for (name, raw) in curves {
            let definition = try XCTUnwrap(raw as? [String: Any])
            let points = try XCTUnwrap(definition["cubicBezier"] as? [Double])
            let token = try XCTUnwrap(SeatLayerPickerCurveTokens.all[name])
            XCTAssertEqual([token.x1, token.y1, token.x2, token.y2], points, name)
        }
        for curve in SeatLayerPickerMotionCurve.allCases {
            XCTAssertNotNil(SeatLayerPickerCurveTokens.all[curve.rawValue])
        }
    }

    func testEveryHapticCueFiresItsDocumentedStrength() throws {
        let haptics = try group("haptics").compactMapValues { $0 as? String }
        XCTAssertEqual(SeatLayerPickerHapticNameTokens.all, haptics.filter {
            $0.key != "note"
        })
        for cue in SeatLayerPickerHapticCue.allCases {
            let name = try XCTUnwrap(haptics[cue.rawValue], cue.rawValue)
            XCTAssertEqual(
                SeatLayerPickerHapticTokens.strength(for: cue),
                SeatLayerPickerHapticTokens.strength(named: name),
                cue.rawValue
            )
        }
    }

    func testStringDefaultsMatchTheDocument() throws {
        let strings = try group("strings").compactMapValues { $0 as? String }
        XCTAssertEqual(
            Set(SeatLayerPickerStringKey.allCases.map(\.rawValue)),
            Set(strings.keys)
        )
        for key in SeatLayerPickerStringKey.allCases {
            XCTAssertEqual(key.englishDefault, strings[key.rawValue], key.rawValue)
        }
    }

    func testPluralKeysAddressTheirTranslatedNames() {
        let ticket = SeatLayerPickerPluralKeys.ticketCount
        XCTAssertEqual(ticket.form(1), ticket.one)
        XCTAssertEqual(ticket.form(0), ticket.other)
        XCTAssertEqual(ticket.form(7), ticket.other)
        XCTAssertEqual(ticket.one.localeKey, "ticketCount.one")
        XCTAssertEqual(ticket.other.localeKey, "ticketCount.other")
        XCTAssertEqual(SeatLayerPickerStringKey.close.localeKey, "close")
    }

    func testTheTokenTableAnswersUntilAHostNamesALocale() {
        // No locale named: the wording the components were drawn with, even
        // though a reviewed English dictionary exists and says other things.
        let defaults = SeatLayerPickerStrings()
        for key in [
            SeatLayerPickerStringKey.close,
            .recentre,
            .testMode,
            .accessibility,
            .fitVenue,
            .errorMessage,
            .accessibilityTitle,
        ] {
            XCTAssertEqual(defaults.text(key), key.englishDefault, key.rawValue)
        }
        XCTAssertEqual(defaults.text(.testMode), "Test mode")
        XCTAssertEqual(defaults.text(.accessibilityTitle), "Accessibility and view")

        // A named locale opts into the reviewed dictionary.
        let english = SeatLayerPickerStrings(localeIdentifier: "en")
        XCTAssertEqual(english.text(.close), "Close")
        XCTAssertEqual(english.text(.testMode), "TEST MODE")

        // A locale with no dictionary keeps the token wording rather than
        // borrowing the reviewed English.
        let unknown = SeatLayerPickerStrings(localeIdentifier: "qya")
        XCTAssertEqual(
            unknown.text(.close),
            SeatLayerPickerStringKey.close.englishDefault
        )

        // A host override still wins over both.
        let overridden = SeatLayerPickerStrings(
            overrides: [.testMode: "Rehearsal"],
            localeIdentifier: "en"
        )
        XCTAssertEqual(overridden.text(.testMode), "Rehearsal")
    }

    func testTypedOverridesReplaceOneStringWithoutForkingTheTable() {
        var strings = SeatLayerPickerStrings(
            overrides: [.close: "Done"],
            localeIdentifier: "en"
        )
        XCTAssertEqual(strings.text(.close), "Done")
        XCTAssertEqual(strings[.close], "Done")
        strings[.close] = nil
        // With the override gone the reviewed English translation answers,
        // which is deliberately shorter than the token's own default.
        XCTAssertEqual(strings.text(.close), "Close")
        // A key the reviewed dictionaries do not carry falls through to the
        // token document's own English.
        XCTAssertEqual(
            strings.text(.chooseSeats),
            SeatLayerPickerStringKey.chooseSeats.englishDefault
        )
    }
}
