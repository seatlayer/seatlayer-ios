import Foundation

/// The amounts one standing area can be asked for.
public struct SeatLayerStandingAmounts: Sendable, Equatable {
    public let minimum: Int
    public let maximum: Int
}

/// The area as the latest snapshot describes it, or `area` when it names none.
func seatLayerLiveStandingArea(_ area: GAArea, snapshot: SeatLayerPickerSnapshot?) -> GAArea {
    snapshot?.generalAdmissionAreas.first { $0.id == area.id } ?? area
}

private func seatLayerIsBox(_ area: GAArea) -> Bool {
    area.bookingMode == "whole" || area.bookingMode == "variable"
}

/// How many places `area` itself still offers, before the order's own limit;
/// nil when the page does not say.
///
/// With the wheelchair filter on, an area offers its free wheelchair places,
/// and a box is offered only if it has any.
func seatLayerStandingPlacesFree(_ area: GAArea, snapshot: SeatLayerPickerSnapshot?) -> Int? {
    let wheelchairOnly = snapshot?.map.accessibilityFilter.contains("wheelchair") ?? false
    guard wheelchairOnly else { return area.available.map { max(0, $0) } }
    let available = max(0, area.available ?? 0)
    if seatLayerIsBox(area) {
        return (area.wheelchairPlaces ?? 0) > 0 ? available : 0
    }
    return min(available, max(0, area.wheelchairAvailable ?? 0))
}

/// The amounts `area` can be asked for, by the page's own rule: the page
/// answers any other amount with no hold and no reason. Nil when there is no
/// such amount.
///
/// Per person, any number that is free and left in the order. A box is sold to
/// one party: all its places, or a party inside its range.
func seatLayerStandingAmounts(_ area: GAArea, snapshot: SeatLayerPickerSnapshot?) -> SeatLayerStandingAmounts? {
    let remaining = (snapshot?.maxSelection ?? 10) - (snapshot?.ticketCount ?? 0)
    let free = seatLayerStandingPlacesFree(area, snapshot: snapshot)
    let room = free.map { min(remaining, $0) } ?? remaining
    let minimum: Int
    let maximum: Int
    if seatLayerIsBox(area) {
        let places = max(0, area.maxOccupancy ?? area.capacity ?? free ?? 0)
        minimum = area.bookingMode == "whole"
            ? places
            : max(1, min(places, area.minOccupancy ?? 1))
        maximum = min(places, room)
    } else {
        minimum = 1
        maximum = room
    }
    guard minimum >= 1, maximum >= minimum else { return nil }
    return SeatLayerStandingAmounts(minimum: minimum, maximum: maximum)
}
