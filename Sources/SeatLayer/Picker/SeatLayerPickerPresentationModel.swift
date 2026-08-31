/// Why the native picker finished its own close ladder.
public enum SeatLayerPickerCloseReason: String, Sendable, Equatable, CaseIterable {
    case closeButton
    case systemBack
    case barrier
    case programmatic
}

#if canImport(Combine)
import Combine
import Foundation

public typealias SeatLayerPickerCheckoutHandler =
    @MainActor (SeatLayerPickerCheckoutHandoff) async throws -> Void

/// The deterministic layer the next back/close request will consume.
public enum SeatLayerPickerBackStep: String, Sendable, Equatable, CaseIterable {
    case prompt
    case cart
    case confirmation
    case section
    case venue
    case close
}

public enum SeatLayerPickerPrompt: Sendable, Equatable {
    case generalAdmission(GAArea)
    case table(SelectedSeat)
}

/// One successfully removed cart intent that may be restored during the native
/// four-second undo window. The runtime session and exact inventory labels are
/// retained; display text is never reverse-engineered into a selection command.
public struct SeatLayerPickerRemovalUndo: Sendable, Equatable {
    public let id: UUID
    public let sessionId: String
    public let lines: [SeatLayerPickerCartLine]
    public let expiresAt: Date

    public var labels: [String] { lines.map(\.label) }

    public init(
        id: UUID = UUID(),
        sessionId: String,
        lines: [SeatLayerPickerCartLine],
        expiresAt: Date
    ) {
        self.id = id
        self.sessionId = sessionId
        self.lines = lines
        self.expiresAt = expiresAt
    }
}

/// Local native-chrome state layered over immutable runtime snapshots.
///
/// The runtime remains authoritative for selection, cart prices, quantities,
/// holds, and revisions. This model owns only presentation facts such as an
/// unanswered confirmation card and whether the cart sheet is expanded.
@MainActor
public final class SeatLayerPickerPresentationModel: ObservableObject {
    @Published public private(set) var pendingSeat: SelectedSeat?
    /// Buyer-authored tier choice for the current pending seat. It deliberately
    /// lives with the presentation owner so renderer-owned inspection surfaces
    /// can come and go without resetting the unanswered decision.
    @Published public private(set) var pendingTierId: String?
    @Published public private(set) var pendingTable: SelectedSeat?
    @Published public private(set) var actionInFlight = false
    @Published public private(set) var checkoutHandoff: SeatLayerPickerCheckoutHandoff?
    @Published public private(set) var lastActionError: SeatLayerError?
    @Published public private(set) var selectionFlight: SeatLayerPickerSelectionFlightMoment?
    @Published public private(set) var removalUndo: SeatLayerPickerRemovalUndo?
    @Published public var cartSheetExpanded: Bool

    public let controller: SeatLayerPickerController
    public private(set) var options: SeatLayerPickerOptions

    public var confirmedCartLines: [SeatLayerPickerCartLine] {
        SeatLayerPickerProjections.confirmedCart(
            controller.snapshot?.cartLines ?? [],
            pending: pendingSeat
        ).items
    }

    public var confirmedTicketCount: Int {
        confirmedCartTotals.quantity
    }

    public var confirmedCartTotal: Double {
        confirmedCartTotals.total
    }

    public var confirmedCartTotals: SeatLayerPickerCartTotals {
        SeatLayerPickerProjections.totals(confirmedCartLines)
    }

    public var canCheckout: Bool {
        guard controller.isReady,
              !options.readOnly,
              !actionInFlight,
              checkoutHandoff == nil,
              activePrompt == nil,
              pendingSeat == nil,
              !confirmedCartLines.isEmpty,
              controller.snapshot?.event.salesClosed != true,
              controller.snapshot?.hold.owner != "host" else { return false }
        return controller.snapshot?.selectionValidity?.isValid != false
    }

    /// Whether the ready-made best-available form may start an inventory
    /// mutation. This follows the same sales and hold-ownership boundary as
    /// the rest of the native buyer chrome.
    public var canUseBestAvailable: Bool {
        canMutateInventory
    }

    /// Picker-owned cart mutations are unavailable in read-only mode and after
    /// a handoff gives the active hold to the host application.
    public var canMutateCart: Bool {
        guard controller.isReady, !options.readOnly, !actionInFlight else { return false }
        guard let hold = controller.snapshot?.hold, hold.active else { return true }
        return hold.owner == "picker"
    }

