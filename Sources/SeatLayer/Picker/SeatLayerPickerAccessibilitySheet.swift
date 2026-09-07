#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// The accessibility and view sheet.
///
/// A switch IS the action: every row applies as it is flipped and the sheet
/// stays open, because a buyer with more than one need flips more than one
/// row. The staged `Apply filters` form this replaced asked twice for one
/// decision, and left a buyer who dragged the sheet away — the gesture that
/// closes every other sheet — with a map that had ignored everything they had
/// just done.
///
/// The sheet takes the height its own content asks for, bounded to a fraction
/// of the screen; the provision list scrolls inside that bound, so the map
/// being filtered stays visible however many provisions a chart carries.
public struct SeatLayerPickerAccessibilityFilters: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.seatLayerPickerBlockedRegionsReporter) private var regions
    @State private var openNote: String?
    /// The height the sheet's own content asks for, summed from its blocks as
    /// they lay out. Zero until the first pass has measured them.
    @State private var measuredContent: Double = 0

    public init() {}

    public var body: some View {
        let availability = SeatLayerPickerAccessibility.availability(
            snapshot: controller.snapshot,
            bundle: controller.bundleInfo
        )
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        if availability.any, controller.snapshot?.map.buyerView == "map" {
            content(availability: availability, palette: palette)
                .onPreferenceChange(SeatLayerAccessSheetBlockHeight.self) { total in
                    measuredContent = total + sheetPadBottom
                }
                .background(palette.surface)
                .modifier(SeatLayerPickerBoundedSheet(height: sheetHeight))
                .accessibilityIdentifier("seatlayer-access-sheet")
                .onAppear { guardMapWhileUp(true) }
                .onDisappear { guardMapWhileUp(false) }
        }
    }

    @ViewBuilder
    private func content(
        availability: SeatLayerPickerAccessibilityAvailability,
        palette: SeatLayerPickerPalette
    ) -> some View {
        let needs = SeatLayerPickerAccessibility.needs(
            snapshot: controller.snapshot,
            availability: availability
        )
        VStack(alignment: .leading, spacing: 0) {
            grabber(palette: palette)
                .measureSeatLayerAccessSheetBlock()
            Text(style.strings.text(.accessibilityTitle))
                .seatLayerPickerFont(
                    size: titleFontSize,
                    weight: .seatLayerPickerWeight(titleWeight)
                )
                .foregroundColor(palette.text)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, sheetPadX)
                .padding(.bottom, titleGap)
                .measureSeatLayerAccessSheetBlock()
            // The rows are the only part that scrolls: the title and the VIEW
            // group stay put, so a chart carrying the whole vocabulary still
            // shows the buyer what the sheet is and where the display
            // switches are. Sized to the rows until the bound is reached,
            // which is what keeps a two-row sheet two rows tall.
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(needs.enumerated()), id: \.element.key) { index, need in
                        needRow(
                            need,
                            palette: palette,
                            last: index == needs.count - 1
                        )
                        // The sheet's provisions land one after the next, the
                        // way the cart's cards do: a vocabulary that appears
                        // whole reads as a page redraw.
                        .seatLayerPickerArrivalPop(index: index)
                    }
                }
                .padding(.horizontal, sheetPadX)
                .measureSeatLayerAccessSheetBlock()
            }
            viewGroup(availability: availability, palette: palette)
                .padding(.horizontal, sheetPadX)
                .measureSeatLayerAccessSheetBlock()
        }
        .padding(.bottom, sheetPadBottom)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The drag grabber, drawn rather than asked of the platform so iOS 15 —
    /// which has no `presentationDragIndicator` — carries the same mark, and
    /// so the sheet reads as draggable before the buyer tries it.
    private func grabber(palette: SeatLayerPickerPalette) -> some View {
        Capsule()
            .fill(palette.mutedText.opacity(grabberOpacity))
            .frame(
                width: SeatLayerPickerSizeTokens.sheetGrabberWidth,
                height: SeatLayerPickerSizeTokens.sheetGrabberHeight
            )
            .frame(
                maxWidth: .infinity,
                minHeight: SeatLayerPickerSizeTokens.sheetHandleHeight,
                alignment: .center
            )
            .accessibilityHidden(true)
    }

    // MARK: - Provision rows

    @ViewBuilder
    private func needRow(
        _ need: SeatLayerPickerAccessNeed,
        palette: SeatLayerPickerPalette,
        last: Bool
    ) -> some View {
        let label = style.strings.accessNeed(need.key)
        let on = controller.snapshot?.map.accessibilityFilter.contains(need.key) == true
        // An uncounted provision stays live: only a counted zero is sold out.
        let soldOut = need.count == 0
        let note = note(for: need)
        VStack(alignment: .leading, spacing: 0) {
            row(
                glyph: need.key,
                label: label,
                note: note,
                count: countCell(need, label: label, palette: palette),
                on: on,
                enabled: !soldOut,
                palette: palette,
                divider: !last,
                identifier: "seatlayer-access-need-\(need.key)"
            ) {
                toggleNeed(need.key, on: !on)
            }
            if let note, openNote == need.key {
                Text(note)
                    .seatLayerPickerFont(size: SeatLayerPickerSizeTokens.accessRowNoteFontSize)
                    .foregroundColor(palette.mutedText)
                    .padding(.leading, noteIndent)
                    .padding(.bottom, SeatLayerPickerSizeTokens.accessRowPaddingY)
                    .accessibilityHidden(true)
            }
        }
    }

    /// The count column: a jump chip where the walk is offered, a plain figure
    /// otherwise. The figure does not move or change size when it becomes
    /// pressable — only its ground arrives.
    @ViewBuilder
    private func countCell(
        _ need: SeatLayerPickerAccessNeed,
        label: String,
        palette: SeatLayerPickerPalette
    ) -> some View {
        // An uncounted provision prints no figure at all rather than a zero
        // it was never told.
        let text = need.count.map { free in
            free == 0
                ? zeroCount
                : style.strings.text(.accessFreeCount, replacing: ["count": String(free)])
        } ?? ""
        if controller.supportsAccessibilityFocus, (need.count ?? 0) > 0 {
            Button { jump(to: need.key) } label: {
                Text(text)
                    .seatLayerPickerFont(
                        size: SeatLayerPickerSizeTokens.accessStepFontSize,
                        weight: .heavy
                    )
                    .monospacedDigit()
                    .foregroundColor(palette.text)
                    .lineLimit(1)
                    .padding(.horizontal, SeatLayerPickerSizeTokens.accessStepPaddingX)
                    .frame(minHeight: SeatLayerPickerSizeTokens.accessStepHeight)
                    .background(palette.text.opacity(jumpChipGround))
                    .clipShape(Capsule())
                    .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(label), \(text), \(style.strings.text(.accessJumpFirstSection))")
        } else {
            Text(text)
                .seatLayerPickerFont(size: SeatLayerPickerSizeTokens.accessStepFontSize)
                .monospacedDigit()
                .foregroundColor(palette.mutedText)
                .lineLimit(1)
        }
    }

    // MARK: - View group

    @ViewBuilder
    private func viewGroup(
        availability: SeatLayerPickerAccessibilityAvailability,
        palette: SeatLayerPickerPalette
    ) -> some View {
        if availability.limitedView || availability.colorblind {
            // One container, so the group measures and lays out as one block.
            VStack(alignment: .leading, spacing: 0) {
                Text(style.strings.text(.viewGroupTitle))
                    .seatLayerPickerFont(size: viewHeadingFontSize, weight: .bold)
                    .modifier(SeatLayerPickerLetterSpacing(amount: viewHeadingTracking))
                    .foregroundColor(palette.mutedText)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.leading, SeatLayerPickerSizeTokens.accessRowPaddingX)
                    .padding(.top, viewHeadingPadTop)
                    .padding(.trailing, SeatLayerPickerSizeTokens.accessRowPaddingX)
                    .padding(.bottom, viewHeadingPadBottom)
                if availability.limitedView {
                    row(
                        glyph: "restrictedView",
                        label: style.strings.text(.hideLimitedView),
                        note: nil,
                        count: EmptyView(),
                        on: controller.snapshot?.map.hideLimitedView == true,
                        enabled: true,
                        palette: palette,
                        divider: availability.colorblind,
                        identifier: "seatlayer-access-limited-view"
                    ) {
                        let next = !(controller.snapshot?.map.hideLimitedView == true)
                        runPickerAction(controller) {
                            _ = try await controller.setLimitedViewFilter(next)
                        }
                    }
                }
                if availability.colorblind {
                    row(
                        glyph: "contrast",
                        label: style.strings.text(.colorblindSafe),
                        note: nil,
                        count: EmptyView(),
                        on: controller.snapshot?.map.colorblindSafe == true,
                        enabled: true,
                        palette: palette,
                        divider: false,
                        identifier: "seatlayer-access-colorblind"
                    ) {
                        let next = !(controller.snapshot?.map.colorblindSafe == true)
                        runPickerAction(controller) {
                            _ = try await controller.setColorblindSafe(next)
                        }
                    }
                }
            }
        }
    }

    // MARK: - One row

    /// icon · gap · label (+ ⓘ) · count column · gap · switch, at one fixed
    /// height for every row on the sheet. The whole line is the control, so
    /// the buyer aims at the words rather than at the toggle.
    @ViewBuilder
    private func row<Count: View>(
        glyph: String,
        label: String,
        note: String?,
        count: Count,
        on: Bool,
        enabled: Bool,
        palette: SeatLayerPickerPalette,
        divider: Bool,
        identifier: String,
        toggle: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            SeatLayerPickerAccessRowGlyph(key: glyph, color: palette.mutedText)
                .frame(
                    width: SeatLayerPickerSizeTokens.accessRowIconCell,
                    height: SeatLayerPickerSizeTokens.accessRowIconCell
                )
                .accessibilityHidden(true)
            Spacer().frame(width: SeatLayerPickerSizeTokens.accessRowGap)
            // The label and its ⓘ share ONE cell: the ⓘ explains the words
            // beside it, not the switch at the far end, so it sits against
            // the label rather than out at the count column.
            HStack(spacing: 0) {
                Text(label)
                    .seatLayerPickerFont(
                        size: SeatLayerPickerSizeTokens.accessRowLabelFontSize,
                        weight: .semibold
                    )
                    .foregroundColor(palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let note {
                    Button {
                        openNote = openNote == glyph ? nil : glyph
                    } label: {
                        Image(systemName: "info.circle")
                            .seatLayerPickerFont(
                                size: SeatLayerPickerSizeTokens.accessNoteIconSize
                            )
                            .foregroundColor(
                                openNote == glyph ? palette.accent : palette.mutedText
                            )
                            .frame(
                                width: noteColumn,
                                height: SeatLayerPickerSizeTokens.minimumHitTarget
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(note)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            count
                .frame(width: countColumn, alignment: .trailing)
            Spacer().frame(width: SeatLayerPickerSizeTokens.accessRowSwitchGap)
            SeatLayerPickerAccessSwitch(on: on, palette: palette)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, SeatLayerPickerSizeTokens.accessRowPaddingX)
        .frame(height: rowHeight)
        .opacity(enabled ? 1 : disabledRowOpacity)
        .contentShape(Rectangle())
        .onTapGesture { if enabled { toggle() } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue(on: on))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier)
        .overlay(alignment: .bottom) {
            if divider {
                Rectangle()
                    .fill(palette.divider.opacity(rowDividerOpacity))
                    .frame(height: 1)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func accessibilityValue(on: Bool) -> String {
        on ? style.strings.text(.select) : ""
    }

    // MARK: - Behaviour

    /// Sends the whole union on every flip, and reads availability at the
    /// moment of the flip rather than capturing it when the sheet opened.
    private func toggleNeed(_ key: String, on: Bool) {
        var union = controller.snapshot?.map.accessibilityFilter ?? []
        if on {
            if !union.contains(key) { union.append(key) }
        } else {
            union.removeAll { $0 == key }
        }
        runPickerAction(controller) {
            guard SeatLayerPickerAccessibility.availability(
                snapshot: controller.snapshot,
                bundle: controller.bundleInfo
            ).accessibility else { return }
            _ = try await controller.setAccessibilityFilter(union)
        }
    }

    /// The count as a jump: turn the provision on if it was off, apply, close
    /// the sheet — the one control on it that does — and take the first step.
    private func jump(to key: String) {
        var union = controller.snapshot?.map.accessibilityFilter ?? []
        if !union.contains(key) { union.append(key) }
        dismiss()
        runPickerAction(controller) {
            guard SeatLayerPickerAccessibility.availability(
                snapshot: controller.snapshot,
                bundle: controller.bundleInfo
            ).accessibility else { return }
            _ = try await controller.setAccessibilityFilter(union)
            guard controller.supportsAccessibilityFocus else { return }
            _ = try await controller.focusNextAccessibleSection(types: union)
        }
    }

    /// A modal over the page guards the whole map while it is up.
    ///
    /// Through the registry rather than the command: this sheet is one of
    /// several surfaces that may be guarding at once, and sending the runtime
    /// an empty list on close would drop every other one's rectangle with it.
    private func guardMapWhileUp(_ blocked: Bool) {
        guard let regions else { return }
        let screen = UIScreen.main.bounds
        regions.cover(
            "accessSheet",
            blocked
                ? SeatLayerBlockedRegion(
                    x: 0,
                    y: 0,
                    w: Double(screen.width),
                    h: Double(screen.height)
                )
                : nil
        )
    }

    private func note(for need: SeatLayerPickerAccessNeed) -> String? {
        guard need.key == "wheelchair",
              controller.snapshot?.map.accessNeeds.contains(where: {
                  $0.key == "companion"
              }) == true else { return nil }
        return style.strings.text(.companionSeatsNote)
    }

    /// How tall the sheet may grow before its rows start scrolling.
    private var sheetBound: Double {
        seatLayerAccessSheetHeight(screenHeight: Double(UIScreen.main.bounds.height))
    }

    /// The sheet takes the room its own content asks for, up to the bound —
    /// two provisions and the VIEW group is a short sheet, not a bound-tall
    /// one with a hole in the middle. Once the bound is reached the rows keep
    /// their inner scroll and the map stays visible behind the rest.
    private var sheetHeight: Double {
        guard measuredContent > 0 else { return sheetBound }
        return min(measuredContent, sheetBound)
    }

    // tokens.json gap: the sheet's fixed row height, its count and note
    // columns, the zero figure and the sheet's own paddings are Dart-local
    // constants in `picker_accessibility.dart` rather than tokens. Lift them
    // into `Design/tokens.json` and regenerate; every value below is the
    // Flutter number, not a new one.
    private let rowHeight = 50.0
    private let countColumn = 68.0
    private let noteColumn = 36.0
    private let zeroCount = "0"
    private let rowDividerOpacity = 0.35
    private let disabledRowOpacity = 0.58
    private let jumpChipGround = 0.06
    private let sheetPadX = 20.0
    private let sheetPadBottom = 20.0
    private let titleGap = 12.0
    // tokens.json gap: the sheet's own title has no role in the type ramp.
    // Flutter draws it at Material's `titleLarge`, which is 22 pt; the ramp's
    // nearest role is `headerTitle` at 16, which is the picker's own header
    // and a rung too quiet for the surface a buyer opened deliberately. 22 at
    // the ramp's heading weight until a `sheetTitle` role exists.
    private let titleFontSize = 22.0
    private let titleWeight = 700.0
    // tokens.json gap: the grabber's ink. Flutter takes Material's own drag
    // handle, which is the muted ink at this weight; the bar's width, height
    // and the block it centres in are all tokens.
    private let grabberOpacity = 0.4
    private let viewHeadingFontSize = 11.0
    private let viewHeadingTracking = 0.6
    private let viewHeadingPadTop = 18.0
    private let viewHeadingPadBottom = 4.0

    private var noteIndent: Double {
        SeatLayerPickerSizeTokens.accessRowPaddingX
            + SeatLayerPickerSizeTokens.accessRowIconCell
            + SeatLayerPickerSizeTokens.accessRowGap
    }
}

/// The height of one of the sheet's own blocks, summed over all of them.
///
/// The rows are measured INSIDE their scroll view, where they lay out at the
/// height they want rather than the height they are given — which is what
/// lets the sheet ask for its content and fall back to scrolling only once
/// the bound is reached.
private struct SeatLayerAccessSheetBlockHeight: PreferenceKey {
    static let defaultValue: Double = 0

    static func reduce(value: inout Double, nextValue: () -> Double) {
        value += nextValue()
    }
}

private extension View {
    func measureSeatLayerAccessSheetBlock() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SeatLayerAccessSheetBlockHeight.self,
                    value: Double(proxy.size.height)
                )
            }
        )
    }
}

/// Letter-spacing for the one heading that carries it.
struct SeatLayerPickerLetterSpacing: ViewModifier {
    let amount: Double

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.kerning(amount)
        } else {
            content
        }
    }
}

