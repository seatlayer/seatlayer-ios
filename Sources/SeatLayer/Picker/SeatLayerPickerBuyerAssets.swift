import Foundation

/// How the bytes for one event-scoped image are actually fetched.
///
/// Injected so tests never open a socket, and so a host with its own HTTP
/// stack — a proxy, a pinned session, an offline cache — can supply one.
public typealias SeatLayerAssetFetch =
    @Sendable (URL, [String: String]) async throws -> Data

/// Fetches the buyer-scoped images the native chrome draws itself.
///
/// A seat-view thumbnail is NOT a plain image URL. On a private event the same
/// path answers 401 without the buyer's bearer, and handing that bearer to a
/// shared image loader would leak it into a cache key nobody owns. So this
/// mirrors the runtime's own transport — `GET {apiBase}{reference}` with an
/// `Authorization: Bearer …` header and no cookies — and keeps the bytes in a
/// small cache of its own.
///
/// **Every failure resolves to nil.** "No photograph" is an ordinary state of
/// the seat card, and a thrown error there would take down a card the buyer is
/// in the middle of answering. Nothing here is logged either: the failure may
/// carry the request that carried the bearer.
@MainActor
public final class SeatLayerBuyerAssetLoader {
    /// The default API origin, matching the runtime's own.
    public static let defaultAPIBase = "https://api.seatlayer.io"

    /// How many decoded references the loader keeps.
    public static let cacheEntries = 12

    /// How long before a bearer's stated expiry it stops being used.
    public static let tokenSafetyMargin: TimeInterval = 30

    /// How long the default transport may take before the card gives up.
    ///
    /// Without this a stalled connection would leave the strip on its loading
    /// gradient for as long as the card is up, and the buyer would never get
    /// the plain card the miss path promises. An injected fetch owns its own
    /// timeout.
    public nonisolated static let fetchTimeout: TimeInterval = 15

    /// The event every reference has to belong to.
    public let eventKey: String

    /// The API origin the reference is resolved against.
    public let apiBase: String

    private let tokenProvider: BuyerAccessTokenProvider?
    private let fetch: SeatLayerAssetFetch
    private var token: BuyerAccessToken?
    /// Insertion-ordered, so the oldest read is the one evicted.
    private var order: [String] = []
    private var bytes: [String: Data] = [:]
    private var inFlight: [String: Task<Data?, Never>] = [:]

    public init(
        eventKey: String,
        apiBase: String? = nil,
        token: BuyerAccessToken? = nil,
        tokenProvider: BuyerAccessTokenProvider? = nil,
        fetch: SeatLayerAssetFetch? = nil
    ) {
        self.eventKey = eventKey
        var base = apiBase ?? SeatLayerBuyerAssetLoader.defaultAPIBase
        while base.hasSuffix("/") { base.removeLast() }
        self.apiBase = base
        self.token = token
        self.tokenProvider = tokenProvider
        self.fetch = fetch ?? seatLayerDefaultAssetFetch
    }

    /// A loader built from what the host configured the picker with.
    public convenience init(
        configuration: SeatLayerConfiguration,
        fetch: SeatLayerAssetFetch? = nil
    ) {
        self.init(
            eventKey: configuration.event,
            apiBase: configuration.apiBase,
            token: configuration.buyerAccessToken,
            tokenProvider: configuration.buyerAccessTokenProvider,
            fetch: fetch
        )
    }

    /// The bytes for `reference`, or nil when there is no photograph to show.
    ///
    /// Nil covers every reason at once — a reference this event does not own, a
    /// 403 or 404, no bearer, a dead network — because the card does the same
    /// thing for all of them.
    public func load(_ reference: String) async -> Data? {
        if let cached = bytes[reference] {
            // Reading an entry makes it the most recent one.
            order.removeAll { $0 == reference }
            order.append(reference)
            return cached
        }
        // One request per reference however many cards ask for it: two seats in
        // the same row can share a photograph, and a buyer scrubbing the map
        // can reopen the same card before the first fetch has landed.
        if let running = inFlight[reference] { return await running.value }
        let task = Task { @MainActor [weak self] in
            await self?.perform(reference)
        }
        inFlight[reference] = task
        let result = await task.value
        inFlight[reference] = nil
        return result
    }

