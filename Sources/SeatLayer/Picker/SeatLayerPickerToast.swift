import Foundation
#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
#endif

/// How loud one toast is, and what colour its hairline takes.
///
/// Only the border changes between tones. A message the buyer did not ask for
/// should read as the same object every time, coloured by how much it matters
/// rather than repainted into a different component.
public enum SeatLayerPickerToastTone: String, Sendable, Equatable, CaseIterable {
    /// A fact. "D-14 removed."
    case neutral
    /// Something the buyer should know before they act again.
    case warning
    /// Something that did not work.
    case error
    /// Something that did.
    case success
}

/// One thing to say, and at most one thing to do about it.
///
/// A toast is a sentence, not a chip: it wraps, it never blocks anything, and
/// it is gone in a few seconds. Everything the buyer must still be able to act
/// on lives on a surface that stays.
public struct SeatLayerPickerToast: Sendable, Equatable, Identifiable {
    public let id: UUID
    /// The sentence.
    public let message: String
    /// How much it matters.
    public let tone: SeatLayerPickerToastTone
    /// The label of the one action, or nil for a toast that only tells.
    public let actionLabel: String?

    public init(
        _ message: String,
        tone: SeatLayerPickerToastTone = .neutral,
        actionLabel: String? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.message = message
        self.tone = tone
        self.actionLabel = actionLabel
    }

    /// Whether this toast offers something to press.
    public var hasAction: Bool { actionLabel != nil }

    /// Whether `other` says the same thing this one already says.
    public func saysTheSameAs(_ other: SeatLayerPickerToast) -> Bool {
        message == other.message && tone == other.tone
    }
}

/// The one shake an error-tone toast arrives with.
///
/// A toast that only tells is a sentence appearing; a toast that says
/// something did not work has to be noticed, and the picker has no second
/// colour to spend on it — only the border changes between tones. So the
/// error tone moves once and settles.
///
// tokens.json gap: the shake itself is not in the token document — only its
// duration is (`motion.duration.bump`). The travel and the number of passes
// are named here so the integrator can lift them.
public enum SeatLayerPickerToastShake {
    /// How far the card travels at the widest point of the shake, in points.
    /// Far enough to be a movement, near enough that the sentence stays
    /// readable through it.
    public static let amplitude: Double = 6
    /// How many times it crosses centre.
    public static let passes: Double = 3
}

/// How far a shaking toast stands from centre at `progress` — 0 at the start,
/// 1 once it has settled.
///
/// Damped by design: the movement is largest as the card arrives and is gone
/// by the end, so the toast never sits vibrating under a sentence the buyer is
/// still reading.
public func seatLayerPickerToastShakeOffset(
    progress: Double,
    amplitude: Double = SeatLayerPickerToastShake.amplitude
) -> Double {
    let travel = min(1, max(0, progress))
    let decay = 1 - travel
    return amplitude * decay * sin(travel * SeatLayerPickerToastShake.passes * 2 * .pi)
}

/// How long one toast stays up before it takes itself away.
public let seatLayerPickerToastDwell = TimeInterval(
    SeatLayerPickerMotionDurationTokens.toastDwell
) / 1000

#if canImport(SwiftUI) && canImport(UIKit)

/// The queue behind one picker's toasts.
///
/// Deliberately a queue of one. Two sentences stacked over a map are two
/// things to read while the thing they are about is underneath them, so a new
/// message replaces the standing one and restarts its dwell. The same sentence
/// arriving twice in a row is ignored, because two signals commonly describe
/// one event.
@MainActor
public final class SeatLayerPickerToastQueue: ObservableObject {
    /// What is on screen, or nil.
    @Published public private(set) var current: SeatLayerPickerToast?

    private var dwell: Task<Void, Never>?
    private var renderers = 0
    private var action: (@MainActor () -> Void)?

    public init() {}

    /// Say `toast`, replacing anything standing.
    public func show(_ toast: SeatLayerPickerToast, action: (@MainActor () -> Void)? = nil) {
        if let current, current.saysTheSameAs(toast) { return }
        current = toast
        self.action = action
        dwell?.cancel()
        dwell = nil
        arm()
    }

