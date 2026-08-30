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
    }

    private var pickerHost: SeatLayerPickerViewController?
    private var checkoutInvocationCount = 0
    private var didFlipTheme = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.059, green: 0.082, blue: 0.133, alpha: 1)
        overrideUserInterfaceStyle = .dark
        installPicker()
    }

    private func installPicker() {
        var configuration = SeatLayerConfiguration(
            event: Fixture.eventKey,
            apiBase: Fixture.apiBase,
            locale: "en",
            currency: "EUR"
        )
        configuration.hostInfo = [
            "app": "SeatLayerDemo/1.0",
            "journey": "native-picker-e2e",
        ]

        let options = SeatLayerPickerOptions(
            layout: .phone,
            confirmSelection: true,
            holdTtlMs: 15 * 60 * 1_000,
            panelInitiallyCollapsed: true,
            refreshOnResume: true,
            announceHoldLapse: true
        )
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
                appearanceHost?.updateAppearance(themeMode: .light)
                NSLog("[SeatLayerDemo] E2E theme flip=light selectionPreserved=%d", seats.count)
            },
            onHoldChanged: { hold in
                NSLog(
                    "[SeatLayerDemo] E2E hold active=%@ owner=%@",
                    hold.active.description,
                    hold.owner ?? "-"
                )
            },
            onError: { error in
                NSLog(
                    "[SeatLayerDemo] E2E error code=%@ message=%@",
                    error.code,
                    error.errorDescription ?? "-"
                )
            }
        )

        let host = SeatLayerPickerViewController(
            configuration: configuration,
            options: options,
            themeMode: .dark,
            callbacks: callbacks,
            onCheckout: { [weak self] handoff in
                guard let self else { return }
                checkoutInvocationCount += 1
                NSLog(
                    "[SeatLayerDemo] E2E checkout callback=%d holdTransferred=true lines=%d total=%.2f",
                    checkoutInvocationCount,
                    handoff.lineItems.count,
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

        let success = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        success.tintColor = UIColor(red: 0.608, green: 0.541, blue: 0.984, alpha: 1)
        success.contentMode = .scaleAspectFit
        success.heightAnchor.constraint(equalToConstant: 58).isActive = true

        let title = UILabel()
        title.text = "Checkout handoff received"
        title.font = .systemFont(ofSize: 24, weight: .bold)
        title.textColor = .white
        title.textAlignment = .center
        title.accessibilityIdentifier = "seatlayer-demo-checkout-title"

        let subtitle = UILabel()
        subtitle.text = "The native host owns this hold now.\nThe picker callback ran exactly \(callbackCount) time."
        subtitle.font = .systemFont(ofSize: 15, weight: .regular)
        subtitle.textColor = UIColor(white: 0.72, alpha: 1)
        subtitle.numberOfLines = 0
        subtitle.textAlignment = .center

        let total = UILabel()
        total.text = handoff.total.formatted(
            .currency(code: handoff.currency).precision(.fractionLength(0...2))
        )
        total.font = .systemFont(ofSize: 34, weight: .heavy)
        total.textColor = .white
        total.textAlignment = .center
        total.accessibilityIdentifier = "seatlayer-demo-checkout-total"

        let details = UILabel()
        let lines = handoff.lineItems.map { line in
            "\(line.quantity)× \(line.displayLabel ?? line.label)"
        }
        details.text = ([
            "Hold: transferred to native host",
            "Items: \(handoff.lineItems.count)",
        ] + lines).joined(separator: "\n")
        details.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
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
