#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The seat card's two answers, and the small theatre around the recommended
/// one.
///
/// Three things happen on `Add seat`, and each says something the still button
/// cannot. On arrival one highlight crosses it: this is the thing to press.
/// While it waits it breathes, slowly, for as long as it waits: the offer is
/// still open, and it is the buyer's own hesitation that keeps it open. On the
/// press its own ink fills from the leading edge under a drawn check and the
/// word turns to `Added`: the ticket is in the cart. Only the last of the three
/// is about the buyer's own action, and the ticket was counted before the sweep
/// started — this is a receipt, not a progress bar.

/// How far the breath's halo reaches, and how deep its colour goes.
// tokens.json gap: `_inviteHalo` / `_inviteHaloInk` / `_inviteSwell` are
// file-local constants in Flutter too.
let seatLayerPickerInviteHalo: Double = 6
let seatLayerPickerInviteHaloInk = 0.35
/// How much the button swells at the top of each breath.
let seatLayerPickerInviteSwell = 0.02

/// The card's quiet answer: no fill, so it never competes with `Add seat`.
struct SeatLayerPickerCancelButton: View {
    let label: String
    let palette: SeatLayerPickerPalette
    let style: SeatLayerPickerPartStyle?
    let action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            Text(label)
                .seatLayerPickerFont(size: 13, weight: .heavy)
                .lineLimit(1)
                .foregroundColor(action == nil
                    ? palette.mutedText.opacity(0.5)
                    : palette.mutedText)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // The divider's own colour at less than half strength: enough
                // of a ground to read as a button, never enough to compete for
                // the press.
                .background(styledGround ?? palette.divider.opacity(0.44))
                .clipShape(shape)
                .overlay { shape.stroke(palette.divider, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: style?.cornerRadius ?? SeatLayerPickerRadiusTokens.button,
            style: .continuous
        )
    }

    private var styledGround: Color? {
        style?.background.flatMap { UIColor(slHex: $0) }.map(Color.init(uiColor:))
    }
}

/// The card's recommended answer, and the theatre around it.
struct SeatLayerPickerAddSeatButton: View {
    let label: String
    let palette: SeatLayerPickerPalette
    let style: SeatLayerPickerPartStyle?
    /// Whether this press takes a seat back out of the cart.
    ///
    /// The same button asking the opposite question: it carries the failure
    /// colour and a cross rather than the accent and a tick. A TICK IS THE
    /// WRONG PROMISE ON A REMOVE — it reads as "done, added" on the one press
    /// that empties a line out of the cart.
    let destructive: Bool
    /// Whether the press has been committed and the button is now a receipt.
    let added: Bool
    /// Whether the arrival highlight and the breath play at all.
    let invite: Bool
    /// The buyer has found this button, so the card can stop pointing at it.
    let onInviteEnd: () -> Void
    let action: (() -> Void)?

    @State private var inviteStart = Date()
    @State private var press: Double = 0

    var body: some View {
        Group {
            if invite {
                TimelineView(.animation) { context in
                    surface(elapsedMs: context.date.timeIntervalSince(inviteStart) * 1000)
                }
            } else {
                surface(elapsedMs: nil)
            }
        }
        .onChange(of: added) { isAdded in
            guard isAdded else { return }
            withAnimation(.linear(
                duration: Double(SeatLayerPickerMotionDurationTokens.pressSweep) / 1000
            )) {
                press = 1
            }
        }
    }

    private func surface(elapsedMs: Double?) -> some View {
        let breath = seatLayerPickerInviteBreath(elapsedMs: elapsedMs)
        let sweep = seatLayerPickerInviteSweep(elapsedMs: elapsedMs)
        return content(sweep: sweep)
            .scaleEffect(1 + seatLayerPickerInviteSwell * breath)
            .background {
                // The halo is drawn outside the button's own box, and its
                // colour holds while only its reach grows — a halo that fades
                // as it widens reads as a ripple leaving the button, and this
                // one is the button itself swelling.
                if breath > 0 {
                    let spread = seatLayerPickerInviteHalo * breath
                    RoundedRectangle(
                        cornerRadius: SeatLayerPickerRadiusTokens.button + spread / 2,
                        style: .continuous
                    )
                    .strokeBorder(
                        palette.accent.opacity(seatLayerPickerInviteHaloInk),
                        lineWidth: spread
                    )
                    .padding(-spread / 2)
                    .allowsHitTesting(false)
                }
            }
    }