    /// Run the standing toast's offer, then take it away.
    public func act() {
        let offer = action
        dismiss()
        offer?()
    }

    /// Take the standing toast away now.
    public func dismiss() {
        dwell?.cancel()
        dwell = nil
        action = nil
        guard current != nil else { return }
        current = nil
    }

    /// A surface started drawing this queue.
    ///
    /// A queue nobody is watching must not run a clock: a picker composed
    /// without a toast band would otherwise leave a dwell behind every
    /// message, and the message would expire unseen before the surface that
    /// shows it was ever mounted.
    public func beginRendering() {
        renderers += 1
        arm()
    }

    /// A surface stopped drawing this queue.
    public func endRendering() {
        renderers = max(0, renderers - 1)
        guard renderers == 0 else { return }
        dwell?.cancel()
        dwell = nil
    }

    private func arm() {
        guard current != nil, renderers > 0, dwell == nil else { return }
        let seconds = seatLayerPickerToastDwell
        dwell = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }
}

private let seatLayerPickerToastQueues =
    NSMapTable<SeatLayerPickerController, SeatLayerPickerToastQueue>.weakToStrongObjects()

/// The toast queue belonging to `controller`, created on first use.
///
/// Held beside the controller rather than inside it: the queue is presentation
/// and the controller is the session, and a host driving the picker headlessly
/// should never allocate one.
@MainActor
public func seatLayerPickerToasts(
    for controller: SeatLayerPickerController
) -> SeatLayerPickerToastQueue {
    if let existing = seatLayerPickerToastQueues.object(forKey: controller) { return existing }
    let queue = SeatLayerPickerToastQueue()
    seatLayerPickerToastQueues.setObject(queue, forKey: controller)
    return queue
}

// tokens.json gap: the toast card's own geometry and type are Dart-local
// literals in `picker_toast.dart` (corner 16, pad 16/9, gap 12, drawn pill 30,
// text 12.5/w600, pill 12.5/w800, shadow 0 12 32 -12 at 50% black).
private enum SeatLayerPickerToastMetrics {
    static let corner: Double = 16
    static let padX: Double = 16
    static let padY: Double = 9
    static let padTrailingWithAction: Double = 8
    static let gap: Double = 12
    static let pillHeight: Double = 30
    static let pillPadX: Double = 10
    static let bandPadX: Double = 14
    static let bandPadBottom: Double = 14
    static let messageSize: Double = 12.5
    static let shadowRadius: Double = 11
    static let shadowY: Double = 8
}

