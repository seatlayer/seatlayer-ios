#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The head of the map's control column: the filters that decide who can sit
/// where.
///
/// A drawn control rather than a lettered one, and named for what it opens:
/// a chart with real access needs offers accessibility filters, and a chart
/// with only the colourblind-safe palette offers display options. Naming both
/// "accessibility" told a buyer with no access need that the control was not
/// for them.
public struct SeatLayerPickerAccessibilityButton: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.seatLayerPickerBlockedRegionsReporter) private var regions
    @State private var showingFilters = false

    public init() {}

    public var body: some View {
        let availability = SeatLayerPickerAccessibility.availability(
            snapshot: controller.snapshot,
            bundle: controller.bundleInfo
        )
        let palette = seatLayerPickerMapChromePalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        let chrome = seatLayerPickerMapChromeDisc(palette)
        if availability.any, controller.snapshot?.map.buyerView == "map" {
            let activeCount = SeatLayerPickerAccessibility.activeCount(
                controller.snapshot,
                availability: availability
            )
            let needs = availability.accessibility || availability.limitedView
            Button { openFilters() } label: {
                Image(systemName: needs ? "figure.roll" : "slider.horizontal.3")
                    .seatLayerPickerFont(size: 18, weight: .semibold)
                    .foregroundColor(activeCount > 0 ? palette.accent : palette.text)
                    .frame(
                        width: SeatLayerPickerSizeTokens.accessibilityControlSize,
                        height: SeatLayerPickerSizeTokens.accessibilityControlSize
                    )
                    .background(
                        activeCount > 0
                            ? palette.accent.opacity(0.13).background(chrome.ground)
                            : chrome.ground.opacity(1).background(chrome.ground)
                    )
                    .overlay {
                        Circle().stroke(
                            activeCount > 0 ? palette.accent.opacity(0.52) : chrome.line,
                            lineWidth: 1
                        )
                    }
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                    // Native-better: how many filters are on, without opening
                    // the sheet to find out.
                    .overlay(alignment: .topTrailing) {
                        if activeCount > 0 {
                            Text(String(activeCount))
                                .seatLayerPickerFont(size: 9, weight: .heavy)
                                .foregroundColor(palette.onAccent)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(palette.accent)
                                .clipShape(Circle())
                        }
                    }
                    .frame(
                        width: SeatLayerPickerSizeTokens.minimumHitTarget,
                        height: SeatLayerPickerSizeTokens.minimumHitTarget
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!controller.isReady)
            .accessibilityLabel(
                style.strings.text(needs ? .accessibility : .displayOptions)
            )
            .accessibilityValue(activeCount == 0 ? "" : String(activeCount))
            .sheet(isPresented: $showingFilters) {
                SeatLayerPickerPartHost(.accessibilityFilters) {
                    SeatLayerPickerAccessibilityFilters()
                }
                .environmentObject(controller)
                .environmentObject(presentation)
                .environment(\.seatLayerPickerStyle, style)
                .environment(\.seatLayerPickerBlockedRegionsReporter, regions)
                // SwiftUI sheets otherwise resolve their system surface
                // independently from an explicitly light or dark picker. Keep
                // native controls and the picker palette on the same side of
                // the contrast boundary.
                .preferredColorScheme(palette.dark ? .dark : .light)
            }
        }
    }

    /// A card standing over the map is a question the buyer has not answered.
    /// Opening the filters answers it with "not this seat" rather than leaving
    /// a card waiting underneath a sheet.
    private func openFilters() {
        Task { @MainActor in
            _ = await presentation.cancelPending()
            showingFilters = true
        }
    }
}

/// The tour of the sections that hold matching free spaces.
///
/// It rides beside the accessibility disc rather than above it: they are one
/// subject. It draws nothing at all until a filter is on AND the runtime
/// answers, so the column is three discs the rest of the time — and it never
/// draws a count of zero, because a section nobody counted is not a section
/// with nothing in it.
public struct SeatLayerPickerAccessibleStepper: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @State private var tour = SeatLayerPickerAccessibilityTour()
    @State private var walking = false

    public init() {}

    public var body: some View {
        let palette = seatLayerPickerMapChromePalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        if let label = pillLabel {
            Button { walk() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "figure.roll")
                        .seatLayerPickerFont(
                            size: SeatLayerPickerSizeTokens.accessStepFontSize,
                            weight: .bold
                        )
                    Text(label)
                        .seatLayerPickerFont(
                            size: SeatLayerPickerSizeTokens.accessStepFontSize,
                            weight: .heavy
                        )
                        .lineLimit(1)
                        .monospacedDigit()
                    Image(systemName: "chevron.forward")
                        .seatLayerPickerFont(
                            size: SeatLayerPickerSizeTokens.accessStepFontSize - 1,
                            weight: .bold
                        )
                }
                .foregroundColor(palette.accent)
                .padding(.horizontal, SeatLayerPickerSizeTokens.accessStepPaddingX)
                .frame(height: SeatLayerPickerSizeTokens.accessStepHeight)
                .background(palette.accent.opacity(0.12).background(palette.chrome))
                .overlay {
                    Capsule().stroke(palette.accent.opacity(0.4), lineWidth: 1)
                }
                .clipShape(Capsule())
                .frame(minHeight: SeatLayerPickerSizeTokens.minimumHitTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!controller.isReady || walking)
            .accessibilityLabel(style.strings.text(
                tour.isWalking ? .accessJumpNextSection : .accessJumpFirstSection
            ))
            .accessibilityValue(label)
            .dynamicTypeSize(...DynamicTypeSize.large)
            .onChange(of: controller.snapshot?.map.accessibilityFilter) { filter in
                // A different filter is a different tour.
                tour.reconcile(activeTypes: filter ?? [])
            }
            .onAppear { tour.reconcile(activeTypes: activeTypes) }
        }
    }

    /// What the pill says, or nil where it is not drawn at all.
    ///
    /// Before the first jump it offers the count the runtime reported; after
    /// one it says which stop the buyer is on, printed one-based over a
    /// zero-based index.
    private var activeTypes: [String] { controller.snapshot?.map.accessibilityFilter ?? [] }

    private var pillLabel: String? {
        guard controller.snapshot?.map.buyerView == "map" else { return nil }
        switch tour.state(
            supportsFocus: controller.supportsAccessibilityFocus,
            sectionsWithMatches: seatLayerAccessibleSectionCount(
                snapshot: controller.snapshot,
                types: activeTypes,
                supportsCounts: controller.supportsSectionAccessCounts
            )
        ) {
        case .step(let index, let total):
            return style.strings.text(.accessibleStep, replacing: [
                "index": String(index),
                "total": String(total),
            ])
        case .counted(let sections):
            return style.strings.text(.accessibleSections, replacing: [
                "count": String(sections),
            ])
        // A runtime that walks but does not count has a tour to offer and no
        // number to put on it, so the pill invites the first step by name.
        case .uncounted:
            return style.strings.text(.accessJumpFirstSection)
        case .absent:
            return nil
        }
    }

    private func walk() {
        guard !walking else { return }
        walking = true
        let types = activeTypes
        tour.reconcile(activeTypes: types)
        Task { @MainActor in
            defer { walking = false }
            // A nil answer means nothing matches — not an error, and never a
            // step with a zero total. The pill leaves rather than drawing
            // "0 of 0".
            tour.advance(to: try? await controller.focusNextAccessibleSection(types: types))
        }
    }
}
#endif
