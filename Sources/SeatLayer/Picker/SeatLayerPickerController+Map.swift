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
