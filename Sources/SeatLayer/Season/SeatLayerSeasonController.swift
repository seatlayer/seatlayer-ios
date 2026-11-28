import Combine
import Foundation

/// Headless API of one Season page.
///
/// Observe the published state, or the publishers for one-off events. The
/// page draws the Season; `SeatLayerSeasonPicker` wears the app's bar over it.
@MainActor
public final class SeatLayerSeasonController: ObservableObject {
    @Published public internal(set) var phase: SeatLayerPickerPhase = .idle
    /// The page's last status line: loading, ready (with the dates), held, …
    @Published public internal(set) var status: SeatLayerSeasonStatus?
    /// The buyer's hold, while there is one.
    @Published public internal(set) var hold: SeatLayerSeasonHandoff?
    /// The page's line to the server, from a page that reports it.
    @Published public internal(set) var connection: SeatLayerConnectionState?

    public private(set) var bundleInfo: BundleInfo?
    public var isReady: Bool {
        if case .ready = phase { return true }
        return false
    }

    /// The buyer pressed continue: book this hold on your server, charge at
    /// your prices, then call `markBooked`. Once per operation.
    public var continues: AnyPublisher<SeatLayerSeasonHandoff, Never> { continueSubject.eraseToAnyPublisher() }
    /// A hold this page made or restored is booked. Once per operation.
    public var bookings: AnyPublisher<SeatLayerSeasonHandoff, Never> { bookingSubject.eraseToAnyPublisher() }
    /// The hold ran out or the server let it go.
    public var holdExpirations: AnyPublisher<Void, Never> { holdExpirationSubject.eraseToAnyPublisher() }
    public var accessExpirations: AnyPublisher<BuyerAccessExpiredEvent, Never> {
        accessExpirationSubject.eraseToAnyPublisher()
    }
    public var accessUnavailability: AnyPublisher<BuyerAccessUnavailableEvent, Never> {
        accessUnavailableSubject.eraseToAnyPublisher()
    }
    /// Errors the page reports after it is ready.
    public var errors: AnyPublisher<SeatLayerError, Never> { errorSubject.eraseToAnyPublisher() }

    private let continueSubject = PassthroughSubject<SeatLayerSeasonHandoff, Never>()
    private let bookingSubject = PassthroughSubject<SeatLayerSeasonHandoff, Never>()
    private let holdExpirationSubject = PassthroughSubject<Void, Never>()
    private let accessExpirationSubject = PassthroughSubject<BuyerAccessExpiredEvent, Never>()
    private let accessUnavailableSubject = PassthroughSubject<BuyerAccessUnavailableEvent, Never>()
    private let errorSubject = PassthroughSubject<SeatLayerError, Never>()

    var transport: (any SeatLayerPickerCommandTransport)?
    /// The buyer's hold as last reported, kept while one page takes another's
    /// place: with no page to ask, a close keeps it.
    private(set) var lastHold: SeatLayerSeasonHandoff?
    private var runtimeOwner: UUID?
    private var continued = Set<String>()
    private var booked = Set<String>()
    private var handoffs: [String: SeatLayerSeasonHandoff] = [:]

    public init() {}

    public func supports(capability: String) -> Bool {
        bundleInfo?.supports(capability: capability) == true
    }

    public func supports(command: String) -> Bool {
        bundleInfo?.supports(command: command) == true
    }

    // MARK: - Commands

    /// A fresh caller-stable id for a hold. Keep it to retry the same hold.
    public static func newOperationId() -> String { "sop_\(randomId())" }

    /// A fresh caller-stable id for a release.
    public static func newReleaseActionId() -> String { "sra_\(randomId())" }

    /// Holds the seats named by `labels` for every date of the package.
    ///
    /// - Parameter priceTypes: A seat label's price type (`child`, …) on a
    ///   package priced by type.
    public func holdSameSeat(
        _ labels: [String],
        operationId: String? = nil,
        priceTypes: [String: String]? = nil
    ) async throws -> SeatLayerSeasonHandoff {
        try handoff(from: await send("season.holdSameSeat", .object(compacting: [
            "labels": .array(labels.map(JSONValue.string)),
            "operationId": .string(operationId ?? Self.newOperationId()),
            "priceTypes": priceTypes.map { .object($0.mapValues(JSONValue.string)) },
        ])))
    }

