#if canImport(UIKit)
import UIKit
import WebKit

/// A seat map.
///
/// Hosts a `WKWebView` running the immutable, version-pinned SeatLayer mobile
/// page, performs the
/// bridge handshake, and exposes the chart as async Swift methods.
///
/// ## Known constraint (v0.1)
///
/// The map must be a FIXED-HEIGHT or full-screen box. Do not place it inside a
/// `UIScrollView` / `List` / `ScrollView`. The canvas consumes pan and pinch to
/// drive its own zoom, so an enclosing scroll view and the map fight over every
/// gesture and neither behaves. Give it a definite frame and let the map own the
/// space it occupies.
@MainActor
public final class SeatLayerView: UIView {

    /// The `WKScriptMessageHandler` name the web bundle probes for
    /// (`window.webkit.messageHandlers.seatlayer`).
    static let messageHandlerName = "seatlayer"

    public weak var delegate: SeatLayerViewDelegate?

    /// What the bundle advertised in `hello`. Populated before `ready`.
    public private(set) var bundleInfo: BundleInfo?
    /// What `sys.ready` reported. Non-nil once the chart exists.
    public private(set) var readyInfo: ReadyInfo?
    /// The negotiated protocol revision, or `nil` before a successful handshake.
    public private(set) var protocolRevision: Int?

    public var isReady: Bool { readyInfo != nil }

    private var webView: WKWebView!
    private var client: BridgeClient!
    private var configuration: SeatLayerConfiguration?
    private var channel: WebViewChannel?
    private var readyContinuations: [CheckedContinuation<ReadyInfo, Error>] = []
    private var handshakeTimeoutTask: Task<Void, Never>?
    private var hasFinished = false
    private var allowedPageURL: URL?
    private let bridgeProfile: SeatLayerBridgeProfile
    private weak var pickerController: SeatLayerPickerController?

    // MARK: - Init

    public override init(frame: CGRect) {
        bridgeProfile = .raw
        pickerController = nil
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        bridgeProfile = .raw
        pickerController = nil
        super.init(coder: coder)
        setUp()
    }

    init(
        frame: CGRect,
        bridgeProfile: SeatLayerBridgeProfile,
        pickerController: SeatLayerPickerController
    ) {
        self.bridgeProfile = bridgeProfile
        self.pickerController = pickerController
        super.init(frame: frame)
        setUp()
    }

