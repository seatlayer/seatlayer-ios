#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// What the picker says by the button when the line, not the seats, is the
/// trouble (§3.4.2):
/// - a press without an answer: `strings.checkConnection` as a small message,
///   where it was the red line; the red line stays for refusals;
/// - a server fault on a hold or on the way to checkout:
///   `strings.couldNotReachCheckout` with `strings.retry`, which runs the
///   app's checkout again;
/// - from 10 s into a hold or a best-seats search without an answer:
///   `strings.takingLonger`.
struct SeatLayerPickerConnectionFeed: ViewModifier {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @State private var slowPress: Task<Void, Never>?
    @State private var searching = false

    func body(content: Content) -> some View {
        let presses = seatLayerPickerPressWatch(for: controller)
        content
            .onChange(of: presentation.lastActionError) { error in
                guard let error else { return }
                tell(error)
            }
            .onChange(of: waitingOnServer) { waiting in
                slowPress?.cancel()
                slowPress = nil
                guard waiting else { return }
                slowPress = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(seatLayerPickerTakingLongerSeconds * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    say(SeatLayerPickerToast(style.strings.text(.takingLonger)))
                }
            }
            .onReceive(presses.$waiting) { searching = $0 }
            .onDisappear {
                slowPress?.cancel()
                slowPress = nil
            }
    }

    /// A hold being made, or a best-seats search: the app's own step after
    /// the handoff is not the picker's to time.
    private var waitingOnServer: Bool {
        (presentation.actionInFlight && !presentation.handoffInFlight) || searching
    }

    private func tell(_ error: SeatLayerError) {
        // A page that did not load is told by its own panel.
        guard !controller.pageFailed else { return }
        let failure = controller.failure(for: error)
        guard seatLayerPickerToldAsMessage(error, failure: failure) else { return }
        if seatLayerPickerFailureKind(error) == .server {
            let retry = seatLayerPickerPressWatch(for: controller).retry
            seatLayerPickerToasts(for: controller).show(
                SeatLayerPickerToast(
                    style.strings.text(.couldNotReachCheckout),
                    tone: .warning,
                    actionLabel: retry == nil ? nil : style.strings.text(.retry)
                ),
                action: retry
            )
        } else {
            say(SeatLayerPickerToast(style.strings.text(.checkConnection), tone: .warning))
        }
        presentation.dismissActionError()
    }

    private func say(_ toast: SeatLayerPickerToast) {
        seatLayerPickerToasts(for: controller).show(toast)
    }
}

extension View {
    /// Tell a lost line by the button as a small message, not the red line.
    func seatLayerPickerConnectionFeed() -> some View {
        modifier(SeatLayerPickerConnectionFeed())
    }
}
#endif