    /// New buyer inventory choices are additionally closed when the runtime
    /// declares that sales have ended. Existing cart lines remain removable.
    public var canMutateInventory: Bool {
        controller.snapshot?.event.salesClosed != true && canMutateCart
    }

    public var canUndoRemoval: Bool {
        guard let undo = removalUndo,
              undo.expiresAt > Date(),
              undo.sessionId == controller.snapshot?.sessionId,
              canMutateCart else { return false }
        let present = Set((controller.snapshot?.cartLines ?? []).map(\.lineKey))
        return undo.lines.allSatisfy { !present.contains($0.lineKey) }
    }

    /// Non-replaying observations of buyer actions owned by native chrome.
    public var seatSelections: AnyPublisher<SelectedSeat, Never> {
        seatSelectionSubject.eraseToAnyPublisher()
    }

    public var seatRemovals: AnyPublisher<String, Never> {
        seatRemovalSubject.eraseToAnyPublisher()
    }

    public var seatViewOpenings: AnyPublisher<SelectedSeat, Never> {
        seatViewOpeningSubject.eraseToAnyPublisher()
    }

    public var checkoutContinuations: AnyPublisher<SeatLayerPickerCheckoutHandoff, Never> {
        checkoutContinuationSubject.eraseToAnyPublisher()
    }

    public var closures: AnyPublisher<SeatLayerPickerCloseReason, Never> {
        closureSubject.eraseToAnyPublisher()
    }

    public var nextBackStep: SeatLayerPickerBackStep {
        if activePrompt != nil { return .prompt }
        if cartSheetExpanded { return .cart }
        if controller.snapshot?.map.buyerView != "map" { return .venue }
        if pendingSeat != nil { return .confirmation }
        if controller.snapshot?.map.focusedSectionId != nil
            || (controller.snapshot?.map.rung ?? "zones") != "zones" { return .section }
        return .close
    }

    public var activePrompt: SeatLayerPickerPrompt? {
        guard canMutateInventory else { return nil }
        if let area = controller.generalAdmissionCandidate {
            return .generalAdmission(area)
        }
        if let pendingTable { return .table(pendingTable) }
        return nil
    }

    private var cancellables: Set<AnyCancellable> = []
    private var answered = Set<String>()
    private var runtimeSessionId: String?
    private var latestRevision: Int?
    private var checkoutTask: Task<SeatLayerPickerCheckoutHandoff, Error>?
    private var closeTask: Task<Void, Never>?
    private var removalUndoExpiryTask: Task<Void, Never>?
    private var didClose = false
    private let seatSelectionSubject = PassthroughSubject<SelectedSeat, Never>()
    private let seatRemovalSubject = PassthroughSubject<String, Never>()
    private let seatViewOpeningSubject = PassthroughSubject<SelectedSeat, Never>()
    private let checkoutContinuationSubject = PassthroughSubject<SeatLayerPickerCheckoutHandoff, Never>()
    private let closureSubject = PassthroughSubject<SeatLayerPickerCloseReason, Never>()

    public init(
        controller: SeatLayerPickerController,
        options: SeatLayerPickerOptions = .init()
    ) {
        self.controller = controller
        self.options = options
        self.cartSheetExpanded = !options.panelInitiallyCollapsed

        controller.$snapshot
            .sink { [weak self] snapshot in self?.apply(snapshot) }
            .store(in: &cancellables)
        controller.$lastError
            .sink { [weak self] error in self?.lastActionError = error }
            .store(in: &cancellables)
    }

    public func update(options: SeatLayerPickerOptions) {
        guard self.options != options else { return }
        self.options = options
        if options.readOnly { controller.dismissGeneralAdmissionCandidate() }
        apply(controller.snapshot, policyChanged: true)
    }

    /// Accept the currently displayed seat. Selection is already present in
    /// the runtime, so confirmation is a local acknowledgement, not a second
    /// inventory mutation.
    public func confirmPending(animateToCart: Bool = true) {
        guard let pendingSeat, let identity = identity(of: pendingSeat) else { return }
        if animateToCart { publishSelectionFlight(for: pendingSeat) }
        answered.insert(identity)
        setPendingSeat(nextPending(in: controller.snapshot))
        seatSelectionSubject.send(pendingSeat)
    }

