import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Hash of the canonical cross-platform picker token input used to generate
/// this file. Flutter and React Native publish the same hash.
public let seatLayerPickerTokenSourceSHA256 =
    "27751f1d250d9492c5f38bc93aa5ca1bb0db32ab4732cc20dff918ee5fda85a1"

/// Hash of the canonical locale input used by the native picker strings.
public let seatLayerPickerLocaleSourceSHA256 =
    "340645082f4280ce445375fc1675601b78665cb8b0fadb3622bdc8d69561215f"

/// Hash of the platform-neutral picker component catalogue.
public let seatLayerPickerComponentSourceSHA256 =
    "0f2a02e63a45c81903adab54b1fb6e5b672b22eb86b2823ef083b0b4926a2951"

/// Hash of the platform-neutral picker specification.
public let seatLayerPickerSpecSourceSHA256 =
    "2d21c47d255cac9ce1a1cf239c8d9361d42bfed18e25e37dc41fac3591f27d39"

// Every number the native chrome draws now enters Swift through
// `SeatLayerPickerTokens*.g.swift`, generated from `Design/tokens.json`. This
// file keeps only behaviour built on top of those constants, plus the
// deprecated names that older call sites still spell.

extension SeatLayerPickerSizeTokens {
    /// Retired with the dense ticket list. Kept so existing call sites still
    /// compile; it has no counterpart in the canonical token document.
    @available(*, deprecated, message: "The dense ticket list has been retired.")
    public static let denseLineHeight: Double = 40

    /// Retired with the dense ticket list.
    @available(*, deprecated, message: "The dense ticket list has been retired.")
    public static let denseVisibleLines = 5
}

/// One animated moment in the native chrome.
public enum SeatLayerPickerMotionEffect: String, Sendable, Equatable, CaseIterable {
    case enter
    case exit
    case dock
    case sheet
    case fly
    case pop
    case stagger
    case crossfade
    case bump
    case chevron
    case toast
    case immersive
    case pressSweep
    case cardEnter
    case thumbOut
}

/// The named curves the picker animates along.
public enum SeatLayerPickerMotionCurve: String, Sendable, Equatable, CaseIterable {
    case easeEnter
    case easeExit
    case spring
}

public struct SeatLayerPickerCubicBezier: Sendable, Equatable {
    public let x1: Double
    public let y1: Double
    public let x2: Double
    public let y2: Double

    public init(x1: Double, y1: Double, x2: Double, y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
}

/// Durations, in milliseconds, resolved from the generated motion tokens.
///
/// The generated namespace is `SeatLayerPickerMotionDurationTokens`; this one
/// keeps the `…Milliseconds` spellings the chrome already uses and the
/// effect-keyed lookup the motion resolver is built on.
public enum SeatLayerPickerMotionTokens {
    public static let budgetMilliseconds = SeatLayerPickerMotionDurationTokens.budgetMs
    public static let enterMilliseconds = SeatLayerPickerMotionDurationTokens.enter
    public static let exitMilliseconds = SeatLayerPickerMotionDurationTokens.exit
    public static let dockMilliseconds = SeatLayerPickerMotionDurationTokens.dock
    public static let sheetMilliseconds = SeatLayerPickerMotionDurationTokens.sheet
    public static let flyMilliseconds = SeatLayerPickerMotionDurationTokens.fly
    public static let popMilliseconds = SeatLayerPickerMotionDurationTokens.pop
    public static let staggerMilliseconds = SeatLayerPickerMotionDurationTokens.stagger
    public static let crossfadeMilliseconds = SeatLayerPickerMotionDurationTokens.crossfade
    public static let toastMilliseconds = SeatLayerPickerMotionDurationTokens.toast
    public static let immersiveMilliseconds = SeatLayerPickerMotionDurationTokens.immersive
    public static let undoWindowMilliseconds = SeatLayerPickerMotionDurationTokens.undoWindow

    public static func duration(
        _ effect: SeatLayerPickerMotionEffect
    ) -> Int {
        SeatLayerPickerMotionDurationTokens.inBudget[effect.rawValue]
            ?? SeatLayerPickerMotionDurationTokens.enter
    }

    public static var allDurations: [SeatLayerPickerMotionEffect: Int] {
        Dictionary(uniqueKeysWithValues: SeatLayerPickerMotionEffect.allCases.map {
            ($0, duration($0))
        })
    }
}

public struct SeatLayerPickerResolvedMotion: Sendable, Equatable {
    public let effect: SeatLayerPickerMotionEffect
    public let durationMilliseconds: Int
    public let curve: SeatLayerPickerCubicBezier
    /// Effects with no meaningful reduced form are omitted rather than played
    /// instantly when Reduce Motion is enabled.
    public let skipped: Bool

