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
                    // The host's own name for the event first: it is known
                    // before the chart is, so the header reads as this event
                    // from the first frame rather than as a generic heading
                    // that changes under the buyer.
                    Text(eventName ?? style.strings.text(.chooseSeats))
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
            if controller.snapshot?.event.salesClosed == true {
                SeatLayerPickerSalesClosedPill()
                    .fixedSize(horizontal: true, vertical: false)
            } else if style.options.chrome.holdPill,
               let expiry = controller.snapshot?.hold.expiresAt,
               controller.snapshot?.hold.active == true {
                // Never hidden while the hold lives: a lapse ends the hold, and
                // the pill goes with it rather than being suppressed under it.
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
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
        .accessibilitySortPriority(headerReadingOrder)
    }

    /// What the header calls this event.
    ///
    /// The host's own name wins over the chart's: it is the name the buyer
    /// already saw on the page that brought them here, and it is known before
    /// the runtime has answered anything.
    private var eventName: String? {
        if let named = style.options.eventName,
           !named.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return named
        }
        return controller.snapshot?.event.name
    }

    /// §4.10 reading order: the header is read first, at 800.
    private let headerReadingOrder = 800.0
}

/// The neutral pill that says an event has stopped selling.
///
/// Neutral, never the accent: this is a fact about the event, not a warning
/// about the buyer's own time.
public struct SeatLayerPickerSalesClosedPill: View {
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
        HStack(spacing: 5) {
            Image(systemName: "lock.fill").accessibilityHidden(true)
            Text(style.strings.text(.salesClosedPill)).lineLimit(1)
        }
        .seatLayerPickerFont(size: 12, weight: .bold)
        .foregroundColor(palette.mutedText)
        .padding(.horizontal, 10)
        .frame(minHeight: pillHeight)
        .background(palette.text.opacity(neutralWash))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("seatlayer-sales-closed-pill")
    }

    // tokens.json gap: the header pill's own height and neutral ground.
    private let pillHeight = 28.0
    private let neutralWash = 0.08
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

/// The picker's only clock.
///
/// Ticks twice a second so a second never appears to skip, floors at zero, and
/// inverts to a full accent with a breathing status light for the last minute
/// — which it also counts out, second by second, to a screen reader. It stops
/// the moment a read finds the hold gone, even when the snapshot in hand still
/// describes a live one: a clock still running over released seats is the one
/// thing that can leave a buyer reassured right up to a failed checkout.
public struct SeatLayerPickerHoldCountdown: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        if controller.snapshot?.hold.active == true, controller.holdLapse == nil {
            TimelineView(.periodic(from: .now, by: tickSeconds)) { context in
                let remaining = seatLayerPickerHoldSecondsRemaining(
                    expiresAt: expiresAt,
                    now: context.date.timeIntervalSince1970
                )
                let expiring = remaining <= seatLayerPickerHoldExpiringSeconds
                let clock = seatLayerPickerHoldClock(remaining)
                HStack(spacing: 5) {
                    statusLight(expiring: expiring, palette: palette, date: context.date)
                    Text(clock).monospacedDigit()
                }
                .seatLayerPickerFont(size: 12, weight: .bold)
                .foregroundColor(expiring ? palette.onAccent : palette.text)
                .padding(.horizontal, 10)
                .frame(minHeight: pillHeight)
                .background(expiring ? palette.accent : palette.background)
                .clipShape(Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(style.strings.text(.heldFor, replacing: ["clock": clock]))
                // Announced politely on the minute, and every second of the
                // last one — an interruption a buyer cannot silence would be
                // worse than the deadline it describes.
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityIdentifier("seatlayer-hold-countdown")
            }
        }
    }

    @ViewBuilder
    private func statusLight(
        expiring: Bool,
        palette: SeatLayerPickerPalette,
        date: Date
    ) -> some View {
        if expiring {
            let breathe = !reduceMotion && Int(date.timeIntervalSince1970 * 2) % 2 == 0
            Circle()
                .fill(palette.onAccent)
                .frame(width: statusLightSize, height: statusLightSize)
                .opacity(breathe ? 1 : breathedOpacity)
                .animation(
                    seatLayerPickerAnimation(.crossfade, reduceMotion: reduceMotion),
                    value: breathe
                )
                .accessibilityHidden(true)
        } else {
            Image(systemName: "timer").accessibilityHidden(true)
        }
    }

    // tokens.json gap: the pill's height and its status light, both Dart-local
    // constants in `picker_header.dart`.
    private let tickSeconds = 0.5
    private let pillHeight = 28.0
    private let statusLightSize = 7.0
    private let breathedOpacity = 0.35
}
#endif