    /// Update the local tier decision without mutating inventory. The runtime
    /// accepts the resolved tier only when `confirmPending(tierId:)` runs.
    public func choosePendingTier(_ tierId: String?) {
        guard let pendingSeat else {
            pendingTierId = nil
            return
        }
        pendingTierId = SeatLayerPickerTiering.resolvedTierId(
            for: pendingSeat,
            preferred: tierId
        )
    }

    /// Apply a pending ticket tier before locally acknowledging the seat.
    /// A failed runtime mutation deliberately leaves the card open.
    @discardableResult
    public func confirmPending(tierId: String?) async -> Bool {
        guard !actionInFlight,
              let pending = pendingSeat,
              let pendingIdentity = identity(of: pending) else { return false }
        let selectedTierId = SeatLayerPickerTiering.resolvedTierId(
            for: pending,
            preferred: tierId ?? pendingTierId
        )
        actionInFlight = true
        defer { actionInFlight = false }
        do {
            if selectedTierId != pending.tierId {
                _ = try await controller.setSeatTier(
                    seatId: pending.id,
                    tierId: selectedTierId
                )
            }
            publishSelectionFlight(for: pending)
            answered.insert(pendingIdentity)
            setPendingSeat(nextPending(in: controller.snapshot))
            seatSelectionSubject.send(confirmedSeat(pending, preferredTierId: selectedTierId))
            return true
        } catch let error as SeatLayerError {
            lastActionError = error
            controller.record(error)
            return false
        } catch {
            let wrapped = SeatLayerError.transport(error.localizedDescription)
            lastActionError = wrapped
            controller.record(wrapped)
            return false
        }
    }

    public func confirmTable(_ table: SelectedSeat) {
        guard let identity = identity(of: table) else { return }
        answered.insert(identity)
        pendingTable = nextTable(in: controller.snapshot)
    }

    /// Reject the exact pending seat and wait for the runtime snapshot that
    /// removes it. A failed deselection leaves the card visible and retryable.
    @discardableResult
    public func cancelPending() async -> Bool {
        guard !actionInFlight, let pending = pendingSeat else { return false }
        actionInFlight = true
        defer { actionInFlight = false }
        do {
            _ = try await controller.deselectObjects([pending.label])
            if let identity = identity(of: pending) { answered.insert(identity) }
            setPendingSeat(nextPending(in: controller.snapshot))
            return true
        } catch let error as SeatLayerError {
            lastActionError = error
            controller.record(error)
            return false
        } catch {
            let wrapped = SeatLayerError.transport(error.localizedDescription)
            lastActionError = wrapped
            controller.record(wrapped)
            return false
        }
    }

    @discardableResult
    public func cancelTable() async -> Bool {
        guard !actionInFlight, let table = pendingTable else { return false }
        actionInFlight = true
        defer { actionInFlight = false }
        do {
            _ = try await controller.deselectObjects([table.label])
            if let identity = identity(of: table) { answered.insert(identity) }
            pendingTable = nextTable(in: controller.snapshot)
            return true
        } catch let error as SeatLayerError {
            lastActionError = error
            controller.record(error)
            return false
        } catch {
            let wrapped = SeatLayerError.transport(error.localizedDescription)
            lastActionError = wrapped
            controller.record(wrapped)
            return false
        }
    }

    public func dismissActionError() {
        lastActionError = nil
        controller.dismissError()
    }

    /// Remove confirmed cart inventory through the serialized controller and
    /// publish only after the runtime accepts the mutation.
    public func removeCartLines(_ labels: [String]) async throws {
        var seen: Set<String> = []
        let labels = labels.filter { !$0.isEmpty && seen.insert($0).inserted }
        guard !labels.isEmpty else { return }
        try requireCartMutation()
        let sessionId = try currentSessionId()
        let lines = labels.compactMap { label in
            confirmedCartLines.first { $0.label == label }
        }
        guard lines.count == labels.count else { throw cartLineUnavailable() }
        actionInFlight = true
        defer { actionInFlight = false }
        var removed: [SeatLayerPickerCartLine] = []
        do {
            for line in lines {
                _ = try await controller.removeCartLine(label: line.label)
                removed.append(line)
                seatRemovalSubject.send(line.label)
            }
        } catch {
            if !removed.isEmpty { beginRemovalUndo(lines: removed, sessionId: sessionId) }
            throw error
        }
        beginRemovalUndo(lines: removed, sessionId: sessionId)
    }

