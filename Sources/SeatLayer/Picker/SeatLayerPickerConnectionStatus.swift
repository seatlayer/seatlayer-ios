#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// The frames the status is placed against, read from the map's chrome.
struct SeatLayerPickerConnectionAnchors: Equatable {
    var testChip: CGRect?
    var viewMode: CGRect?
    /// The levels' pill, wherever it stands; only its width is read.
    var floorRail: CGRect?

    init(testChip: CGRect? = nil, viewMode: CGRect? = nil, floorRail: CGRect? = nil) {
        self.testChip = testChip
        self.viewMode = viewMode
        self.floorRail = floorRail
    }

    init(_ entries: [SeatLayerPickerBlockedRegionEntry]) {
        func frame(_ key: AnyHashable) -> CGRect? {
            guard let region = entries.last(where: { $0.key == key })?.region,
                  region.w > 0, region.h > 0 else { return nil }
            return CGRect(x: region.x, y: region.y, width: region.w, height: region.h)
        }
        testChip = frame(AnyHashable(SeatLayerPickerMapChromeKey.testChip))
        viewMode = frame(AnyHashable(SeatLayerPickerMapChromeKey.viewMode))
        floorRail = frame(AnyHashable(SeatLayerPickerMapChromeKey.floorRail))
    }
}

/// `You’re offline`, `Updating…` or `Back online` on the map's top line
/// (§3.4.2). Drawn only while there is something to say; takes no touches.
struct SeatLayerPickerConnectionLayer: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let anchors: SeatLayerPickerConnectionAnchors
    let fallbackTop: Double
    let wide: Bool
    var levelsOnLine = false

    @State private var natural: CGSize = .zero

    var body: some View {
        let shown = controller.connectionShown
        GeometryReader { geometry in
            let mapWidth = Double(geometry.size.width)
            ZStack(alignment: .topLeading) {
                if shown != .none {
                    let rightToLeft = layoutDirection == .rightToLeft
                    let place = seatLayerPickerConnectionPlace(
                        mapWidth: mapWidth,
                        testChip: anchors.testChip.map {
                            seatLayerPickerLeadingFrame($0, mapWidth: mapWidth, rightToLeft: rightToLeft)
                        },
                        viewMode: anchors.viewMode.map {
                            seatLayerPickerLeadingFrame($0, mapWidth: mapWidth, rightToLeft: rightToLeft)
                        },
                        fallbackTop: fallbackTop,
                        wide: wide,
                        naturalWidth: Double(natural.width),
                        height: max(SeatLayerPickerSizeTokens.connectionStatusHeight, Double(natural.height)),
                        levelsOnLine: levelsOnLine
                    )
                    SeatLayerPickerConnectionStatus(shown: shown, oneLineEach: !place.below)
                        .frame(width: place.width, alignment: .leading)
                        .padding(.leading, place.x)
                        .padding(.top, place.y)
                        .transition(reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .offset(y: SeatLayerPickerSizeTokens.connectionStatusRise)))
                }
                // The words' own width, one line each, to decide whether they
                // fit beside the chip.
                SeatLayerPickerConnectionStatus(shown: shown == .none ? .offline : shown, oneLineEach: true, announces: false)
                    .fixedSize()
                    .hidden()
                    .background(GeometryReader { measured in
                        Color.clear.preference(key: SeatLayerPickerConnectionSizeKey.self, value: measured.size)
                    })
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onPreferenceChange(SeatLayerPickerConnectionSizeKey.self) { natural = $0 }
        .animation(
            reduceMotion
                ? .easeInOut(duration: Double(SeatLayerPickerMotionDurationTokens.crossfade) / 1000)
                : .easeOut(duration: Double(SeatLayerPickerMotionDurationTokens.connectionIn) / 1000),
            value: shown
        )
        .allowsHitTesting(false)
    }
}

