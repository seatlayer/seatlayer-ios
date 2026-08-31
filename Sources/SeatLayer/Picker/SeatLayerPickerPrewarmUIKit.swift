#if canImport(UIKit)
import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

/// UIKit-accessible prewarm surface. Prewarming loads only the pinned page;
/// event configuration and credentials are supplied after one-time transfer.
@MainActor
public enum SeatLayerPickerPrewarming {
    public static func prewarm(
        pageURL: URL = SeatLayer.mobilePageURL,
        ttl: TimeInterval = seatLayerPickerPrewarmDefaultTTL
    ) async throws {
        try await SeatLayerPickerPrewarmPool.shared.prewarm(pageURL: pageURL, ttl: ttl)
    }

    public static func cancelPrewarm() {
        SeatLayerPickerPrewarmPool.shared.cancel()
    }

    public static var status: SeatLayerPickerPrewarmStatus {
        SeatLayerPickerPrewarmPool.shared.status
    }
}

#if canImport(SwiftUI)
public extension SeatLayerPicker {
    static func prewarm(
        pageURL: URL = SeatLayer.mobilePageURL,
        ttl: TimeInterval = seatLayerPickerPrewarmDefaultTTL
    ) async throws {
        try await SeatLayerPickerPrewarming.prewarm(pageURL: pageURL, ttl: ttl)
    }

    static func cancelPrewarm() {
        SeatLayerPickerPrewarming.cancelPrewarm()
    }

    static var prewarmStatus: SeatLayerPickerPrewarmStatus {
        SeatLayerPickerPrewarming.status
    }
}
#endif

@MainActor
final class SeatLayerPickerPrewarmPool {
    static let shared = SeatLayerPickerPrewarmPool()

    private var ledger = SeatLayerPickerPrewarmLedger()
    private var hosted: (generation: Int, host: SeatLayerWebHost)?
    private var expiryTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private(set) var status: SeatLayerPickerPrewarmStatus = .idle

    private init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.cancel() }
        })
        observers.append(center.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.cancel() }
        })
    }

    func prewarm(pageURL: URL, ttl: TimeInterval) async throws {
        guard let ttl = normalizedSeatLayerPickerPrewarmTTL(ttl) else {
            throw SeatLayerError.decoding("prewarm TTL must be a positive finite interval")
        }
        let now = Date().timeIntervalSinceReferenceDate
        let decision = ledger.start(pageURL: pageURL, now: now, ttl: ttl)
        switch decision {
        case .reuse(let generation):
            guard let hosted, hosted.generation == generation else {
                _ = ledger.cancel()
                return try await prewarm(pageURL: pageURL, ttl: ttl)
            }
            try await hosted.host.waitUntilNavigationFinished()

        case .replace(let previousGeneration, let entry):
            if previousGeneration != nil || hosted != nil {
                hosted?.host.cancelPrewarm()
                hosted = nil
            }
            expiryTask?.cancel()
            let host = SeatLayerWebHost()
            host.beginPrewarm(pageURL: pageURL)
            hosted = (entry.generation, host)
            status = .loading
            scheduleExpiry(entry)
            do {
                try await host.waitUntilNavigationFinished()
                if hosted?.generation == entry.generation { status = .ready }
            } catch {
                if hosted?.generation == entry.generation {
                    hosted = nil
                    _ = ledger.cancel()
                    expiryTask?.cancel()
                    expiryTask = nil
                    status = .idle
                }
                throw error
            }
        }
    }

    func consume(pageURL: URL) -> SeatLayerWebHost? {
        let now = Date().timeIntervalSinceReferenceDate
        guard let generation = ledger.consume(pageURL: pageURL, now: now),
              let hosted,
              hosted.generation == generation else {
            // A page mismatch or an already-expired ledger entry must not leave
            // a detached page alive until a later TTL callback.
            cancel()
            return nil
        }
        self.hosted = nil
        expiryTask?.cancel()
        expiryTask = nil
        status = .idle
        return hosted.host
    }

    func cancel() {
        _ = ledger.cancel()
        hosted?.host.cancelPrewarm()
        hosted = nil
        expiryTask?.cancel()
        expiryTask = nil
        status = .idle
    }

    private func scheduleExpiry(_ entry: SeatLayerPickerPrewarmLedger.Entry) {
        let remaining = max(
            0,
            entry.expiresAt - Date().timeIntervalSinceReferenceDate
        )
        let nanoseconds = UInt64(min(remaining, 86_400) * 1_000_000_000)
        expiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled, let self else { return }
            let generation = self.ledger.expire(
                now: Date().timeIntervalSinceReferenceDate
            )
            guard generation == entry.generation else {
                // Long finite TTLs sleep in bounded chunks so the nanosecond
                // conversion cannot overflow and expiry is still eventually
                // enforced.
                if self.ledger.entry?.generation == entry.generation {
                    self.scheduleExpiry(entry)
                }
                return
            }
            if self.hosted?.generation == entry.generation {
                self.hosted?.host.cancelPrewarm()
                self.hosted = nil
            }
            self.status = .idle
            self.expiryTask = nil
        }
    }
}
#endif
