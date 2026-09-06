#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Adaptive compact floor entry point; the always-visible strip remains a
/// separate public part for layouts that have room.
public struct SeatLayerPickerFloorSelector: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style

    public init() {}

    public var body: some View {
        let floors = controller.snapshot?.map.floors ?? []
        if floors.count > 1,
           controller.snapshot?.map.buyerView == "map" {
            Menu(activeLabel(floors)) {
                if controller.supportsFloorStack {
                    Button(style.strings.text(.allFloors)) {
                        runPickerAction(controller) { _ = try await controller.showAllFloors() }
                    }
                }
                ForEach(floors, id: \.id) { floor in
                    Button(floor.name) {
                        runPickerAction(controller) { _ = try await controller.setFloor(floor.id) }
                    }
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("seatlayer-floor-selector")
        }
    }

    private func activeLabel(_ floors: [SeatLayerPickerFloorInfo]) -> String {
        if controller.snapshot?.map.showsAllFloors == true { return style.strings.text(.allFloors) }
        return floors.first { $0.id == controller.snapshot?.map.activeFloorId }?.name
            ?? floors.first?.name
            ?? style.strings.text(.allFloors)
    }
}

/// Scrollable section list for wide or host-owned layouts.
public struct SeatLayerPickerSectionNavigator: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style

    public init() {}

    public var body: some View {
        if controller.snapshot?.map.buyerView == "map" {
            ScrollView {
                LazyVStack(spacing: 4) {
                    Button(style.strings.text(.overview)) {
                        runPickerAction(controller) { _ = try await controller.overview() }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    ForEach(controller.snapshot?.sections ?? [], id: \.id) { section in
                        Button {
                            runPickerAction(controller) { _ = try await controller.focusSection(section.id) }
                        } label: {
                            HStack {
                                Text(section.displayLabel ?? section.label).lineLimit(1)
                                Spacer()
                                if let count = section.seatsLeft {
                                    Text(style.strings.seatsLeft(count)).font(.caption)
                                }
                            }
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(
                            controller.snapshot?.map.focusedSectionId == section.id ? .isSelected : []
                        )
                    }
                }
            }
        }
    }
}
#endif
