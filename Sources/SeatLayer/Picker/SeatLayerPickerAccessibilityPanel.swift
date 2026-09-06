#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct SeatLayerPickerAccessibilityFilters: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @State private var initial = SeatLayerPickerAccessibilityDraft()
    @State private var draft = SeatLayerPickerAccessibilityDraft()
    @State private var sessionId: String?
    @State private var busy = false

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
        if availability.any,
           controller.snapshot?.map.buyerView == "map" {
            NavigationView {
                Form {
                    let needs = SeatLayerPickerAccessibility.needs(
                        snapshot: controller.snapshot,
                        availability: availability
                    )
                    if !needs.isEmpty {
                        Section {
                            ForEach(needs, id: \.key) { need in
                                needRow(need, palette: palette)
                            }
                        }
                    }
                    if availability.limitedView {
                        Toggle(
                            style.strings.text(.hideLimitedView),
                            isOn: $draft.hideLimitedView
                        )
                        .disabled(busy)
                    }
                    if availability.colorblind {
                        Toggle(
                            style.strings.text(.colorblindSafe),
                            isOn: $draft.colorblindSafe
                        )
                        .disabled(busy)
                    }
                    Section {
                        Button {
                            apply()
                        } label: {
                            HStack {
                                Spacer()
                                if busy { ProgressView().tint(palette.onAccent) }
                                Text(style.strings.text(.applyFilters))
                                    .seatLayerPickerFont(size: 15, weight: .heavy)
                                Spacer()
                            }
                            .frame(minHeight: 44)
                        }
                        .listRowBackground(palette.accent)
                        .foregroundColor(palette.onAccent)
                        .disabled(busy)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(style.strings.text(.cancel)) { dismiss() }
                            .disabled(busy)
                    }
                    ToolbarItem(placement: .principal) {
                        Text(style.strings.text(.accessibilityTitle))
                            .seatLayerPickerFont(size: 16, weight: .bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .accentColor(palette.accent)
            }
            .onAppear(perform: resetDraft)
            .onChange(of: controller.snapshot?.sessionId) { _ in
                resetDraft()
            }
        }
    }

    private func needRow(
        _ need: SeatLayerPickerAccessNeed,
        palette: SeatLayerPickerPalette
    ) -> some View {
        let selected = draft.types.contains(need.key)
        let enabled = !busy && need.count > 0
        return Button {
            draft.toggle(need.key)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? palette.accent : palette.mutedText)
                Text(style.strings.accessNeed(
                    need.key,
                    count: need.count
                ))
                Spacer()
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundColor(enabled ? palette.text : palette.mutedText)
        .disabled(!enabled)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("seatlayer-access-need-\(need.key)")
    }

    private func resetDraft() {
        let value = SeatLayerPickerAccessibility.draft(from: controller.snapshot)
        initial = value
        draft = value
        sessionId = controller.snapshot?.sessionId
    }

    private func apply() {
        guard !busy, sessionId == controller.snapshot?.sessionId else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                if try await controller.applyAccessibilityFilters(draft, from: initial) {
                    dismiss()
                }
            } catch let error as SeatLayerError {
                controller.record(error)
            } catch {
                controller.record(.transport(error.localizedDescription))
            }
        }
    }
}
#endif
