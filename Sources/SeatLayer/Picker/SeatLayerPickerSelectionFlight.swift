import Foundation
#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
#endif

public enum SeatLayerPickerSelectionFlightLayout: String, Sendable, Equatable, CaseIterable {
    case phone
    case wide
}

public struct SeatLayerPickerSelectionFlightPoint: Sendable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct SeatLayerPickerSelectionFlightPlan: Sendable, Equatable {
    public let start: SeatLayerPickerSelectionFlightPoint
    public let control: SeatLayerPickerSelectionFlightPoint
    public let end: SeatLayerPickerSelectionFlightPoint
    public let durationMilliseconds: Int
    public let skipped: Bool
}

/// One successful native confirmation. The UUID intentionally makes two
/// confirmations of the same seat distinct animation moments.
public struct SeatLayerPickerSelectionFlightMoment: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let seatId: String
    public let label: String
    public let categoryKey: String?

    public init(
        id: UUID = UUID(),
        seatId: String,
        label: String,
        categoryKey: String?
    ) {
        self.id = id
        self.seatId = seatId
        self.label = label
        self.categoryKey = categoryKey
    }
}

/// The ticket itself, travelling from the card to the collapsed cart.
///
/// A labelled chip in the category's own colour rather than an anonymous dot:
/// what left the card is a specific seat, and the buyer should be able to read
/// WHICH one on its way to the summary that has already counted it. That is the
/// one thing a card which simply closes cannot say.
public enum SeatLayerPickerSelectionFlight {
    /// Where the chip leaves from and where it lands.
    ///
    /// `origin` is the card's own centre and `target` the footer's summary
    /// line, both measured before the count reflows. Either may be absent — a
    /// host composing its own chrome reports neither — and the fallbacks are
    /// the same figures the web and Flutter use: the middle of the map for the
    /// card, and a fixed inset above the foot of the screen for the summary.
    public static func plan(
        width: Double,
        height: Double,
        layout: SeatLayerPickerSelectionFlightLayout,
        reduceMotion: Bool,
        origin: SeatLayerPickerSelectionFlightPoint? = nil,
        target: SeatLayerPickerSelectionFlightPoint? = nil
    ) -> SeatLayerPickerSelectionFlightPlan {
        let safeWidth = max(1, width)
        let safeHeight = max(1, height)
        let start = origin ?? SeatLayerPickerSelectionFlightPoint(
            x: safeWidth / 2,
            y: min(max(44, safeHeight * 0.52), max(44, safeHeight - 72))
        )
        let end: SeatLayerPickerSelectionFlightPoint
        if let target {
            end = target
        } else {
            switch layout {
            case .phone:
                end = .init(
                    x: safeWidth / 2,
                    y: max(18, safeHeight - seatLayerPickerCartChipAim)
                )
            case .wide:
                end = .init(
                    x: max(18, safeWidth - 160),
                    y: min(max(60, safeHeight * 0.28), max(60, safeHeight - 36))
                )
            }
        }
        let lift = min(112, max(44, safeHeight * 0.12))
        let control = SeatLayerPickerSelectionFlightPoint(
            x: (start.x + end.x) / 2,
            y: max(12, min(start.y, end.y) - lift)
        )
        return .init(
            start: start,
            control: control,
            end: end,
            durationMilliseconds: SeatLayerPickerMotionDurationTokens.confirmFlight,
            // Not created at all under reduced motion: an indicator that
            // appears and vanishes in the same frame is just a flicker.
            skipped: reduceMotion
        )
    }

    public static func point(
        at progress: Double,
        in plan: SeatLayerPickerSelectionFlightPlan
    ) -> SeatLayerPickerSelectionFlightPoint {
        let t = min(1, max(0, progress))
        let inverse = 1 - t
        return .init(
            x: inverse * inverse * plan.start.x
                + 2 * inverse * t * plan.control.x
                + t * t * plan.end.x,
            y: inverse * inverse * plan.start.y
                + 2 * inverse * t * plan.control.y
                + t * t * plan.end.y
        )
    }