private struct SeatLayerPickerConnectionSizeKey: PreferenceKey {
    static var defaultValue: CGSize { .zero }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// The status card itself.
struct SeatLayerPickerConnectionStatus: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    let shown: SeatLayerConnectionShown
    let oneLineEach: Bool
    var announces = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            card(held: seatLayerPickerConnectionSaysStillHeld(
                shown: shown,
                hold: controller.snapshot?.hold,
                now: context.date.timeIntervalSince1970
            ))
        }
    }

    private func card(held: Bool) -> some View {
        let palette = seatLayerPickerMapChromePalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        let title = style.strings.text(titleKey)
        let second = held ? style.strings.text(.stillHeld) : nil
        let radius = held
            ? SeatLayerPickerRadiusTokens.connectionStatusTwoLines
            : SeatLayerPickerSizeTokens.connectionStatusHeight / 2
        return HStack(spacing: SeatLayerPickerSizeTokens.connectionStatusSignGap) {
            SeatLayerPickerConnectionSign(shown: shown, palette: palette)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .seatLayerPickerFont(size: SeatLayerPickerSizeTokens.connectionStatusTitleFont, weight: .semibold)
                    .foregroundColor(palette.text)
                    .lineLimit(oneLineEach ? 1 : nil)
                    .fixedSize(horizontal: false, vertical: true)
                if let second {
                    Text(second)
                        .seatLayerPickerFont(size: SeatLayerPickerSizeTokens.connectionStatusLineFont)
                        .foregroundColor(palette.mutedText)
                        .lineLimit(oneLineEach ? 1 : nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.leading, SeatLayerPickerSizeTokens.connectionStatusPadStart)
        .padding(.trailing, SeatLayerPickerSizeTokens.connectionStatusPadEnd)
        .padding(.vertical, 6)
        .frame(
            minHeight: held
                ? SeatLayerPickerSizeTokens.connectionStatusTwoLineHeight
                : SeatLayerPickerSizeTokens.connectionStatusHeight,
            alignment: .leading
        )
        .background(palette.dark ? palette.surface : palette.background)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(palette.divider, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, second].compactMap { $0 }.joined(separator: " "))
        .onAppear { announce(title: title, second: second) }
        .onChange(of: shown) { _ in announce(title: style.strings.text(titleKey), second: second) }
    }

    private var titleKey: SeatLayerPickerStringKey {
        switch shown {
        case .offline, .none: return .offline
        case .updating: return .updating
        case .back: return .backOnline
        }
    }

    /// `You’re offline` (with its second line) and `Back online` are read once;
    /// `Updating…` is not.
    private func announce(title: String, second: String?) {
        guard announces, shown == .offline || shown == .back else { return }
        guard SeatLayerPickerConnectionAnnouncements.shared.take(shown, for: controller) else { return }
        UIAccessibility.post(
            notification: .announcement,
            argument: [title, second].compactMap { $0 }.joined(separator: " ")
        )
    }
}

/// Each change is read aloud once per picker, though the card that says it
/// may be drawn more than once (the measuring copy, a redraw).
@MainActor
final class SeatLayerPickerConnectionAnnouncements {
    static let shared = SeatLayerPickerConnectionAnnouncements()
    private let last = NSMapTable<SeatLayerPickerController, Box>.weakToStrongObjects()

    private final class Box {
        var shown: SeatLayerConnectionShown
        init(_ shown: SeatLayerConnectionShown) { self.shown = shown }
    }

    /// True the first time `shown` is to be read for `controller` since it
    /// last changed.
    func take(_ shown: SeatLayerConnectionShown, for controller: SeatLayerPickerController) -> Bool {
        if let box = last.object(forKey: controller) {
            guard box.shown != shown else { return false }
            box.shown = shown
        } else {
            last.setObject(Box(shown), forKey: controller)
        }
        return true
    }
}

/// A crossed-out wifi sign, a turning ring, or a tick.
struct SeatLayerPickerConnectionSign: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var size = SeatLayerPickerSizeTokens.connectionStatusSign
    let shown: SeatLayerConnectionShown
    let palette: SeatLayerPickerPalette
    var diameter: Double?

    @State private var turning = false

    var body: some View {
        let side = diameter ?? min(size, SeatLayerPickerSizeTokens.connectionStatusSign * 1.6)
        Group {
            switch shown {
            case .offline, .none:
                Image(systemName: "wifi.slash")
                    .resizable()
                    .scaledToFit()
                    .font(.system(size: side, weight: .semibold))
                    .foregroundColor(seatLayerPickerConnectionColor(lost: true, dark: palette.dark))
            case .updating:
                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(palette.mutedText, style: StrokeStyle(lineWidth: max(1.5, side / 8), lineCap: .round))
                    .padding(side / 10)
                    .rotationEffect(.degrees(turning ? 360 : 0))
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(
                            .linear(duration: Double(SeatLayerPickerMotionDurationTokens.connectionRing) / 1000)
                                .repeatForever(autoreverses: false)
                        ) { turning = true }
                    }
            case .back:
                Image(systemName: "checkmark")
                    .resizable()
                    .scaledToFit()
                    .font(.system(size: side, weight: .bold))
                    .padding(side / 10)
                    .foregroundColor(seatLayerPickerConnectionColor(lost: false, dark: palette.dark))
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

/// `color.*.connectionLost` or `color.*.connectionBack`: never a club's accent.
func seatLayerPickerConnectionColor(lost: Bool, dark: Bool) -> Color {
    if dark {
        return pickerColor(lost ? SeatLayerPickerDarkColorTokens.connectionLost : SeatLayerPickerDarkColorTokens.connectionBack)
    }
    return pickerColor(lost ? SeatLayerPickerLightColorTokens.connectionLost : SeatLayerPickerLightColorTokens.connectionBack)
}
#endif
