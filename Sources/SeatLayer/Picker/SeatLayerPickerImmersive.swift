import Foundation

/// Semantic actions owned by native venue-3D chrome.
public enum SeatLayerPickerVenue3DAction: String, Sendable, Equatable, CaseIterable {
    case back
    case previous
    case next
    case reset
    case recentre
}

/// Exact `picker.setBuyerView` request planned from immutable snapshot state.
public struct SeatLayerPickerBuyerViewRequest: Sendable, Equatable {
    public let view: String
    public let flyToSeatId: String?
    public let resetView: Bool

    public init(
        view: String,
        flyToSeatId: String? = nil,
        resetView: Bool = false
    ) {
        self.view = view
        self.flyToSeatId = flyToSeatId
        self.resetView = resetView
    }
}

/// Target and authored row neighbours projected for native 3D controls.
public struct SeatLayerPickerVenue3DPosition: Sendable, Equatable {
    public let targetSeatId: String?
    public let targetSeat: SelectedSeat?
    public let previousSeatId: String?
    public let nextSeatId: String?

    public init(
        targetSeatId: String?,
        targetSeat: SelectedSeat?,
        previousSeatId: String?,
        nextSeatId: String?
    ) {
        self.targetSeatId = targetSeatId
        self.targetSeat = targetSeat
        self.previousSeatId = previousSeatId
        self.nextSeatId = nextSeatId
    }
}

/// Exact native ownership gates for the optional immersive surfaces.
public struct SeatLayerPickerImmersiveAvailability: Sendable, Equatable {
    public let venue3D: Bool
    public let navigationMode: Bool
    public let seatViewAction: Bool
    public let panoramaChrome: Bool
    public let zoomIn: Bool
    public let zoomOut: Bool
    public let zoomToFit: Bool

    public init(
        venue3D: Bool,
        navigationMode: Bool,
        seatViewAction: Bool,
        panoramaChrome: Bool,
        zoomIn: Bool,
        zoomOut: Bool,
        zoomToFit: Bool
    ) {
        self.venue3D = venue3D
        self.navigationMode = navigationMode
        self.seatViewAction = seatViewAction
        self.panoramaChrome = panoramaChrome
        self.zoomIn = zoomIn
        self.zoomOut = zoomOut
        self.zoomToFit = zoomToFit
    }

    public static let unavailable = SeatLayerPickerImmersiveAvailability(
        venue3D: false,
        navigationMode: false,
        seatViewAction: false,
        panoramaChrome: false,
        zoomIn: false,
        zoomOut: false,
        zoomToFit: false
    )
}

/// Native chrome ownership for one rendered frame. The cart and required
/// commercial truth stay available while map-only controls yield to the
/// renderer-owned immersive gesture surface.
public struct SeatLayerPickerChromeVisibility: Sendable, Equatable {
    public let priceLegend: Bool
    public let floors: Bool
    public let dock: Bool
    public let mapControls: Bool
    public let accessibility: Bool
    public let cart: Bool
    public let venue3D: Bool
    public let panorama: Bool

    public init(
        priceLegend: Bool,
        floors: Bool,
        dock: Bool,
        mapControls: Bool,
        accessibility: Bool,
        cart: Bool,
        venue3D: Bool,
        panorama: Bool
    ) {
        self.priceLegend = priceLegend
        self.floors = floors
        self.dock = dock
        self.mapControls = mapControls
        self.accessibility = accessibility
        self.cart = cart
        self.venue3D = venue3D
        self.panorama = panorama
    }

    public var immersive: Bool { venue3D || panorama }
}

/// Trimmed runtime-authored wording for the native panorama disclosure rail.
public struct SeatLayerPickerPanoramaWording: Sendable, Equatable {
    public let title: String?
    public let caption: String?
    public let badge: String?
    public let dragHint: String?

    public var summary: String? { title ?? caption ?? badge }
}

/// Pure shared semantics used by the ready-made and headless picker surfaces.
public enum SeatLayerPickerImmersive {
    /// Panorama wins when the runtime is transitioning out of a targeted 3D
    /// seat. Its web close control and gesture surface must remain unobscured.
    public static func chromeVisibility(
        _ availability: SeatLayerPickerImmersiveAvailability
    ) -> SeatLayerPickerChromeVisibility {
        let panorama = availability.panoramaChrome
        let venue3D = availability.venue3D && !panorama
        let immersive = venue3D || panorama
        return SeatLayerPickerChromeVisibility(
            priceLegend: !panorama,
            floors: !immersive,
            dock: !immersive,
            mapControls: !immersive,
            accessibility: !immersive,
            cart: true,
            venue3D: venue3D,
            panorama: panorama
        )
    }

