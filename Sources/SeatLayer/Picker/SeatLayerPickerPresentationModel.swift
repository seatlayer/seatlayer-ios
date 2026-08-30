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

/// Local native-chrome state layered over immutable runtime snapshots.
///
/// The runtime remains authoritative for selection, cart prices, quantities,
/// holds, and revisions. This model owns only presentation facts such as an
/// unanswered confirmation card and whether the cart sheet is expanded.
@MainActor
public final class SeatLayerPickerPresentationModel: ObservableObject {
    @Published public private(set) var pendingSeat: SelectedSeat?
    @Published public private(set) var pendingTable: SelectedSeat?
    @Published public private(set) var actionInFlight = false
    @Published public private(set) var checkoutHandoff: SeatLayerPickerCheckoutHandoff?
    @Published public private(set) var lastActionError: SeatLayerError?
    @Published public private(set) var selectionFlight: SeatLayerPickerSelectionFlightMoment?
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
        SeatLayerPickerProjections.totals(confirmedCartLines).quantity
    }

    public var confirmedCartTotal: Double {
        SeatLayerPickerProjections.totals(confirmedCartLines).total
    }

    public var canCheckout: Bool {
        guard controller.isReady,
              !options.readOnly,
              !actionInFlight,
              checkoutHandoff == nil,
              activePrompt == nil,
              pendingSeat == nil,
              !confirmedCartLines.isEmpty,
              controller.snapshot?.hold.owner != "host" else { return false }
        return controller.snapshot?.selectionValidity?.isValid != false
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
            .compactMap { $0 }
            .sink { [weak self] error in self?.lastActionError = error }
            .store(in: &cancellables)
    }

    public func update(options: SeatLayerPickerOptions) {
        guard self.options != options else { return }
        self.options = options
        apply(controller.snapshot, policyChanged: true)
    }

    /// Accept the currently displayed seat. Selection is already present in
    /// the runtime, so confirmation is a local acknowledgement, not a second
    /// inventory mutation.
    public func confirmPending(animateToCart: Bool = true) {
        guard let pendingSeat, let identity = identity(of: pendingSeat) else { return }
        if animateToCart { publishSelectionFlight(for: pendingSeat) }
        answered.insert(identity)
        self.pendingSeat = nextPending(in: controller.snapshot)
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
            preferred: tierId
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
            pendingSeat = nextPending(in: controller.snapshot)
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
            pendingSeat = nextPending(in: controller.snapshot)
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

        let task = Task { @MainActor [controller, options] in
            let handoff = try await controller.checkout(ttlMs: options.holdTtlMs)
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
    public func close(using handler: (@MainActor () async -> Void)? = nil) async {
        if let closeTask { return await closeTask.value }
        let task = Task { @MainActor [controller] in
            _ = try? await controller.abort()
            await handler?()
        }
        closeTask = task
        await task.value
        closeTask = nil
    }

    /// Consume one layer of the shared back ladder. The host close callback is
    /// reached only after cart, confirmation, section, and venue state are gone.
    @discardableResult
    public func back(using handler: (@MainActor () async -> Void)? = nil) async -> SeatLayerPickerBackStep {
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
            await close(using: handler)
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
            pendingSeat = nil
            pendingTable = nil
            checkoutHandoff = nil
            selectionFlight = nil
            return
        }
        if runtimeSessionId == snapshot.sessionId {
            if !policyChanged, let latestRevision, snapshot.revision < latestRevision { return }
        } else {
            runtimeSessionId = snapshot.sessionId
            answered.removeAll()
            checkoutHandoff = nil
            selectionFlight = nil
        }
        latestRevision = snapshot.revision
        let present = Set(snapshot.selection.compactMap(identity))
        answered = answered.intersection(present)
        pendingSeat = nextPending(in: snapshot)
        pendingTable = nextTable(in: snapshot)
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

    private func publishSelectionFlight(for seat: SelectedSeat) {
        selectionFlight = .init(
            seatId: seat.id,
            label: seat.label,
            categoryKey: seat.categoryKey
        )
    }
}
#endif
