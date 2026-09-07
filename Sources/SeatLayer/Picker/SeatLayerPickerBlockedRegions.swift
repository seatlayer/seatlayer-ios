import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Where the native chrome lies over the map, told to the runtime.
///
/// The map is a web view, and a tap on a control drawn over it reaches the
/// page as well: the host resigns the gesture after the page has already seen
/// the touch, so a press on a control could also select the seat beneath it. A
/// guard sent on touch-down loses that race — a bridge round trip is far
/// longer than a tap — so the only one that works is standing before the
/// finger lands. Every piece of chrome that stands on the map reports its
/// rectangle once per layout, and the runtime swallows any pointer sequence
/// that starts inside one.
///
/// Three parts: the value (`SeatLayerBlockedRegion`), the coalescing reporter
/// (`SeatLayerPickerCoalescedReport`) and the registry that collects what the
/// chrome measures (`SeatLayerPickerBlockedRegionRegistry`). The view layer
/// owns the measuring; nothing here touches SwiftUI, so all of it is testable.

/// The bridge command, named once so the gate and the send cannot drift.
let seatLayerBlockedRegionsCommand = "picker.setBlockedRegions"

/// How long a rectangle keeps blocking after its control has gone.
///
/// The leak this guards against is a touch delivered to the web view after the
/// host has already handled it, so a control that leaves on its own tap — a
/// card's Add button, an overview disc — must keep guarding a moment longer.
public let seatLayerBlockedRegionLinger: TimeInterval = 0.6

/// One rectangle of native chrome over the map, in the map's own logical
/// points, measured from the map surface's top-left corner.
public struct SeatLayerBlockedRegion: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let w: Double
    public let h: Double

    /// Creates a region. Non-finite edges and negative sizes floor to zero
    /// rather than being sent: the runtime refuses the WHOLE list for one bad
    /// rectangle, and a mis-measured control must not drop the guard on the
    /// rest.
    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x.isFinite ? x : 0
        self.y = y.isFinite ? y : 0
        self.w = w.isFinite && w > 0 ? w : 0
        self.h = h.isFinite && h > 0 ? h : 0
    }

    #if canImport(CoreGraphics)
    /// From a rectangle already expressed in the map's coordinates.
    public init(_ rect: CGRect) {
        self.init(
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            w: Double(rect.size.width),
            h: Double(rect.size.height)
        )
    }
    #endif

    var jsonValue: JSONValue {
        .object(["x": .double(x), "y": .double(y), "w": .double(w), "h": .double(h)])
    }
}

/// Sends one kind of host report to the runtime at most once per run-loop
/// turn, and never twice for the same value.
///
/// Native chrome settles over several layout passes — a dock animating in
/// while the sheet re-measures — and each pass would otherwise mint its own
/// command. Repeats are dropped; a repeat of a value still in flight waits on
/// the send it duplicates rather than reporting success on its behalf.
@MainActor
public final class SeatLayerPickerCoalescedReport<Value> {
    private let send: (Value) async -> Void
    private let isEqual: (Value, Value) -> Bool
    private var pending: Value?
    private var sent: Value?
    private var flushScheduled = false
    private var inFlight: Task<Void, Never>?

    /// Creates a reporter that hands each settled value to `send`.
    ///
    /// `equals` decides what "the same value" means; a list of regions
    /// replaces the default with element-wise equality.
    public init(
        equals: @escaping (Value, Value) -> Bool,
        send: @escaping (Value) async -> Void
    ) {
        self.isEqual = equals
        self.send = send
    }

    /// Report `value`. Safe to call from every layout pass.
    public func report(_ value: Value) {
        pending = value
        guard !flushScheduled else { return }
        flushScheduled = true
        Task { @MainActor in
            self.flushScheduled = false
            await self.flush()
        }
    }

    /// Forget what a runtime that is going away was told. A fresh runtime
    /// knows nothing until it is told, so the next report has to be sent even
    /// when the value has not moved.
    public func forget() {
        sent = nil
        inFlight = nil
    }

    /// Deliver the pending value now. Exposed so a test does not have to race
    /// the run loop.
    public func flush() async {
        guard let wanted = pending else { return }
        pending = nil
        if let sent, isEqual(sent, wanted) {
            await inFlight?.value
            return
        }
        sent = wanted
        let task = Task { @MainActor in await self.send(wanted) }
        inFlight = task
        await task.value
        if inFlight == task { inFlight = nil }
    }
}

/// The blocked-regions report: the whole list, replaced on every send.
public typealias SeatLayerPickerBlockedRegionsReport =
    SeatLayerPickerCoalescedReport<[SeatLayerBlockedRegion]>

