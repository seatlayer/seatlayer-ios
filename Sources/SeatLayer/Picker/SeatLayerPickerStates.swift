#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

// The buyer-facing states: access, sales closed, sold out and booked. Every
// one of them is a designed state rather than a set of disabled controls.

/// A veiled overlay over the whole picker when the buyer's access will not do.
///
/// Every reason has exactly one action, and the button does its work **in
/// place first**: `refresh` re-bootstraps the session and re-reads the chart
/// through the live runtime, so the map never goes away and the buyer keeps
/// their camera and their picks. Only if that fails does it fall back to a
/// remount — and only where no host is listening, because a host that passed
/// `onAccessUnavailable` may be running its own recovery that a remount would
/// destroy.
public struct SeatLayerPickerAccessPanel: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var reason: SeatLayerPickerAccessPanelReason?
    @State private var busy = false
    @State private var spin = false
    private let hostIsListening: Bool
    private let refresh: (@MainActor () async throws -> Bool)?
    private let remount: (@MainActor () -> Void)?

    public init(
        hostIsListening: Bool = false,
        refresh: (@MainActor () async throws -> Bool)? = nil,
        remount: (@MainActor () -> Void)? = nil
    ) {
        self.hostIsListening = hostIsListening
        self.refresh = refresh
        self.remount = remount
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        ZStack {
            if let reason {
                palette.background
                    .opacity(SeatLayerPickerTransparency.scrimOpacity(
                        requested: veilOpacity,
                        reduceTransparency: reduceTransparency
                    ))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
                card(reason, palette: palette)
            }
        }
        .onReceive(controller.accessUnavailability) { event in
            reason = SeatLayerPickerAccessPanelReason(event)
        }
        .onReceive(controller.accessExpirations) { event in
            if let next = SeatLayerPickerAccessPanelReason(event) { reason = next }
        }
    }

    @ViewBuilder
    private func card(
        _ reason: SeatLayerPickerAccessPanelReason,
        palette: SeatLayerPickerPalette
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: busy ? "arrow.triangle.2.circlepath" : "lock.circle")
                .seatLayerPickerFont(size: badgeGlyphSize, weight: .bold)
                .foregroundColor(palette.accent)
                .frame(width: badgeSize, height: badgeSize)
                .background(palette.accent.opacity(badgeTint))
                .clipShape(Circle())
                .rotationEffect(.degrees(spin ? 360 : 0))
                .accessibilityHidden(true)
            Text(style.strings.text(reason.title))
                .seatLayerPickerFont(size: 17, weight: .heavy)
                .foregroundColor(palette.text)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(style.strings.text(reason.body))
                .seatLayerPickerFont(size: 13, weight: .medium)
                .foregroundColor(palette.mutedText)
                .multilineTextAlignment(.center)
            Button { act(reason) } label: {
                Text(style.strings.text(reason.action))
                    .seatLayerPickerFont(size: 15, weight: .heavy)
                    .foregroundColor(palette.onAccent)
                    .padding(.horizontal, 20)
                    .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                    .background(palette.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
        .padding(cardPadding)
        .frame(maxWidth: cardMaxWidth)
        .background(palette.surface)
        .overlay {
            RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card)
                .stroke(palette.divider, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card))
        .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: shadowOffset)
        .padding(20)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("seatlayer-access-panel")
    }

    private func act(_ reason: SeatLayerPickerAccessPanelReason) {
        guard !busy else { return }
        busy = true
        if !reduceMotion {
            withAnimation(.linear(duration: spinSeconds).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
        Task { @MainActor in
            defer {
                busy = false
                spin = false
            }
            if reason.refreshesInPlace, let refresh {
                if (try? await refresh()) == true {
                    self.reason = nil
                    return
                }
                // The refresh failed. A host that was told already may be
                // running its own recovery; remounting under it destroys that.
                guard !hostIsListening else { return }
            }
            remount?()
            self.reason = nil
        }
    }

    private let veilOpacity = 0.88
    // tokens.json gap: the panel's badge, card width and shadow are Dart-local
    // constants in `picker_states.dart`.
    private let badgeSize = 56.0
    private let badgeGlyphSize = 26.0
    private let badgeTint = 0.14
    private let cardPadding = 22.0
    private let cardMaxWidth = 360.0
    private let shadowOpacity = 0.24
    private let shadowRadius = 24.0
    private let shadowOffset = 10.0
    private let spinSeconds = 0.9
}

/// The tray statement that says sales have ended, in the buyer's own words.
public struct SeatLayerPickerSalesClosedStatement: View {
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
        VStack(alignment: .leading, spacing: 6) {
            Text(style.strings.text(.salesClosed))
                .seatLayerPickerFont(size: 14, weight: .heavy)
                .foregroundColor(palette.text)
            Text(style.strings.text(.salesClosedCopy))
                .seatLayerPickerFont(size: 12, weight: .medium)
                .foregroundColor(palette.mutedText)
            if let date = eventDateLine {
                Text(date)
                    .seatLayerPickerFont(size: 12, weight: .semibold)
                    .foregroundColor(palette.mutedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        // Neutral throughout, never the accent.
        .background(palette.text.opacity(neutralWash))
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.card))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("seatlayer-sales-closed")
    }

    /// The event's own date line, in the buyer's locale and the event's zone.
    private var eventDateLine: String? {
        guard let event = controller.snapshot?.event, let startsAt = event.startsAt else {
            return nil
        }
        let seconds = startsAt > 10_000_000_000 ? startsAt / 1_000 : startsAt
        let formatter = DateFormatter()
        formatter.locale = style.strings.resolvedLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        if let timezone = event.timezone, let zone = TimeZone(identifier: timezone) {
            formatter.timeZone = zone
        }
        return formatter.string(from: Date(timeIntervalSince1970: seconds))
    }

    // tokens.json gap: the neutral text tint the statement sits on.
    private let neutralWash = 0.06
}

/// The veil over a map with nothing left on it.
///
/// Informational only — there is no waitlist — and it clears live, because the
/// predicate behind it is read from every snapshot.
public struct SeatLayerPickerSoldOutOverlay: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        ZStack {
            palette.background
                .opacity(SeatLayerPickerTransparency.scrimOpacity(
                    requested: veilOpacity,
                    reduceTransparency: reduceTransparency
                ))
                .ignoresSafeArea()
            VStack(spacing: 8) {
                Text(eyebrow.uppercased(with: style.strings.resolvedLocale))
                    .seatLayerPickerFont(size: eyebrowFontSize, weight: .bold)
                    .modifier(SeatLayerPickerLetterSpacing(amount: eyebrowTracking))
                    .foregroundColor(palette.mutedText)
                    .lineLimit(1)
                Text(style.strings.text(.soldOutTitle))
                    .seatLayerPickerFont(size: titleFontSize, weight: .heavy)
                    .foregroundColor(palette.text)
                Text(style.strings.text(.soldOutCopy))
                    .seatLayerPickerFont(size: 13, weight: .medium)
                    .foregroundColor(palette.mutedText)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("seatlayer-sold-out")
    }

    private var eyebrow: String {
        let brand = controller.snapshot?.branding.brandName
        let event = controller.snapshot?.event.name
        for candidate in [brand, event] {
            if let candidate,
               !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return candidate
            }
        }
        return style.strings.text(.soldOutEyebrow)
    }

    private let veilOpacity = 0.9
    // tokens.json gap: the sold-out eyebrow and title sizes.
    private let eyebrowFontSize = 11.0
    private let eyebrowTracking = 1.4
    private let titleFontSize = 30.0
}