    private func setUp() {
        let controller = WKUserContentController()
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController = controller
        // Buyer access and hold/session material must not survive this picker
        // process in cookies, local storage, or the shared website data store.
        webConfiguration.websiteDataStore = .nonPersistent()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.suppressesIncrementalRendering = false

        // Suppress the UIWebView-era affordances that fight a canvas: the
        // double-tap-to-zoom gesture, the long-press callout, and text
        // selection all steal touches the map needs for its own zoom/pan.
        let hardening = """
        (function () {
          var meta = document.createElement('meta');
          meta.name = 'viewport';
          meta.content = 'width=device-width, initial-scale=1, maximum-scale=1, ' +
                         'minimum-scale=1, user-scalable=no, viewport-fit=cover';
          document.head.appendChild(meta);
          var style = document.createElement('style');
          style.textContent =
            'html,body{margin:0;padding:0;height:100%;overflow:hidden;' +
            '-webkit-user-select:none;user-select:none;' +
            '-webkit-touch-callout:none;' +
            '-webkit-tap-highlight-color:transparent;' +
            'overscroll-behavior:none;touch-action:none;}';
          document.head.appendChild(style);
        })();
        """
        controller.addUserScript(
            WKUserScript(source: hardening, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )

        webView = WKWebView(frame: bounds, configuration: webConfiguration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.navigationDelegate = self

        // The map is not a scrolling document. Everything below hands the
        // gesture space to the canvas.
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.bouncesZoom = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        for recognizer in webView.scrollView.gestureRecognizers ?? [] {
            if let tap = recognizer as? UITapGestureRecognizer, tap.numberOfTapsRequired == 2 {
                tap.isEnabled = false
            }
        }
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false

        addSubview(webView)

        let channel = WebViewChannel(webView: webView)
        self.channel = channel
        self.client = BridgeClient(channel: channel, timeout: BridgeClient.defaultTimeout)

        controller.add(MessageProxy(view: self), name: Self.messageHandlerName)
    }

    deinit {
        // `client` is an actor; tearing it down from deinit needs a detached hop.
        let client = self.client
        Task.detached { await client?.close() }
    }

    // MARK: - Loading

    /// Load a chart and wait for the handshake to complete.
    ///
    /// Returns once `sys.ready` arrives. Throws `.incompatible` when the two
    /// protocol ranges do not overlap, `.handshakeTimeout` when the bundle never
    /// reports ready, and `.bridge` when the chart fails to render.
    @discardableResult
    public func load(_ configuration: SeatLayerConfiguration) async throws -> ReadyInfo {
        self.configuration = configuration
        self.hasFinished = false
        self.readyInfo = nil
        self.protocolRevision = nil
        self.bundleInfo = nil
        pickerController?.beginLoading()

        // Rebuild the client so a reload does not inherit stale correlations or
        // event sequence watermarks from the previous chart.
        await client.close()
        guard let channel else { throw SeatLayerError.transport("web view unavailable") }
        client = BridgeClient(channel: channel, timeout: configuration.commandTimeout)

        let pageURL = configuration.pageURL ?? SeatLayer.mobilePageURL
        allowedPageURL = pageURL

        await client.onSignal { [weak self] signal in
            Task { @MainActor [weak self] in self?.handle(signal) }
        }

        startHandshakeTimeout(configuration.handshakeTimeout)
        if pageURL.isFileURL {
            webView.loadFileURL(pageURL, allowingReadAccessTo: pageURL.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: pageURL))
        }

        return try await withCheckedThrowingContinuation { continuation in
            readyContinuations.append(continuation)
        }
    }

    /// Legacy bundled page shell retained for offline fixtures and migration.
    /// Production loads the immutable hosted page so its lazy locale, 3D,
    /// panorama, checkout, and worker assets resolve from the same origin.
    static func bundledPageURL() throws -> URL {
        guard let root = Bundle.module.resourceURL?.appendingPathComponent("Web") else {
            throw SeatLayerError.missingResource("Web")
        }
        let page = root.appendingPathComponent("index.html")
        guard FileManager.default.fileExists(atPath: page.path) else {
            throw SeatLayerError.missingResource("Web/index.html")
        }
        return page
    }

    private func startHandshakeTimeout(_ seconds: TimeInterval) {
        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            // The task inherits this view's main-actor isolation, so the hop is
            // already made.
            self?.finishHandshake(.failure(.handshakeTimeout(seconds: seconds)))
        }
    }

    private func finishHandshake(_ result: Result<ReadyInfo, SeatLayerError>) {
        guard !hasFinished else {
            // A failure AFTER ready (a late sys.error) is a delegate callback,
            // not a load result.
            if case .failure(let error) = result {
                if bridgeProfile.isPicker {
                    pickerController?.fail(error)
                } else {
                    delegate?.seatLayerView(self, didFailWith: error)
                }
            }
            return
        }
        hasFinished = true
        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = nil

        let waiting = readyContinuations
        readyContinuations.removeAll()

        switch result {
        case .success(let info):
            readyInfo = info
            protocolRevision = info.protocolRevision
            for continuation in waiting { continuation.resume(returning: info) }
            delegate?.seatLayerViewDidBecomeReady(self, info: info)
        case .failure(let error):
            pickerController?.fail(error)
            for continuation in waiting { continuation.resume(throwing: error) }
            delegate?.seatLayerView(self, didFailWith: error)
        }
    }

    // MARK: - Inbound

    fileprivate func receive(_ body: Any, from frame: WKFrameInfo) {
        guard frame.isMainFrame, accepts(origin: frame.securityOrigin) else { return }
        guard let envelope = Envelope.decode(foundation: body) else { return }
        Task { [client] in await client?.ingest(envelope) }
    }

    private func accepts(origin: WKSecurityOrigin) -> Bool {
        guard let page = allowedPageURL else { return false }
        if page.isFileURL { return origin.protocol == "file" }
        guard origin.protocol.caseInsensitiveCompare(page.scheme ?? "") == .orderedSame,
              origin.host.caseInsensitiveCompare(page.host ?? "") == .orderedSame
        else { return false }

        if let explicitPort = page.port {
            return origin.port == explicitPort
        }

        // `WKSecurityOrigin.port` uses 0 for an omitted default port on some
        // WebKit builds and the numeric default (443/80) on others. These are
        // the same origin only when the configured URL itself omits its port;
        // an explicitly configured non-default port still has to match above.
        let defaultPort = page.scheme?.lowercased() == "https" ? 443
            : page.scheme?.lowercased() == "http" ? 80
            : 0
        return origin.port == 0 || origin.port == defaultPort
    }

