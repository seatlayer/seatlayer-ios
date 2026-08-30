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

/// Geometry shared by the ready-made animation and deterministic fixtures.
public enum SeatLayerPickerSelectionFlight {
    public static func plan(
        width: Double,
        height: Double,
        layout: SeatLayerPickerSelectionFlightLayout,
        reduceMotion: Bool
    ) -> SeatLayerPickerSelectionFlightPlan {
        let safeWidth = max(1, width)
        let safeHeight = max(1, height)
        let start = SeatLayerPickerSelectionFlightPoint(
            x: safeWidth / 2,
            y: min(max(44, safeHeight * 0.52), max(44, safeHeight - 72))
        )
        let end: SeatLayerPickerSelectionFlightPoint
        switch layout {
        case .phone:
            end = .init(x: safeWidth / 2, y: max(18, safeHeight - 24))
        case .wide:
            end = .init(
                x: max(18, safeWidth - 160),
                y: min(max(60, safeHeight * 0.28), max(60, safeHeight - 36))
            )
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
            durationMilliseconds: SeatLayerPickerMotionTokens.flyMilliseconds,
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
}

#if canImport(SwiftUI) && canImport(UIKit)
struct SeatLayerPickerSelectionFlightOverlay: View {
    let moment: SeatLayerPickerSelectionFlightMoment
    let color: Color
    let layout: SeatLayerPickerSelectionFlightLayout
    let reduceMotion: Bool
    @State private var progress = 0.0
    @State private var visible = true

    var body: some View {
        GeometryReader { geometry in
            let plan = SeatLayerPickerSelectionFlight.plan(
                width: geometry.size.width,
                height: geometry.size.height,
                layout: layout,
                reduceMotion: reduceMotion
            )
            if visible, !plan.skipped {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .overlay { Circle().stroke(.white.opacity(0.86), lineWidth: 2) }
                    .shadow(color: color.opacity(0.46), radius: 7)
                    .modifier(SeatLayerPickerQuadraticFlightEffect(
                        progress: progress,
                        plan: plan
                    ))
                    .opacity(progress < 0.92 ? 1 : max(0, (1 - progress) / 0.08))
                    .scaleEffect(progress < 0.82 ? 1 : max(0.55, 1 - (progress - 0.82)))
                    .task(id: moment.id) {
                        progress = 0
                        visible = true
                        await Task.yield()
                        withAnimation(seatLayerPickerAnimation(
                            .fly,
                            reduceMotion: reduceMotion
                        )) {
                            progress = 1
                        }
                        try? await Task.sleep(
                            nanoseconds: UInt64(plan.durationMilliseconds) * 1_000_000
                        )
                        guard !Task.isCancelled else { return }
                        visible = false
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
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
