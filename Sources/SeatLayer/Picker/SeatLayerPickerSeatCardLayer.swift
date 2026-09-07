#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The seat card, the glass under it, and the map moving out from beneath both.
///
/// One place so the three cannot drift apart. The card has ONE home — a fixed
/// bottom sheet resting a constant inset above the foot of the map — the veil's
/// hole follows the seat wherever the runtime has panned it to, and the lift is
/// asked for and given back in step with the card arriving and leaving.
///
/// Drop it over the map. It draws nothing at all when no card is up.
public struct SeatLayerPickerSeatCardLayer: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.seatLayerPickerCardStyles) private var slots
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The band the picker's own chrome stands on above the map.
    private let topInset: Double
    /// The band it stands on below the map.
    private let bottomInset: Double
    private let onAction: ((SeatLayerPickerConfirmationAction, SelectedSeat) -> Void)?

    @State private var cardHeight: Double = 0
    @StateObject private var lift = SeatLayerPickerSeatLiftBox()

    public init(
        topInset: Double = 0,
        bottomInset: Double = 0,
        onAction: ((SeatLayerPickerConfirmationAction, SelectedSeat) -> Void)? = nil
    ) {
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.onAction = onAction
    }

    public var body: some View {
        GeometryReader { geometry in
            let subject = seatLayerPickerCardQuestion(
                presentation: presentation,
                controller: controller,
                options: style.options
            )
            ZStack(alignment: .topLeading) {
                if let subject {
                    let cardTop = seatLayerConfirmCardTop(
                        card: CGSize(width: 0, height: cardHeight),
                        area: geometry.size,
                        topInset: topInset,
                        bottomInset: bottomInset
                    )
                    SeatLayerPickerSpotlight(
                        seatPoint: seatPoint(for: subject.seat),
                        anchorDy: lift.anchorDy,
                        reduceTransparency: reduceTransparency,
                        tint: slots.scrim,
                        // Tapping the glass gives the seat back. On this
                        // platform the map behind a decision is inert, so the
                        // press cannot also reach it — letting it through would
                        // select a second seat under the buyer's own finger
                        // while they were still answering about the first.
                        onPress: { dismissByPress(subject) }
                    )
                    card(subject: subject, cardTop: cardTop, area: geometry.size)
                        .task(id: liftKey(
                            subject: subject,
                            area: geometry.size,
                            cardTop: cardTop
                        )) {
                            syncLift(subject: subject, area: geometry.size, cardTop: cardTop)
                        }
                }
            }
            .coordinateSpace(name: seatLayerPickerCardSpace)
            .onPreferenceChange(SeatLayerPickerCardHeightKey.self) { height in
                cardHeight = height
            }
            .onChange(of: subject?.seat.id) { seatId in
                // The question is over: the map goes back where the buyer had
                // it, at a fixed resting place and only if they have not moved
                // it themselves since.
                if seatId == nil { lift.release() }
            }
        }
        .animation(
            seatLayerPickerAnimation(.cardEnter, reduceMotion: reduceMotion, curve: .spring),
            value: presentation.candidateSeat?.id ?? presentation.pendingSeat?.id
        )
        .onDisappear {
            // The picker is going away: there is nothing left to pan on.
            lift.forget()
        }
    }

    private func card(
        subject: SeatLayerPickerCardSubject,
        cardTop: Double,
        area: CGSize
    ) -> some View {
        SeatLayerPickerPartHost(.confirmCard) {
            SeatLayerPickerSeatConfirmation(onAction: onAction)
        }
        .background {
            GeometryReader { card in
                Color.clear.preference(
                    key: SeatLayerPickerCardHeightKey.self,
                    value: card.size.height
                )
            }
        }
        .seatLayerPickerFlightOrigin(in: .named(seatLayerPickerCardSpace))
        .frame(maxWidth: .infinity)
        // The height is zero on the first pass, which would put the card at the
        // foot of the map for one frame; it is drawn once it has been measured.
        .offset(y: cardHeight > 0 ? cardTop : area.height)
        .opacity(cardHeight > 0 ? 1 : 0)
        .transition(
            // Opacity in, a small rise and a touch of scale, growing from the
            // direction the map is: the card arrives out of the venue rather
            // than being stamped on top of it.
            .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
        )
    }

    // MARK: - The lift

    /// Everything a lift depends on, as one value, so it is asked again when
    /// any of them moves and never asked twice for the same question.
    private func liftKey(
        subject: SeatLayerPickerCardSubject,
        area: CGSize,
        cardTop: Double
    ) -> String {
        [
            subject.seat.id,
            String(format: "%.0f", area.height),
            String(format: "%.0f", cardTop),
            String(controller.snapshot?.revision ?? -1),
            presentation.mapMayMove ? "1" : "0",
        ].joined(separator: "|")
    }

    private func syncLift(
        subject: SeatLayerPickerCardSubject,
        area: CGSize,
        cardTop: Double
    ) {
        guard cardHeight > 0 else { return }
        // The pull-back after an answer runs once the chip has landed, not
        // under it: a map that re-frames while a ticket is still in the air
        // takes the buyer's eye off the thing that has just changed.
        guard presentation.mapMayMove else { return }
        lift.sync(
            seatId: subject.seat.id,
            mapHeight: Double(area.height),
            top: topInset,
            bottom: bottomInset,
            sheet: seatLayerConfirmSheetBand(
                cardTop: cardTop,
                area: area,
                topInset: topInset
            ),
            revision: controller.snapshot?.revision ?? -1,
            controller: controller
        )
    }

    // MARK: - Where the seat is

    /// Where the runtime says the seat sits on screen, or nil when it reports
    /// no point at all — an older runtime, or a seat off the current camera.
    private func seatPoint(for seat: SelectedSeat) -> CGPoint? {
        guard controller.supports(capability: seatLayerScreenPointCapability),
              let point = seat.screenPoint,
              // Half a point would aim the hole at the map's top-left corner
              // rather than at the seat.
              point.isComplete,
              let x = point.x,
              let y = point.y else { return nil }
        return CGPoint(x: x, y: y)
    }

    private func dismissByPress(_ subject: SeatLayerPickerCardSubject) {
        controller.emitHaptic(.cardCancelled)
        Task { @MainActor in
            if subject.question == .remove {
                // A stray press on the map must never empty someone's cart.
                presentation.dismissCandidate()
                onAction?(.cancel, subject.seat)
                return
            }
            guard await presentation.cancelPending() else { return }
            presentation.dismissCandidate()
            onAction?(.cancel, subject.seat)
        }
    }
}

