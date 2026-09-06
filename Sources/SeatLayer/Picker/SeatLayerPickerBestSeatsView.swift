#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

// tokens.json gap: the card's own plate is Dart-local in
// `picker_best_seats.dart` — padding 8, corner 11, border = divider blended
// with 34 % accent, a diagonal wash from 5 % to 11 % accent over surface;
// title ✦ 14, title 12.5 / w800, ⓘ 15 with 6 pt padding, explanation 12 muted,
// 6 pt between rows, action ✦ 13, select padding 9 / 10 and a 16 pt chevron.
private enum SeatLayerPickerBestSeatsMetrics {
    static let plateRadius: Double = 11
    static let platePad: Double = 8
    static let plateBorderBlend: Double = 0.34
    static let washFrom: Double = 0.05
    static let washTo: Double = 0.11
    static let rowGap: Double = 6
    static let titleStarSize: Double = 14
    static let titleSize: Double = 12.5
    static let titleGap: Double = 6
    static let infoSize: Double = 15
    static let infoPad: Double = 6
    static let explanationSize: Double = 12
    static let actionStarSize: Double = 13
    static let actionPadX: Double = 10
    static let actionGap: Double = 6
    static let selectPadLeading: Double = 9
    static let selectPadTrailing: Double = 10
    static let chevronSize: Double = 16
    static let stepperKey: Double = 34
    static let stepperKeyRadius: Double = 7
    static let stepperGlyph: Double = 14
    static let star = "✦"
}

