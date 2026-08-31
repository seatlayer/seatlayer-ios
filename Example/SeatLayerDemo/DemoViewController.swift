import SeatLayer
import UIKit

/// End-to-end host for the ready-made native picker.
///
/// The default fixture is SeatLayer's controlled production test event. It
/// uses the hosted CDN runtime and hosted HTTPS API end to end, while remaining
/// sandbox inventory. Override either value with a launch environment variable
/// when exercising a local or customer-specific event.
@MainActor
final class DemoViewController: UIViewController {
    private enum Fixture {
        static var eventKey: String {
            ProcessInfo.processInfo.environment["SEATLAYER_EVENT_KEY"]
                ?? "ev_ba4c90989806"
        }

        static var apiBase: String {
            ProcessInfo.processInfo.environment["SEATLAYER_API_BASE"]
                ?? "https://api.seatlayer.io"
        }

        static var locale: String {
            ProcessInfo.processInfo.environment["SEATLAYER_DEMO_LOCALE"] ?? "en"
        }
    }

    private var pickerHost: SeatLayerPickerViewController?
    private var checkoutInvocationCount = 0
    private var didFlipTheme = false
    private var didCreateExplicitHold = false

    override var childForStatusBarStyle: UIViewController? { pickerHost }

    override func viewDidLoad() {
        super.viewDidLoad()
        let themeMode = demoThemeMode
        view.backgroundColor = themeMode == .light
            ? UIColor(red: 0.965, green: 0.973, blue: 0.988, alpha: 1)
            : UIColor(red: 0.059, green: 0.082, blue: 0.133, alpha: 1)
        switch themeMode {
        case .light: overrideUserInterfaceStyle = .light
        case .dark: overrideUserInterfaceStyle = .dark
        case .auto: overrideUserInterfaceStyle = .unspecified
        }
        if ProcessInfo.processInfo.environment["SEATLAYER_PREWARM"] == "1" {
            let indicator = installPrewarmIndicator()
            Task { @MainActor in
                do {
                    try await SeatLayerPickerPrewarming.prewarm()
                    NSLog("[SeatLayerDemo] E2E prewarm ready=true")
                } catch {
                    NSLog("[SeatLayerDemo] E2E prewarm ready=false")
                }
                indicator.removeFromSuperview()
                installPicker()
            }
        } else {
            installPicker()
        }
    }

