import Combine
import SeatLayer
import SwiftUI
import UIKit

/// Compiled consumer examples for the public custom-composition surface.
/// The main demo presents the ready UIKit host; these types intentionally stay
/// unreferenced so both alternative integration levels compile on every build.
struct CustomSwiftUIPickerExample: View {
    let configuration: SeatLayerConfiguration
    let onCheckout: SeatLayerPickerCheckoutHandler

    private let options = SeatLayerPickerOptions(
        layout: .phone,
        confirmSelection: true,
        panelInitiallyCollapsed: true
    )

    var body: some View {
        SeatLayerPickerScope(
            options: options,
            themeMode: .auto,
            strings: SeatLayerPickerStrings(localeIdentifier: "en")
        ) { controller in
            ZStack {
                SeatLayerPickerMap(
                    configuration: configuration,
                    options: options,
                    controller: controller
                )
                VStack(spacing: 0) {
                    SeatLayerPickerHeader()
                    SeatLayerPickerPriceLegend()
                    Spacer()
                    SeatLayerPickerDockBar()
                    SeatLayerPickerCartSheet(onCheckout: onCheckout)
                }
            }
        }
    }
}

@MainActor
final class CustomUIKitPickerExample: UIViewController {
    private let mapView: SeatLayerPickerMapView
    private let statusLabel = UILabel()
    private var snapshotSubscription: AnyCancellable?

    init(configuration: SeatLayerConfiguration) {
        let controller = SeatLayerPickerController()
        mapView = SeatLayerPickerMapView(
            configuration: configuration,
            controller: controller
        )
        super.init(nibName: nil, bundle: nil)
        snapshotSubscription = controller.$snapshot.sink { [weak self] snapshot in
            self?.statusLabel.text = snapshot.map {
                "\($0.ticketCount) tickets · revision \($0.revision)"
            } ?? "Loading seats"
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.backgroundColor = .secondarySystemBackground
        statusLabel.textAlignment = .center
        statusLabel.adjustsFontForContentSizeCategory = true
        view.addSubview(mapView)
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { try? await mapView.load() }
    }

    deinit {
        Task { @MainActor [mapView] in await mapView.destroy() }
    }
}
