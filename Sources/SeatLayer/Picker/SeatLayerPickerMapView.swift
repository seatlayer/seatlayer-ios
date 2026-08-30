#if canImport(UIKit)
import UIKit
#if canImport(Combine)
import Combine
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

/// UIKit host for the headless protocol-2 chart.
///
/// The view renders only the map. Applications place their own UIKit controls
/// around it and observe `controller.snapshot` for state.
@MainActor
public final class SeatLayerPickerMapView: UIView {
    public let controller: SeatLayerPickerController

    private var configuration: SeatLayerConfiguration?
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
        let pageURL = configuration.pageURL ?? SeatLayer.mobilePageURL
        let prewarmedHost = SeatLayerPickerPrewarmPool.shared.consume(pageURL: pageURL)
        self.chartView = SeatLayerView(
            frame: .zero,
            bridgeProfile: .picker(
                enable3D: options.enable3D,
                enableSeatView: options.enableSeatView,
                config: options.bridgeConfig
            ),
            pickerController: resolvedController,
            prewarmedHost: prewarmedHost
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
        guard let configuration else { throw SeatLayerError.destroyed }
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
        configuration = nil
        try? await chartView.destroy()
        controller.markDestroyed()
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

#if canImport(SwiftUI)
/// Ready-made UIKit host for the same native component tree exposed to
/// SwiftUI. Use `SeatLayerPickerMapViewController` when the application wants
/// only the headless map and will compose all chrome itself.
@MainActor
public final class SeatLayerPickerViewController: UIHostingController<SeatLayerPicker> {
    public let pickerController: SeatLayerPickerController
    public let presentationModel: SeatLayerPickerPresentationModel
    private let closeHandler: SeatLayerPickerCloseHandler?
    private let pickerConfiguration: SeatLayerConfiguration
    private let pickerOptions: SeatLayerPickerOptions
    private let pickerCallbacks: SeatLayerPickerCallbacks
    private let checkoutHandler: SeatLayerPickerCheckoutHandler
    private let pickerBuilders: SeatLayerPickerBuilders
    private let pickerHapticAdapter: (any SeatLayerPickerHapticAdapter)?
    private var pickerTheme: SeatLayerPickerTheme
    private var pickerThemeMode: SeatLayerPickerThemeMode
    private var pickerStrings: SeatLayerPickerStrings
    private var pickerStyles: SeatLayerPickerStyles
    private var appearanceCancellables: Set<AnyCancellable> = []

    public init(
        configuration: SeatLayerConfiguration,
        controller: SeatLayerPickerController? = nil,
        options: SeatLayerPickerOptions = .init(),
        theme: SeatLayerPickerTheme = .init(),
        themeMode: SeatLayerPickerThemeMode = .auto,
        strings: SeatLayerPickerStrings = .init(),
        styles: SeatLayerPickerStyles = .init(),
        builders: SeatLayerPickerBuilders = .init(),
        hapticAdapter: (any SeatLayerPickerHapticAdapter)? = nil,
        callbacks: SeatLayerPickerCallbacks = .init(),
        onCheckout: @escaping SeatLayerPickerCheckoutHandler,
        onClose: SeatLayerPickerCloseHandler? = nil
    ) {
        let resolved = controller ?? SeatLayerPickerController()
        pickerController = resolved
        let presentation = SeatLayerPickerPresentationModel(controller: resolved, options: options)
        presentationModel = presentation
        closeHandler = onClose
        pickerConfiguration = configuration
        pickerOptions = options
        pickerCallbacks = callbacks
        checkoutHandler = onCheckout
        pickerBuilders = builders
        pickerHapticAdapter = hapticAdapter
        pickerTheme = theme
        pickerThemeMode = themeMode
        pickerStrings = strings
        pickerStyles = styles
        super.init(rootView: SeatLayerPicker(
            configuration: configuration,
            controller: resolved,
            presentation: presentation,
            options: options,
            theme: theme,
            themeMode: themeMode,
            strings: strings,
            styles: styles,
            builders: builders,
            hapticAdapter: hapticAdapter,
            callbacks: callbacks,
            onCheckout: onCheckout,
            onClose: onClose
        ))
        bindSystemAppearance()
    }

    @available(*, unavailable)
    public required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("SeatLayerPickerViewController must be created in code.")
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        let lightForeground = SeatLayerPickerSystemAppearance.prefersLightForeground(
            themeMode: pickerThemeMode,
            systemIsDark: traitCollection.userInterfaceStyle == .dark,
            immersive: pickerController.snapshot?.map.isVenue3D == true
                || pickerController.seatView?.hasContent == true
        )
        return lightForeground ? .lightContent : .darkContent
    }

    public override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }

    /// Hardware Escape and Command-[ consume the same deterministic layer as
    /// the native header and host navigation integration.
    public override var keyCommands: [UIKeyCommand]? {
        // The panorama pixels and their close transition are renderer-owned.
        // Leaving these commands unclaimed lets WKWebView deliver Escape to
        // that surface instead of canceling the still-pending native seat.
        guard pickerController.seatView?.hasContent != true else { return nil }
        return [
            UIKeyCommand(
                input: UIKeyCommand.inputEscape,
                modifierFlags: [],
                action: #selector(performPickerBack)
            ),
            UIKeyCommand(
                input: "[",
                modifierFlags: .command,
                action: #selector(performPickerBack)
            ),
        ]
    }

    public override func accessibilityPerformEscape() -> Bool {
        guard pickerController.seatView?.hasContent != true else { return false }
        performPickerBack()
        return true
    }

    /// The same prompt → cart → confirmation → section → venue → close ladder
    /// used by the ready-made header. UIKit navigation owners can call this
    /// from their back item or interactive-pop coordinator.
    @discardableResult
    public func handleBack() async -> SeatLayerPickerBackStep {
        await presentationModel.back(using: closeHandler)
    }

    public var nextBackStep: SeatLayerPickerBackStep {
        presentationModel.nextBackStep
    }

    /// Re-resolve native and renderer colors in place. The active controller,
    /// renderer view, camera, selection, prompt, and cart remain mounted.
    public func updateAppearance(
        theme: SeatLayerPickerTheme? = nil,
        themeMode: SeatLayerPickerThemeMode? = nil,
        strings: SeatLayerPickerStrings? = nil,
        styles: SeatLayerPickerStyles? = nil
    ) {
        if let theme { pickerTheme = theme }
        if let themeMode { pickerThemeMode = themeMode }
        if let strings { pickerStrings = strings }
        if let styles { pickerStyles = styles }
        rootView = SeatLayerPicker(
            configuration: pickerConfiguration,
            controller: pickerController,
            presentation: presentationModel,
            options: pickerOptions,
            theme: pickerTheme,
            themeMode: pickerThemeMode,
            strings: pickerStrings,
            styles: pickerStyles,
            builders: pickerBuilders,
            hapticAdapter: pickerHapticAdapter,
            callbacks: pickerCallbacks,
            onCheckout: checkoutHandler,
            onClose: closeHandler
        )
        setNeedsStatusBarAppearanceUpdate()
        navigationController?.setNeedsStatusBarAppearanceUpdate()
    }

    @objc private func performPickerBack() {
        Task { @MainActor in _ = await handleBack() }
    }

    private func bindSystemAppearance() {
        pickerController.$snapshot
            .combineLatest(pickerController.$seatView)
            .sink { [weak self] _, _ in
                self?.setNeedsStatusBarAppearanceUpdate()
                self?.navigationController?.setNeedsStatusBarAppearanceUpdate()
            }
            .store(in: &appearanceCancellables)
    }
}
#endif
#endif
