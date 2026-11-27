#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

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
    @State private var slow = false

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
                if slow {
                    Text(style.strings.text(.loadingTakingLonger))
                        .seatLayerPickerFont(size: 13)
                        .foregroundColor(palette.mutedText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 48)
                        .transition(.opacity)
                }
            }
        }
        .onAppear(perform: start)
        .task {
            try? await Task.sleep(nanoseconds: UInt64(seatLayerPickerSlowOpeningSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(seatLayerPickerAnimation(.crossfade, reduceMotion: reduceMotion)) { slow = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(style.strings.text(slow ? .loadingTakingLonger : .loading))
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
    @State private var inFront = UIApplication.shared.applicationState != .background
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
        let kind = failureKind
        VStack(spacing: 12) {
            if kind == .connection {
                SeatLayerPickerConnectionSign(shown: .offline, palette: palette, diameter: 26)
                    .frame(width: 56, height: 56)
                    .overlay { Circle().stroke(palette.divider, lineWidth: 1) }
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .seatLayerPickerFont(size: 26)
                    .foregroundColor(palette.error)
            }
            Text(style.strings.text(kind == .connection ? .offline : .mapDidNotLoad))
                .seatLayerPickerFont(size: 15, weight: .bold)
                .foregroundColor(palette.text)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if kind != .server {
                Text(style.strings.text(.checkConnection))
                    .seatLayerPickerFont(size: 12)
                    .foregroundColor(palette.mutedText)
                    .multilineTextAlignment(.center)
            }
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
        .task(id: kind == .connection && inFront) { await retryWhileOffline(kind) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            seatLayerPickerOfflineTries(for: controller).restart()
            inFront = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            inFront = false
        }
    }

    /// Why the page did not load: nothing answered, its server failed, or
    /// anything else (a chart that would not draw, a page too slow to start).
    private var failureKind: SeatLayerPickerFailureKind {
        guard case .failed(let error) = controller.phase else { return .other }
        return seatLayerPickerFailureKind(error)
    }

    /// While the app is in front, a page nothing answered is opened again by
    /// itself after 10 s and 20 s, then every 30 s. In the background it waits.
    private func retryWhileOffline(_ kind: SeatLayerPickerFailureKind) async {
        guard kind == .connection, inFront else { return }
        let tries = seatLayerPickerOfflineTries(for: controller)
        try? await Task.sleep(nanoseconds: UInt64(tries.nextWait() * 1_000_000_000))
        guard !Task.isCancelled else { return }
        tries.tried()
        retry()
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