/// Collects the rectangles the chrome measures and hands the runtime the whole
/// list, once per turn, only when it has changed.
///
/// The view layer registers a control under any hashable key and clears it on
/// disappear; the registry keeps a rectangle alive for `linger` after its
/// control has gone, because the touch this guards against arrives after the
/// host has already handled the tap — a control that leaves on its own tap
/// would otherwise stop guarding exactly where the finger is.
@MainActor
public final class SeatLayerPickerBlockedRegionRegistry {
    private let report: ([SeatLayerBlockedRegion]) -> Void
    private let departed: (AnyHashable) -> Void
    private let linger: TimeInterval
    private var order: [AnyHashable] = []
    private var rects: [AnyHashable: SeatLayerBlockedRegion] = [:]
    private var leaving: [AnyHashable: Task<Void, Never>] = [:]

    /// `departed` is called the moment a key's rectangle actually leaves the
    /// list — at the end of its linger, not when it was asked to go. It is what
    /// lets the owner know a lowered key is finally gone, rather than guessing
    /// at the timing of it.
    public init(
        linger: TimeInterval = seatLayerBlockedRegionLinger,
        report: @escaping ([SeatLayerBlockedRegion]) -> Void,
        departed: @escaping (AnyHashable) -> Void = { _ in }
    ) {
        self.linger = max(0, linger)
        self.report = report
        self.departed = departed
    }

    /// Whether `key` still has a rectangle in the list — including one that is
    /// lingering after its control has gone.
    public func isRegistered(_ key: AnyHashable) -> Bool { rects[key] != nil }

    /// What is registered right now, in registration order.
    public var regions: [SeatLayerBlockedRegion] {
        order.compactMap { rects[$0] }
    }

    /// Record `rect` for `key`, or forget `key` with nil.
    ///
    /// Forgetting is deferred by `linger`; recording again in the meantime
    /// simply keeps the rectangle.
    public func set(_ key: AnyHashable, _ rect: SeatLayerBlockedRegion?) {
        guard let rect else {
            guard rects[key] != nil, leaving[key] == nil else { return }
            guard linger > 0 else {
                remove(key)
                return
            }
            let nanoseconds = UInt64(linger * 1_000_000_000)
            leaving[key] = Task { @MainActor in
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                self.leaving[key] = nil
                self.remove(key)
            }
            return
        }
        leaving.removeValue(forKey: key)?.cancel()
        if rects[key] == rect { return }
        if rects[key] == nil { order.append(key) }
        rects[key] = rect
        report(regions)
    }

    /// Forget everything at once, with no linger: the layout itself is gone.
    public func removeAll() {
        for task in leaving.values { task.cancel() }
        leaving.removeAll()
        rects.removeAll()
        order.removeAll()
        report([])
    }

    private func remove(_ key: AnyHashable) {
        guard rects.removeValue(forKey: key) != nil else { return }
        order.removeAll { $0 == key }
        report(regions)
        departed(key)
    }
}

/// Element-wise equality, for the coalescing report.
public func seatLayerBlockedRegionsEqual(
    _ a: [SeatLayerBlockedRegion],
    _ b: [SeatLayerBlockedRegion]
) -> Bool {
    a == b
}

@MainActor
extension SeatLayerPickerController {
    /// Whether the mounted runtime takes the rectangles at all.
    ///
    /// Gated on the command being in the bundle's own `hello` table: this
    /// changes nothing a snapshot reports, so the command table IS the whole
    /// contract. An older runtime is left as it was.
    public var supportsBlockedRegions: Bool {
        isReady && supports(command: seatLayerBlockedRegionsCommand)
    }

    /// Tell the runtime the whole list of rectangles a touch must not fall
    /// through. An empty list clears the guard.
    public func setBlockedRegions(_ regions: [SeatLayerBlockedRegion]) async {
        guard supportsBlockedRegions else { return }
        do {
            try await presentation(
                seatLayerBlockedRegionsCommand,
                .object(["rects": .array(regions.map(\.jsonValue))])
            )
        } catch {
            swallowUnsupported(error)
        }
    }

    /// A reporter that coalesces per-frame rectangle reports into one command.
    ///
    /// The view layer builds one of these, hands it to a
    /// `SeatLayerPickerBlockedRegionRegistry`, and calls `report(_:)` as often
    /// as it likes.
    public func makeBlockedRegionsReport() -> SeatLayerPickerBlockedRegionsReport {
        SeatLayerPickerCoalescedReport(equals: seatLayerBlockedRegionsEqual) {
            [weak self] regions in
            await self?.setBlockedRegions(regions)
        }
    }
}