    /// How big the chip is at `progress`, and how much of it is there.
    ///
    /// It appears at just over half size, reaches full size a fifth of the way
    /// along, and shrinks as it lands.
    public static func scaleAndOpacity(
        at progress: Double
    ) -> (scale: Double, opacity: Double) {
        let t = min(1, max(0, progress))
        let rise = seatLayerPickerCartChipRise
        if t < rise {
            return (0.6 + 0.4 * (t / rise), t / rise)
        }
        let after = (t - rise) / max(0.0001, 1 - rise)
        return (1 - 0.45 * after, 1 - 0.85 * after)
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
/// Where the chip leaves from: the card's own centre, in picker coordinates.
struct SeatLayerPickerFlightOriginKey: PreferenceKey {
    static var defaultValue: CGPoint?
    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        value = nextValue() ?? value
    }
}

/// Where the chip lands: the footer's summary line, measured BEFORE the count
/// reflows, so the chip aims at the number it is about to change.
struct SeatLayerPickerFlightTargetKey: PreferenceKey {
    static var defaultValue: CGPoint?
    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        value = nextValue() ?? value
    }
}

extension View {
    /// Report this view's centre as the chip's departure point.
    func seatLayerPickerFlightOrigin(in space: CoordinateSpace) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: SeatLayerPickerFlightOriginKey.self,
                    value: CGPoint(
                        x: geometry.frame(in: space).midX,
                        y: geometry.frame(in: space).midY
                    )
                )
            }
        }
    }

    /// Report this view's centre as the chip's landing point.
    func seatLayerPickerFlightTarget(in space: CoordinateSpace) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: SeatLayerPickerFlightTargetKey.self,
                    value: CGPoint(
                        x: geometry.frame(in: space).midX,
                        y: geometry.frame(in: space).midY
                    )
                )
            }
        }
    }
}

struct SeatLayerPickerSelectionFlightOverlay: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    let moment: SeatLayerPickerSelectionFlightMoment
    let color: Color
    let layout: SeatLayerPickerSelectionFlightLayout
    let reduceMotion: Bool
    var origin: CGPoint?
    var target: CGPoint?
    @State private var progress = 0.0
    @State private var visible = true

    var body: some View {
        GeometryReader { geometry in
            let plan = SeatLayerPickerSelectionFlight.plan(
                width: geometry.size.width,
                height: geometry.size.height,
                layout: layout,
                reduceMotion: reduceMotion,
                origin: origin.map { .init(x: $0.x, y: $0.y) },
                target: target.map { .init(x: $0.x, y: $0.y) }
            )
            if visible, !plan.skipped {
                let figure = SeatLayerPickerSelectionFlight.scaleAndOpacity(at: progress)
                Text(moment.label)
                    .seatLayerPickerFont(size: 11, weight: .bold)
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundColor(seatLayerPickerFlyingInk(color))
                    .padding(.horizontal, 7)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Capsule().fill(color))
                    .modifier(SeatLayerPickerQuadraticFlightEffect(
                        progress: progress,
                        plan: plan
                    ))
                    .opacity(figure.opacity)
                    .scaleEffect(figure.scale)
                    .task(id: moment.id) {
                        progress = 0
                        visible = true
                        await Task.yield()
                        withAnimation(.timingCurve(
                            SeatLayerPickerCurveTokens.spring.x1,
                            SeatLayerPickerCurveTokens.spring.y1,
                            SeatLayerPickerCurveTokens.spring.x2,
                            SeatLayerPickerCurveTokens.spring.y2,
                            duration: Double(plan.durationMilliseconds) / 1000
                        )) {
                            progress = 1
                        }
                        try? await Task.sleep(
                            nanoseconds: UInt64(plan.durationMilliseconds) * 1_000_000
                        )
                        guard !Task.isCancelled else { return }
                        visible = false
                        // The landing is the chip's to call — never a clock
                        // somewhere else guessing at its flight: the count
                        // swells and the map pulls back only now.
                        presentation.chipDidLand()
                        try? await Task.sleep(
                            nanoseconds: UInt64(SeatLayerPickerMotionDurationTokens.bump)
                                * 1_000_000
                        )
                        guard !Task.isCancelled else { return }
                        // The backstop that frees the map: a composition that
                        // draws no swell must not leave the lift standing.
                        presentation.endCartLanding()
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Ink that reads on a category colour nobody chose for legibility.
func seatLayerPickerFlyingInk(_ fill: Color) -> Color {
    SeatLayerPickerInk.relativeLuminance(SeatLayerPickerInkColor(fill)) > 0.5
        ? Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255)
        : .white
}

private struct SeatLayerPickerQuadraticFlightEffect: GeometryEffect {
    var progress: Double
    let plan: SeatLayerPickerSelectionFlightPlan

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let point = SeatLayerPickerSelectionFlight.point(at: progress, in: plan)
        return ProjectionTransform(CGAffineTransform(
            translationX: point.x - Double(size.width) / 2,
            y: point.y - Double(size.height) / 2
        ))
    }
}
#endif
