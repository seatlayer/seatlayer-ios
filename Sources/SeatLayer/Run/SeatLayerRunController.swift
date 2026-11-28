import Combine
import Foundation

/// Headless API of one run page.
///
/// Observe the published state, or the publishers for one-off events. The
/// page draws the run; `SeatLayerRunPicker` wears the app's bar over it.
@MainActor
public final class SeatLayerRunController: ObservableObject {
    @Published public internal(set) var phase: SeatLayerPickerPhase = .idle
    /// The run the page opened. Nil until the page names it.
    @Published public internal(set) var descriptor: SeatLayerRunDescriptor?
    @Published public internal(set) var selectionMode: SeatLayerRunSelectionMode?
    /// What the page shows in place of seats, when it does.
    @Published public internal(set) var status: SeatLayerRunStatus?
    /// The buyer's hold, while there is one.
    @Published public internal(set) var hold: SeatLayerRunHandoff?
    /// The page's line to the server, from a page that reports it.
    @Published public internal(set) var connection: SeatLayerConnectionState?

    public private(set) var bundleInfo: BundleInfo?
    public var isReady: Bool {
        if case .ready = phase { return true }
        return false
    }

    /// The buyer pressed the page's continue: take the hold to checkout.
    /// Once per operation.
    public var continues: AnyPublisher<SeatLayerRunHandoff, Never> { continueSubject.eraseToAnyPublisher() }
    /// A hold the page reports booked, after `markBooked`. Once per operation.
    public var bookings: AnyPublisher<SeatLayerRunHandoff, Never> { bookingSubject.eraseToAnyPublisher() }
    public var holdExpirations: AnyPublisher<Void, Never> { holdExpirationSubject.eraseToAnyPublisher() }
    public var accessExpirations: AnyPublisher<BuyerAccessExpiredEvent, Never> {
        accessExpirationSubject.eraseToAnyPublisher()
    }
    public var accessUnavailability: AnyPublisher<BuyerAccessUnavailableEvent, Never> {
        accessUnavailableSubject.eraseToAnyPublisher()
    }
    /// Errors the page reports after it is ready.
    public var errors: AnyPublisher<SeatLayerError, Never> { errorSubject.eraseToAnyPublisher() }

    private let continueSubject = PassthroughSubject<SeatLayerRunHandoff, Never>()
    private let bookingSubject = PassthroughSubject<SeatLayerRunHandoff, Never>()
    private let holdExpirationSubject = PassthroughSubject<Void, Never>()
    private let accessExpirationSubject = PassthroughSubject<BuyerAccessExpiredEvent, Never>()
    private let accessUnavailableSubject = PassthroughSubject<BuyerAccessUnavailableEvent, Never>()
    private let errorSubject = PassthroughSubject<SeatLayerError, Never>()

    var transport: (any SeatLayerPickerCommandTransport)?
    /// The page opened on a hold it may not announce: ask for it when ready.
    var readsHeldOrderOnReady = false
    private var runtimeOwner: UUID?
    private var continued = Set<String>()
    private var booked = Set<String>()

    public init() {}

    public func supports(capability: String) -> Bool {
        bundleInfo?.supports(capability: capability) == true
    }

    public func supports(command: String) -> Bool {
        bundleInfo?.supports(command: command) == true
    }

    // MARK: - Commands

    /// Holds the buyer's seats and returns the hold for checkout.
    public func continueToCheckout() async throws -> SeatLayerRunHandoff {
        guard let handoff = SeatLayerRunHandoff(try await send("group.continue")["handoff"]) else {
            throw SeatLayerError.decoding("the page answered without a hold")
        }
        return handoff
    }

    /// The hold the page has for this buyer, if any.
    public func getHeldOrder() async throws -> SeatLayerRunHandoff? {
        SeatLayerRunHandoff(try await send("group.getHeldOrder")["heldOrder"])
    }

    /// Asks the page for a hold it took up but has not announced.
    func readHeldOrder() async {
        guard hold == nil, let held = try? await getHeldOrder(), hold == nil, isReady else { return }
        hold = held
    }

    /// Lets the hold go.
    public func release() async throws -> Bool {
        try await send("group.release")["released"]?.boolValue == true
    }

    public func setSelectionMode(_ mode: SeatLayerRunSelectionMode) async throws -> Bool {
        try await send("group.setSelectionMode", ["mode": .string(mode.rawValue)])["changed"]?.boolValue == true
    }

    /// Tells the page your server booked the hold. Take the sale from your
    /// own server, never from here.
    public func markBooked(operationId: String? = nil) async throws -> SeatLayerRunBookedStatus {
        let result = try await send(
            "group.markBooked",
            .object(compacting: ["operationId": operationId.map(JSONValue.string)])
        )
        return SeatLayerRunBookedStatus(
            rawValue: result["status"]?.stringValue ?? SeatLayerRunBookedStatus.pending.rawValue
        )
    }