    private func handle(_ signal: BridgeSignal) {
        switch signal {
        case .hello(let payload):
            handleHello(payload)
        case .event(let name, let payload, _):
            handleEvent(name: name, payload: payload)
        case .unhandled(let envelope):
            if !bridgeProfile.isPicker {
                delegate?.seatLayerView(self, didReceiveUnknownEvent: envelope.type, payload: envelope.payload)
            }
        }
    }

    private func handleHello(_ payload: JSONValue?) {
        let info = BundleInfo(payload)
        bundleInfo = info

        // Negotiate natively BEFORE replying. The web side checks too, but
        // failing here means the app never even asks for a chart it could not
        // drive, and the caller gets a typed error instead of a blank view.
        do {
            try bridgeProfile.validate(info)
            guard let configuration else { return }
            if bridgeProfile.isPicker, let client {
                pickerController?.connect(transport: client, bundleInfo: info)
            }
            if configuration.usesPrivateAccess,
               !info.supports(capability: "native-access-provider") {
                finishHandshake(.failure(.incompatible(
                    native: bridgeProfile.protocolRange,
                    web: info.protocolRange,
                    reason: "the bundle does not support private buyer access"
                )))
                return
            }
            if configuration.usesSelectionPolicy,
               (!info.supports(capability: "selection-controls")
                || !info.supports(capability: "selection-validity")) {
                finishHandshake(.failure(.incompatible(
                    native: bridgeProfile.protocolRange,
                    web: info.protocolRange,
                    reason: "the bundle does not support the configured selection policy"
                )))
                return
            }
            Task { [client] in
                await client?.sendInit(
                    payload: bridgeProfile.initPayload(configuration: configuration, bundle: info)
                )
            }
        } catch let error as SeatLayerError {
            finishHandshake(.failure(error))
        } catch {
            finishHandshake(.failure(.transport("bridge profile validation failed")))
        }
    }

    private func handleEvent(name: String, payload: JSONValue?) {
        switch name {
        case "sys.ready":
            let info = ReadyInfo(payload)
            if bridgeProfile.isPicker, info.protocolRevision != 2 {
                finishHandshake(.failure(.incompatible(
                    native: bridgeProfile.protocolRange,
                    web: ProtocolRange(
                        min: info.protocolRevision,
                        max: info.protocolRevision
                    ),
                    reason: "the picker runtime did not confirm protocol revision 2"
                )))
                return
            }
            pickerController?.markReady(info, payload: payload)
            finishHandshake(.success(info))

        case "sys.incompatible":
            let web = ProtocolRange.from(payload?["web"]) ?? bridgeProfile.protocolRange
            let reason = payload?["message"]?.stringValue
                ?? payload?["code"]?.stringValue
                ?? "the seat map bundle rejected this app's protocol range"
            finishHandshake(.failure(.incompatible(
                native: bridgeProfile.protocolRange,
                web: web,
                reason: reason
            )))

        case "sys.error":
            finishHandshake(.failure(.bridge(BridgeErrorPayload(payload))))

        case "picker.snapshot" where bridgeProfile.isPicker:
            pickerController?.accept(snapshot: payload?["snapshot"] ?? payload)

        case "seatView.changed" where bridgeProfile.isPicker:
            pickerController?.accept(seatView: payload?["seatView"])

        case "selection.changed":
            let seats = decodeList(payload?["seats"], as: SelectedSeat.self)
            delegate?.seatLayerView(self, selectionDidChange: seats)

        case "selection.validity.changed":
            if let validity = try? payload?["validity"]?.decode(SelectionValidity.self) {
                delegate?.seatLayerView(self, selectionValidityDidChange: validity)
            }

        case "selection.valid":
            delegate?.seatLayerView(
                self,
                selectionDidBecomeValid: decodeList(payload?["seats"], as: SelectedSeat.self)
            )

        case "selection.invalid":
            if let validity = try? payload?["validity"]?.decode(SelectionValidity.self) {
                delegate?.seatLayerView(self, selectionDidBecomeInvalid: validity)
            }

        case "selection.limit":
            if let maximum = payload?["maxSelection"]?.intValue {
                delegate?.seatLayerView(self, didReachSelectionLimit: maximum)
            }

        case "access.token.request":
            provideBuyerAccessToken(payload)

        case "access.expired":
            if let event = try? payload?.decode(BuyerAccessExpiredEvent.self) {
                delegate?.seatLayerView(self, buyerAccessDidExpire: event)
            }

        case "access.unavailable":
            if let event = try? payload?.decode(BuyerAccessUnavailableEvent.self) {
                delegate?.seatLayerView(self, buyerAccessBecameUnavailable: event)
            }

        case "selection.unavailable":
            if let event = try? payload?.decode(SelectedObjectUnavailableEvent.self) {
                delegate?.seatLayerView(self, selectedObjectsBecameUnavailable: event)
            }

        case "hold.changed":
            if let hold = try? payload?["hold"]?.decode(HoldResult.self) {
                delegate?.seatLayerView(self, holdDidChange: hold)
            }

        case "hold.restored":
            if let hold = try? payload?["hold"]?.decode(HoldResult.self) {
                delegate?.seatLayerView(self, holdWasRestored: hold)
            }

        case "hold.expired":
            delegate?.seatLayerViewHoldDidExpire(self)

        case "ga.click":
            if let area = try? payload?["area"]?.decode(GAArea.self) {
                if bridgeProfile.isPicker {
                    pickerController?.accept(generalAdmissionCandidate: area)
                } else {
                    delegate?.seatLayerView(self, didTapGAArea: area)
                }
            }

        case "hint":
            delegate?.seatLayerView(self, didReceiveHint: payload?["message"]?.stringValue)

        case "error":
            let error = SeatLayerError.bridge(BridgeErrorPayload(payload))
            if bridgeProfile.isPicker {
                pickerController?.record(error)
            } else {
                delegate?.seatLayerView(self, didFailWith: error)
            }

        case "seat.hover":
            let details = payload?["details"].flatMap { $0.isNull ? nil : try? $0.decode(SeatHoverDetails.self) }
            delegate?.seatLayerView(self, seatHoverDidChange: details)

        case "deck.tap":
            if let floorId = payload?["floorId"]?.stringValue {
                delegate?.seatLayerView(self, didTapFloor: floorId)
            }

        default:
            // An event name this build predates. Never a crash.
            if !bridgeProfile.isPicker {
                delegate?.seatLayerView(self, didReceiveUnknownEvent: name, payload: payload)
            }
        }
    }

