import Combine
import Foundation

// Filters, map navigation and view-mode commands.
//
// Split out of SeatLayerPickerController.swift so no one file in this
// package crosses the readability cap. Behaviour is unchanged.

@MainActor
extension SeatLayerPickerController {
    // MARK: - Filters and map navigation

    @discardableResult
    public func setCategoryFilter(
        _ categoryKeys: [String],
        focus: Bool = false
    ) async throws -> SeatLayerPickerSnapshot? {
        if !categoryKeys.isEmpty { try validateNonEmpty(categoryKeys, named: "categoryKeys") }
        return try await mutation("picker.setCategoryFilter", .object(compacting: [
            "categoryKeys": categoryKeys.isEmpty
                ? .null
                : .array(categoryKeys.map(JSONValue.string)),
            "focus": focus ? .bool(true) : nil,
        ]))
    }

    @discardableResult
    public func setAccessibilityFilter(_ types: [String]) async throws -> SeatLayerPickerSnapshot? {
        if !types.isEmpty { try validateNonEmpty(types, named: "types") }
        return try await mutation("picker.setAccessibilityFilter", [
            "types": types.isEmpty ? .null : .array(types.map(JSONValue.string)),
        ])
    }

    @discardableResult
    public func setLimitedViewFilter(_ enabled: Bool) async throws -> SeatLayerPickerSnapshot? {
        try await mutation("picker.setLimitedViewFilter", ["on": .bool(enabled)])
    }

