import CoreGraphics
import Foundation

/// Where the seat card sits over the map, and how the map moves out from
/// under it.
///
/// **One home, and the map moves instead.** The phone card is a fixed bottom
/// sheet: it rests a constant inset above the foot of the map on every tap, so
/// Cancel and `Add seat` are under the same pixels every time. Nothing about
/// the tapped seat is read when placing it.
///
/// The card used to move to the seat. On a tall phone that read badly — the
/// seat is a small ring in a small hole and the card is at the foot of the map,
/// so the two halves of one question could be hundreds of points apart and the
/// buyer had to hunt for the seat they had just tapped. Keeping the seat and
/// the card together is the MAP's job now: `picker.frameSeat` pans the seat
/// into the band the card leaves clear — x untouched, zoom untouched — and puts
/// it back when the card goes, unless the buyer has moved the map in between.

/// The gap between the fixed sheet and the nearest seat the runtime should
/// keep clear of it.
///
/// The web widget's `NARROW_CONFIRM_SEAT_GAP`: the band the buyer reads the map
/// in ends this far above the sheet's top edge, so a seat framed into it is
/// never pressed against the card asking about it.
public let seatLayerConfirmCardSeatGap = SeatLayerPickerSizeTokens.confirmCardSeatGap

/// Where the card rests: the daylight between its bottom edge and the foot of
/// the map.
public let seatLayerConfirmCardRestInset = SeatLayerPickerSizeTokens.confirmCardRestInset

/// The closest the card may come to the top of the map.
public let seatLayerConfirmCardTopInset = SeatLayerPickerSizeTokens.confirmCardTopInset

/// Where the seat rests once its card has gone: the middle of the band the
/// chrome leaves clear.
///
/// The web sheet undoes its own pans exactly. Over the bridge that sum is not
/// trustworthy: the map is a hosted web view that re-fits itself when it
/// changes size under a collapsing sheet, so a lift can be undone by a refit
/// this side never sees and asked for again — and undoing both then throws the
/// section off the screen. A fixed resting place is honest and predictable;
/// the gesture guard still leaves a buyer who moved the map where they put it.
public let seatLayerSheetRestoreFraction = 0.5

/// Where the card's top edge belongs over a `area`-sized map.
///
/// `topInset` and `bottomInset` are the bands the picker's own chrome stands
/// on: the map the card lives over is what is left between them, so the card
/// never slides behind the dock or under the floor strip.
public func seatLayerConfirmCardTop(
    card: CGSize,
    area: CGSize,
    topInset: Double = 0,
    bottomInset: Double = 0,
    restInset: Double = seatLayerConfirmCardRestInset,
    headroom: Double = seatLayerConfirmCardTopInset
) -> Double {
    let foot = Double(area.height) - bottomInset
    let ceiling = topInset + headroom
    return max(ceiling, foot - restInset - Double(card.height))
}

/// What the raised sheet covers, as a bottom viewport inset for the runtime.
///
/// The runtime frames every fit and every focus glide INSIDE the insets the
/// host reports, so this is what moves the map out from under the card on a
/// runtime too old to pan a seat itself: a sheet the runtime has not been told
/// about is a sheet the venue is framed underneath. Measured from the foot of
/// the map surface up to `seatGap` above the card's top edge, so the clear band
/// ends in daylight rather than against the card's own shadow.
///
/// Answers 0 when the sheet would leave no band at all: a host short enough
/// that the card fills it has nowhere to put the seat, and an inset taller than
/// the viewport would ask the runtime to frame into nothing.
public func seatLayerConfirmSheetBand(
    cardTop: Double,
    area: CGSize,
    topInset: Double = 0,
    seatGap: Double = seatLayerConfirmCardSeatGap
) -> Double {
    let band = Double(area.height) - cardTop + seatGap
    if Double(area.height) - topInset - band <= 0 { return 0 }
    return band
}

/// Where, within the band the runtime knows about, the seat has to rest so
/// that it sits at `at` of the band the SHEET leaves clear.
///
/// The runtime frames between `top` and `mapHeight − bottom` — the chrome the
/// layout reports as insets — and knows nothing of the sheet, which is
/// deliberately NOT reported (an inset re-frames and re-zooms the section). So
/// the sheet is folded into the fraction instead. Clamped to the band; 0 when
/// there is no band at all.
public func seatLayerSheetLiftFraction(
    mapHeight: Double,
    top: Double,
    bottom: Double,
    sheet: Double,
    at: Double = seatLayerSheetSeatFraction
) -> Double {
    let band = mapHeight - top - bottom
    let clear = mapHeight - top - sheet
    guard band > 0, clear > 0 else { return 0 }
    return min(1, max(0, (clear * at) / band))
}

/// The lift the layout makes for a seat card, and its undoing.
///
/// Driven from the layout every frame with what the card and the chrome
/// measure; it sends only when the question has changed. One lift per card: a
/// card replaced by another seat's card without a dismiss in between keeps the
/// first lift standing and the second ADDS to it, so the one restore at the end
/// puts the map back where the buyer had it rather than half way.
@MainActor
public final class SeatLayerPickerSeatLift {
    /// The runtime's pan; see `SeatLayerPickerController.frameSeat`.
    public typealias Frame = @MainActor (
        _ seatId: String,
        _ fraction: Double,
        _ gestures: Int?
    ) async -> SeatLayerSeatFrame?

