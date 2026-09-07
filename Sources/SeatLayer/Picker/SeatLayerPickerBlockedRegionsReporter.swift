import Foundation
#if canImport(Combine)
import Combine
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

// The view half of the blocked-region guard. The value, the coalescing report
// and the registry are in `SeatLayerPickerBlockedRegions.swift`; this is what
// measures the chrome and keeps the registry in step with what is drawn.
//
// Why a guard at all: the map is a web view, and on iOS 26 a tap on a control
// drawn over it reaches the page as well — the host is told it lost the
// gesture 134 ms before the finger lifts and WKWebView is handed the touch
// regardless, so a press on a corner disc also selected the seat under it. A
// guard sent on touch-down loses that race; the only one that works is
// standing before the finger lands.

/// One control's measured rectangle, under the key it registered with.
public struct SeatLayerPickerBlockedRegionEntry: Equatable {
    /// Stable for the life of the control; two controls never share one.
    public let key: AnyHashable
    /// Where the control stands, in the map surface's own coordinates.
    public let region: SeatLayerBlockedRegion

    public init(key: AnyHashable, region: SeatLayerBlockedRegion) {
        self.key = key
        self.region = region
    }
}

/// Keeps the runtime's picture of the native chrome in step with what is drawn.
///
/// The view layer hands it the whole list of what is on screen after every
/// layout pass; the reporter works out what left, hands that to the registry —
/// which lingers a departing rectangle so a control that leaves on its own tap
/// still guards the late touch — and the registry coalesces the result into
/// one command per turn.
///
/// Deliberately free of SwiftUI so the bookkeeping is exercised by the macOS
/// unit suite: the SwiftUI half below only measures.
@MainActor
public final class SeatLayerPickerBlockedRegionsReporter: ObservableObject {
    private var registry: SeatLayerPickerBlockedRegionRegistry?
    private var regionReport: SeatLayerPickerBlockedRegionsReport?
    private var interactionReport: SeatLayerPickerCoalescedReport<Bool>?
    private weak var controller: SeatLayerPickerController?
    private var present: [AnyHashable] = []
    /// Keys the layout has taken away and the registry has not dropped yet.
    ///
    /// A lowered key is on its way out, and a measurement that names it again
    /// is a LATE LAYOUT PASS until proven otherwise: preference values are
    /// delivered a frame behind, and a re-attach replays the last list it was
    /// given. Re-registering on one of those revived a cover that had already
    /// been lowered — a rectangle over the whole map that never lifts, which is
    /// a map that takes no tap, pan or pinch ever again. So a measurement for a
    /// lowered key is ignored, and only the registry saying the key is gone —
    /// or an authoritative `cover(_:_:)` raise, which carries the value its own
    /// change delivered — takes it off this list.
    private var lowering: Set<AnyHashable> = []

    public init(linger: TimeInterval = seatLayerBlockedRegionLinger) {
        registry = SeatLayerPickerBlockedRegionRegistry(
            linger: linger,
            report: { [weak self] regions in
                self?.regionReport?.report(regions)
            },
            departed: { [weak self] key in
                self?.lowering.remove(key)
            }
        )
    }

    /// What the runtime has been told about, in registration order.
    public var regions: [SeatLayerBlockedRegion] { registry?.regions ?? [] }

    /// Point the reporter at a mounted runtime.
    ///
    /// A fresh runtime knows nothing until it is told, so both reports forget
    /// what the previous one was sent rather than de-duplicating against it.
    public func attach(to controller: SeatLayerPickerController) {
        guard self.controller !== controller else { return }
        self.controller = controller
        regionReport = controller.makeBlockedRegionsReport()
        interactionReport = SeatLayerPickerCoalescedReport(equals: ==) { [weak controller] enabled in
            try? await controller?.setInteractionEnabled(enabled)
        }
        regionReport?.report(regions)
    }

    /// The composing layout is going away: the guard goes with it, and the
    /// runtime is told so rather than being left guarding a screen that no
    /// longer exists.
    public func detach() {
        registry?.removeAll()
        present.removeAll()
        lowering.removeAll()
        regionReport?.forget()
        interactionReport?.forget()
        regionReport = nil
        interactionReport = nil
        controller = nil
    }

    /// Record everything drawn on the map right now.
    ///
    /// Keys that were present and no longer are leave through the registry, so
    /// they keep guarding for `seatLayerBlockedRegionLinger` first.
    public func apply(_ entries: [SeatLayerPickerBlockedRegionEntry]) {
        let arriving = entries.map(\.key)
        for key in present where !arriving.contains(key) {
            lower(key)
        }
        // A key still lingering is NOT present: it is guarded by the rectangle
        // it left behind, and the next pass that measures it after the registry
        // has dropped it registers it afresh.
        present = arriving.filter { !lowering.contains($0) }
        for entry in entries where !lowering.contains(entry.key) {
            registry?.set(entry.key, entry.region)
        }
    }