    public init(
        effect: SeatLayerPickerMotionEffect,
        durationMilliseconds: Int,
        curve: SeatLayerPickerCubicBezier,
        skipped: Bool
    ) {
        self.effect = effect
        self.durationMilliseconds = durationMilliseconds
        self.curve = curve
        self.skipped = skipped
    }
}

public enum SeatLayerPickerMotion {
    /// The canonical reduced-motion policy, as the token document words it.
    public static let reducedMotionPolicy =
        SeatLayerPickerMotionDurationTokens.reducedMotionPolicy

    /// Motion with no reduced form: skipped rather than played instantly.
    public static let skippedWhenReduced: Set<SeatLayerPickerMotionEffect> = [
        .fly, .stagger,
    ]

    public static func curve(
        _ curve: SeatLayerPickerMotionCurve
    ) -> SeatLayerPickerCubicBezier {
        SeatLayerPickerCurveTokens.all[curve.rawValue]
            ?? SeatLayerPickerCurveTokens.easeEnter
    }

    public static func resolve(
        _ effect: SeatLayerPickerMotionEffect,
        reduceMotion: Bool,
        curve curveName: SeatLayerPickerMotionCurve = .easeEnter
    ) -> SeatLayerPickerResolvedMotion {
        let skipped = reduceMotion && skippedWhenReduced.contains(effect)
        return .init(
            effect: effect,
            durationMilliseconds: reduceMotion
                ? 0
                : SeatLayerPickerMotionTokens.duration(effect),
            curve: curve(curveName),
            skipped: skipped
        )
    }
}

/// The platform strength each buyer-facing cue fires, resolved from the
/// generated `SeatLayerPickerHapticNameTokens`.
public enum SeatLayerPickerHapticTokens {
    public static let selectionAdded =
        strength(named: SeatLayerPickerHapticNameTokens.selectionAdded)
    public static let sectionFocused =
        strength(named: SeatLayerPickerHapticNameTokens.sectionFocused)
    public static let holdCreated =
        strength(named: SeatLayerPickerHapticNameTokens.holdCreated)
    public static let holdExpired =
        strength(named: SeatLayerPickerHapticNameTokens.holdExpired)

    public static func strength(
        for cue: SeatLayerPickerHapticCue
    ) -> SeatLayerPickerHapticStrength {
        strength(named: SeatLayerPickerHapticNameTokens.all[cue.rawValue] ?? "")
    }

    /// A token strength name this platform cannot fire natively degrades to
    /// the nearest impact rather than falling silent.
    static func strength(named name: String) -> SeatLayerPickerHapticStrength {
        switch name {
        case "selection": return .selection
        case "light": return .light
        case "medium": return .medium
        case "heavy": return .heavy
        case "warning": return .heavy
        default: return .light
        }
    }
}

#if canImport(SwiftUI)
func seatLayerPickerAnimation(
    _ effect: SeatLayerPickerMotionEffect,
    reduceMotion: Bool,
    curve: SeatLayerPickerMotionCurve = .easeEnter
) -> Animation? {
    let resolved = SeatLayerPickerMotion.resolve(
        effect,
        reduceMotion: reduceMotion,
        curve: curve
    )
    guard !resolved.skipped, resolved.durationMilliseconds > 0 else { return nil }
    return .timingCurve(
        resolved.curve.x1,
        resolved.curve.y1,
        resolved.curve.x2,
        resolved.curve.y2,
        duration: Double(resolved.durationMilliseconds) / 1_000
    )
}

/// Scales explicit design-token point sizes with the buyer's Dynamic Type
/// setting while retaining the picker typography weights and rounded numerals.
/// A shared modifier keeps custom component implementations from silently
/// falling back to fixed-size text.
struct SeatLayerPickerScaledFontModifier: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 17
    let weight: Font.Weight
    let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight, design: design))
    }
}

extension View {
    func seatLayerPickerFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(SeatLayerPickerScaledFontModifier(
            size: size,
            weight: weight,
            design: design
        ))
    }
}
#endif