    public func removeCartLine(_ label: String) async throws {
        guard !label.isEmpty else { return }
        try requireCartMutation()
        let sessionId = try currentSessionId()
        guard let line = confirmedCartLines.first(where: { $0.label == label }) else {
            throw cartLineUnavailable()
        }
        actionInFlight = true
        defer { actionInFlight = false }
        _ = try await controller.removeCartLine(label: label)
        seatRemovalSubject.send(label)
        beginRemovalUndo(lines: [line], sessionId: sessionId)
    }

    @discardableResult
    public func undoRemoval() async throws -> Bool {
        guard canUndoRemoval, let undo = removalUndo else { return false }
        actionInFlight = true
        defer { actionInFlight = false }
        var restored: [SeatLayerPickerCartLine] = []
        do {
            for line in undo.lines {
                try await restoreCartLine(line)
                restored.append(line)
            }
            clearRemovalUndo()
            return true
        } catch {
            // A tier or quantity command can fail after the label was selected.
            // Remove only the lines restored by this attempt so a retry cannot
            // silently keep a default tier or quantity in the buyer's cart.
            for line in restored.reversed() {
                _ = try? await controller.removeCartLine(label: line.label)
            }
            throw error
        }
    }

    @discardableResult
    public func setTableQuantity(label: String, quantity: Int) async throws -> Bool {
        guard !label.isEmpty, quantity > 0 else { return false }
        guard controller.snapshot?.event.salesClosed != true else {
            throw SeatLayerError.bridge(.init(
                code: "sales_closed",
                message: "ticket sales for this event have ended"
            ))
        }
        try requireCartMutation()
        actionInFlight = true
        defer { actionInFlight = false }
        _ = try await controller.setTableQuantity(label: label, quantity: quantity)
        return true
    }

    /// Record a successful native inspection action without changing selection.
    public func recordSeatViewOpened(_ seat: SelectedSeat) {
        seatViewOpeningSubject.send(seat)
    }

    /// Create or reuse the authoritative hold and deliver it to the host once.
    /// If the host rejects the handoff by throwing, the runtime releases that
    /// exact hold and the buyer stays in the picker.
    @discardableResult
    public func checkout(
        using handler: @escaping SeatLayerPickerCheckoutHandler
    ) async throws -> SeatLayerPickerCheckoutHandoff {
        if let checkoutHandoff { return checkoutHandoff }
        if let checkoutTask { return try await checkoutTask.value }

        let task = Task { @MainActor [weak self, controller, options] in
            let handoff = try await controller.checkout(ttlMs: options.normalizedHoldTtlMs)
            self?.checkoutContinuationSubject.send(handoff)
            do {
                try await handler(handoff)
                return handoff
            } catch {
                _ = try? await controller.rejectHandoff(handoff.holdId)
                throw error
            }
        }
        checkoutTask = task
        actionInFlight = true
        defer {
            checkoutTask = nil
            actionInFlight = false
        }
        do {
            let handoff = try await task.value
            checkoutHandoff = handoff
            return handoff
        } catch let error as SeatLayerError {
            lastActionError = error
            controller.record(error)
            throw error
        } catch {
            let wrapped = SeatLayerError.transport(error.localizedDescription)
            lastActionError = wrapped
            controller.record(wrapped)
            throw wrapped
        }
    }

    /// Close the picker without touching a hold already handed to the host.
    /// The runtime's `picker.abort` releases picker-owned inventory only.
    public func close(
        using handler: (@MainActor () async -> Void)? = nil
    ) async {
        await close(using: handler, reason: .programmatic)
    }

    public func close(
        using handler: (@MainActor () async -> Void)? = nil,
        reason: SeatLayerPickerCloseReason
    ) async {
        guard !didClose else { return }
        if let closeTask { return await closeTask.value }
        let task = Task { @MainActor [controller] in
            _ = try? await controller.abort()
            await handler?()
        }
        closeTask = task
        await task.value
        closeTask = nil
        guard !didClose else { return }
        didClose = true
        closureSubject.send(reason)
    }

