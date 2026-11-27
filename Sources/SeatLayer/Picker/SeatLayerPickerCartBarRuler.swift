#if canImport(UIKit)
import UIKit

/// How wide the cart row's words are, in the system font the picker draws
/// them in, at the buyer's text size.
enum SeatLayerPickerCartBarRuler {
    /// The text size the picker's scaled fonts use for `size` points.
    static func scaled(_ size: Double, category: UIContentSizeCategory) -> Double {
        UIFontMetrics(forTextStyle: .body).scaledValue(
            for: size,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
        )
    }

    static func width(
        _ text: String,
        size: Double,
        weight: UIFont.Weight,
        category: UIContentSizeCategory
    ) -> Double {
        guard !text.isEmpty else { return 0 }
        let font = UIFont.systemFont(ofSize: scaled(size, category: category), weight: weight)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    /// `label` whole, and each part a line may not break.
    static func widths(
        _ label: String,
        size: Double,
        weight: UIFont.Weight,
        category: UIContentSizeCategory
    ) -> SeatLayerPickerCartBarWidths {
        SeatLayerPickerCartBarWidths(
            whole: width(label, size: size, weight: weight, category: category),
            parts: seatLayerPickerCartBarParts(label).map {
                width($0, size: size, weight: weight, category: category)
            }
        )
    }

    static func weight(_ token: Double) -> UIFont.Weight {
        switch token {
        case ..<350: return .light
        case ..<450: return .regular
        case ..<550: return .medium
        case ..<650: return .semibold
        case ..<750: return .bold
        case ..<850: return .heavy
        default: return .black
        }
    }
}
#endif
