import Foundation

enum SeatLayerPickerInventoryStatus: Equatable {
    case availableOrUnknown
    case soldOut
    case salesClosed
}

/// Uses only positive runtime evidence. Incomplete additive snapshots remain
/// usable instead of covering the renderer with an invented sold-out state.
func seatLayerPickerInventoryStatus(
    _ snapshot: SeatLayerPickerSnapshot
) -> SeatLayerPickerInventoryStatus {
    guard snapshot.selection.isEmpty, snapshot.cartLines.isEmpty else {
        return .availableOrUnknown
    }
    if snapshot.event.salesClosed { return .salesClosed }

    let sellableCategories = snapshot.categories.filter { !$0.notForSale }
    // The predicate is about SEATED inventory: every seated category's live
    // free count is zero, there is at least one seated category, and the chart
    // has no general-admission areas at all. A venue that also sells standing
    // room is never sold out on the strength of its seats alone, so GA areas
    // are a disqualification here rather than a second kind of evidence.
    guard snapshot.generalAdmissionAreas.isEmpty else { return .availableOrUnknown }
    guard !sellableCategories.isEmpty,
          sellableCategories.allSatisfy(\.availabilityReported) else {
        return .availableOrUnknown
    }
    if sellableCategories.contains(where: { $0.available > 0 }) {
        return .availableOrUnknown
    }
    return .soldOut
}