    /// Guard the WHOLE map under `key`, or release it with nil.
    ///
    /// For a surface that is not in the map's stack at all — a sheet or a
    /// dialog pushed over the page. Its scrim covers the map, and the tap that
    /// dismisses it reaches the web view too, so a sheet used to close and step
    /// the camera out with one touch.
    public func cover(_ key: AnyHashable, _ region: SeatLayerBlockedRegion?) {
        guard let region else {
            present.removeAll { $0 == key }
            lower(key)
            return
        }
        // A raise carries the value its own change delivered, so it is the
        // truth and it revives the key.
        lowering.remove(key)
        registry?.set(key, region)
    }

    /// Ask the registry to let `key` go, and remember that it is going.
    ///
    /// The rectangle keeps guarding for the linger; what is recorded here is
    /// only that no measurement may put the key back in the meantime.
    private func lower(_ key: AnyHashable) {
        registry?.set(key, nil)
        if registry?.isRegistered(key) == true { lowering.insert(key) }
    }

    /// Tell the runtime whether to accept input at all.
    ///
    /// The second half of §2.4: a surface that takes the whole map wants the
    /// map quiet as well as unclaimed. Coalesced, because the layout asks on
    /// every pass and the answer changes twice per decision.
    public func setInteractionEnabled(_ enabled: Bool) {
        interactionReport?.report(enabled)
    }

    /// Deliver both pending reports now, so a test does not race the run loop.
    public func flush() async {
        await regionReport?.flush()
        await interactionReport?.flush()
    }
}

#if canImport(SwiftUI) && canImport(UIKit)

/// The map surface's own coordinate space.
///
/// Rectangles are reported in the map's logical points, measured from its
/// top-left corner, so every control measures against the same origin whatever
/// it is nested inside.
let seatLayerPickerMapCoordinateSpace = "seatlayer-picker-map"

/// Collects every region measured inside one layout pass.
struct SeatLayerPickerBlockedRegionsPreferenceKey: PreferenceKey {
    static var defaultValue: [SeatLayerPickerBlockedRegionEntry] { [] }

    static func reduce(
        value: inout [SeatLayerPickerBlockedRegionEntry],
        nextValue: () -> [SeatLayerPickerBlockedRegionEntry]
    ) {
        value.append(contentsOf: nextValue())
    }
}

private struct SeatLayerPickerMapChromeRegionModifier: ViewModifier {
    let key: AnyHashable
    let enabled: Bool

    func body(content: Content) -> some View {
        content.background {
            // A background, not an overlay: the region draws nothing and takes
            // no pointer of its own. The control underneath still competes for
            // the touch exactly as §2.4 requires — this is the second guard,
            // for the platform that lets the touch through anyway.
            GeometryReader { geometry in
                Color.clear.preference(
                    key: SeatLayerPickerBlockedRegionsPreferenceKey.self,
                    value: enabled
                        ? [SeatLayerPickerBlockedRegionEntry(
                            key: key,
                            region: SeatLayerBlockedRegion(
                                geometry.frame(in: .named(seatLayerPickerMapCoordinateSpace))
                            )
                        )]
                        : []
                )
            }
        }
    }
}

extension View {
    /// Report this control's rectangle to the runtime for as long as it is
    /// drawn on the map.
    ///
    /// `key` must be stable for the life of the control: it is what the
    /// registry lingers on, and a key that changes per pass would report a
    /// control that arrives and leaves on every frame.
    ///
    /// A control that stays mounted while it has nothing to draw — a prompt
    /// layer between prompts — passes `enabled: false` and reports nothing.
    func seatLayerPickerMapChromeRegion(
        _ key: AnyHashable,
        enabled: Bool = true
    ) -> some View {
        modifier(SeatLayerPickerMapChromeRegionModifier(key: key, enabled: enabled))
    }
}

private struct SeatLayerPickerBlockedRegionsReporterKey: EnvironmentKey {
    static let defaultValue: SeatLayerPickerBlockedRegionsReporter? = nil
}

extension EnvironmentValues {
    /// The reporter guarding the map this view is drawn over, where there is
    /// one.
    ///
    /// Optional rather than an environment object, because the components that
    /// cover the map are public and a custom composition may place one where
    /// no map — and so no reporter — stands underneath it. A missing reporter
    /// is an ordinary state: nothing is guarded, and nothing breaks.
    var seatLayerPickerBlockedRegionsReporter: SeatLayerPickerBlockedRegionsReporter? {
        get { self[SeatLayerPickerBlockedRegionsReporterKey.self] }
        set { self[SeatLayerPickerBlockedRegionsReporterKey.self] = newValue }
    }
}

