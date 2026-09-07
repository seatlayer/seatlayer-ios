#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// What the picker says out loud without being asked.
///
/// The queue itself only holds a sentence and a clock; this is the list of
/// things worth interrupting a buyer for. Deliberately short: a toast is read
/// over the map the buyer is working on, so only facts that change what they
/// are about to do earn one. Everything else has a surface that stays.
///
/// A toast never carries an action the picker cannot actually perform. A seat
/// another buyer took is gone — offering "select it again" over a seat that no
/// longer exists would be a button that lies — so that message tells and stops.
struct SeatLayerPickerToastFeed: ViewModifier {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @State private var reportedSalesClosed: Bool?

    func body(content: Content) -> some View {
        content
            .onReceive(controller.selectedObjectUnavailability) { event in
                say(SeatLayerPickerToast(seatTakenMessage(event), tone: .error))
            }
            .onReceive(controller.holdExpirations) { _ in
                say(SeatLayerPickerToast(
                    style.strings.text(.holdExpired),
                    tone: .warning
                ))
            }
            .onChange(of: controller.snapshot?.event.salesClosed) { closed in
                let previous = reportedSalesClosed
                reportedSalesClosed = closed
                guard closed == true, previous != true else { return }
                say(SeatLayerPickerToast(
                    style.strings.text(.salesClosedToast),
                    tone: .warning
                ))
            }
    }

    /// One seat is named; several are counted as one loss, because a list of
    /// labels in a sentence that disappears is a list nobody can read in time.
    private func seatTakenMessage(_ event: SelectedObjectUnavailableEvent) -> String {
        guard event.labels.count == 1, let label = event.labels.first else {
            return style.strings.text(.seatsJustTaken)
        }
        return style.strings.text(.seatJustTakenByAnother, replacing: ["label": label])
    }

    private func say(_ toast: SeatLayerPickerToast) {
        seatLayerPickerToasts(for: controller).show(toast)
    }
}

extension View {
    /// Publish this picker's unprompted messages to its toast queue.
    func seatLayerPickerToastFeed() -> some View {
        modifier(SeatLayerPickerToastFeed())
    }
}
#endif
