#if canImport(UIKit)
import UIKit
import WebKit

/// Transferable renderer page. Before ownership transfer it buffers bridge
/// messages but has no event configuration, token provider, controller, or
/// session state. `SeatLayerView.load` arms delivery and sends `init`.
@MainActor
final class SeatLayerWebHost: NSObject {
    enum NavigationState: Equatable {
        case idle
        case loading
        case finished
        case failed(String)
        case cancelled
    }

    let webView: WKWebView
    private let relay: SeatLayerScriptMessageRelay
    private weak var target: SeatLayerView?
    private var messageDeliveryArmed = false
    private var bufferedMessages: [(body: Any, frame: WKFrameInfo)] = []
    private var navigationWaiters: [CheckedContinuation<Void, Error>] = []
    private var allowedPageURL: URL?
    private var clearing = false
    private(set) var requestedPageURL: URL?
    private(set) var navigationState: NavigationState = .idle

    override init() {
        let relay = SeatLayerScriptMessageRelay()
        let contentController = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        // Every transferred host still owns a fresh, memory-only data store.
        configuration.websiteDataStore = .nonPersistent()
        configuration.allowsInlineMediaPlayback = true
        configuration.suppressesIncrementalRendering = false
        contentController.addUserScript(WKUserScript(
            source: Self.canvasHardening,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        contentController.add(relay, name: SeatLayerView.messageHandlerName)
        self.relay = relay
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        relay.host = self
        webView.navigationDelegate = self
    }

    func attach(to target: SeatLayerView) {
        self.target = target
    }

    func armMessageDelivery() {
        guard !messageDeliveryArmed else { return }
        messageDeliveryArmed = true
        let messages = bufferedMessages
        bufferedMessages.removeAll(keepingCapacity: false)
        for message in messages {
            target?.receive(message.body, from: message.frame)
        }
    }

    func beginPrewarm(pageURL: URL) {
        load(pageURL)
    }

    func load(_ pageURL: URL) {
        if !navigationWaiters.isEmpty {
            finishNavigation(.failure(CancellationError()))
        }
        clearing = false
        requestedPageURL = pageURL
        allowedPageURL = pageURL
        navigationState = .loading
        if pageURL.isFileURL {
            webView.loadFileURL(
                pageURL,
                allowingReadAccessTo: pageURL.deletingLastPathComponent()
            )
        } else {
            webView.load(URLRequest(url: pageURL))
        }
    }

    func waitUntilNavigationFinished() async throws {
        switch navigationState {
        case .finished: return
        case .failed(let message): throw SeatLayerError.transport(message)
        case .cancelled: throw CancellationError()
        case .idle, .loading:
            try await withCheckedThrowingContinuation { continuation in
                navigationWaiters.append(continuation)
            }
        }
    }

    func cancelPrewarm() {
        webView.stopLoading()
        navigationState = .cancelled
        finishNavigation(.failure(CancellationError()))
        bufferedMessages.removeAll(keepingCapacity: false)
    }

    func stopAndClear() {
        webView.stopLoading()
        messageDeliveryArmed = false
        bufferedMessages.removeAll(keepingCapacity: false)
        target = nil
        requestedPageURL = nil
        allowedPageURL = nil
        clearing = true
        navigationState = .cancelled
        finishNavigation(.failure(SeatLayerError.destroyed))
        webView.loadHTMLString("", baseURL: nil)
    }

    fileprivate func receive(_ body: Any, frame: WKFrameInfo) {
        guard messageDeliveryArmed else {
            // A healthy prewarm emits only the handshake. Keep a small bound so
            // a malformed page cannot grow a detached host indefinitely.
            if bufferedMessages.count == 32 { bufferedMessages.removeFirst() }
            bufferedMessages.append((body, frame))
            return
        }
        target?.receive(body, from: frame)
    }

    private func failNavigation(_ message: String) {
        navigationState = .failed(message)
        finishNavigation(.failure(SeatLayerError.transport(message)))
        target?.webHostDidFail(message)
    }

    private func finishNavigation(_ result: Result<Void, Error>) {
        let waiters = navigationWaiters
        navigationWaiters.removeAll(keepingCapacity: false)
        for continuation in waiters { continuation.resume(with: result) }
    }

    private static let canvasHardening = """
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
}

extension SeatLayerWebHost: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(
            clearing || navigationAction.request.url == allowedPageURL ? .allow : .cancel
        )
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !clearing else { return }
        navigationState = .finished
        finishNavigation(.success(()))
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        failNavigation("page load failed: \(error.localizedDescription)")
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        failNavigation("page navigation failed: \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        let message = "the web content process terminated"
        navigationState = .failed(message)
        finishNavigation(.failure(SeatLayerError.transport(message)))
        target?.webHostContentProcessDidTerminate()
    }
}

private final class SeatLayerScriptMessageRelay: NSObject, WKScriptMessageHandler {
    weak var host: SeatLayerWebHost?

    func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        MainActor.assumeIsolated { [weak host] in
            host?.receive(message.body, frame: message.frameInfo)
        }
    }
}
#endif