/// Holds the sheet to the height it asked for, and tells the platform the
/// same number where it can be told.
///
/// On iOS 15 the system sheet has no detent API and takes the height it takes;
/// the row list still scrolls inside its own bound, so nothing is lost but the
/// map staying visible behind it.
private struct SeatLayerPickerBoundedSheet: ViewModifier {
    let height: Double

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            // The sheet draws its own grabber, so the platform's is off:
            // two bars stacked is how a sheet says it was assembled twice.
            content
                .frame(maxHeight: height, alignment: .top)
                .presentationDetents([.height(height)])
                .presentationDragIndicator(.hidden)
        } else {
            content.frame(maxHeight: height, alignment: .top)
        }
    }
}

/// The sheet's own switch: a drawn track and knob, not the platform's, so the
/// row owns the semantics and one contrast decision covers every row.
struct SeatLayerPickerAccessSwitch: View {
    let on: Bool
    let palette: SeatLayerPickerPalette

    var body: some View {
        Capsule()
            .fill(on ? palette.accent : palette.mutedText.opacity(offTrackOpacity))
            .frame(
                width: SeatLayerPickerSizeTokens.accessSwitchWidth,
                height: SeatLayerPickerSizeTokens.accessSwitchHeight
            )
            .overlay(alignment: on ? .trailing : .leading) {
                Circle()
                    .fill(palette.surface)
                    .frame(
                        width: SeatLayerPickerSizeTokens.accessSwitchKnob,
                        height: SeatLayerPickerSizeTokens.accessSwitchKnob
                    )
                    .padding(.horizontal, knobInset)
            }
    }