/// Holds the lift across rebuilds, and republishes the pan the chrome draws
/// against.
///
/// The pan carries no revision — it is camera only — so nothing else on this
/// side hears about it, and the spotlight's hole would keep the place the seat
/// had before the map moved.
@MainActor
final class SeatLayerPickerSeatLiftBox: ObservableObject {
    @Published private(set) var anchorDy: Double = 0
    private var engine: SeatLayerPickerSeatLift?

    nonisolated init() {}

    func sync(
        seatId: String,
        mapHeight: Double,
        top: Double,
        bottom: Double,
        sheet: Double,
        revision: Int,
        controller: SeatLayerPickerController
    ) {
        let lift = engine ?? make(controller: controller)
        lift.sync(
            seatId: seatId,
            mapHeight: mapHeight,
            top: top,
            bottom: bottom,
            sheet: sheet,
            revision: revision
        )
    }

    func release() {
        engine?.release()
        engine = nil
        anchorDy = 0
    }

    func forget() {
        engine?.forget()
        engine = nil
        anchorDy = 0
    }

    private func make(controller: SeatLayerPickerController) -> SeatLayerPickerSeatLift {
        let lift = SeatLayerPickerSeatLift(
            onChanged: { [weak self] in
                guard let self else { return }
                self.anchorDy = self.engine?.anchorDy ?? 0
            },
            frame: { [weak controller] seatId, fraction, gestures in
                await controller?.frameSeat(seatId, fraction: fraction, gestures: gestures)
            }
        )
        engine = lift
        return lift
    }
}

/// The capability that carries `selection[].screenPoint`.
public let seatLayerScreenPointCapability = "seat-screen-point-v1"

/// The card layer's own coordinate space, so the chip's departure point is
/// measured in the same frame the card is placed in.
let seatLayerPickerCardSpace = "seatlayer.picker.card"

struct SeatLayerPickerCardHeightKey: PreferenceKey {
    static var defaultValue: Double = 0
    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = max(value, nextValue())
    }
}

/// Whether a seat card is standing over the map right now.
///
/// The rest of the chrome reads this rather than a seat: the sheet hides its
/// handle, the anchors dim and go inert, and the footer's action greys out
/// while a buyer is answering one question.
@MainActor
public func seatLayerPickerCardIsUp(
    presentation: SeatLayerPickerPresentationModel,
    controller: SeatLayerPickerController,
    options: SeatLayerPickerOptions
) -> Bool {
    seatLayerPickerCardQuestion(
        presentation: presentation,
        controller: controller,
        options: options
    ) != nil
}
#endif