    private func provideBuyerAccessToken(_ payload: JSONValue?) {
        guard let requestId = payload?["requestId"]?.stringValue else { return }
        let rawReason = payload?["reason"]?.stringValue ?? "initial"
        let reason = BuyerAccessRefreshReason(rawValue: rawReason) ?? .unknown(rawReason)
        let provider = configuration?.buyerAccessTokenProvider

        Task { [client] in
            guard let provider else {
                _ = try? await client?.command(
                    "access.token.unavailable",
                    payload: ["requestId": .string(requestId)]
                )
                return
            }

            do {
                let token = try await provider(.init(reason: reason))
                guard !token.token.isEmpty,
                      token.expiresAt.map(\.isFinite) ?? true else {
                    throw SeatLayerError.decoding("buyer access provider returned an invalid token")
                }
                var response: [String: JSONValue] = [
                    "requestId": .string(requestId),
                    "token": .string(token.token),
                ]
                if let expiresAt = token.expiresAt { response["expiresAt"] = .double(expiresAt) }
                _ = try await client?.command("access.token.provide", payload: .object(response))
            } catch {
                // Provider errors are deliberately sanitized; neither an error
                // description nor a bearer is sent to the web runtime.
                _ = try? await client?.command(
                    "access.token.unavailable",
                    payload: ["requestId": .string(requestId)]
                )
            }
        }
    }

    private func decodeList<T: Decodable>(_ value: JSONValue?, as type: T.Type) -> [T] {
        guard let items = value?.arrayValue else { return [] }
        // Decode per element: one malformed entry must not discard the rest.
        return items.compactMap { try? $0.decode(T.self) }
    }

    // MARK: - Commands

    private func run(_ command: String, _ payload: JSONValue? = nil) async throws -> JSONValue {
        try await client.command(command, payload: payload)
    }

    /// Hold the current selection.
    @discardableResult
    public func hold(ttlMs: Int? = nil) async throws -> HoldResult? {
        let result = try await run("hold", .object(compacting: ["ttlMs": ttlMs.map(JSONValue.int)]))
        return try optional(result["hold"], as: HoldResult.self)
    }