    /// Consume one layer of the shared back ladder. The host close callback is
    /// reached only after cart, confirmation, section, and venue state are gone.
    @discardableResult
    public func back(
        using handler: (@MainActor () async -> Void)? = nil
    ) async -> SeatLayerPickerBackStep {
        await back(using: handler, closeReason: .programmatic)
    }

    @discardableResult
    public func back(
        using handler: (@MainActor () async -> Void)? = nil,
        closeReason: SeatLayerPickerCloseReason
    ) async -> SeatLayerPickerBackStep {
        let step = nextBackStep
        switch step {
        case .prompt:
            switch activePrompt {
            case .generalAdmission:
                controller.dismissGeneralAdmissionCandidate()
            case .table:
                _ = await cancelTable()
            case nil:
                break
            }
        case .cart:
            cartSheetExpanded = false
        case .confirmation:
            _ = await cancelPending()
        case .section:
            do { try await controller.zoomOut() }
            catch let error as SeatLayerError { controller.record(error) }
            catch { controller.record(.transport(error.localizedDescription)) }
        case .venue:
            do {
                if let snapshot = controller.snapshot,
                   let request = SeatLayerPickerImmersive.request(
                       for: .back,
                       snapshot: snapshot
                   ) {
                    _ = try await controller.setBuyerView(
                        request.view,
                        flyToSeatId: request.flyToSeatId,
                        resetView: request.resetView
                    )
                }
            } catch let error as SeatLayerError { controller.record(error) }
            catch { controller.record(.transport(error.localizedDescription)) }
        case .close:
            await close(using: handler, reason: closeReason)
        }
        return step
    }

    private func apply(
        _ snapshot: SeatLayerPickerSnapshot?,
        policyChanged: Bool = false
    ) {
        guard let snapshot else {
            runtimeSessionId = nil
            latestRevision = nil
            answered.removeAll()
            setPendingSeat(nil)
            pendingTable = nil
            checkoutHandoff = nil
            selectionFlight = nil
            clearRemovalUndo()
            didClose = false
            return
        }
        if runtimeSessionId == snapshot.sessionId {
            if !policyChanged, let latestRevision, snapshot.revision < latestRevision { return }
        } else {
            runtimeSessionId = snapshot.sessionId
            answered.removeAll()
            checkoutHandoff = nil
            selectionFlight = nil
            didClose = false
            clearRemovalUndo()
        }
        latestRevision = snapshot.revision
        if options.readOnly || snapshot.event.salesClosed || snapshot.hold.active {
            controller.dismissGeneralAdmissionCandidate()
        }
        let present = Set(snapshot.selection.compactMap(identity))
        answered = answered.intersection(present)
        setPendingSeat(nextPending(in: snapshot))
        pendingTable = nextTable(in: snapshot)
        if let undo = removalUndo {
            let present = Set(snapshot.cartLines.map(\.lineKey))
            if undo.lines.contains(where: { present.contains($0.lineKey) }) {
                clearRemovalUndo()
            }
        }
    }

    private func nextPending(in snapshot: SeatLayerPickerSnapshot?) -> SelectedSeat? {
        guard let snapshot,
              options.confirmSelection,
              !options.readOnly,
              !snapshot.hold.active else { return nil }
        return snapshot.selection.reversed().first { seat in
            guard seat.objectType?.rawValue != "table" || seat.bookingMode != "variable",
                  let identity = identity(of: seat) else { return false }
            return !answered.contains(identity)
        }
    }

    private func nextTable(in snapshot: SeatLayerPickerSnapshot?) -> SelectedSeat? {
        guard let snapshot,
              !options.readOnly,
              !snapshot.hold.active else { return nil }
        return snapshot.selection.reversed().first { seat in
            guard seat.objectType?.rawValue == "table",
                  seat.bookingMode == "variable",
                  let identity = identity(of: seat) else { return false }
            return !answered.contains(identity)
        }
    }

    private func identity(of seat: SelectedSeat) -> String? {
        SeatLayerPickerProjections.seatIdentity(seat)
    }

    private func setPendingSeat(_ next: SelectedSeat?) {
        let previousIdentity = pendingSeat.flatMap(identity)
        let nextIdentity = next.flatMap(identity)
        pendingSeat = next
        guard let next else {
            pendingTierId = nil
            return
        }
        pendingTierId = SeatLayerPickerTiering.resolvedTierId(
            for: next,
            preferred: previousIdentity == nextIdentity ? pendingTierId : nil
        )
    }