    /// New runtimes own row order. Selection order is a bounded fallback only
    /// while a pinned older runtime omits the additive position fields.
    public static func position(
        map: SeatLayerPickerMapState,
        selection: [SelectedSeat]
    ) -> SeatLayerPickerVenue3DPosition {
        let targetId = map.view3DTargetSeatId
        let targetIndex = targetId.flatMap { id in
            selection.firstIndex { $0.id == id }
        }
        let fallbackTarget = targetIndex.map { selection[$0] }

        let previous: String?
        let next: String?
        if map.reportsView3DPosition {
            previous = map.view3DPreviousSeatId
            next = map.view3DNextSeatId
        } else {
            previous = targetIndex.flatMap { index in
                index > selection.startIndex ? selection[index - 1].id : nil
            }
            next = targetIndex.flatMap { index in
                let candidate = index + 1
                return candidate < selection.endIndex ? selection[candidate].id : nil
            }
        }

        return SeatLayerPickerVenue3DPosition(
            targetSeatId: targetId,
            targetSeat: map.view3DTargetSeat ?? fallbackTarget,
            previousSeatId: previous,
            nextSeatId: next
        )
    }

    public static func position(
        in snapshot: SeatLayerPickerSnapshot
    ) -> SeatLayerPickerVenue3DPosition {
        position(map: snapshot.map, selection: snapshot.selection)
    }

    /// Whether the 3D camera is below its whole-venue overview.
    public static func hasFocusedView(_ map: SeatLayerPickerMapState) -> Bool {
        if map.reportsView3DPosition {
            return map.view3DTargetSeatId != nil || map.view3DFocusedSectionId != nil
        }
        return map.view3DTargetSeatId != nil
            || map.focusedSectionId != nil
            || map.focusedSection != nil
            || map.rung == "seats"
    }

    /// Produces no request at a disabled boundary or outside venue 3D.
    public static func request(
        for action: SeatLayerPickerVenue3DAction,
        snapshot: SeatLayerPickerSnapshot
    ) -> SeatLayerPickerBuyerViewRequest? {
        guard snapshot.map.isVenue3D else { return nil }
        let position = position(in: snapshot)
        switch action {
        case .back:
            return hasFocusedView(snapshot.map)
                ? SeatLayerPickerBuyerViewRequest(view: "venue3d", resetView: true)
                : SeatLayerPickerBuyerViewRequest(view: "map")
        case .reset:
            return SeatLayerPickerBuyerViewRequest(view: "venue3d", resetView: true)
        case .previous:
            guard let id = position.previousSeatId else { return nil }
            return SeatLayerPickerBuyerViewRequest(view: "venue3d", flyToSeatId: id)
        case .next:
            guard let id = position.nextSeatId else { return nil }
            return SeatLayerPickerBuyerViewRequest(view: "venue3d", flyToSeatId: id)
        case .recentre:
            guard let id = position.targetSeatId else { return nil }
            return SeatLayerPickerBuyerViewRequest(
                view: "venue3d",
                flyToSeatId: id,
                resetView: true
            )
        }
    }

    /// Resolves all renderer/native ownership legs instead of probing support
    /// by sending a command after a buyer taps a control.
    public static func availability(
        snapshot: SeatLayerPickerSnapshot?,
        bundle: BundleInfo?,
        seatView: SeatLayerSeatView?
    ) -> SeatLayerPickerImmersiveAvailability {
        guard let snapshot, let bundle else { return .unavailable }
        let native = bundle.supports(capability: "native-chrome-contract-v1")
        let venue = snapshot.map.isVenue3D
            && snapshot.capabilities.contains("venue3d")
            && native
            && bundle.supports(capability: "venue-3d-v1")
            && bundle.supports(command: "picker.setBuyerView")
        let navigation = venue
            && bundle.supports(capability: "venue-3d-controls-v1")
            && bundle.supports(command: "picker.setVenue3DNavigationMode")
        let seatViewAction = venue
            && snapshot.map.view3DTargetSeatId != nil
            && snapshot.capabilities.contains("seatView")
            && bundle.supports(capability: "seat-view-v1")
            && bundle.supports(command: "picker.openSeatView")
        let panorama = seatView?.hasContent == true
            && snapshot.capabilities.contains("seatView")
            && native
            && bundle.supports(capability: "native-seat-view-chrome-v1")
            && bundle.events.contains("seatView.changed")
        return SeatLayerPickerImmersiveAvailability(
            venue3D: venue,
            navigationMode: navigation,
            seatViewAction: seatViewAction,
            panoramaChrome: panorama,
            zoomIn: venue && bundle.supports(command: "picker.zoomIn"),
            zoomOut: venue && bundle.supports(command: "picker.zoomOut"),
            zoomToFit: venue && bundle.supports(command: "picker.zoomToFit")
        )
    }

    public static func panoramaWording(
        _ view: SeatLayerSeatView?
    ) -> SeatLayerPickerPanoramaWording {
        SeatLayerPickerPanoramaWording(
            title: wording(view?.title),
            caption: wording(view?.caption),
            badge: wording(view?.badge),
            dragHint: wording(view?.dragHint)
        )
    }

    private static func wording(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

public extension SeatLayerSeatView {
    var hasContent: Bool {
        SeatLayerPickerImmersive.panoramaWording(self).summary != nil
    }
}