    /// Space the page keeps clear at its edges. Nil gives the page its own.
    public func setViewportInsets(top: Double = 0, right: Double = 0, bottom: Double = 0, left: Double = 0) async throws {
        _ = try await send("group.setViewportInsets", [
            "top": .double(top), "right": .double(right), "bottom": .double(bottom), "left": .double(left),
        ])
    }

    /// Tells the page the app went to the background or came back. Returns
    /// whether the hold is still held, when the page says.
    @discardableResult
    public func setForeground(_ foreground: Bool) async throws -> Bool? {
        try await send(
            "group.lifecycle",
            ["state": .string(foreground ? "foreground" : "background")]
        )["held"]?.boolValue
    }

    /// Tears the page's run down. Best effort: the page may already be gone.
    public func destroy() async {
        if isReady { _ = try? await send("group.destroy") }
        dropPage()
        phase = .destroyed
    }

    private func send(_ command: String, _ payload: JSONValue? = nil) async throws -> JSONValue {
        guard let transport, isReady else {
            throw SeatLayerError.bridge(.init(code: BridgeErrorCode.notReady, message: "the run page is not ready"))
        }
        return try await transport.command(command, payload: payload ?? .object([:]))
    }

    // MARK: - Page events

    func accept(event name: String, payload: JSONValue?) {
        switch name {
        case "group.ready":
            guard let run = SeatLayerRunDescriptor(payload?["performanceGroup"]) else { return }
            descriptor = run
            if let mode = payload?["selectionMode"]?.stringValue {
                selectionMode = SeatLayerRunSelectionMode(rawValue: mode)
            }
        case "group.status":
            if let next = SeatLayerRunStatus(payload) { status = next }
        case "group.hold", "group.holdChanged":
            let handoff = SeatLayerRunHandoff(payload?["handoff"])
            if handoff == nil, name == "group.hold" { return }
            hold = handoff
        case "group.holdExpired":
            hold = nil
            holdExpirationSubject.send()
        case "group.checkout":
            guard let handoff = SeatLayerRunHandoff(payload?["handoff"]),
                  continued.insert(handoff.operationId).inserted else { return }
            continueSubject.send(handoff)
        case "group.booked":
            guard let handoff = SeatLayerRunHandoff(payload?["handoff"]),
                  booked.insert(handoff.operationId).inserted else { return }
            bookingSubject.send(handoff)
        case "group.selectionMode.changed":
            guard let mode = payload?["selectionMode"]?.stringValue else { return }
            selectionMode = SeatLayerRunSelectionMode(rawValue: mode)
        case "group.access.expired":
            if let event = try? payload?.decode(BuyerAccessExpiredEvent.self) {
                accessExpirationSubject.send(event)
            }
        case "group.access.unavailable":
            if let event = try? payload?.decode(BuyerAccessUnavailableEvent.self) {
                accessUnavailableSubject.send(event)
            }
        case "group.error":
            errorSubject.send(.bridge(BridgeErrorPayload(payload)))
        default:
            // An event this build predates. Never a crash.
            break
        }
    }

    /// The page is gone; what it reported goes with it.
    func dropPage() {
        transport = nil
        bundleInfo = nil
        descriptor = nil
        selectionMode = nil
        status = nil
        hold = nil
        connection = nil
    }

    private func acceptsOwner(_ owner: UUID?) -> Bool {
        owner == nil || owner == runtimeOwner
    }
}

extension SeatLayerRunController: SeatLayerSurfaceSession {
    func sessionBeginLoading(owner: UUID?) {
        runtimeOwner = owner
        dropPage()
        phase = .loading
    }

    func sessionConnect(
        transport: any SeatLayerPickerCommandTransport,
        bundleInfo: BundleInfo,
        owner: UUID?
    ) {
        guard acceptsOwner(owner) else { return }
        self.transport = transport
        self.bundleInfo = bundleInfo
    }

    func sessionReady(_ info: ReadyInfo, payload: JSONValue?, owner: UUID?) {
        guard acceptsOwner(owner) else { return }
        phase = .ready(info)
        if readsHeldOrderOnReady {
            Task { @MainActor [weak self] in await self?.readHeldOrder() }
        }
    }

    func sessionFailed(_ error: SeatLayerError, owner: UUID?) {
        guard acceptsOwner(owner) else { return }
        if isReady {
            errorSubject.send(error)
        } else {
            phase = .failed(error)
        }
    }

    func sessionConnection(_ payload: JSONValue?, owner: UUID?) {
        guard acceptsOwner(owner), supports(capability: "connection-state-v1") else { return }
        connection = SeatLayerConnectionState(page: payload?["state"])
    }

    func sessionDestroyed(owner: UUID?) {
        guard acceptsOwner(owner) else { return }
        dropPage()
        // A page torn down because it failed keeps the failure in view: the
        // picker swaps the page for the failure panel, which ends the page.
        if case .failed = phase { return }
        phase = .destroyed
    }

    func sessionEvent(_ name: String, payload: JSONValue?, owner: UUID?) {
        guard acceptsOwner(owner) else { return }
        accept(event: name, payload: payload)
    }
}