extension SeatLayerPickerStringKey {
    /// Renamed to `rowWord` in the canonical token document.
    @available(*, deprecated, renamed: "rowWord")
    public static var row: Self { .rowWord }
    /// Renamed to `seatWord`.
    @available(*, deprecated, renamed: "seatWord")
    public static var seat: Self { .seatWord }
    /// Renamed to `sectionWord`.
    @available(*, deprecated, renamed: "sectionWord")
    public static var section: Self { .sectionWord }
    /// Renamed to `placeWord`.
    @available(*, deprecated, renamed: "placeWord")
    public static var place: Self { .placeWord }
    /// Renamed to `accessiblePhysicalSeat`.
    @available(*, deprecated, renamed: "accessiblePhysicalSeat")
    public static var accessiblePlace: Self { .accessiblePhysicalSeat }
    /// Renamed to `accessiblePhysicalSeat`.
    @available(*, deprecated, renamed: "accessiblePhysicalSeat")
    public static var wheelchairAccessibleSeating: Self { .accessiblePhysicalSeat }
    /// Renamed to `emptyWheelchairSpace`.
    @available(*, deprecated, renamed: "emptyWheelchairSpace")
    public static var wheelchairSpaceNoFixedChair: Self { .emptyWheelchairSpace }
    /// Renamed to `chooseTableGuests`.
    @available(*, deprecated, renamed: "chooseTableGuests")
    public static var chooseGuests: Self { .chooseTableGuests }
    /// Renamed to `testModeExplained`.
    @available(*, deprecated, renamed: "testModeExplained")
    public static var testModeDescription: Self { .testModeExplained }
    /// Renamed to `noSelectableSeats`.
    @available(*, deprecated, renamed: "noSelectableSeats")
    public static var noTicketsAvailable: Self { .noSelectableSeats }
    /// Renamed to `ticketType`.
    @available(*, deprecated, renamed: "ticketType")
    public static var ticket: Self { .ticketType }
    /// Renamed to `restrictedView`.
    @available(*, deprecated, renamed: "restrictedView")
    public static var limitedViewNotice: Self { .restrictedView }
    /// Renamed to `viewGroupTitle`.
    @available(*, deprecated, renamed: "viewGroupTitle")
    public static var viewInformation: Self { .viewGroupTitle }
    /// Renamed to `removeSeat`; a table line is removed the same way.
    @available(*, deprecated, renamed: "removeSeat")
    public static var removeTable: Self { .removeSeat }
    /// Retired: the accessibility sheet applies its filters live.
    @available(*, deprecated, message: "Filters apply live; there is no apply step.")
    public static var applyFilters: Self { .continueWord }
    /// Retired with the staged hold-recovery prompt.
    @available(*, deprecated, renamed: "retry")
    public static var recoverSeats: Self { .retry }
    /// Retired: the seat card no longer offers a bare dismiss verb.
    @available(*, deprecated, renamed: "close")
    public static var dismiss: Self { .close }
}

/// Buyer-facing wording for the native chrome. Host overrides use the same
/// stable keys as Flutter and React Native and may replace one string without
/// forking a component.
public struct SeatLayerPickerStrings: Sendable, Equatable {
    /// Per-key overrides. The keys are `SeatLayerPickerStringKey` raw values;
    /// prefer the typed `init(overrides:localeIdentifier:)` and
    /// `subscript(_:)` to writing raw names.
    public var overrides: [String: String]
    /// BCP-47 locale. Nil follows the buyer's first preferred language.
    public var localeIdentifier: String?

    public init(
        overrides: [SeatLayerPickerStringKey: String] = [:],
        localeIdentifier: String? = nil
    ) {
        self.overrides = Dictionary(
            uniqueKeysWithValues: overrides.map { ($0.key.rawValue, $0.value) }
        )
        self.localeIdentifier = localeIdentifier
    }

    /// Untyped overrides, kept for hosts that carry their own key table.
    @available(*, deprecated, message: "Use init(overrides:localeIdentifier:) with typed keys.")
    public init(
        overrides: [String: String],
        localeIdentifier: String? = nil
    ) {
        self.overrides = overrides
        self.localeIdentifier = localeIdentifier
    }

    /// Reads or replaces the override for one key.
    public subscript(key: SeatLayerPickerStringKey) -> String? {
        get { overrides[key.rawValue] }
        set { overrides[key.rawValue] = newValue }
    }

    public static var supportedLocales: [String] { generatedLocales.keys.sorted() }

    var resolvedLocale: Locale {
        Locale(identifier: requestedLocaleIdentifier)
    }

    var usesRightToLeftLayout: Bool {
        let language = requestedLocaleIdentifier.split(separator: "-").first
            .map { String($0).lowercased() } ?? "en"
        return ["ar", "fa", "he", "ku"].contains(language)
    }

