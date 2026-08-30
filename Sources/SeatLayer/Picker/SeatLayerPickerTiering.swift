import Foundation

/// Immediate buyer-facing amount for a pending ticket-tier choice.
public struct SeatLayerPickerTierQuote: Sendable, Equatable {
    public let tierId: String?
    public let amount: Double
    public let currency: String?

    public init(tierId: String?, amount: Double, currency: String?) {
        self.tierId = tierId
        self.amount = amount
        self.currency = currency
    }
}

/// Pure ticket-tier semantics shared by ready-made and custom compositions.
public enum SeatLayerPickerTiering {
    public static func resolvedTierId(
        for seat: SelectedSeat,
        preferred: String?
    ) -> String? {
        let tiers = seat.tiers ?? []
        if let preferred, tiers.contains(where: { $0.id == preferred }) {
            return preferred
        }
        if let current = seat.tierId, tiers.contains(where: { $0.id == current }) {
            return current
        }
        return tiers.first?.id
    }

    public static func tier(
        for seat: SelectedSeat,
        preferred: String?
    ) -> CategoryTier? {
        guard let id = resolvedTierId(for: seat, preferred: preferred) else { return nil }
        return seat.tiers?.first { $0.id == id }
    }

    public static func quote(
        for seat: SelectedSeat,
        preferred: String?,
        fallbackCurrency: String? = nil
    ) -> SeatLayerPickerTierQuote? {
        let selected = tier(for: seat, preferred: preferred)
        guard let amount = selected?.price ?? seat.price, amount.isFinite else { return nil }
        return SeatLayerPickerTierQuote(
            tierId: selected?.id,
            amount: amount,
            currency: nonBlank(selected?.currency)
                ?? nonBlank(seat.currency)
                ?? nonBlank(fallbackCurrency)
        )
    }

    public static func quote(
        for tier: CategoryTier,
        fallbackCurrency: String? = nil
    ) -> SeatLayerPickerTierQuote? {
        guard tier.price.isFinite else { return nil }
        return SeatLayerPickerTierQuote(
            tierId: tier.id,
            amount: tier.price,
            currency: nonBlank(tier.currency) ?? nonBlank(fallbackCurrency)
        )
    }

    public static func guidance(
        for tier: CategoryTier,
        companionFallback: String
    ) -> String? {
        if let authored = nonBlank(tier.buyerMessage) { return authored }
        guard tier.restriction?.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "companion" else { return nil }
        return nonBlank(companionFallback)
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