    @discardableResult
    public func focusSection(_ sectionId: String) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(sectionId, named: "sectionId")
        return try await mutation("picker.focusSection", ["sectionId": .string(sectionId)])
    }

    @discardableResult
    public func overview() async throws -> SeatLayerPickerSnapshot? {
        try await mutation("picker.overview")
    }

    @discardableResult
    public func setRung(_ rung: String) async throws -> SeatLayerPickerSnapshot? {
        guard ["zones", "sections", "seats"].contains(rung) else {
            throw badPayload("SeatLayer rung must be zones, sections, or seats.")
        }
        return try await mutation("picker.setRung", ["rung": .string(rung)])
    }

    @discardableResult
    public func setFloor(_ floorId: String) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(floorId, named: "floorId")
        return try await mutation("picker.setFloor", ["floorId": .string(floorId)])
    }

    @discardableResult
    public func showAllFloors() async throws -> SeatLayerPickerSnapshot? {
        guard supportsFloorStack else { return snapshot }
        return try await setFloor(seatLayerAllFloors)
    }

    @discardableResult
    public func setColorblindSafe(_ enabled: Bool) async throws -> SeatLayerPickerSnapshot? {
        try await mutation("picker.setColorblindSafe", ["on": .bool(enabled)])
    }

    /// Applies only changed, independently supported filter families. The
    /// session and capability legs are rechecked before every command.
    @discardableResult
    public func applyAccessibilityFilters(
        _ draft: SeatLayerPickerAccessibilityDraft,
        from initial: SeatLayerPickerAccessibilityDraft
    ) async throws -> Bool {
        guard let starting = snapshot else { return false }
        let sessionId = starting.sessionId
        let startingAvailability = SeatLayerPickerAccessibility.availability(
            snapshot: starting,
            bundle: bundleInfo
        )
        let plan = SeatLayerPickerAccessibility.mutations(
            from: initial,
            to: draft,
            availability: startingAvailability
        )
        for operation in plan {
            guard let live = snapshot, live.sessionId == sessionId else { return false }
            let available = SeatLayerPickerAccessibility.availability(
                snapshot: live,
                bundle: bundleInfo
            )
            switch operation {
            case .accessibility(let types) where available.accessibility:
                _ = try await setAccessibilityFilter(types)
            case .limitedView(let enabled) where available.limitedView:
                _ = try await setLimitedViewFilter(enabled)
            case .colorblind(let enabled) where available.colorblind:
                _ = try await setColorblindSafe(enabled)
            default:
                return false
            }
            guard snapshot?.sessionId == sessionId else { return false }
        }
        if SeatLayerPickerAccessibility.shouldFocusSeats(after: plan),
           supports(command: "picker.setRung"),
           snapshot?.map.rung != "seats" {
            _ = try await setRung("seats")
        }
        return snapshot?.sessionId == sessionId
    }

    @discardableResult
    public func setViewMode(_ mode: SeatLayerViewMode) async throws -> SeatLayerPickerSnapshot? {
        try await mutation("picker.setViewMode", ["mode": .string(mode.rawValue)])
    }

    @discardableResult
    public func setBuyerView(
        _ view: String,
        flyToSeatId: String? = nil,
        resetView: Bool = false
    ) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(view, named: "view")
        if let flyToSeatId { try validateNonEmpty(flyToSeatId, named: "flyToSeatId") }
        guard supportsVenue3D else { return snapshot }
        return try await mutation("picker.setBuyerView", .object(compacting: [
            "view": .string(view),
            "flyToSeatId": flyToSeatId.map(JSONValue.string),
            "resetView": resetView ? .bool(true) : nil,
        ]))
    }

    @discardableResult
    public func openSeatView(_ seatId: String) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(seatId, named: "seatId")
        guard supportsSeatView else { return snapshot }
        return try await mutation("picker.openSeatView", ["seatId": .string(seatId)])
    }

    /// Whether the runtime can open the seat's own 360 view from the scene.
    public var supportsVenue360: Bool { supports(command: "picker.openVenue360") }

    /// Open the panorama the buyer is standing at inside the 3D scene.
    ///
    /// A distinct command from `picker.openSeatView`: that one is the map's
    /// "see the view from here", and this one is the scene's — the runtime
    /// keeps the camera it already has rather than travelling to the seat
    /// again. Falls back to the map's command where the runtime is older, so
    /// the chip never goes dead.
    @discardableResult
    public func openVenue360(_ seatId: String) async throws -> SeatLayerPickerSnapshot? {
        try validateNonEmpty(seatId, named: "seatId")
        guard supportsSeatView else { return snapshot }
        guard supportsVenue360 else { return try await openSeatView(seatId) }
        return try await mutation("picker.openVenue360", ["seatId": .string(seatId)])
    }

    @discardableResult
    public func setVenue3DNavigationMode(_ mode: String) async throws -> SeatLayerPickerSnapshot? {
        guard ["orbit", "pan"].contains(mode) else {
            throw badPayload("SeatLayer 3D navigation mode must be orbit or pan.")
        }
        guard supports(capability: "venue-3d-controls-v1", command: "picker.setVenue3DNavigationMode") else {
            return snapshot
        }
        return try await mutation("picker.setVenue3DNavigationMode", ["mode": .string(mode)])
    }

    public func zoomIn() async throws { _ = try await mutation("picker.zoomIn") }
    public func zoomOut() async throws { _ = try await mutation("picker.zoomOut") }
    public func zoomToFit() async throws { _ = try await mutation("picker.zoomToFit") }

    public func setThemeMode(
        _ mode: SeatLayerPickerThemeMode?,
        mapTheme: SeatLayerPickerMapTheme? = nil
    ) async throws {
        if let mapTheme { try validate(mapTheme: mapTheme) }
        var payload: [String: JSONValue] = [
            "mode": mode.map { .string($0.rawValue) } ?? .null,
        ]
        if supports(capability: "native-chrome-contract-v1"), let mapTheme {
            payload["mapTheme"] = mapTheme.jsonValue
        }
        try await presentation("picker.setThemeMode", .object(payload))
    }

    public func setInteractionEnabled(_ enabled: Bool) async throws {
        try await presentation("picker.setInteractionEnabled", ["enabled": .bool(enabled)])
    }

    public func setViewportInsets(_ insets: SeatLayerPickerViewportInsets?) async throws {
        guard supportsViewportInsets else { return }
        let payload: JSONValue
        if let insets {
            guard [insets.top, insets.right, insets.bottom, insets.left]
                .allSatisfy({ $0.isFinite && $0 >= 0 }) else {
                throw badPayload("SeatLayer viewport insets must be finite numbers greater than or equal to zero.")
            }
            payload = [
                "top": .double(insets.top),
                "right": .double(insets.right),
                "bottom": .double(insets.bottom),
                "left": .double(insets.left),
            ]
        } else {
            payload = ["insets": .null]
        }
        try await presentation("picker.setViewportInsets", payload)
    }

}

