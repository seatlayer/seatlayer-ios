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
    let categoryEvidence = !sellableCategories.isEmpty
        && sellableCategories.allSatisfy(\.availabilityReported)
    let gaEvidence = !snapshot.generalAdmissionAreas.isEmpty
        && snapshot.generalAdmissionAreas.allSatisfy { ($0.available ?? -1) >= 0 }

    if !sellableCategories.isEmpty && !categoryEvidence { return .availableOrUnknown }
    if !snapshot.generalAdmissionAreas.isEmpty && !gaEvidence { return .availableOrUnknown }
    guard categoryEvidence || gaEvidence else { return .availableOrUnknown }

    if sellableCategories.contains(where: { $0.available > 0 })
        || snapshot.generalAdmissionAreas.contains(where: { ($0.available ?? 0) > 0 }) {
        return .availableOrUnknown
    }
    return .soldOut
}