    private func installPrewarmIndicator() -> UIStackView {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .white
        spinner.startAnimating()
        let label = UILabel()
        label.text = "Preparing seat map…"
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .body)
        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return stack
    }

    private func installPicker() {
        var configuration = SeatLayerConfiguration(
            event: Fixture.eventKey,
            apiBase: Fixture.apiBase,
            locale: Fixture.locale,
            currency: "EUR"
        )
        if ProcessInfo.processInfo.environment["SEATLAYER_CLOSURE_FIXTURE"] == "1" {
            guard let fixtureURL = Bundle.main.url(
                forResource: "picker-closure-fixture",
                withExtension: "html"
            ) else {
                showConfigurationFailure("The picker closure fixture is missing from this demo build.")
                return
            }
            if let state = ProcessInfo.processInfo.environment["SEATLAYER_CLOSURE_STATE"],
               !state.isEmpty,
               var components = URLComponents(url: fixtureURL, resolvingAgainstBaseURL: false) {
                components.queryItems = [URLQueryItem(name: "state", value: state)]
                configuration.pageURL = components.url ?? fixtureURL
            } else {
                configuration.pageURL = fixtureURL
            }
            NSLog("[SeatLayerDemo] E2E closure fixture=true")
        }
        configuration.hostInfo = [
            "app": "SeatLayerDemo/1.0",
            "journey": "native-picker-e2e",
        ]

        let options = SeatLayerPickerOptions(
            layout: ProcessInfo.processInfo.environment["SEATLAYER_DEMO_WIDE"] == "1"
                ? .wide
                : .phone,
            confirmSelection: ProcessInfo.processInfo.environment["SEATLAYER_DEMO_SKIP_CONFIRM"] != "1",
            holdTtlMs: 15 * 60 * 1_000,
            panelInitiallyCollapsed: true,
            refreshOnResume: true,
            announceHoldLapse: true
        )
        var strings = SeatLayerPickerStrings(localeIdentifier: Fixture.locale)
        if ProcessInfo.processInfo.environment["SEATLAYER_DEMO_LONG_TEXT"] == "1" {
            strings.overrides[SeatLayerPickerStringKey.accessibilityTitle.rawValue] =
                "Accessibility, visibility, and colour-assistance preferences"
            strings.overrides[SeatLayerPickerStringKey.emptyTrayHint.rawValue] =
                "Choose a place on the seating map, or ask us to find the best available option for your whole party."
            strings.overrides[SeatLayerPickerStringKey.testModeDescription.rawValue] =
                "This is a controlled demonstration event. No real reservation, payment, or booking will be created."
        }
        weak var appearanceHost: SeatLayerPickerViewController?
        let callbacks = SeatLayerPickerCallbacks(
            onReady: { info in
                NSLog(
                    "[SeatLayerDemo] E2E ready protocol=%d mode=%@ transport=%@",
                    info.protocolRevision,
                    info.mode.rawValue,
                    info.transport.rawValue
                )
            },
            onChartLoad: { load in
                let trace = load.trace
                NSLog(
                    "[SeatLayerDemo] E2E chart-load outcome=%@ load=%@ tapMs=%@ bootMs=%@ hostMs=%@ apiMs=%@ sceneMs=%@ paintMs=%@ cache=%@ platform=%@ bundle=%@",
                    trace.outcome ?? "legacy-success",
                    trace.load ?? "-",
                    load.tapToReadyMs.map(String.init) ?? "-",
                    trace.bootMs.map(String.init) ?? "-",
                    load.hostMs.map(String.init) ?? "-",
                    trace.api.map(String.init) ?? "-",
                    trace.scene.map(String.init) ?? "-",
                    trace.paint.map(String.init) ?? "-",
                    trace.chartCache ?? "-",
                    trace.platform ?? "-",
                    trace.bundle ?? "-"
                )
            },
            onSelectionChanged: { [weak self] seats in
                NSLog(
                    "[SeatLayerDemo] E2E selection count=%d labels=%@",
                    seats.count,
                    seats.map(\.label).joined(separator: ",")
                )
                guard let self,
                      !seats.isEmpty,
                      !self.didFlipTheme,
                      ProcessInfo.processInfo.environment["SEATLAYER_VALIDATE_THEME_FLIP"] == "1"
                else { return }
                self.didFlipTheme = true
                Task { @MainActor [weak self] in
                    // A fixture snapshot can arrive while the hosting
                    // controller is still being constructed. Yield until the
                    // local weak reference below has been assigned so this
                    // validation log can never claim a skipped update.
                    await Task.yield()
                    guard let appearanceHost else {
                        self?.didFlipTheme = false
                        return
                    }
                    appearanceHost.updateAppearance(themeMode: .light)
                    NSLog(
                        "[SeatLayerDemo] E2E theme flip=light selectionPreserved=%d",
                        seats.count
                    )
                }
            },
            onHoldTransition: { hold, _ in
                NSLog(
                    "[SeatLayerDemo] E2E hold active=%@ owner=%@",
                    (hold?.active ?? false).description,
                    hold?.owner ?? "-"
                )
            },
            onError: { error in
                NSLog(
                    "[SeatLayerDemo] E2E error code=%@ retryable=%@",
                    error.code,
                    error.isRetryable.description
                )
            },
            onSeatSelected: { [weak self] seat in
                NSLog(
                    "[SeatLayerDemo] E2E confirmation label=%@ tier=%@ price=%.2f currency=%@",
                    seat.label,
                    seat.tierId ?? "-",
                    seat.price ?? 0,
                    seat.currency ?? "-"
                )
                guard let self,
                      !self.didCreateExplicitHold,
                      ProcessInfo.processInfo.environment["SEATLAYER_DEMO_HOLD_AFTER_CONFIRM"] == "1",
                      let host = appearanceHost
                else { return }
                self.didCreateExplicitHold = true
                Task { @MainActor in
                    do {
                        _ = try await host.pickerController.holdSelection(
                            ttlMs: 15 * 60 * 1_000
                        )
                        NSLog("[SeatLayerDemo] E2E explicit picker hold=true")
                    } catch let error as SeatLayerError {
                        NSLog(
                            "[SeatLayerDemo] E2E explicit picker hold=false code=%@",
                            error.code
                        )
                    } catch {
                        NSLog("[SeatLayerDemo] E2E explicit picker hold=false")
                    }
                }
            }
        )

        let host = SeatLayerPickerViewController(
            configuration: configuration,
            options: options,
            themeMode: demoThemeMode,
            strings: strings,
            callbacks: callbacks,
            onCheckout: { [weak self] handoff in
                guard let self else { return }
                checkoutInvocationCount += 1
                let quantity = handoff.lineItems.reduce(0) { $0 + $1.quantity }
                NSLog(
                    "[SeatLayerDemo] E2E checkout callback=%d holdTransferred=true lines=%d quantity=%d currency=%@ total=%.2f",
                    checkoutInvocationCount,
                    handoff.lineItems.count,
                    quantity,
                    handoff.currency,
                    handoff.total
                )
                showCheckoutReceipt(handoff)
            },
            onClose: { [weak self] in
                guard let self else { return }
                NSLog("[SeatLayerDemo] E2E close")
                showClosedState()
            }
        )
        appearanceHost = host
        pickerHost = host

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.accessibilityIdentifier = "seatlayer-demo-picker"
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }

    private var demoThemeMode: SeatLayerPickerThemeMode {
        switch ProcessInfo.processInfo.environment["SEATLAYER_DEMO_THEME"]?.lowercased() {
        case "light": return .light
        case "auto": return .auto
        default: return .dark
        }
    }

    private func showConfigurationFailure(_ message: String) {
        let label = UILabel()
        label.text = message
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityIdentifier = "seatlayer-demo-configuration-error"
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 24
            ),
            label.trailingAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -24
            ),
            label.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }

    private func showCheckoutReceipt(_ handoff: SeatLayerPickerCheckoutHandoff) {
        let receipt = CheckoutReceiptViewController(
            handoff: handoff,
            callbackCount: checkoutInvocationCount
        )
        receipt.modalPresentationStyle = .fullScreen
        present(receipt, animated: true)
    }

    private func showClosedState() {
        let closed = UIViewController()
        closed.view.backgroundColor = UIColor(red: 0.059, green: 0.082, blue: 0.133, alpha: 1)
        let label = UILabel()
        label.text = "Picker closed"
        label.font = .preferredFont(forTextStyle: .title2)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        closed.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: closed.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: closed.view.centerYAnchor),
        ])
        closed.modalPresentationStyle = .fullScreen
        present(closed, animated: true)
    }
}