    private func publishSelectionFlight(for seat: SelectedSeat) {
        selectionFlight = .init(
            seatId: seat.id,
            label: seat.label,
            categoryKey: seat.categoryKey
        )
    }

    private func confirmedSeat(
        _ pending: SelectedSeat,
        preferredTierId: String?
    ) -> SelectedSeat {
        if let current = controller.snapshot?.selection.first(where: {
            identity(of: $0) == identity(of: pending)
        }) {
            return current
        }
        var confirmed = pending
        let quote = SeatLayerPickerTiering.quote(
            for: pending,
            preferred: preferredTierId,
            fallbackCurrency: controller.snapshot?.currency
        )
        confirmed.tierId = quote?.tierId
        confirmed.price = quote?.amount ?? confirmed.price
        confirmed.currency = quote?.currency ?? confirmed.currency
        return confirmed
    }

    private func currentSessionId() throws -> String {
        guard let sessionId = controller.snapshot?.sessionId else {
            throw SeatLayerError.bridge(.init(code: "not_ready", message: "the picker has no active session"))
        }
        return sessionId
    }

    private func restoreCartLine(_ line: SeatLayerPickerCartLine) async throws {
        if line.objectType == "ga" {
            if let tierId = line.tierId {
                _ = try await controller.holdGeneralAdmission(
                    areaId: line.objectId,
                    quantity: max(1, line.quantity),
                    tierId: .some(tierId),
                    ttlMs: options.normalizedHoldTtlMs
                )
            } else {
                _ = try await controller.holdGeneralAdmission(
                    areaId: line.objectId,
                    quantity: max(1, line.quantity),
                    ttlMs: options.normalizedHoldTtlMs
                )
            }
            return
        }

        _ = try await controller.selectObjects([line.label])
        do {
            if line.objectType == "table", line.quantity > 0 {
                _ = try await controller.setTableQuantity(
                    label: line.label,
                    quantity: line.quantity,
                    ttlMs: options.normalizedHoldTtlMs
                )
            }
            guard let tierId = line.tierId else { return }
            let selectedSeatId = controller.snapshot?.selection.first(where: {
                $0.label == line.label || $0.id == line.seatId
            })?.id ?? line.seatId
            guard let selectedSeatId, !selectedSeatId.isEmpty else {
                throw cartLineUnavailable()
            }
            _ = try await controller.setSeatTier(seatId: selectedSeatId, tierId: tierId)
        } catch {
            _ = try? await controller.removeCartLine(label: line.label)
            throw error
        }
    }

    private func requireCartMutation() throws {
        if actionInFlight {
            throw SeatLayerError.bridge(.init(code: "busy", message: "a picker action is already in progress"))
        }
        guard controller.isReady else {
            throw SeatLayerError.bridge(.init(code: "not_ready", message: "the picker is not ready"))
        }
        guard !options.readOnly else {
            throw SeatLayerError.bridge(.init(code: "read_only", message: "the picker is read-only"))
        }
        if let hold = controller.snapshot?.hold, hold.active, hold.owner != "picker" {
            throw SeatLayerError.bridge(.init(
                code: "hold_owned_by_host",
                message: "the active hold belongs to the host"
            ))
        }
    }

    private func cartLineUnavailable() -> SeatLayerError {
        SeatLayerError.bridge(.init(
            code: "cart_line_unavailable",
            message: "the cart line is no longer available"
        ))
    }

    private func beginRemovalUndo(
        lines: [SeatLayerPickerCartLine],
        sessionId: String
    ) {
        guard !lines.isEmpty else { return }
        removalUndoExpiryTask?.cancel()
        let undo = SeatLayerPickerRemovalUndo(
            sessionId: sessionId,
            lines: lines,
            expiresAt: Date().addingTimeInterval(
                Double(SeatLayerPickerMotionTokens.undoWindowMilliseconds) / 1_000
            )
        )
        removalUndo = undo
        removalUndoExpiryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(SeatLayerPickerMotionTokens.undoWindowMilliseconds) * 1_000_000
            )
            guard !Task.isCancelled, self?.removalUndo?.id == undo.id else { return }
            self?.clearRemovalUndo()
        }
    }

    private func clearRemovalUndo() {
        removalUndoExpiryTask?.cancel()
        removalUndoExpiryTask = nil
        removalUndo = nil
    }
}
#endif