/// "You're all set" — shown only once a hand-off has settled to a sale.
public struct SeatLayerPickerBookedOverlay: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false
    @AccessibilityFocusState private var backFocused: Bool
    private let handoff: SeatLayerPickerCheckoutHandoff
    private let onBackToMap: () -> Void

    public init(
        handoff: SeatLayerPickerCheckoutHandoff,
        onBackToMap: @escaping () -> Void
    ) {
        self.handoff = handoff
        self.onBackToMap = onBackToMap
    }

    public var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        VStack(spacing: 14) {
            Image(systemName: "checkmark")
                .seatLayerPickerFont(size: badgeGlyphSize, weight: .heavy)
                .foregroundColor(palette.onAccent)
                .frame(width: badgeSize, height: badgeSize)
                .background(palette.accent)
                .clipShape(Circle())
                .scaleEffect(popped ? 1 : 0.72)
                .accessibilityHidden(true)
            Text(style.strings.text(.allSetTitle))
                .seatLayerPickerFont(size: 24, weight: .heavy)
                .foregroundColor(palette.text)
                .accessibilityAddTraits(.isHeader)
            Text("\(style.strings.ticketCount(handoff.lineItems.count)) \(style.strings.text(.confirmedAndOnWay))")
                .seatLayerPickerFont(size: 13, weight: .medium)
                .foregroundColor(palette.mutedText)
                .multilineTextAlignment(.center)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(handoff.lineItems, id: \.label) { line in
                        Text(line.label)
                            .seatLayerPickerFont(size: 12, weight: .bold)
                            .foregroundColor(palette.text)
                            .padding(.horizontal, 12)
                            .frame(minHeight: pillHeight)
                            .background(palette.surface)
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxHeight: pillListMaxHeight)
            Button(action: onBackToMap) {
                Text(style.strings.text(.backToMap))
                    .seatLayerPickerFont(size: 15, weight: .heavy)
                    .foregroundColor(palette.onAccent)
                    .padding(.horizontal, 22)
                    .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                    .background(palette.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityFocused($backFocused)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else {
                popped = true
                backFocused = true
                return
            }
            withAnimation(seatLayerPickerAnimation(.pop, reduceMotion: false)) { popped = true }
            // Focused on the next frame, so the badge's arrival does not steal
            // the announcement from the way out.
            Task { @MainActor in backFocused = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("seatlayer-booked")
    }

    // tokens.json gap: the booked badge and seat-pill metrics.
    private let badgeSize = 72.0
    private let badgeGlyphSize = 32.0
    private let pillHeight = 30.0
    private let pillListMaxHeight = 180.0
}
#endif
