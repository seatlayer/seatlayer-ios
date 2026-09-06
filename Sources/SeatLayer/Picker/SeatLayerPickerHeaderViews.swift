#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI


enum SeatLayerPickerChromeMetrics {
    static let compactRailHeight = 44.0
    static let compactLegendPaintHeight = 30.0
    static let regularLegendPaintHeight = 40.0
    static let compactViewModePaintHeight = 32.0
    static let regularViewModePaintHeight = 40.0
    static let compactFloorPaintHeight = 30.0
    static let regularFloorPaintHeight = 36.0
    static let compactTruthPaintHeight = 20.0
}

/// Event identity, hold countdown, and optional close control.
public struct SeatLayerPickerHeader: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    private let onClose: (() -> Void)?
    private let compact: Bool

    public init(onClose: (() -> Void)? = nil, compact: Bool = false) {
        self.onClose = onClose
        self.compact = compact
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        HStack(spacing: 10) {
            SeatLayerPickerLogo()
                .fixedSize()
            if !style.options.hideEventDetails {
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.snapshot?.event.name ?? style.strings.text(.chooseSeats))
                        .seatLayerPickerFont(size: compact ? 14 : 16, weight: .bold)
                        .foregroundColor(palette.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if !compact,
                       let venue = controller.snapshot?.event.venue,
                       !venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(venue)
                            .seatLayerPickerFont(size: 11, weight: .medium)
                            .foregroundColor(palette.mutedText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            } else {
                Spacer(minLength: 0)
            }
            if style.options.chrome.holdPill,
               let expiry = controller.snapshot?.hold.expiresAt,
               controller.snapshot?.hold.active == true,
               controller.holdLapse == nil {
                SeatLayerPickerPartHost(.holdCountdown) {
                    SeatLayerPickerHoldCountdown(expiresAt: expiry)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .seatLayerPickerFont(size: 15, weight: .bold)
                        .frame(
                            width: SeatLayerPickerSizeTokens.minimumHitTarget,
                            height: SeatLayerPickerSizeTokens.minimumHitTarget
                        )
                }
                .foregroundColor(palette.text)
                .buttonStyle(.plain)
                .accessibilityLabel(style.strings.text(.close))
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, compact ? 0 : 6)
        .frame(minHeight: SeatLayerPickerSizeTokens.headerHeight)
        .background(palette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }
}

public struct SeatLayerPickerLogo: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        Group {
            if let raw = controller.snapshot?.branding.logoURL,
               let url = URL(string: raw) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView().tint(palette.onAccent)
                }
            } else {
                Image(systemName: "chair.lounge.fill")
                    .seatLayerPickerFont(size: 15, weight: .bold)
                    .foregroundColor(palette.onAccent)
            }
        }
        .frame(
            width: SeatLayerPickerSizeTokens.headerLogoSize,
            height: SeatLayerPickerSizeTokens.headerLogoSize
        )
        .background(palette.accent)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityHidden(true)
    }
}

public struct SeatLayerPickerHoldCountdown: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    private let expiresAt: Double

    public init(expiresAt: Double) {
        self.expiresAt = expiresAt
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(expiryDate.timeIntervalSince(context.date)))
            HStack(spacing: 5) {
                Image(systemName: "timer")
                Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                    .monospacedDigit()
            }
            .seatLayerPickerFont(size: 12, weight: .bold)
            .foregroundColor(palette.text)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(palette.background)
            .clipShape(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(style.strings.text(
                .heldFor,
                replacing: ["clock": String(format: "%d:%02d", remaining / 60, remaining % 60)]
            ))
        }
    }

    private var expiryDate: Date {
        Date(timeIntervalSince1970: expiresAt > 10_000_000_000 ? expiresAt / 1_000 : expiresAt)
    }
}
#endif