/// "Find seats together": one plate, a stepper, at most two selects and one
/// action.
public struct SeatLayerBestSeatsForm: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var quantity = 2
    @State private var categoryKey: String?
    @State private var zoneId: String?
    @State private var sessionId: String?
    @State private var busy = false
    @State private var explaining = false

    public init() {}

    public var body: some View {
        if style.options.enableBestAvailable,
           controller.supports(command: "picker.bestAvailable"),
           controller.snapshot != nil {
            let palette = resolveSeatLayerPickerPalette(
                style: style,
                colorScheme: colorScheme,
                snapshot: controller.snapshot
            )
            VStack(spacing: SeatLayerPickerBestSeatsMetrics.rowGap) {
                titleRow(palette: palette)
                if explaining {
                    Text(style.strings.text(.closestGroupChosenInstantly))
                        .seatLayerPickerFont(
                            size: SeatLayerPickerBestSeatsMetrics.explanationSize,
                            weight: .regular
                        )
                        .foregroundColor(palette.mutedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if categories.count > 1 {
                    select(
                        label: categoryLabel,
                        palette: palette,
                        menu: {
                            Button(style.strings.text(.anyTicketType)) { categoryKey = nil }
                            ForEach(categories, id: \.key) { category in
                                Button(category.label) { categoryKey = category.key }
                            }
                        }
                    )
                }
                // A venue with no zones is not asked which zone: a select whose
                // only answer is "anywhere" is a question with one answer.
                if !zones.isEmpty {
                    select(
                        label: zoneLabel,
                        palette: palette,
                        menu: {
                            Button(style.strings.text(.anyVenueZone)) { zoneId = nil }
                            ForEach(zones, id: \.id) { zone in
                                Button(zone.label) { zoneId = zone.id }
                            }
                        }
                    )
                }
                HStack(spacing: SeatLayerPickerBestSeatsMetrics.rowGap) {
                    stepper(palette: palette)
                    action(palette: palette)
                }
            }
            .padding(SeatLayerPickerBestSeatsMetrics.platePad)
            .background {
                LinearGradient(
                    colors: [
                        palette.surface.seatLayerPickerBlended(
                            with: palette.accent,
                            amount: SeatLayerPickerBestSeatsMetrics.washFrom
                        ),
                        palette.surface.seatLayerPickerBlended(
                            with: palette.accent,
                            amount: SeatLayerPickerBestSeatsMetrics.washTo
                        ),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(
                RoundedRectangle(cornerRadius: SeatLayerPickerBestSeatsMetrics.plateRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: SeatLayerPickerBestSeatsMetrics.plateRadius)
                    .stroke(
                        palette.divider.seatLayerPickerBlended(
                            with: palette.accent,
                            amount: SeatLayerPickerBestSeatsMetrics.plateBorderBlend
                        ),
                        lineWidth: 1
                    )
            }
            .animation(
                seatLayerPickerAnimation(.crossfade, reduceMotion: reduceMotion),
                value: explaining
            )
            .onAppear { adoptSession() }
            .onChange(of: controller.snapshot?.sessionId) { _ in adoptSession() }
            .accessibilityIdentifier("seatlayer-best-seats")
        }
    }

    // MARK: - Rows

    /// The title line may never wrap: it truncates.
    private func titleRow(palette: SeatLayerPickerPalette) -> some View {
        HStack(spacing: SeatLayerPickerBestSeatsMetrics.titleGap) {
            Text(SeatLayerPickerBestSeatsMetrics.star)
                .seatLayerPickerFont(
                    size: SeatLayerPickerBestSeatsMetrics.titleStarSize,
                    weight: .bold
                )
                .foregroundColor(palette.accent)
                .accessibilityHidden(true)
            Text(style.strings.text(.findSeatsTogether))
                .seatLayerPickerFont(
                    size: SeatLayerPickerBestSeatsMetrics.titleSize,
                    weight: .heavy
                )
                .foregroundColor(palette.text)
                .lineLimit(1)
                .truncationMode(.tail)
            Button {
                explaining.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .seatLayerPickerFont(
                        size: SeatLayerPickerBestSeatsMetrics.infoSize,
                        weight: .semibold
                    )
                    .foregroundColor(palette.mutedText)
                    .padding(SeatLayerPickerBestSeatsMetrics.infoPad)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(style.strings.text(.aboutBestSeats))
            .accessibilityValue(
                explaining ? style.strings.text(.closestGroupChosenInstantly) : ""
            )
            .accessibilityIdentifier("seatlayer-best-seats-about")
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func select<Menu: View>(
        label: String,
        palette: SeatLayerPickerPalette,
        @ViewBuilder menu: () -> Menu
    ) -> some View {
        SwiftUI.Menu {
            menu()
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .seatLayerPickerFont(SeatLayerPickerTypeTokens.bestSeatsSelect)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .seatLayerPickerFont(
                        size: SeatLayerPickerBestSeatsMetrics.chevronSize * 0.65,
                        weight: .semibold
                    )
                    .foregroundColor(palette.mutedText)
            }
            .foregroundColor(enabled ? palette.text : palette.mutedText)
            .padding(.leading, SeatLayerPickerBestSeatsMetrics.selectPadLeading)
            .padding(.trailing, SeatLayerPickerBestSeatsMetrics.selectPadTrailing)
            .frame(
                maxWidth: .infinity,
                minHeight: SeatLayerPickerSizeTokens.bestSeatsSelectHeight
            )
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.control))
            .overlay {
                RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.control)
                    .stroke(palette.divider, lineWidth: 1)
            }
            // The drawn select is 34 pt; the touch target around it is not.
            .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
        }
        .disabled(!enabled)
    }

    /// A tabular value between two filled keys.
    private func stepper(palette: SeatLayerPickerPalette) -> some View {
        HStack(spacing: 0) {
            stepperKey("minus", delta: -1, palette: palette)
            Text("\(quantity)")
                .seatLayerPickerFont(SeatLayerPickerTypeTokens.bestSeatsSelect)
                .monospacedDigit()
                .foregroundColor(palette.text)
                .frame(maxWidth: .infinity)
            stepperKey("plus", delta: 1, palette: palette)
        }
        .padding(.horizontal, 4)
        .frame(
            width: SeatLayerPickerSizeTokens.bestSeatsStepperWidth,
            height: SeatLayerPickerSizeTokens.minimumHitTarget
        )
        .background(palette.background)
        .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.control))
        .overlay {
            RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.control)
                .stroke(palette.divider, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func stepperKey(
        _ symbol: String,
        delta: Int,
        palette: SeatLayerPickerPalette
    ) -> some View {
        let next = quantity + delta
        return Button {
            quantity = min(maximum, max(1, next))
        } label: {
            Image(systemName: symbol)
                .seatLayerPickerFont(
                    size: SeatLayerPickerBestSeatsMetrics.stepperGlyph,
                    weight: .heavy
                )
                .foregroundColor(palette.text)
                .frame(
                    width: SeatLayerPickerBestSeatsMetrics.stepperKey,
                    height: SeatLayerPickerBestSeatsMetrics.stepperKey
                )
                .background(palette.surface)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: SeatLayerPickerBestSeatsMetrics.stepperKeyRadius
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled || next < 1 || next > maximum)
        .accessibilityLabel(
            delta < 0
                ? style.strings.text(.fewerTickets)
                : style.strings.text(.moreTickets)
        )
    }

    private func action(palette: SeatLayerPickerPalette) -> some View {
        Button {
            search()
        } label: {
            HStack(spacing: SeatLayerPickerBestSeatsMetrics.actionGap) {
                if busy {
                    ProgressView().tint(palette.onAccent)
                } else {
                    Text(SeatLayerPickerBestSeatsMetrics.star)
                        .seatLayerPickerFont(
                            size: SeatLayerPickerBestSeatsMetrics.actionStarSize,
                            weight: .bold
                        )
                }
                Text(
                    busy
                        ? style.strings.text(.findingBestSeats)
                        : style.strings.findBestSeats(quantity)
                )
                .seatLayerPickerFont(SeatLayerPickerTypeTokens.bestSeatsGo)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .foregroundColor(palette.onAccent)
            .padding(.horizontal, SeatLayerPickerBestSeatsMetrics.actionPadX)
            .frame(
                maxWidth: .infinity,
                minHeight: SeatLayerPickerSizeTokens.selectorHeight
            )
            // Busy stays accent at slight transparency: a grey button reads as
            // refused, and the search the buyer asked for is running.
            .background(palette.accent.opacity(busy ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: SeatLayerPickerRadiusTokens.control))
        }
        .buttonStyle(.plain)
        .disabled(!enabled || quantity < 1)
        .accessibilityIdentifier("seatlayer-best-seats-go")
    }

    // MARK: - State

    private var categories: [SeatLayerPickerCategory] {
        controller.snapshot?.categories.filter { !$0.notForSale } ?? []
    }

    private var zones: [SeatLayerPickerZone] {
        controller.snapshot?.bestAvailableZones ?? []
    }

    private var maximum: Int {
        max(1, controller.snapshot?.maxSelection ?? 10)
    }

    private var enabled: Bool {
        presentation.canUseBestAvailable && !busy
    }

    private var categoryLabel: String {
        categories.first { $0.key == categoryKey }?.label
            ?? style.strings.text(.anyTicketType)
    }

    private var zoneLabel: String {
        zones.first { $0.id == zoneId }?.label ?? style.strings.text(.anyVenueZone)
    }

    private func search() {
        busy = true
        runPickerAction(controller) {
            defer { busy = false }
            _ = try await controller.bestAvailable(
                quantity: quantity,
                categoryKey: categoryKey,
                zoneId: zoneId,
                ttlMs: style.options.normalizedHoldTtlMs
            )
        }
    }

    /// On a new session the zone defaults to the focused section's zone where
    /// the finder accepts it, and the ticket type to the live category filter
    /// only when that filter holds exactly one known key.
    private func adoptSession() {
        guard sessionId != controller.snapshot?.sessionId else { return }
        sessionId = controller.snapshot?.sessionId
        quantity = min(2, maximum)
        let filter = controller.snapshot?.map.categoryFilter ?? []
        categoryKey = filter.count == 1
            && categories.contains { $0.key == filter[0] }
            ? filter[0]
            : nil
        let focusedZone = controller.snapshot?.map.focusedSection?.zoneId
        zoneId = zones.contains { $0.id == focusedZone } ? focusedZone : nil
    }
}
#endif
