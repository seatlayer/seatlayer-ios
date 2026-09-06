#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// How tall the cart's cards want to be, before the sheet caps them.
struct SeatLayerPickerCartContentHeightKey: PreferenceKey {
    static var defaultValue: Double = 0
    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = max(value, nextValue())
    }
}

/// One card per ticket, scrolling inside whatever height the sheet gives it.
public struct SeatLayerPickerCartList: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    /// Lines the buyer has dropped and the runtime has not answered for yet.
    @State private var removing: Set<String> = []

    public init() {}

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: SeatLayerPickerSizeTokens.cartCardGap) {
                ForEach(lines, id: \.lineKey) { line in
                    SeatLayerPickerCartCard(
                        line: line,
                        held: held,
                        removing: removing.contains(line.lineKey),
                        onRemove: { remove(line) }
                    )
                }
            }
            .padding(.horizontal, SeatLayerPickerSizeTokens.cartTrayPadX)
            .padding(.top, SeatLayerPickerSizeTokens.cartTrayPadTop)
            .padding(.bottom, SeatLayerPickerSizeTokens.cartTrayPadBottom)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: SeatLayerPickerCartContentHeightKey.self,
                        value: geometry.size.height
                    )
                }
            }
        }
        .scrollDisabledIfPossible(lines.count <= 1)
        .accessibilityIdentifier("seatlayer-cart-list")
    }

    private var lines: [SeatLayerPickerCartLine] {
        presentation.confirmedCartLines
    }

    /// A held card is inventory the HOST has already been handed. The picker's
    /// own hold is not a lock: those tickets are still the buyer's to change.
    private var held: Bool {
        controller.snapshot?.hold.active == true
            && controller.snapshot?.hold.owner == "host"
    }

    /// Removal is optimistic and silent: the line fades and its × goes inert
    /// in the same frame, and only a failure speaks — through the sheet's own
    /// inline action error. There is no toast and no Undo.
    private func remove(_ line: SeatLayerPickerCartLine) {
        guard !removing.contains(line.lineKey) else { return }
        removing.insert(line.lineKey)
        let key = line.lineKey
        runPickerAction(controller) {
            defer { removing.remove(key) }
            try await presentation.removeCartLine(line.label)
        }
    }
}

extension View {
    /// Locks a scroll view that has nothing to scroll, so a one-card cart does
    /// not bounce under the finger that is dragging the sheet.
    @ViewBuilder
    func scrollDisabledIfPossible(_ disabled: Bool) -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDisabled(disabled)
        } else {
            self
        }
    }
}
#endif
