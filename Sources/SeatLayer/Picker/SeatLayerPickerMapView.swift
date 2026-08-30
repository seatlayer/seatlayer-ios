#if canImport(UIKit)
import UIKit

/// UIKit host for the headless protocol-2 chart.
///
/// The view renders only the map. Applications place their own UIKit controls
/// around it and observe `controller.snapshot` for state.
@MainActor
public final class SeatLayerPickerMapView: UIView {
    public let controller: SeatLayerPickerController

    private let configuration: SeatLayerConfiguration
    private let chartView: SeatLayerView
    private var loadTask: Task<ReadyInfo, Error>?

    public init(
        configuration: SeatLayerConfiguration,
        options: SeatLayerPickerOptions = .init(),
        controller: SeatLayerPickerController? = nil
    ) {
        self.configuration = configuration
        let resolvedController = controller ?? SeatLayerPickerController()
        self.controller = resolvedController
        self.chartView = SeatLayerView(
            frame: .zero,
            bridgeProfile: .picker(
                enable3D: options.enable3D,
                enableSeatView: options.enableSeatView,
                config: options.bridgeConfig
            ),
            pickerController: resolvedController
        )
        super.init(frame: .zero)
        setUp()
    }

    public required init?(coder: NSCoder) {
        return nil
    }

    private func setUp() {
        backgroundColor = .clear
        chartView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chartView)
        NSLayoutConstraint.activate([
            chartView.leadingAnchor.constraint(equalTo: leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: trailingAnchor),
            chartView.topAnchor.constraint(equalTo: topAnchor),
            chartView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    /// Start the hosted renderer once and await its protocol-2 handshake.
    @discardableResult
    public func load() async throws -> ReadyInfo {
        if let loadTask { return try await loadTask.value }
        let task = Task { @MainActor [configuration, chartView] in
            try await chartView.load(configuration)
        }
        loadTask = task
        do {
            return try await task.value
        } catch {
            loadTask = nil
            throw error
        }
    }

    /// Tear down the chart and reject subsequent controller actions.
    public func destroy() async {
        loadTask?.cancel()
        loadTask = nil
        try? await controller.destroy()
    }
}

/// Full-screen UIKit convenience around `SeatLayerPickerMapView`.
@MainActor
public final class SeatLayerPickerMapViewController: UIViewController {
    public let pickerMapView: SeatLayerPickerMapView
    public var pickerController: SeatLayerPickerController { pickerMapView.controller }

    public init(
        configuration: SeatLayerConfiguration,
        options: SeatLayerPickerOptions = .init(),
        controller: SeatLayerPickerController? = nil
    ) {
        pickerMapView = SeatLayerPickerMapView(
            configuration: configuration,
            options: options,
            controller: controller
        )
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        return nil
    }

    public override func loadView() {
        view = pickerMapView
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { try? await pickerMapView.load() }
    }
}
#endif
