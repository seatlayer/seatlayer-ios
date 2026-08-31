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

    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .currency
    numberFormatter.currencyCode = safeCurrency
    numberFormatter.locale = locale
    numberFormatter.maximumFractionDigits = safeAmount.rounded() == safeAmount ? 0 : 2
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
