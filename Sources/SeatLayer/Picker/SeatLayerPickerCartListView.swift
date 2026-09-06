#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct SeatLayerPickerCartList: View {
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(denseRuns, id: \.id) { run in
                        if run.isGroup {
                            SeatLayerPickerCartRunView(run: run)
                        } else if let line = run.members.first?.item {
                            SeatLayerPickerCartLineView(line: line)
                        }
                    }
                }
            }
            if presentation.removalUndo != nil {
                SeatLayerPickerCartUndoView()
            }
        }
        .background(resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        ).surface)
    }

    private var denseRuns: [SeatLayerPickerDenseRun] {
        let lines = presentation.confirmedCartLines.map { line in
            let category = controller.snapshot?.categories.first { $0.key == line.categoryKey }
            return SeatLayerPickerProjections.denseLine(
                line,
                selection: controller.snapshot?.selection ?? [],
                display: .init(
                    categoryLabel: line.tierName ?? category?.label,
                    amountText: seatLayerPickerMoney(
                        line.total,
                        currency: line.currency,
                        style: style
                    )
                ),
                held: controller.snapshot?.hold.active == true
            )
        }
        return SeatLayerPickerProjections.denseRuns(lines)
    }
}

private struct SeatLayerPickerCartRunView: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var expanded = false
    let run: SeatLayerPickerDenseRun

    var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        VStack(spacing: 0) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        expandButton(palette: palette)
                        HStack(spacing: 8) {
                            runAmount(palette: palette)
                            Spacer(minLength: 4)
                            removeButton(palette: palette)
                        }
                    }
                } else {
                    HStack(spacing: 9) {
                        expandButton(palette: palette)
                        Spacer(minLength: 4)
                        runAmount(palette: palette)
                        removeButton(palette: palette)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 4 : 0)
            .frame(minHeight: SeatLayerPickerSizeTokens.denseLineHeight)
            .overlay(alignment: .bottom) {
                Rectangle().fill(palette.divider).frame(height: 1).padding(.leading, 30)
            }
            if expanded {
                ForEach(orderedMembers, id: \.item.lineKey) { line in
                    SeatLayerPickerCartLineView(line: line.item)
                }
            }
        }
    }

    private var orderedMembers: [SeatLayerPickerDenseLine] {
        SeatLayerPickerProjections.membersInSeatOrder(run)
    }

    private func expandButton(palette: SeatLayerPickerPalette) -> some View {
        Button { expanded.toggle() } label: {
            HStack(spacing: 7) {
                Image(systemName: "chevron.right")
                    .seatLayerPickerFont(size: 11, weight: .bold)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                VStack(alignment: .leading, spacing: 2) {
                    Text(runHeading)
                        .seatLayerPickerFont(size: 13, weight: .semibold)
                        .foregroundColor(palette.text)
                    Text(runSummary)
                        .seatLayerPickerFont(size: 10, weight: .medium)
                        .foregroundColor(palette.mutedText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: SeatLayerPickerSizeTokens.minimumHitTarget, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundColor(palette.mutedText)
        .accessibilityLabel([runHeading, runSummary].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityValue(expanded ? style.strings.text(.showLess) : style.strings.text(.moreTickets))
    }

    private func runAmount(palette: SeatLayerPickerPalette) -> some View {
        Text(seatLayerPickerMoney(
            run.total,
            currency: run.members.first?.item.currency ?? controller.snapshot?.currency ?? "USD",
            style: style
        ))
        .seatLayerPickerFont(size: 12, weight: .bold)
        .foregroundColor(palette.text)
    }

    @ViewBuilder
    private func removeButton(palette: SeatLayerPickerPalette) -> some View {
        if presentation.canMutateCart, let first = orderedMembers.first {
            Button {
                runPickerAction(controller) {
                    try await presentation.removeCartLine(first.item.label)
                }
            } label: {
                Image(systemName: "xmark")
                    .seatLayerPickerFont(size: 12, weight: .bold)
                    .frame(
                        width: SeatLayerPickerSizeTokens.minimumHitTarget,
                        height: SeatLayerPickerSizeTokens.minimumHitTarget
                    )
            }
            .buttonStyle(.plain)
            .foregroundColor(palette.mutedText)
            .accessibilityLabel(style.strings.text(.removeSeat))
        }
    }

    private var runHeading: String {
        [run.members.first?.section, run.members.first?.rowLabel]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var runSummary: String {
        [
            style.strings.ticketCount(run.quantity),
            run.seatsLabel,
            run.members.first?.categoryLabel ?? "",
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }
}

struct SeatLayerPickerCartUndoView: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        HStack(spacing: 10) {
            Text(style.strings.text(.seatRemoved))
                .seatLayerPickerFont(size: 13, weight: .semibold)
                .foregroundColor(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(style.strings.text(.undo)) {
                runPickerAction(controller) { _ = try await presentation.undoRemoval() }
            }
            .seatLayerPickerFont(size: 13, weight: .bold)
            .foregroundColor(palette.accent)
            .frame(minWidth: SeatLayerPickerSizeTokens.minimumHitTarget)
            .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
            .disabled(!presentation.canUndoRemoval)
        }
        .padding(.horizontal, 12)
        .background(palette.surface)
        .overlay(alignment: .top) { Rectangle().fill(palette.divider).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("seatlayer-cart-undo")
    }
}

private struct SeatLayerPickerCartLineView: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let line: SeatLayerPickerCartLine

    var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    identity(palette: palette)
                    HStack(spacing: 6) {
                        tableQuantityControls(palette: palette)
                        Spacer(minLength: 4)
                        amount(palette: palette)
                        removeButton(palette: palette)
                    }
                }
            } else {
                HStack(spacing: 9) {
                    identity(palette: palette)
                    Spacer(minLength: 4)
                    tableQuantityControls(palette: palette)
                    amount(palette: palette)
                    removeButton(palette: palette)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 4 : 0)
        .frame(minHeight: SeatLayerPickerSizeTokens.denseLineHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.divider).frame(height: 1).padding(.leading, 30)
        }
    }

    private func identity(palette: SeatLayerPickerPalette) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(categoryColor(fallback: palette.accent))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(line.displayLabel ?? line.label)
                    .seatLayerPickerFont(size: 13, weight: .semibold)
                    .foregroundColor(palette.text)
                let detail = [ticketTypeLabel, line.sectionLabel, line.rowLabel, line.seatNumber]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail)
                        .seatLayerPickerFont(size: 10, weight: .medium)
                        .foregroundColor(palette.mutedText)
                }
            }
        }
    }

    @ViewBuilder
    private func tableQuantityControls(palette: SeatLayerPickerPalette) -> some View {
        if line.objectType == "table" {
            if presentation.canMutateCart {
                quantityButton("minus", delta: -1, palette: palette)
            }
            Text("\(line.quantity)")
                .seatLayerPickerFont(size: 12, weight: .bold)
                .foregroundColor(palette.text)
                .frame(minWidth: 20)
            if presentation.canMutateCart {
                quantityButton("plus", delta: 1, palette: palette)
            }
        }
    }

    private func amount(palette: SeatLayerPickerPalette) -> some View {
        Text(seatLayerPickerMoney(line.total, currency: line.currency, style: style))
            .seatLayerPickerFont(size: 12, weight: .bold)
            .foregroundColor(palette.text)
    }

    @ViewBuilder
    private func removeButton(palette: SeatLayerPickerPalette) -> some View {
        if presentation.canMutateCart {
            Button {
                runPickerAction(controller) { try await presentation.removeCartLine(line.label) }
            } label: {
                Image(systemName: "xmark")
                    .seatLayerPickerFont(size: 12, weight: .bold)
                    .frame(
                        width: SeatLayerPickerSizeTokens.minimumHitTarget,
                        height: SeatLayerPickerSizeTokens.minimumHitTarget
                    )
            }
            .buttonStyle(.plain)
            .foregroundColor(palette.mutedText)
            .accessibilityLabel(style.strings.text(.removeSeat))
        }
    }

    private func quantityButton(
        _ symbol: String,
        delta: Int,
        palette: SeatLayerPickerPalette
    ) -> some View {
        Button {
            let next = line.quantity + delta
            guard next > 0 else { return }
            runPickerAction(controller) {
                _ = try await presentation.setTableQuantity(label: line.label, quantity: next)
            }
        } label: {
            Image(systemName: symbol)
                .seatLayerPickerFont(size: 10, weight: .bold)
                .frame(
                    width: SeatLayerPickerSizeTokens.minimumHitTarget,
                    height: SeatLayerPickerSizeTokens.minimumHitTarget
                )
        }
        .buttonStyle(.plain)
        .foregroundColor(palette.text)
        .disabled(line.quantity + delta <= 0 || presentation.actionInFlight)
    }

    private func categoryColor(fallback: Color) -> Color {
        guard let raw = controller.snapshot?.categories
            .first(where: { $0.key == line.categoryKey })?.color,
              let color = UIColor(slHex: raw) else { return fallback }
        return Color(uiColor: color)
    }

    private var ticketTypeLabel: String? {
        line.tierName ?? controller.snapshot?.categories
            .first(where: { $0.key == line.categoryKey })?.label
    }
}
#endif