    /// Reattach to an open hold (app relaunch, checkout resume).
    @discardableResult
    public func resumeHold(holdId: String) async throws -> HoldResult? {
        let result = try await run("resumeHold", ["holdId": .string(holdId)])
        return try optional(result["hold"], as: HoldResult.self)
    }

    /// Push the hold's expiry out.
    @discardableResult
    public func extendHold(ttlMs: Int? = nil) async throws -> HoldResult? {
        let result = try await run("extendHold", .object(compacting: ["ttlMs": ttlMs.map(JSONValue.int)]))
        return try optional(result["hold"], as: HoldResult.self)
    }

    /// Release the whole hold.
    public func release() async throws {
        _ = try await run("release")
    }

    /// Release specific seats from the hold, keeping the rest.
    @discardableResult
    public func releaseLabels(_ labels: [String]) async throws -> Bool {
        let result = try await run("releaseLabels", ["labels": .array(labels.map(JSONValue.string))])
        return result["released"]?.boolValue ?? false
    }

    /// Ask the server for the best `qty` seats and hold them.
    @discardableResult
    public func bestAvailable(
        qty: Int,
        categoryKey: String? = nil,
        zoneId: String? = nil,
        preferPremium: Bool? = nil,
        ttlMs: Int? = nil
    ) async throws -> BestAvailableResult? {
        let result = try await run("bestAvailable", .object(compacting: [
            "qty": .int(qty),
            "categoryKey": categoryKey.map(JSONValue.string),
            "zoneId": zoneId.map(JSONValue.string),
            "preferPremium": preferPremium.map(JSONValue.bool),
            "ttlMs": ttlMs.map(JSONValue.int),
        ]))
        return try optional(result["hold"], as: BestAvailableResult.self)
    }

    /// Hold general-admission capacity.
    ///
    /// `tierId` is doubly optional on purpose, mirroring the web contract:
    /// omitting it leaves the tier untouched, while passing `.some(nil)` sends
    /// an explicit `null` to revert to the default tier.
    @discardableResult
    public func holdGA(
        areaId: String,
        qty: Int,
        tierId: String?? = nil,
        ttlMs: Int? = nil
    ) async throws -> HoldResult? {
        var payload: [String: JSONValue] = ["areaId": .string(areaId), "qty": .int(qty)]
        if let tierId { payload["tierId"] = tierId.map(JSONValue.string) ?? .null }
        if let ttlMs { payload["ttlMs"] = .int(ttlMs) }
        let result = try await run("holdGA", .object(payload))
        return try optional(result["hold"], as: HoldResult.self)
    }

    /// Choose a ticket tier for one seat. `nil` reverts to the default tier.
    public func setSeatTier(seatId: String, tierId: String?) async throws {
        _ = try await run("setSeatTier", [
            "seatId": .string(seatId),
            "tierId": tierId.map(JSONValue.string) ?? .null,
        ])
    }

    /// The current selection.
    public func getSelection() async throws -> [SelectedSeat] {
        let result = try await run("getSelection")
        return decodeList(result["seats"], as: SelectedSeat.self)
    }

    /// Select free objects by engine id or public label.
    @discardableResult
    public func selectObjects(_ objects: [String]) async throws -> [SelectedSeat] {
        let result = try await run("selectObjects", ["objects": .array(objects.map(JSONValue.string))])
        return decodeList(result["seats"], as: SelectedSeat.self)
    }

    public func deselectObjects(_ objects: [String]) async throws {
        _ = try await run("deselectObjects", ["objects": .array(objects.map(JSONValue.string))])
    }

    public func clearSelection() async throws { _ = try await run("clearSelection") }

    @discardableResult
    public func selectCategories(_ categoryKeys: [String]) async throws -> [SelectedSeat] {
        let result = try await run(
            "selectCategories",
            ["categoryKeys": .array(categoryKeys.map(JSONValue.string))]
        )
        return decodeList(result["seats"], as: SelectedSeat.self)
    }

    public func deselectCategories(_ categoryKeys: [String]) async throws {
        _ = try await run(
            "deselectCategories",
            ["categoryKeys": .array(categoryKeys.map(JSONValue.string))]
        )
    }

    /// Replace the buyer-selectable allow-list. `nil` restores all objects.
    public func setSelectableObjects(_ objects: [String]?) async throws {
        _ = try await run(
            "setSelectableObjects",
            ["objects": objects.map { .array($0.map(JSONValue.string)) } ?? .null]
        )
    }