@MainActor
private final class CheckoutReceiptViewController: UIViewController {
    private let handoff: SeatLayerPickerCheckoutHandoff
    private let callbackCount: Int

    init(handoff: SeatLayerPickerCheckoutHandoff, callbackCount: Int) {
        self.handoff = handoff
        self.callbackCount = callbackCount
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(red: 0.059, green: 0.082, blue: 0.133, alpha: 1)
        view.accessibilityIdentifier = "seatlayer-demo-checkout-receipt"
        view.accessibilityViewIsModal = true

        let success = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        success.tintColor = UIColor(red: 0.608, green: 0.541, blue: 0.984, alpha: 1)
        success.contentMode = .scaleAspectFit
        success.heightAnchor.constraint(equalToConstant: 58).isActive = true

        let title = UILabel()
        title.text = "Checkout handoff received"
        title.font = .preferredFont(forTextStyle: .title2)
        title.adjustsFontForContentSizeCategory = true
        title.textColor = .white
        title.textAlignment = .center
        title.accessibilityIdentifier = "seatlayer-demo-checkout-title"

        let subtitle = UILabel()
        subtitle.text = "The native host owns this hold now.\nThe picker callback ran exactly \(callbackCount) time."
        subtitle.font = .preferredFont(forTextStyle: .body)
        subtitle.adjustsFontForContentSizeCategory = true
        subtitle.textColor = UIColor(white: 0.72, alpha: 1)
        subtitle.numberOfLines = 0
        subtitle.textAlignment = .center

        let total = UILabel()
        total.text = handoff.total.formatted(
            .currency(code: handoff.currency).precision(.fractionLength(0...2))
        )
        total.font = .preferredFont(forTextStyle: .largeTitle)
        total.adjustsFontForContentSizeCategory = true
        total.textColor = .white
        total.textAlignment = .center
        total.accessibilityIdentifier = "seatlayer-demo-checkout-total"

        let details = UILabel()
        let lines = handoff.lineItems.map { line in
            let type = line.tierName ?? line.tierId ?? line.categoryKey
            let price = line.unitPrice.formatted(
                .currency(code: line.currency).precision(.fractionLength(0...2))
            )
            return "\(line.quantity)× \(line.displayLabel ?? line.label) · \(type) · \(price)"
        }
        details.text = ([
            "Hold: transferred to native host",
            "Items: \(handoff.lineItems.count)",
        ] + lines).joined(separator: "\n")
        details.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(
            for: .monospacedSystemFont(ofSize: 13, weight: .regular)
        )
        details.adjustsFontForContentSizeCategory = true
        details.textColor = UIColor(white: 0.8, alpha: 1)
        details.numberOfLines = 0
        details.textAlignment = .center
        details.accessibilityIdentifier = "seatlayer-demo-checkout-details"

        let stack = UIStackView(arrangedSubviews: [success, title, subtitle, total, details])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }
}
