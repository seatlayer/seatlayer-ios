#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct SeatLayerPickerLoadingView: View {
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(style: style, colorScheme: colorScheme, snapshot: nil)
        VStack(spacing: 12) {
            ProgressView().tint(palette.accent)
            Text(style.strings.text(.loading))
                .seatLayerPickerFont(size: 14, weight: .semibold)
                .foregroundColor(palette.mutedText)
        }
        .padding(24)
        .seatLayerPickerTranslucentBackground(palette.surface, opacity: 0.96)
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.base))
        .accessibilityElement(children: .combine)
    }
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
            Text(style.strings.text(.errorMessage))
                .seatLayerPickerFont(size: 15, weight: .bold)
                .foregroundColor(palette.text)
            if let error = controller.lastError {
                Text(seatLayerPickerBuyerErrorText(error, strings: style.strings))
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