    /// Forget `reference`, so the next open fetches it again.
    ///
    /// The usual reason for a miss is a bearer that had just expired, and the
    /// buyer's next tap on the same seat should not be told the same lie.
    public func evict(_ reference: String) {
        bytes[reference] = nil
        order.removeAll { $0 == reference }
    }

    /// Forget everything. Called when the picker session ends.
    public func clear() {
        bytes.removeAll()
        order.removeAll()
        for task in inFlight.values { task.cancel() }
        inFlight.removeAll()
        token = nil
    }

    /// The absolute URL `reference` names, or nil when it is not this event's.
    ///
    /// The runtime already applies this predicate before emitting the field; it
    /// is applied again here because a reference that reached this side wrong
    /// is a request that must not be MADE, not a request that fails.
    public func resolve(_ reference: String) -> URL? {
        guard let event = seatLayerAssetReferenceEvent(reference),
              event == eventKey,
              !eventKey.isEmpty else { return nil }
        return URL(string: apiBase + reference)
    }

    private func perform(_ reference: String) async -> Data? {
        guard let url = resolve(reference) else { return nil }
        guard let authorization = await authorizationHeader() else { return nil }
        do {
            let data = try await fetch(url, ["Authorization": authorization])
            guard !data.isEmpty else { return nil }
            remember(reference, data)
            return data
        } catch {
            // Deliberately opaque: the failure may carry the request that
            // carried the bearer, and nothing here may log or rethrow it.
            return nil
        }
    }

    private func remember(_ reference: String, _ data: Data) {
        bytes[reference] = data
        order.removeAll { $0 == reference }
        order.append(reference)
        while order.count > SeatLayerBuyerAssetLoader.cacheEntries {
            bytes[order.removeFirst()] = nil
        }
    }

    /// The `Authorization` header value, or nil when this event has none of the
    /// sort the host can supply.
    private func authorizationHeader() async -> String? {
        if let held = token, !SeatLayerBuyerAssetLoader.isExpiring(held) {
            return "Bearer \(held.token)"
        }
        guard let tokenProvider else {
            // A one-shot token that has already expired is not refreshable, and
            // a public event has no token at all. Both are "no photograph" —
            // except that a stale one is still worth one attempt.
            return token.map { "Bearer \($0.token)" }
        }
        do {
            // `asset` is not one of the reasons this build's enum names, and
            // the open enum carries it through verbatim: the host's provider
            // sees the same string every other SeatLayer SDK sends.
            let fresh = try await tokenProvider(.init(reason: .unknown("asset")))
            token = fresh
            return "Bearer \(fresh.token)"
        } catch {
            return nil
        }
    }

    static func isExpiring(_ token: BuyerAccessToken) -> Bool {
        guard let expiresAt = token.expiresAt, expiresAt.isFinite else { return false }
        let deadline = Date(timeIntervalSince1970: expiresAt / 1000)
            .addingTimeInterval(-SeatLayerBuyerAssetLoader.tokenSafetyMargin)
        return Date() >= deadline
    }
}

/// The event a `/pub/events/{key}/assets/{asset}` reference belongs to, or nil
/// for anything that is not one.
///
/// Deliberately not a general URL parser: the only shape the runtime emits is
/// this one, and anything else is a request this side must not make.
public func seatLayerAssetReferenceEvent(_ reference: String) -> String? {
    let prefix = "/pub/events/"
    guard reference.hasPrefix(prefix) else { return nil }
    let rest = reference.dropFirst(prefix.count)
    guard let separator = rest.range(of: "/assets/") else { return nil }
    let event = String(rest[rest.startIndex..<separator.lowerBound])
    let asset = String(rest[separator.upperBound...])
    guard !event.isEmpty, !event.contains("/"), !asset.isEmpty else { return nil }
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
    guard asset.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
    return event.removingPercentEncoding ?? event
}