/// The toast surface itself: a wrapping sentence on the picker's own ground.
public struct SeatLayerPickerToastCard: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 before the shake, 1 once it has settled. A card that never shakes
    /// stays at 1, which is the resting place either way.
    @State private var shake: Double = 1
    private let toast: SeatLayerPickerToast
    private let onAct: () -> Void

    public init(toast: SeatLayerPickerToast, onAct: @escaping () -> Void = {}) {
        self.toast = toast
        self.onAct = onAct
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        HStack(spacing: SeatLayerPickerToastMetrics.gap) {
            Text(toast.message)
                .seatLayerPickerFont(
                    size: SeatLayerPickerToastMetrics.messageSize,
                    weight: .semibold
                )
                .foregroundColor(palette.text)
                .fixedSize(horizontal: false, vertical: true)
            if let label = toast.actionLabel {
                actionPill(label, palette: palette)
            }
        }
        .padding(.leading, SeatLayerPickerToastMetrics.padX)
        .padding(
            .trailing,
            toast.hasAction
                ? SeatLayerPickerToastMetrics.padTrailingWithAction
                : SeatLayerPickerToastMetrics.padX
        )
        .padding(.vertical, SeatLayerPickerToastMetrics.padY)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerToastMetrics.corner))
        .overlay {
            RoundedRectangle(cornerRadius: SeatLayerPickerToastMetrics.corner)
                .stroke(border(palette: palette), lineWidth: 1)
        }
        // `0 12 32 -12` at 50 % black: SwiftUI has no negative spread, so the
        // alpha carries the tightening the spread does in the design source.
        .shadow(
            color: .black.opacity(0.22),
            radius: SeatLayerPickerToastMetrics.shadowRadius,
            y: SeatLayerPickerToastMetrics.shadowY
        )
        .modifier(SeatLayerPickerToastShakeEffect(progress: shake))
        .onAppear { shakeIfSomethingDidNotWork() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("seatlayer-toast")
    }

    /// One shake, on arrival, for the error tone only — and none at all for a
    /// viewer who has asked for less movement, which is a shake with no
    /// reduced form rather than a shorter one.
    private func shakeIfSomethingDidNotWork() {
        guard toast.tone == .error,
              !reduceMotion,
              !SeatLayerPickerMotion.capturing else { return }
        shake = 0
        withAnimation(
            .linear(
                duration: Double(SeatLayerPickerMotionDurationTokens.bump) / 1_000
            )
        ) {
            shake = 1
        }
    }

    /// Tones change only the border. The picker has no green of its own, and a
    /// confirmation is the buyer's own action landing — which is what the
    /// accent already means here.
    private func border(palette: SeatLayerPickerPalette) -> Color {
        switch toast.tone {
        case .neutral: return palette.divider
        case .warning: return palette.warning
        case .error: return palette.error
        case .success: return palette.accent
        }
    }

    /// A 44 pt hit box around a 30 pt drawn pill: the pill is the drawn size
    /// the web picker uses, and a thumb needs the rest of it.
    private func actionPill(_ label: String, palette: SeatLayerPickerPalette) -> some View {
        Button(action: onAct) {
            Text(label)
                .seatLayerPickerFont(
                    size: SeatLayerPickerToastMetrics.messageSize,
                    weight: .heavy
                )
                .foregroundColor(palette.onAccent)
                .lineLimit(1)
                .padding(.horizontal, SeatLayerPickerToastMetrics.pillPadX)
                .frame(height: SeatLayerPickerToastMetrics.pillHeight)
                .background(palette.accent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(height: SeatLayerPickerSizeTokens.minimumHitTarget)
        .accessibilityIdentifier("seatlayer-toast-action")
    }
}

/// Moves a card along the shake, once.
struct SeatLayerPickerToastShakeEffect: GeometryEffect {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: seatLayerPickerToastShakeOffset(progress: progress),
            y: 0
        ))
    }
}

/// The bottom-centre band of the map where toasts appear.
///
/// It renders nothing until something is said, and it never takes a pointer
/// except on its own action pill, so the map underneath stays the way out.
public struct SeatLayerPickerToastBand: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    private let bottomInset: Double
    private let lifted: Bool

    /// - Parameters:
    ///   - bottomInset: what the chrome standing on the bottom of the map
    ///     already covers.
    ///   - lifted: whether a seat card is up. The message is the reply to the
    ///     tap that opened that card, so it rises clear of it rather than
    ///     being read through it.
    public init(bottomInset: Double = 0, lifted: Bool = false) {
        self.bottomInset = bottomInset
        self.lifted = lifted
    }

    public var body: some View {
        SeatLayerPickerToastBandBody(
            queue: seatLayerPickerToasts(for: controller),
            bottomInset: bottomInset,
            lifted: lifted
        )
    }
}

/// The band, once its queue is known.
struct SeatLayerPickerToastBandBody: View {
    @ObservedObject var queue: SeatLayerPickerToastQueue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let bottomInset: Double
    let lifted: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if let toast = queue.current {
                SeatLayerPickerToastCard(toast: toast) { queue.act() }
                    .id(toast.id)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .move(edge: .bottom))
                    )
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityLabel(toast.message)
            }
        }
        .padding(.horizontal, SeatLayerPickerToastMetrics.bandPadX)
        .padding(
            .bottom,
            bottomInset
                + SeatLayerPickerToastMetrics.bandPadBottom
                + (lifted ? SeatLayerPickerSizeTokens.toastCardLift : 0)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(queue.current?.hasAction == true)
        .animation(
            seatLayerPickerAnimation(.toast, reduceMotion: reduceMotion),
            value: queue.current?.id
        )
        .onAppear { queue.beginRendering() }
        .onDisappear { queue.endRendering() }
    }
}
#endif