    /// Holds the best `quantity` seats the page finds.
    public func holdBestAvailable(
        _ quantity: Int,
        operationId: String? = nil,
        categoryKey: String? = nil,
        zoneId: String? = nil,
        accessibility: [String]? = nil,
        requireContiguous: Bool? = nil
    ) async throws -> SeatLayerSeasonHandoff {
        try handoff(from: await send("season.holdBestAvailable", .object(compacting: [
            "qty": .int(quantity),
            "operationId": .string(operationId ?? Self.newOperationId()),
            "categoryKey": categoryKey.map(JSONValue.string),
            "zoneId": zoneId.map(JSONValue.string),
            "accessibility": accessibility.map { .array($0.map(JSONValue.string)) },
            "requireContiguous": requireContiguous.map(JSONValue.bool),
        ])))
    }

    /// Opens on a hold your app already has. Nil when it is no longer held.
    public func restoreOperation(_ operationId: String) async throws -> SeatLayerSeasonHandoff? {
        let result = try await send("season.restoreOperation", ["operationId": .string(operationId)])
        guard let restored = SeatLayerSeasonHandoff(result["handoff"]) else { return nil }
        handoffs[restored.operationId] = restored
        return restored
    }

    /// Back to choosing seats.
    public func chooseSeats() async throws {
        _ = try await send("season.chooseSeats")
    }

    /// Switches to the package `planActivationId`.
    public func choosePackage(_ planActivationId: String) async throws {
        _ = try await send("season.choosePackage", ["planActivationId": .string(planActivationId)])
    }

    /// Tells the page your server booked the hold: it shows it booked and
    /// never releases it. Call it only after your server has booked.
    public func markBooked(operationId: String? = nil) async throws -> SeatLayerSeasonBookedStatus {
        let result = try await send(
            "season.markBooked",
            .object(compacting: ["operationId": operationId.map(JSONValue.string)])
        )
        return SeatLayerSeasonBookedStatus(
            rawValue: result["status"]?.stringValue ?? SeatLayerSeasonBookedStatus.pending.rawValue
        )
    }

    /// Lets the held seats go. True only when the hold was released; a booked
    /// hold never is.
    public func release(releaseActionId: String? = nil) async throws -> Bool {
        try await send(
            "season.release",
            ["releaseActionId": .string(releaseActionId ?? Self.newReleaseActionId())]
        )["released"]?.boolValue == true
    }

    /// The held order as the page prices it, or nil with nothing held.
    public func getHeldOrder() async throws -> SeatLayerSeasonHeldOrder? {
        SeatLayerSeasonHeldOrder(try await send("season.getHeldOrder")["heldOrder"])
    }

    /// The buyer pressed close or Back. With seats held the page asks whether
    /// to release or keep them, and waits for the buyer; the outcome says what
    /// to do with the screen. With no page up, the seats held stay held.
    public func requestClose() async throws -> SeatLayerSeasonClose {
        guard isReady else { return closeWithoutPage() }
        let result = try await send("season.requestClose")
        return SeatLayerSeasonClose(
            outcome: SeatLayerSeasonCloseOutcome(
                rawValue: result["outcome"]?.stringValue ?? SeatLayerSeasonCloseOutcome.stayed.rawValue
            ),
            operationId: result["operationId"]?.stringValue
        )
    }

    /// Tells the page the app went to the background or came back. Coming
    /// back, the page reads the hold again; the answer says whether it is
    /// still held.
    @discardableResult
    public func setForeground(_ foreground: Bool) async throws -> Bool? {
        try await send(
            "season.lifecycle",
            ["state": .string(foreground ? "foreground" : "background")]
        )["held"]?.boolValue
    }