/// The default transport: `URLSession`, so the package gains no dependency.
///
/// Ephemeral rather than shared: a bearer-carrying request has no business in
/// the process-wide URL cache or cookie store.
private let seatLayerDefaultAssetFetch: SeatLayerAssetFetch = { url, headers in
    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil
    configuration.httpCookieAcceptPolicy = .never
    configuration.httpShouldSetCookies = false
    configuration.timeoutIntervalForRequest = SeatLayerBuyerAssetLoader.fetchTimeout
    let session = URLSession(configuration: configuration)
    defer { session.finishTasksAndInvalidate() }
    var request = URLRequest(url: url)
    for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse,
          (200..<300).contains(http.statusCode) else {
        throw SeatLayerAssetUnavailable()
    }
    return data
}

/// Carries no status, no URL and no headers — see `SeatLayerBuyerAssetLoader`.
struct SeatLayerAssetUnavailable: Error {}

@MainActor
extension SeatLayerPickerController {
    /// Whether the runtime reports authored seat-view photographs, the distance
    /// to the stage and the seat's confidence disclosure.
    ///
    /// Read off the handshake rather than off the snapshot: `snapshot.features`
    /// says which features the EVENT has, and this says whether the bundle
    /// speaks the fields at all. A runtime that predates them simply omits
    /// them, and the card is then the card it was before this existed.
    public var supportsSeatViewThumbnails: Bool {
        supports(capability: seatLayerSeatViewThumbnailCapability)
    }
}

/// The capability that gates the photograph, the sight line and the passport.
public let seatLayerSeatViewThumbnailCapability = "seat-view-thumbnail-v1"

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

private struct SeatLayerBuyerAssetLoaderKey: EnvironmentKey {
    /// A controller with no session above it gets an inert loader that resolves
    /// every reference to nil, so the card's code path is the same whether or
    /// not a session is attached.
    @MainActor
    static let defaultValue = SeatLayerBuyerAssetLoader(eventKey: "")
}

extension EnvironmentValues {
    /// The transport for this session's buyer-scoped images.
    public var seatLayerBuyerAssetLoader: SeatLayerBuyerAssetLoader {
        get { self[SeatLayerBuyerAssetLoaderKey.self] }
        set { self[SeatLayerBuyerAssetLoaderKey.self] = newValue }
    }
}

extension View {
    /// Bind the buyer-scoped image transport for `configuration`.
    ///
    /// One loader per event: the cache is what makes reopening the same seat
    /// instant, so it must not be rebuilt on every layout pass.
    public func seatLayerBuyerAssets(
        for configuration: SeatLayerConfiguration,
        fetch: SeatLayerAssetFetch? = nil
    ) -> some View {
        modifier(SeatLayerBuyerAssetBinding(configuration: configuration, fetch: fetch))
    }
}

private struct SeatLayerBuyerAssetBinding: ViewModifier {
    let configuration: SeatLayerConfiguration
    let fetch: SeatLayerAssetFetch?
    @StateObject private var box = SeatLayerBuyerAssetLoaderBox()

    func body(content: Content) -> some View {
        content
            .environment(
                \.seatLayerBuyerAssetLoader,
                box.loader(for: configuration, fetch: fetch)
            )
    }
}

@MainActor
private final class SeatLayerBuyerAssetLoaderBox: ObservableObject {
    private var current: SeatLayerBuyerAssetLoader?

    nonisolated init() {}

    func loader(
        for configuration: SeatLayerConfiguration,
        fetch: SeatLayerAssetFetch?
    ) -> SeatLayerBuyerAssetLoader {
        if let current, current.eventKey == configuration.event, fetch == nil {
            return current
        }
        current?.clear()
        let next = SeatLayerBuyerAssetLoader(configuration: configuration, fetch: fetch)
        current = next
        return next
    }

    deinit {
        let loader = current
        Task { @MainActor in loader?.clear() }
    }
}
#endif
