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

    func testAmountsHaveTheirCurrencysDecimalsAndAThousandsMark() {
        func money(_ amount: Double, _ currency: String, _ locale: String) -> String {
            formatSeatLayerPickerMoney(
                amount, currency: currency, locale: Locale(identifier: locale), pricing: nil
            ).replacingOccurrences(of: "\u{00A0}", with: " ")
                .replacingOccurrences(of: "\u{202F}", with: " ")
        }
        XCTAssertEqual(money(12.625, "KWD", "en_US"), "KWD 12.625")
        XCTAssertEqual(money(12454.5, "KWD", "en_US"), "KWD 12,454.500")
        XCTAssertEqual(money(125_000, "INR", "en_US"), "₹125,000")
        XCTAssertEqual(money(1234.5, "EUR", "de_DE"), "1.234,50 €")
        XCTAssertEqual(money(1234.5, "JPY", "en_US"), "¥1,235")
        XCTAssertEqual(money(30, "GBP", "en_GB"), "£30")
        XCTAssertFalse(money(12.5, "SAR", "ar").contains("١"))
    }

    private enum FormattingFailure: Error {
        case rejected
    }
}
