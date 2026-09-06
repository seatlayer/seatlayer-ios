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

    public init() {
        registry = SeatLayerPickerBlockedRegionRegistry { [weak self] regions in
            self?.regionReport?.report(regions)
        }
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
            registry?.set(key, nil)
        }
        present = arriving
        for entry in entries {
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
        if region == nil { present.removeAll { $0 == key } }
        registry?.set(key, region)
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

private struct SeatLayerPickerBlockedRegionsModifier: ViewModifier {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @StateObject private var reporter = SeatLayerPickerBlockedRegionsReporter()
    @State private var entries: [SeatLayerPickerBlockedRegionEntry] = []
    let interactionEnabled: Bool

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: seatLayerPickerMapCoordinateSpace)
            .environmentObject(reporter)
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

extension View {
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
