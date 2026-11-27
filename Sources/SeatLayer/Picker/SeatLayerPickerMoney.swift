import Foundation

/// Safe formatting boundary shared by every native chrome surface.
func formatSeatLayerPickerMoney(
    _ amount: Double,
    currency: String,
    locale: Locale,
    pricing: SeatLayerPickerPricing?
) -> String {
    let safeAmount = amount.isFinite ? amount : 0
    let normalizedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        .uppercased()
    let safeCurrency = normalizedCurrency.isEmpty ? "USD" : normalizedCurrency

    let digits = seatLayerPickerMoneyDigits(safeAmount, currency: safeCurrency)
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .currency
    numberFormatter.currencyCode = safeCurrency
    // The map writes Arabic amounts with the digits 0 to 9.
    numberFormatter.locale = locale.identifier.lowercased().hasPrefix("ar")
        ? Locale(identifier: "\(locale.identifier)@numbers=latn")
        : locale
    numberFormatter.usesGroupingSeparator = true
    // Half up, as the map rounds: ¥1,234.5 is ¥1,235 there, not ¥1,234.
    numberFormatter.roundingMode = .halfUp
    numberFormatter.minimumFractionDigits = digits
    numberFormatter.maximumFractionDigits = digits
    let fallback = numberFormatter.string(from: NSNumber(value: safeAmount))
        ?? "\(safeCurrency) \(safeAmount)"

    guard let formatter = pricing?.formatter else { return fallback }
    do {
        let formatted = try formatter(safeAmount, safeCurrency)
        return formatted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? fallback
            : formatted
    } catch {
        return fallback
    }
}

/// Currencies whose amounts are not written with two decimals.
private let seatLayerPickerNoDecimalCurrencies: Set<String> = Set((
    "AFN ALL BIF CLP COP DJF GNF HUF IDR IQD IRR ISK JPY KMF KPW KRW LAK LBP MGA MMK PKR PYG RWF "
    + "SLL SOS SYP UGX VND VUV XAF XOF XPF YER"
).split(separator: " ").map(String.init))
private let seatLayerPickerThreeDecimalCurrencies: Set<String> = ["BHD", "JOD", "KWD", "LYD", "OMR", "TND"]

/// A whole amount has no decimals; any other has as many as its currency has.
func seatLayerPickerMoneyDigits(_ amount: Double, currency: String) -> Int {
    if amount.rounded() == amount || seatLayerPickerNoDecimalCurrencies.contains(currency) { return 0 }
    return seatLayerPickerThreeDecimalCurrencies.contains(currency) ? 3 : 2
}