    private func content(sweep: Double) -> some View {
        Button { action?() } label: {
            HStack(spacing: 7) {
                // The check is drawn rather than swapped in: it grows out of
                // the press it is answering.
                SeatLayerPickerTickShape(cross: destructive)
                    .trim(from: 0, to: added ? press : 1)
                    .stroke(ink, style: StrokeStyle(
                        lineWidth: 2.8 * 16 / 24,
                        lineCap: .round,
                        lineJoin: .round
                    ))
                    .frame(width: 16, height: 16)
                // Shrinks only when it must: `Remove seat` beside the 3D square
                // and a 34 % Cancel does not fit at full size on a 390 pt
                // phone, and an answer the buyer cannot read is worse than one
                // a point smaller.
                Text(label)
                    .seatLayerPickerFont(size: 13, weight: .heavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack(alignment: .leading) {
                    ground
                    // The press filling the button with its own ink from the
                    // leading edge.
                    if press > 0 {
                        GeometryReader { geometry in
                            ink.opacity(0.20)
                                .frame(width: geometry.size.width * press)
                        }
                    }
                    // A band two button-widths wide crossing from wholly
                    // leading to wholly trailing, so the highlight enters and
                    // leaves rather than fading in place.
                    if sweep > 0, sweep < 1 {
                        LinearGradient(
                            stops: [
                                .init(color: ink.opacity(0), location: 0),
                                .init(color: ink.opacity(0.24), location: 0.32),
                                .init(color: ink.opacity(0.24), location: 0.68),
                                .init(color: ink.opacity(0), location: 1),
                            ],
                            startPoint: UnitPoint(x: sweep * 2 - 1.5, y: 0.5),
                            endPoint: UnitPoint(x: sweep * 2 + 0.5, y: 0.5)
                        )
                    }
                }
            }
            .clipShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        // Reaching the button by keyboard is the same answer as putting a
        // finger on the card: the invitation has done its job and must not keep
        // moving under a focus ring the buyer is already reading.
        .onSeatLayerFocusChange { focused in if focused { onInviteEnd() } }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: style?.cornerRadius ?? SeatLayerPickerRadiusTokens.button,
            style: .continuous
        )
    }

    private var ground: Color {
        if let styled = style?.background.flatMap({ UIColor(slHex: $0) }) {
            return Color(uiColor: styled)
        }
        if action == nil {
            return seatLayerPickerBlend(palette.mutedText, 0.16, over: palette.surface)
        }
        return destructive ? palette.error : palette.accent
    }

    /// `onAccent` is authored against the accent and says nothing about the
    /// failure colour, so the destructive ink is read off the ground it
    /// actually sits on.
    private var ink: Color {
        if action == nil { return palette.mutedText.opacity(0.58) }
        guard destructive else { return palette.onAccent }
        return seatLayerPickerBandInk(palette.error)
    }
}

/// Where in the current breath the button is: 0 at rest, 1 at the top.
///
/// Zero before the breathing starts, so the button leaves the invitation at
/// exactly its resting size. In between it is the web's own two-keyframe
/// breath: out to the top by the halfway mark and back down again, each half
/// eased in and out rather than one cosine across the whole cycle — a cosine is
/// symmetric but not the same curve, and the peak is where the eye reads the
/// amplitude.
func seatLayerPickerInviteBreath(elapsedMs: Double?) -> Double {
    guard let elapsedMs else { return 0 }
    let since = elapsedMs - Double(SeatLayerPickerMotionDurationTokens.inviteBreatheDelay)
    guard since > 0 else { return 0 }
    let span = Double(SeatLayerPickerMotionDurationTokens.inviteBreathe)
    let phase = (since.truncatingRemainder(dividingBy: span)) / span
    return phase < 0.5
        ? seatLayerPickerInviteEase(phase * 2)
        : 1 - seatLayerPickerInviteEase((phase - 0.5) * 2)
}

/// How much of the arrival highlight has crossed the button.
func seatLayerPickerInviteSweep(elapsedMs: Double?) -> Double {
    guard let elapsedMs else { return 0 }
    let since = elapsedMs - Double(SeatLayerPickerMotionDurationTokens.inviteDelay)
    let span = Double(SeatLayerPickerMotionDurationTokens.inviteSweep)
    guard span > 0 else { return 1 }
    return min(1, max(0, since / span))
}

/// The curve each half of a breath travels: the web's `cubic-bezier(.4,0,.6,1)`.
func seatLayerPickerInviteEase(_ t: Double) -> Double {
    let clamped = min(1, max(0, t))
    return seatLayerPickerCubicBezierValue(
        SeatLayerPickerCubicBezier(x1: 0.4, y1: 0, x2: 0.6, y2: 1),
        at: clamped
    )
}

/// The y of a cubic-Bézier timing curve at progress `t`.
///
/// Newton on the x polynomial, then the y polynomial: the curve is authored as
/// a CSS easing, where the parameter is not the progress.
func seatLayerPickerCubicBezierValue(
    _ curve: SeatLayerPickerCubicBezier,
    at t: Double
) -> Double {
    func axis(_ p1: Double, _ p2: Double, _ s: Double) -> Double {
        let inverse = 1 - s
        return 3 * inverse * inverse * s * p1 + 3 * inverse * s * s * p2 + s * s * s
    }
    var guess = t
    for _ in 0..<8 {
        let x = axis(curve.x1, curve.x2, guess) - t
        if abs(x) < 1e-6 { break }
        let inverse = 1 - guess
        let slope = 3 * inverse * inverse * curve.x1
            + 6 * inverse * guess * (curve.x2 - curve.x1)
            + 3 * guess * guess * (1 - curve.x2)
        if abs(slope) < 1e-6 { break }
        guess -= x / slope
    }
    return axis(curve.y1, curve.y2, min(1, max(0, guess)))
}

/// The tick on `Add seat`, or the cross on `Remove seat`.
struct SeatLayerPickerTickShape: Shape {
    let cross: Bool

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / 24
        var path = Path()
        if cross {
            path.move(to: CGPoint(x: 6 * scale, y: 6 * scale))
            path.addLine(to: CGPoint(x: 18 * scale, y: 18 * scale))
            path.move(to: CGPoint(x: 18 * scale, y: 6 * scale))
            path.addLine(to: CGPoint(x: 6 * scale, y: 18 * scale))
        } else {
            path.move(to: CGPoint(x: 20 * scale, y: 6 * scale))
            path.addLine(to: CGPoint(x: 9 * scale, y: 17 * scale))
            path.addLine(to: CGPoint(x: 4 * scale, y: 12 * scale))
        }
        return path
    }
}

extension View {
    /// `onChange(of: isFocused)` without demanding a newer SwiftUI than the
    /// package's floor.
    func onSeatLayerFocusChange(_ handler: @escaping (Bool) -> Void) -> some View {
        modifier(SeatLayerPickerFocusReporter(handler: handler))
    }
}

private struct SeatLayerPickerFocusReporter: ViewModifier {
    let handler: (Bool) -> Void
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .onChange(of: focused) { handler($0) }
    }
}
#endif