    public func setMaxSelection(_ maximum: Int) async throws {
        _ = try await run("setMaxSelection", ["maxSelection": .int(maximum)])
    }

    public func getSelectionValidity() async throws -> SelectionValidity? {
        let result = try await run("getSelectionValidity")
        return try optional(result["validity"], as: SelectionValidity.self)
    }

    /// Ask the shared picker to renew private buyer access immediately.
    @discardableResult
    public func refreshAccess() async throws -> Bool {
        let result = try await run("refreshAccess")
        return result["refreshed"]?.boolValue ?? false
    }

    /// The open hold, if any.
    public func getCurrentHold() async throws -> HoldResult? {
        let result = try await run("getCurrentHold")
        return try optional(result["hold"], as: HoldResult.self)
    }

    /// General-admission areas and their live availability.
    public func getGAAreas() async throws -> [GAArea] {
        let result = try await run("getGAAreas")
        return decodeList(result["areas"], as: GAArea.self)
    }

    /// Floors of a multi-floor venue. Empty for a single-floor chart.
    public func getFloors() async throws -> [FloorInfo] {
        let result = try await run("getFloors")
        return decodeList(result["floors"], as: FloorInfo.self)
    }

    public func setFloor(_ floorId: String) async throws {
        _ = try await run("setFloor", ["floorId": .string(floorId)])
    }

    public func setColorblindSafe(_ on: Bool) async throws {
        _ = try await run("setColorblindSafe", ["on": .bool(on)])
    }

    public func setViewMode(_ mode: SeatLayerViewMode) async throws {
        _ = try await run("setViewMode", ["mode": .string(mode.rawValue)])
    }

    public func getViewMode() async throws -> SeatLayerViewMode {
        let result = try await run("getViewMode")
        let raw = result["mode"]?.stringValue ?? "flat"
        return SeatLayerViewMode(rawValue: raw) ?? .unknown(raw)
    }

    public func zoomIn() async throws { _ = try await run("zoomIn") }
    public func zoomOut() async throws { _ = try await run("zoomOut") }
    public func zoomToFit() async throws { _ = try await run("zoomToFit") }

    /// Tear the chart down. Subsequent commands fail with `destroyed`.
    public func destroy() async throws {
        _ = try? await run(bridgeProfile.isPicker ? "picker.destroy" : "destroy")
        await client.close()
        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = nil
        configuration = nil
        allowedPageURL = nil
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        readyInfo = nil
        protocolRevision = nil
        bundleInfo = nil
    }

    private func optional<T: Decodable>(_ value: JSONValue?, as type: T.Type) throws -> T? {
        guard let value, !value.isNull else { return nil }
        do {
            return try value.decode(T.self)
        } catch {
            throw SeatLayerError.decoding("\(T.self): \(error)")
        }
    }
}

// MARK: - Navigation

extension SeatLayerView: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.request.url == allowedPageURL ? .allow : .cancel)
    }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishHandshake(.failure(.transport("page load failed: \(error.localizedDescription)")))
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishHandshake(.failure(.transport("page navigation failed: \(error.localizedDescription)")))
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finishHandshake(.failure(.transport("the web content process terminated")))
    }
}

// MARK: - Message plumbing

/// Breaks the retain cycle `WKUserContentController` → handler → view would
/// otherwise create.
private final class MessageProxy: NSObject, WKScriptMessageHandler {
    weak var view: SeatLayerView?

    init(view: SeatLayerView) {
        self.view = view
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        // The web side posts the envelope OBJECT, not a string: WKScriptMessage
        // bridges JS values to NSDictionary natively, so there is nothing to
        // parse here.
        MainActor.assumeIsolated {
            view?.receive(message.body, from: message.frameInfo)
        }
    }
}

/// native→web over `callAsyncJavaScript`.
private final class WebViewChannel: BridgeChannel, @unchecked Sendable {
    private weak var webView: WKWebView?

    init(webView: WKWebView) {
        self.webView = webView
    }

    func send(_ envelope: Envelope) async {
        let argument = envelope.toFoundation()
        await MainActor.run { [weak webView] in
            guard let webView else { return }
            // The envelope goes as an ARGUMENT, never interpolated into the
            // script source: payload content is then data to the JS engine and
            // can never be parsed as code, whatever it contains.
            webView.callAsyncJavaScript(
                "window.__slBridge && window.__slBridge.recv(frame); return true;",
                arguments: ["frame": argument],
                in: nil,
                in: .page
            ) { _ in }
        }
    }
}

#endif