    public func text(
        _ key: SeatLayerPickerStringKey,
        replacing values: [String: String] = [:]
    ) -> String {
        let template = overrides[key.rawValue]
            ?? overrides[key.localeKey]
            ?? localized[key.localeKey]
            ?? localized[key.rawValue]
            ?? key.englishDefault
        return values.reduce(template) { result, entry in
            result.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
        }
    }

    /// The wording for `count`, choosing the singular or plural form.
    public func text(
        _ plural: SeatLayerPickerPluralKey,
        count: Int,
        replacing values: [String: String] = [:]
    ) -> String {
        var merged = values
        merged["count"] = String(count)
        return text(plural.form(count), replacing: merged)
    }

    public func ticketCount(_ count: Int) -> String {
        text(SeatLayerPickerPluralKeys.ticketCount, count: count)
    }

    public func findBestSeats(_ count: Int) -> String {
        text(SeatLayerPickerPluralKeys.findBestSeats, count: count)
    }

    public func seatsLeft(_ count: Int) -> String {
        text(SeatLayerPickerPluralKeys.seatsLeftInSection, count: count)
    }

    /// Retired with the collapsed sheet's "from" price line.
    @available(*, deprecated, message: "The collapsed sheet no longer prints a from-price.")
    public func fromPrice(_ price: String) -> String {
        text(.fromPrice, replacing: ["price": price])
    }

    public func continueWithTotal(_ money: String) -> String {
        text(.continueWithTotal, replacing: ["money": money])
    }

    public func accessNeed(_ key: String, count: Int? = nil) -> String {
        let canonicalKey = key.lowercased().replacingOccurrences(of: "_", with: "-")
        let known: [String: SeatLayerPickerStringKey] = [
            "wheelchair": .accessWheelchair,
            "companion": .accessCompanion,
            "semi-ambulatory": .accessSemiAmbulatory,
            "designated-aisle": .accessDesignatedAisle,
            "step-free": .accessStepFree,
            "hearing": .accessHearing,
            "cart": .accessCart,
            "sign-language": .accessSignLanguage,
            "low-vision": .accessLowVision,
            "sensory-friendly": .accessSensoryFriendly,
            "plus-size": .accessPlusSize,
            "lift-armrest": .accessLiftArmrest,
        ]
        let words = key
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = words.isEmpty
            ? key
            : String(words.prefix(1)).uppercased(with: resolvedLocale) + words.dropFirst()
        let label = overrides["accessNeeds.\(key)"]
            ?? overrides["accessNeeds.\(canonicalKey)"]
            ?? localized["accessNeeds.\(canonicalKey)"]
            ?? known[canonicalKey].map { text($0) }
            ?? fallback
        guard let count else { return label }
        return text(
            .accessNeedWithCount,
            replacing: ["need": label, "count": String(max(0, count))]
        )
    }

    private var localized: [String: String] {
        let requested = requestedLocaleIdentifier
        if let exact = Self.generatedLocales.first(where: {
            $0.key.caseInsensitiveCompare(requested) == .orderedSame
        })?.value { return exact }
        let language = requested.split(separator: "-").first.map(String.init) ?? "en"
        if language.caseInsensitiveCompare("zh") == .orderedSame {
            let traditional = requested.localizedCaseInsensitiveContains("Hant")
                || requested.localizedCaseInsensitiveContains("TW")
                || requested.localizedCaseInsensitiveContains("HK")
            return Self.generatedLocales[traditional ? "zh-Hant" : "zh-Hans"] ?? [:]
        }
        return Self.generatedLocales.first(where: {
            $0.key.caseInsensitiveCompare(language) == .orderedSame
        })?.value ?? Self.generatedLocales["en"] ?? [:]
    }

    private var requestedLocaleIdentifier: String {
        let candidate = (localeIdentifier ?? Locale.preferredLanguages.first ?? "en")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
        return candidate.isEmpty ? "en" : candidate
    }
}

/// Deliberately derives buyer copy from stable error classification, never
/// from a bridge or host-provided description that could contain private
/// checkout state. Integrators still receive the complete typed error through
/// callbacks for their own diagnostics.
func seatLayerPickerBuyerErrorText(
    _ error: SeatLayerError,
    strings: SeatLayerPickerStrings
) -> String {
    let unavailableCodes: Set<String> = [
        "sold_out",
        "not_enough_together",
        "hold_unavailable",
        "event_closed",
        "sales_closed",
        "no_inventory",
    ]
    if unavailableCodes.contains(error.code) {
        return strings.text(.noSelectableSeats)
    }
    return error.isRetryable ? strings.text(.retry) : strings.text(.errorMessage)
}