    /// When the lift is asked again after it first lands.
    ///
    /// The runtime re-fits the section on its own when its surface changes
    /// size, and the web view finishes growing under a collapsing sheet a frame
    /// or two AFTER the layout has settled — so a lift that landed can be
    /// undone by a refit nobody on this side sees. Asking again, with the
    /// gesture count as the guard, costs one `dy: 0` reply when the seat is
    /// already in place and puts it back when it is not.
    public nonisolated static let defaultSettle: [Double] = [0.350, 0.800]

    private let frame: Frame
    private let settle: [Double]
    private let onChanged: (@MainActor () -> Void)?

    private var currentSeatId: String?
    private var fraction: Double = 0
    private var pan: Double = 0
    private var anchor: Double = 0
    private var gestures: Int?
    private var revision = -1
    private var generation: UInt64 = 0
    private var seenHeight: Double?
    private var isPending = false
    private var settleTask: Task<Void, Never>?

    public init(
        settle: [Double] = SeatLayerPickerSeatLift.defaultSettle,
        onChanged: (@MainActor () -> Void)? = nil,
        frame: @escaping Frame
    ) {
        self.settle = settle
        self.onChanged = onChanged
        self.frame = frame
    }

    /// The seat the map is lifted for, or nil.
    public var seatId: String? { currentSeatId }

    /// The total pan standing, in screen points.
    public var dy: Double { pan }

    /// The pan made since the snapshot the chrome is reading, in screen points.
    ///
    /// `selection[].screenPoint` is computed when the runtime BUILDS a
    /// snapshot, and `picker.frameSeat` publishes none — it is camera only,
    /// with no revision — so a seat's reported point is where it sat before
    /// this lift. Anything drawn against that point adds this, or it lands a
    /// whole lift band away from the seat. A newer snapshot already contains
    /// the pans made before it, so this resets the moment one arrives rather
    /// than accumulating for the card's life.
    public var anchorDy: Double { anchor }

    /// Whether a lift is waiting for the map to hold still.
    public var pending: Bool { isPending }

    /// Keep the map lifted for `seatId`, or put it back for nil.
    ///
    /// `sheet` is the band the card covers, measured from the map's foot; zero
    /// until the card has been laid out, in which case nothing is sent yet.
    /// `revision` re-asks after every snapshot the runtime publishes, so a
    /// glide that lands with the card up is followed; the runtime answers
    /// `dy: 0` when the seat is already in place and declines outright once the
    /// buyer has moved the map.
    public func sync(
        seatId: String?,
        mapHeight: Double,
        top: Double,
        bottom: Double,
        sheet: Double,
        revision: Int
    ) {
        guard let seatId else {
            release()
            return
        }
        let band = mapHeight - top - bottom
        guard band > 0, sheet > 0 else { return }
        // The map is a hosted web view that resizes as the cart sheet collapses
        // under an opening card, and the runtime pans against ITS height at the
        // moment the command lands. A fraction folded against a height caught
        // mid-animation puts the seat under the card. So a lift is only sent
        // once two consecutive syncs agree on the height.
        guard seenHeight == mapHeight else {
            seenHeight = mapHeight
            isPending = true
            return
        }
        isPending = false
        let next = seatLayerSheetLiftFraction(
            mapHeight: mapHeight,
            top: top,
            bottom: bottom,
            sheet: sheet
        )
        if seatId == currentSeatId, next == fraction, revision == self.revision {
            return
        }
        // A newer snapshot recomputed every screen point against the camera
        // this lift has already moved, so the pans folded into it are no longer
        // the shell's to add.
        if revision != self.revision { anchor = 0 }
        currentSeatId = seatId
        fraction = next
        self.revision = revision
        settleTask?.cancel()
        settleTask = nil
        generation += 1
        let generation = generation
        Task { @MainActor [weak self] in
            guard let self, generation == self.generation else { return }
            await self.lift(seatId: seatId, fraction: next, generation: generation)
        }
    }

    private func lift(seatId: String, fraction: Double, generation: UInt64) async {
        let answer = await frame(seatId, fraction, gestures)
        guard let answer, generation == self.generation else { return }
        // A refused lift (the buyer has moved the map) leaves the count where
        // it was, so the restore is refused for the same reason.
        if let gestures, answer.gestures != gestures { return }
        gestures = answer.gestures
        pan += answer.dy
        if answer.dy != 0 {
            anchor += answer.dy
            onChanged?()
        }
        guard settleTask == nil, !settle.isEmpty else { return }
        settleTask = Task { @MainActor [weak self, settle] in
            for delay in settle {
                try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
                guard let self, !Task.isCancelled,
                      generation == self.generation,
                      self.currentSeatId == seatId else { return }
                await self.lift(seatId: seatId, fraction: fraction, generation: generation)
            }
        }
    }

    /// Put the seat at its resting place, unless the buyer has moved the map,
    /// and forget the lift.
    public func release() {
        let seatId = currentSeatId
        let gestures = self.gestures
        let pan = self.pan
        forget()
        guard let seatId, let gestures, pan != 0 else { return }
        Task { @MainActor [frame] in
            _ = await frame(seatId, seatLayerSheetRestoreFraction, gestures)
        }
    }

    /// Forget the lift without touching the map — the picker is going away.
    public func forget() {
        generation += 1
        settleTask?.cancel()
        settleTask = nil
        seenHeight = nil
        isPending = false
        currentSeatId = nil
        fraction = 0
        pan = 0
        anchor = 0
        gestures = nil
        revision = -1
    }
}
