import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Hash of the canonical cross-platform picker token input used to generate
/// this file. Flutter and React Native publish the same hash.
public let seatLayerPickerTokenSourceSHA256 =
    "defb411c1dc94b1071a70bc92dfa7eff0c7ab443fc110dd86c1cfbd8f54182f4"

/// Hash of the canonical locale input used by the native picker strings.
public let seatLayerPickerLocaleSourceSHA256 =
    "340645082f4280ce445375fc1675601b78665cb8b0fadb3622bdc8d69561215f"

/// Hash of the platform-neutral picker component catalogue.
public let seatLayerPickerComponentSourceSHA256 =
    "4b3b7b83e5502633cbbbbcfdb9e1be4cd07e86dc18e22d651dde3711b98b494d"

/// Hash of the platform-neutral picker specification.
public let seatLayerPickerSpecSourceSHA256 =
    "e54c71d029739b05f4d5cd6a34cc83c0fdcc21e926ae8552b14f129dd72cd984"

// Every number the native chrome draws now enters Swift through
// `SeatLayerPickerTokens*.g.swift`, generated from `Design/tokens.json`. This
// file keeps only the behaviour built on top of those constants.

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
    public static let ticketRemoved =
        strength(named: SeatLayerPickerHapticNameTokens.ticketRemoved)
    public static let holdEnding =
        strength(named: SeatLayerPickerHapticNameTokens.holdEnding)
    public static let cardArrived =
        strength(named: SeatLayerPickerHapticNameTokens.cardArrived)
    public static let seatConfirmed =
        strength(named: SeatLayerPickerHapticNameTokens.seatConfirmed)
    public static let cardCancelled =
        strength(named: SeatLayerPickerHapticNameTokens.cardCancelled)

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
        case "warning": return .warning
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

    /// Draws text at one role from the generated type ramp.
    func seatLayerPickerFont(_ token: SeatLayerPickerTypeToken) -> some View {
        seatLayerPickerFont(
            size: token.size,
            weight: .seatLayerPickerWeight(token.weight)
        )
    }
}

extension Font.Weight {
    /// The nearest platform weight to a token's 100–950 numeric weight.
    static func seatLayerPickerWeight(_ value: Double) -> Font.Weight {
        switch value {
        case ..<250: return .ultraLight
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

    /// The reviewed dictionary to consult, or nothing.
    ///
    /// The token table holds the English wording every surface is designed
    /// around, and it answers unless a host has named a locale. A reviewed
    /// dictionary is a starting point a host opts into, exactly as
    /// `SeatLayerPickerStrings.forLocale` is on the other native SDKs — so a
    /// buyer whose device is English still reads the wording the components
    /// were drawn with, and a locale with no dictionary keeps it too rather
    /// than borrowing the reviewed English.
    private var localized: [String: String] {
        guard let requested = namedLocaleIdentifier else { return [:] }
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
        })?.value ?? [:]
    }

    /// The locale a host asked for, if it asked for one.
    private var namedLocaleIdentifier: String? {
        guard let named = localeIdentifier else { return nil }
        let candidate = named
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
        return candidate.isEmpty ? nil : candidate
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
