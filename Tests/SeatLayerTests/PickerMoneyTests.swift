import XCTest
@testable import SeatLayer

final class PickerMoneyTests: XCTestCase {
    func testHostFormatterReceivesFiniteAmountAndNormalizedCurrency() {
        let pricing = SeatLayerPickerPricing { amount, currency in
            "\(currency):\(Int(amount))"
        }

        XCTAssertEqual(formatSeatLayerPickerMoney(
            .infinity,
            currency: " eur ",
            locale: Locale(identifier: "en_US"),
            pricing: pricing
        ), "EUR:0")
    }

    func testThrowingOrBlankFormatterFallsBackToLocaleAwareMoney() {
        let locale = Locale(identifier: "de_DE")
        let expected = formatSeatLayerPickerMoney(
            60,
            currency: "EUR",
            locale: locale,
            pricing: nil
        )
        XCTAssertEqual(formatSeatLayerPickerMoney(
            60,
            currency: "EUR",
            locale: locale,
            pricing: .init { _, _ in "   " }
        ), expected)
        XCTAssertEqual(formatSeatLayerPickerMoney(
            60,
            currency: "EUR",
            locale: locale,
            pricing: .init { _, _ in throw FormattingFailure.rejected }
        ), expected)
    }

    func testPricingEqualityTracksFormatterReplacement() {
        var pricing = SeatLayerPickerPricing { _, _ in "first" }
        let original = pricing
        pricing.formatter = { _, _ in "second" }

        XCTAssertNotEqual(pricing, original)
        XCTAssertEqual(SeatLayerPickerPricing(), SeatLayerPickerPricing())
    }

    private enum FormattingFailure: Error {
        case rejected
    }
}
