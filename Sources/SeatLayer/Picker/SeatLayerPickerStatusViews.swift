#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct SeatLayerPickerAttribution: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        if seatLayerPickerAttributionVisible(in: controller.snapshot) {
            let palette = resolveSeatLayerPickerPalette(
                style: style,
                colorScheme: colorScheme,
                snapshot: controller.snapshot
            )
            HStack(spacing: 4) {
                SeatLayerPickerPoweredMark(
                    background: palette.text,
                    ink: palette.surface
                )
                Text(style.strings.text(.poweredBy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .seatLayerPickerFont(size: 10, weight: .semibold)
            .foregroundColor(palette.text)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .frame(minHeight: SeatLayerPickerSizeTokens.attributionHeight)
            .dynamicTypeSize(...DynamicTypeSize.large)
            .opacity(0.64)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(style.strings.text(.poweredBy))
        }
    }
}

private struct SeatLayerPickerPoweredMark: View {
    let background: Color
    let ink: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            bar(width: 8)
            bar(width: 5.5)
            bar(width: 3)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .frame(width: 12, height: 12, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .accessibilityHidden(true)
    }

    private func bar(width: Double) -> some View {
        Capsule()
            .fill(ink)
            .frame(width: width, height: 2)
    }
}

/// The venue, not a spinner.
///
/// A spinner says only "something is happening"; three concentric seating
/// shells around a stage say what is arriving, and they say it in the chart's
/// own shape. The shells breathe slowly under a diagonal sweep, with a thin
/// indeterminate strip along the top of the map. `strings.loading` is announced
/// but never drawn.
public struct SeatLayerPickerLoadingView: View {
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var sweep = -1.0
    @State private var strip = -1.0

    public init() {}

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: nil
        )
        ZStack {
            palette.background
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                ZStack {
                    SeatLayerPickerVenueSilhouette()
                        .stroke(palette.accent, lineWidth: shellStroke)
                        .frame(width: size * silhouetteFraction, height: size * silhouetteFraction)
                        .opacity(breathing ? shellOpacityHigh : shellOpacityLow)
                        .overlay {
                            if !reduceMotion { sweepBand(width: size * silhouetteFraction) }
                        }
                        .mask {
                            SeatLayerPickerVenueSilhouette()
                                .stroke(Color.black, lineWidth: shellStroke)
                                .frame(
                                    width: size * silhouetteFraction,
                                    height: size * silhouetteFraction
                                )
                        }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            VStack {
                progressStrip(palette: palette)
                Spacer(minLength: 0)
            }
        }
        .onAppear(perform: start)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(style.strings.text(.loading))
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("seatlayer-loading")
    }

    @ViewBuilder
    private func sweepBand(width: Double) -> some View {
        LinearGradient(
            colors: [.clear, .white.opacity(sweepStrength), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: width * sweepWidthFraction)
        .offset(x: sweep * width)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func progressStrip(palette: SeatLayerPickerPalette) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(palette.accent)
                .frame(width: geometry.size.width * stripWidthFraction)
                .offset(x: strip * geometry.size.width)
                .opacity(reduceMotion ? stripRestOpacity : 1)
        }
        .frame(height: stripHeight)
        .background(palette.accent.opacity(stripTrack))
        .accessibilityHidden(true)
    }

    private func start() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: breatheSeconds).repeatForever(autoreverses: true)) {
            breathing = true
        }
        withAnimation(.linear(duration: sweepSeconds).repeatForever(autoreverses: false)) {
            sweep = 1
        }
        withAnimation(.linear(duration: stripSeconds).repeatForever(autoreverses: false)) {
            strip = 1
        }
    }

    // tokens.json gap: the silhouette's own geometry. `motion.duration.shellSweep`
    // and `revealDelay` are tokens; the shell weights and opacities are the
    // Dart-local constants of `picker_status_views.dart`.
    private let silhouetteFraction = 0.62
    private let shellStroke = 2.0
    private let shellOpacityLow = 0.14
    private let shellOpacityHigh = 0.30
    private let sweepWidthFraction = 0.45
    private let sweepStrength = 0.22
    private let breatheSeconds = 1.8
    private let stripHeight = 2.0
    private let stripTrack = 0.16
    private let stripWidthFraction = 0.32
    private let stripRestOpacity = 0.5
    private let stripSeconds = 1.1

    private var sweepSeconds: Double {
        SeatLayerPickerMotionDurationTokens.outsideBudget["shellSweep"].map { Double($0) / 1_000 } ?? 1.2
    }
}

/// Three concentric seating shells around a stage.
struct SeatLayerPickerVenueSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centre = CGPoint(x: rect.midX, y: rect.maxY * stageDrop)
        for index in 0..<shellCount {
            let radius = rect.width * (firstShell + Double(index) * shellStep) / 2
            path.addArc(
                center: centre,
                radius: radius,
                startAngle: .degrees(200),
                endAngle: .degrees(340),
                clockwise: false
            )
        }
        let stage = CGRect(
            x: centre.x - rect.width * stageWidth / 2,
            y: centre.y - rect.height * stageHeight,
            width: rect.width * stageWidth,
            height: rect.height * stageHeight
        )
        path.addRoundedRect(in: stage, cornerSize: CGSize(width: 4, height: 4))
        return path
    }

    private let shellCount = 3
    private let firstShell = 0.44
    private let shellStep = 0.24
    private let stageDrop = 0.78
    private let stageWidth = 0.30
    private let stageHeight = 0.07
}

public struct SeatLayerPickerErrorView: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    private let retry: () -> Void

    public init(retry: @escaping () -> Void) {
        self.retry = retry
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .seatLayerPickerFont(size: 26)
                .foregroundColor(palette.error)
            Text(style.strings.text(.mapDidNotLoad))
                .seatLayerPickerFont(size: 15, weight: .bold)
                .foregroundColor(palette.text)
                .accessibilityAddTraits(.isHeader)
            Text(style.strings.text(.checkConnection))
                .seatLayerPickerFont(size: 12)
                .foregroundColor(palette.mutedText)
                .multilineTextAlignment(.center)
            if controller.lastError?.isRetryable != false {
                Button(style.strings.text(.retry), action: retry)
                    .seatLayerPickerFont(size: 14, weight: .bold)
                    .foregroundColor(palette.onAccent)
                    .padding(.horizontal, 18)
                    .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                    .background(palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.button))
            }
        }
        .padding(24)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card))
        .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
        .padding(20)
    }
}

@MainActor
func runPickerAction(
    _ controller: SeatLayerPickerController,
    _ action: @escaping @MainActor () async throws -> Void
) {
    Task { @MainActor in
        do {
            try await action()
        } catch let error as SeatLayerError {
            controller.record(error)
        } catch {
            controller.record(.transport(error.localizedDescription))
        }
    }
}
#endif