/// The capability that reports `sections[].accessibleFree`.
///
/// Separate from the focus commands because the two are separate capabilities
/// on the wire: a runtime can fly the camera without counting, and chrome that
/// read a missing count as zero would tell a buyer a section is full when the
/// truth is that nobody counted it.
let seatLayerSectionAccessCountsCapability = "section-access-counts-v1"

/// One stop on the accessible-section tour.
public struct SeatLayerPickerAccessibleStep: Sendable, Equatable {
    /// The section the runtime framed.
    public let id: String
    /// What that section is called, already buyer-facing.
    public let label: String
    /// How many matching free spaces it holds.
    public let free: Int
    /// Zero-based position in the tour; chrome prints it one-based.
    public let index: Int
    /// How many stops the walk has.
    public let total: Int

    public init(id: String, label: String, free: Int, index: Int, total: Int) {
        self.id = id
        self.label = label
        self.free = free
        self.index = index
        self.total = total
    }

    /// The step in `value`, or nil when the runtime answered with none.
    public init?(_ value: JSONValue?) {
        guard let id = value?["id"]?.stringValue, !id.isEmpty else { return nil }
        self.init(
            id: id,
            label: value?["label"]?.stringValue ?? id,
            free: value?["free"]?.intValue ?? 0,
            index: value?["index"]?.intValue ?? 0,
            total: value?["total"]?.intValue ?? 0
        )
    }
}

@MainActor
extension SeatLayerPickerController {
    /// Whether the mounted runtime can fly the accessibility filter's camera.
    public var supportsAccessibilityFocus: Bool {
        isReady
            && supports(capability: "accessibility-focus-v1")
            && supports(command: "picker.focusAccessibilityFilter")
    }

    /// Whether `sections[].accessibleFree` is reported at all.
    public var supportsSectionAccessCounts: Bool {
        supports(capability: seatLayerSectionAccessCountsCapability)
    }

    /// Re-run the filter's own camera flight without toggling the filter.
    ///
    /// The buyer has panned away from the spaces the filter lit and wants them
    /// back; turning the filter off and on again is the only other way to ask,
    /// and that briefly shows them the whole venue.
    @discardableResult
    public func focusAccessibilityFilter() async throws -> SeatLayerPickerSnapshot? {
        guard supports(command: "picker.focusAccessibilityFilter") else { return nil }
        return try await mutation("picker.focusAccessibilityFilter")
    }

    /// Frame the next section holding a matching free space.
    ///
    /// `types` defaults to the active filter, which is what the runtime uses
    /// when the field is absent. A nil result means nothing matches — not an
    /// error, and never a step with a zero total: the caller hides its control
    /// rather than drawing "0 of 0".
    public func focusNextAccessibleSection(
        types: [String] = []
    ) async throws -> SeatLayerPickerAccessibleStep? {
        guard supports(command: "picker.focusNextAccessibleSection") else { return nil }
        let payload: JSONValue? = types.isEmpty
            ? nil
            : .object(["types": .array(types.map(JSONValue.string))])
        return try await enqueue { generation in
            let raw = try await self.send("picker.focusNextAccessibleSection", payload)
            _ = try await self.applyMutationResult(raw, generation: generation)
            return SeatLayerPickerAccessibleStep(raw["step"])
        }
    }
}