/// Guards the WHOLE map for as long as one surface stands over it.
///
/// Mounted inside the map's own stack so it measures in the map's coordinate
/// space, and drawn as nothing: it is bookkeeping, not chrome.
struct SeatLayerPickerMapCover: View {
    @Environment(\.seatLayerPickerBlockedRegionsReporter) private var regions
    let key: String
    let active: Bool

    var body: some View {
        GeometryReader { geometry in
            // ONE value, and every report is the value the change delivered.
            //
            // It used to be a rectangle and a flag read back off `self` inside
            // the action. An action closure outlives the body that made it, so
            // the read could answer with the flag the cover was raised on — and
            // the pass that LOWERED it re-registered the cover instead of
            // clearing it. A cover over the whole map that never lifts is a map
            // that takes no taps, pans or pinches ever again, which is what a
            // buyer met the moment they dismissed their first seat card.
            let cover = active
                ? SeatLayerBlockedRegion(
                    geometry.frame(in: .named(seatLayerPickerMapCoordinateSpace))
                )
                : nil
            Color.clear
                .onAppear { regions?.cover(key, cover) }
                .onChange(of: cover) { regions?.cover(key, $0) }
                .onDisappear { regions?.cover(key, nil) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SeatLayerPickerBlockedRegionsModifier: ViewModifier {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @StateObject private var reporter = SeatLayerPickerBlockedRegionsReporter()
    @State private var entries: [SeatLayerPickerBlockedRegionEntry] = []
    let interactionEnabled: Bool

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: seatLayerPickerMapCoordinateSpace)
            .environmentObject(reporter)
            .environment(\.seatLayerPickerBlockedRegionsReporter, reporter)
            .onPreferenceChange(SeatLayerPickerBlockedRegionsPreferenceKey.self) { measured in
                entries = measured
            }
            .onChange(of: entries) { measured in
                reporter.apply(measured)
            }
            .onChange(of: interactionEnabled) { enabled in
                reporter.setInteractionEnabled(enabled)
            }
            .onAppear {
                reporter.attach(to: controller)
                reporter.apply(entries)
                reporter.setInteractionEnabled(interactionEnabled)
            }
            .onDisappear { reporter.detach() }
            .onChange(of: controller.phase) { phase in
                // A reloaded runtime knows nothing about the chrome standing
                // on it, so the whole list goes again rather than being
                // de-duplicated against what the previous one was told.
                guard case .ready = phase else { return }
                reporter.attach(to: controller)
                reporter.apply(entries)
                reporter.setInteractionEnabled(interactionEnabled)
            }
    }
}

private struct SeatLayerPickerContainerWidthKey: PreferenceKey {
    static var defaultValue: Double = 0
    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = max(value, nextValue())
    }
}

private struct SeatLayerPickerBottomInsetKey: PreferenceKey {
    static var defaultValue: Double = 0
    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = max(value, nextValue())
    }
}

extension View {
    /// Measure the picker's OWN box, which is what the composition is keyed
    /// off — never the device and never the window.
    ///
    /// The bottom safe inset comes from the same reading, because §2.5 hands
    /// it to exactly one surface and the layout is what knows which.
    func seatLayerPickerContainerMetrics(
        width: Binding<Double?>,
        bottomSafeInset: Binding<Double>
    ) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: SeatLayerPickerContainerWidthKey.self,
                        value: geometry.size.width
                    )
                    .preference(
                        key: SeatLayerPickerBottomInsetKey.self,
                        value: geometry.safeAreaInsets.bottom
                    )
            }
            .ignoresSafeArea()
        }
        .onPreferenceChange(SeatLayerPickerContainerWidthKey.self) { measured in
            guard measured > 0 else { return }
            width.wrappedValue = measured
        }
        .onPreferenceChange(SeatLayerPickerBottomInsetKey.self) { measured in
            bottomSafeInset.wrappedValue = max(0, measured)
        }
    }

    /// Make this the map surface every `seatLayerPickerMapChromeRegion`
    /// measures against, and keep the runtime told what stands on it.
    ///
    /// One modifier on the map's own stack: it opens the coordinate space,
    /// collects what the chrome inside it measured, and carries the
    /// interaction switch that a full-map surface flips.
    func seatLayerPickerBlockedRegions(interactionEnabled: Bool) -> some View {
        modifier(SeatLayerPickerBlockedRegionsModifier(interactionEnabled: interactionEnabled))
    }
}

#endif
