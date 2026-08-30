import Foundation

/// Exact support legs for the three independently mutable filter families.
public struct SeatLayerPickerAccessibilityAvailability: Sendable, Equatable {
    public let accessibility: Bool
    public let limitedView: Bool
    public let colorblind: Bool

    public init(
        accessibility: Bool,
        limitedView: Bool,
        colorblind: Bool
    ) {
        self.accessibility = accessibility
        self.limitedView = limitedView
        self.colorblind = colorblind
    }

    public var any: Bool { accessibility || limitedView || colorblind }
    public static let unavailable = SeatLayerPickerAccessibilityAvailability(
        accessibility: false,
        limitedView: false,
        colorblind: false
    )
}

/// One editable filter draft. Inventory-backed access types retain runtime
/// order so bridge payloads and VoiceOver order are deterministic.
public struct SeatLayerPickerAccessibilityDraft: Sendable, Equatable {
    public var types: [String]
    public var hideLimitedView: Bool
    public var colorblindSafe: Bool

    public init(
        types: [String] = [],
        hideLimitedView: Bool = false,
        colorblindSafe: Bool = false
    ) {
        var seen = Set<String>()
        self.types = types.filter { !$0.isEmpty && seen.insert($0).inserted }
        self.hideLimitedView = hideLimitedView
        self.colorblindSafe = colorblindSafe
    }

    public mutating func toggle(_ key: String) {
        if let index = types.firstIndex(of: key) {
            types.remove(at: index)
        } else if !key.isEmpty {
            types.append(key)
        }
    }
}

public enum SeatLayerPickerAccessibilityMutation: Sendable, Equatable {
    case accessibility([String])
    case limitedView(Bool)
    case colorblind(Bool)
}

/// Pure availability, projection, and mutation planning for filter chrome.
public enum SeatLayerPickerAccessibility {
    public static func availability(
        snapshot: SeatLayerPickerSnapshot?,
        bundle: BundleInfo?
    ) -> SeatLayerPickerAccessibilityAvailability {
        guard let snapshot, let bundle,
              bundle.supports(capability: "native-chrome-contract-v1") else {
            return .unavailable
        }
        let accessibility = snapshot.capabilities.contains("accessibilityFilter")
            && bundle.supports(capability: "access-needs-v1")
            && bundle.supports(command: "picker.setAccessibilityFilter")
            && !snapshot.map.accessNeeds.isEmpty
        let limited = snapshot.capabilities.contains("limitedViewFilter")
            && bundle.supports(command: "picker.setLimitedViewFilter")
        let colorblind = bundle.supports(capability: "colorblind-safe")
            && bundle.supports(command: "picker.setColorblindSafe")
        return SeatLayerPickerAccessibilityAvailability(
            accessibility: accessibility,
            limitedView: limited,
            colorblind: colorblind
        )
    }

    public static func draft(
        from snapshot: SeatLayerPickerSnapshot?
    ) -> SeatLayerPickerAccessibilityDraft {
        SeatLayerPickerAccessibilityDraft(
            types: snapshot?.map.accessibilityFilter ?? [],
            hideLimitedView: snapshot?.map.hideLimitedView ?? false,
            colorblindSafe: snapshot?.map.colorblindSafe ?? false
        )
    }

    /// Never invents the static taxonomy when the event/runtime reports none.
    public static func needs(
        snapshot: SeatLayerPickerSnapshot?,
        availability: SeatLayerPickerAccessibilityAvailability
    ) -> [SeatLayerPickerAccessNeed] {
        availability.accessibility ? snapshot?.map.accessNeeds ?? [] : []
    }

    /// Produces at most one operation for each independently supported family.
    public static func mutations(
        from initial: SeatLayerPickerAccessibilityDraft,
        to draft: SeatLayerPickerAccessibilityDraft,
        availability: SeatLayerPickerAccessibilityAvailability
    ) -> [SeatLayerPickerAccessibilityMutation] {
        var result: [SeatLayerPickerAccessibilityMutation] = []
        if availability.accessibility, Set(initial.types) != Set(draft.types) {
            result.append(.accessibility(draft.types))
        }
        if availability.limitedView,
           initial.hideLimitedView != draft.hideLimitedView {
            result.append(.limitedView(draft.hideLimitedView))
        }
        if availability.colorblind,
           initial.colorblindSafe != draft.colorblindSafe {
            result.append(.colorblind(draft.colorblindSafe))
        }
        return result
    }

    public static func shouldFocusSeats(
        after mutations: [SeatLayerPickerAccessibilityMutation]
    ) -> Bool {
        mutations.contains { mutation in
            switch mutation {
            case .accessibility(let types): return !types.isEmpty
            case .limitedView(let enabled): return enabled
            case .colorblind: return false
            }
        }
    }

    public static func activeCount(
        _ snapshot: SeatLayerPickerSnapshot?,
        availability: SeatLayerPickerAccessibilityAvailability
    ) -> Int {
        guard let snapshot else { return 0 }
        return (availability.accessibility ? snapshot.map.accessibilityFilter.count : 0)
            + (availability.limitedView && snapshot.map.hideLimitedView ? 1 : 0)
            + (availability.colorblind && snapshot.map.colorblindSafe ? 1 : 0)
    }
}