    /// Paints the page light or dark in place, without a reload.
    public func setThemeMode(_ mode: SeatLayerPickerThemeMode?) async throws {
        _ = try await send("season.setThemeMode", ["mode": mode.map { .string($0.rawValue) } ?? .null])
    }

    /// Space the page keeps clear at its edges.
    public func setViewportInsets(top: Double = 0, right: Double = 0, bottom: Double = 0, left: Double = 0) async throws {
        _ = try await send("season.setViewportInsets", [
            "top": .double(top), "right": .double(right), "bottom": .double(bottom), "left": .double(left),
        ])
    }

    /// Tears the page down. A plain, unfinished hold is released first; a
    /// hold that was continued, restored, booked or kept never is.
    public func destroy() async {
        if isReady { _ = try? await send("season.destroy") }
        dropPage()
        phase = .destroyed
    }

    /// With no page to ask, the seats the buyer holds stay held.
    func closeWithoutPage() -> SeatLayerSeasonClose {
        guard let lastHold, !booked.contains(lastHold.operationId) else {
            return SeatLayerSeasonClose(outcome: .closed)
        }
        return SeatLayerSeasonClose(outcome: .kept, operationId: lastHold.operationId)
    }

    private func send(_ command: String, _ payload: JSONValue? = nil) async throws -> JSONValue {
        guard let transport, isReady else {
            throw SeatLayerError.bridge(.init(code: BridgeErrorCode.notReady, message: "the Season page is not ready"))
        }
        return try await transport.command(command, payload: payload ?? .object([:]))
    }

    private func handoff(from result: JSONValue) throws -> SeatLayerSeasonHandoff {
        guard let handoff = SeatLayerSeasonHandoff(result["handoff"]) else {
            throw SeatLayerError.decoding("the page answered without a hold")
        }
        handoffs[handoff.operationId] = handoff
        return handoff
    }

    private static func randomId() -> String {
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        var generator = SystemRandomNumberGenerator()
        return String((0..<20).map { _ in alphabet[Int(generator.next(upperBound: UInt(alphabet.count)))] })
    }

    // MARK: - Page events

    func accept(event name: String, payload: JSONValue?) {
        switch name {
        case "season.status":
            guard let next = SeatLayerSeasonStatus(payload) else { return }
            status = next
            if next.kind == .booked,
               let operationId = next.operationId,
               let handoff = handoffs[operationId],
               booked.insert(operationId).inserted {
                bookingSubject.send(handoff)
            }
        case "season.hold", "season.holdChanged":
            let handoff = SeatLayerSeasonHandoff(payload?["handoff"])
            if handoff == nil, name == "season.hold" { return }
            if let handoff { handoffs[handoff.operationId] = handoff }
            setHold(handoff)
        case "season.holdExpired":
            setHold(nil)
            holdExpirationSubject.send()
        case "season.continue":
            guard let handoff = SeatLayerSeasonHandoff(payload?["handoff"]),
                  continued.insert(handoff.operationId).inserted else { return }
            handoffs[handoff.operationId] = handoff
            continueSubject.send(handoff)
        case "season.accessExpired":
            if let event = try? payload?.decode(BuyerAccessExpiredEvent.self) {
                accessExpirationSubject.send(event)
            }
        case "season.accessUnavailable":
            if let event = try? payload?.decode(BuyerAccessUnavailableEvent.self) {
                accessUnavailableSubject.send(event)
            }
        case "season.error":
            errorSubject.send(.bridge(BridgeErrorPayload(payload)))
        default:
            // An event this build predates. Never a crash.
            break
        }
    }

    private func setHold(_ next: SeatLayerSeasonHandoff?) {
        hold = next
        lastHold = next
    }

    /// The page is gone; what it reported goes with it. The last hold stays,
    /// for the page that takes its place.
    func dropPage() {
        transport = nil
        bundleInfo = nil
        status = nil
        hold = nil
        connection = nil
    }

    private func acceptsOwner(_ owner: UUID?) -> Bool {
        owner == nil || owner == runtimeOwner
    }
}

extension SeatLayerSeasonController: SeatLayerSurfaceSession {
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