    // tokens.json gap: the knob's inset inside the track.
    private let knobInset = 2.0
    private let offTrackOpacity = 0.32
}

/// One drawing per row, chosen by the runtime's own key.
///
/// INTERIM: the shared per-attribute glyph set (spec §3.8.9, Flutter
/// `picker_seat_icons.dart`) is not on iOS yet, so each key resolves to its
/// closest system glyph here rather than to the authored artwork. That keeps
/// twelve provisions from all wearing one wheelchair, but it is not the shared
/// set: replace the body of this view with the transcribed paths as soon as
/// the seat card lands them.
/// One accommodation's drawing, on the sheet's own row.
///
/// The same authored set the seat card and the map legend draw, so a buyer who
/// learns a mark on the card recognises it on this sheet — a platform symbol
/// set would have made the two surfaces disagree about what a wheelchair space
/// looks like. A key with no drawing renders nothing rather than a placeholder
/// circle: the row already prints the accommodation in words.
struct SeatLayerPickerAccessRowGlyph: View {
    let key: String
    let color: Color

    var body: some View {
        SeatLayerPickerSeatIcon(
            iconKey: Self.glyphKey(for: key),
            color: color,
            size: SeatLayerPickerSizeTokens.accessRowIconSize
        )
    }

    /// The runtime writes accommodation keys in several shapes; the drawings
    /// are filed under one.
    static func glyphKey(for key: String) -> String {
        let normalized = key.lowercased().replacingOccurrences(of: "_", with: "-")
        switch normalized {
        case "restrictedview", "restricted-view": return "restrictedView"
        case "obstructedview", "obstructed-view": return "obstructedView"
        default: return normalized
        }
    }
}
#endif
