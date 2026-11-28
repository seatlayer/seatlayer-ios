#if canImport(UIKit)
import UIKit

/// Loads one hosted surface into its view once, and answers the system
/// ending the page after it was ready, mostly to free memory: it is loaded
/// again at once when the app is in front and otherwise when it comes back.
/// Two pages ended within a minute are replaced; the third fails.
@MainActor
final class SeatLayerSurfaceLoader {
    let view: SeatLayerView
    private var surface: (any SeatLayerSurfaceLoading)?
    private var loadTask: Task<Void, Never>?
    private var waiters: [UUID: CheckedContinuation<ReadyInfo, Error>] = [:]
    private var loaded: ReadyInfo?
    private var recovery = SeatLayerPickerPageRecovery()
    private var awaitingActive: NSObjectProtocol?
    /// Whether the app is in front. Read when the system ends the page: a page
    /// of an app in the background is mostly ended there, and reloading it
    /// there would only be ended again.
    var applicationIsActive: () -> Bool = {
        UIApplication.shared.applicationState == .active
    }
    /// The page is gone: what it reported goes with it.
    var onPageLost: () -> Void = {}
    /// The system keeps ending the page.
    var onGiveUp: (SeatLayerError) -> Void = { _ in }
    /// Readies the profile for the replacement page. By default the
    /// replacement does not start on the app's initial hold: it may be gone
    /// by then, and a page that cannot take it up fails to start.
    var prepareReplacement: (() -> Void)?
    /// Loads the replacement page. By default this loader's own `load`.
    var reload: (() async -> Void)?

    init(view: SeatLayerView, surface: any SeatLayerSurfaceLoading) {
        self.view = view
        self.surface = surface
        view.onPageLost = { [weak self] in self?.pageLost() }
    }

    deinit {
        if let awaitingActive { NotificationCenter.default.removeObserver(awaitingActive) }
        loadTask?.cancel()
        let pending = Array(waiters.values)
        waiters.removeAll(keepingCapacity: false)
        for waiter in pending { waiter.resume(throwing: SeatLayerError.destroyed) }
        let view = view
        Task { @MainActor in try? await view.destroy() }
    }

    func pageLost(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard surface != nil else { return }
        onPageLost()
        loaded = nil
        guard recovery.lost(at: now) else {
            onGiveUp(.transport("The system keeps closing the SeatLayer page."))
            return
        }
        if let prepareReplacement {
            prepareReplacement()
        } else {
            view.dropInitialHoldFromPageStart()
        }
        stopAwaitingActive()
        guard applicationIsActive() else {
            awaitingActive = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.reloadLostPage() }
            }
            return
        }
        reloadLostPage()
    }

    /// A buyer's retry after a failure starts the count again.
    func resetRecovery() {
        recovery.reset()
    }

    private func reloadLostPage() {
        stopAwaitingActive()
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let reload = self.reload {
                await reload()
            } else {
                _ = try? await self.load()
            }
        }
    }

    private func stopAwaitingActive() {
        if let awaitingActive {
            NotificationCenter.default.removeObserver(awaitingActive)
            self.awaitingActive = nil
        }
    }

    /// Starts the page once and awaits its handshake.
    @discardableResult
    func load() async throws -> ReadyInfo {
        if let loaded { return loaded }
        guard let surface else { throw SeatLayerError.destroyed }
        let waiter = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                waiters[waiter] = continuation
                guard loadTask == nil else { return }
                loadTask = Task { @MainActor [weak self, surface, view] in
                    do {
                        let ready = try await view.load(surface: surface)
                        self?.finishLoad(.success(ready))
                    } catch {
                        self?.finishLoad(.failure(error))
                    }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancelWaiter(waiter) }
        }
    }

    /// Tears the page down; later loads fail.
    func destroy() async {
        stopAwaitingActive()
        loadTask?.cancel()
        loadTask = nil
        loaded = nil
        finishLoad(.failure(SeatLayerError.destroyed))
        surface = nil
        try? await view.destroy()
    }

    private func finishLoad(_ result: Result<ReadyInfo, Error>) {
        loadTask = nil
        if case .success(let info) = result { loaded = info }
        let pending = Array(waiters.values)
        waiters.removeAll(keepingCapacity: false)
        for waiter in pending { waiter.resume(with: result) }
    }

    private func cancelWaiter(_ id: UUID) {
        waiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }
}
#endif
