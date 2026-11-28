#if canImport(UIKit)
import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

/// UIKit host for the Season page.
///
/// The page draws the Season: its package, dates, map and cart. Place your own
/// bar around it, or use `SeatLayerSeasonPicker` for the ready one.
@MainActor
public final class SeatLayerSeasonMapView: UIView {
    public let controller: SeatLayerSeasonController

    private let configuration: SeatLayerSeasonConfiguration
    private let chartView: SeatLayerView
    private let loader: SeatLayerSurfaceLoader
    /// The hold the next page opens on, after the system ended the last one.
    private var resuming: SeatLayerSeasonHandoff?

    /// - Parameter themeMode: The side the page opens on. `.auto` leaves it
    ///   to the page. Follow a later change with `controller.setThemeMode`.
    public convenience init(
        configuration: SeatLayerSeasonConfiguration,
        controller: SeatLayerSeasonController? = nil,
        themeMode: SeatLayerPickerThemeMode = .auto
    ) {
        self.init(configuration: configuration, controller: controller, themeMode: themeMode, again: false)
    }

    /// `again`: the page takes the place of one that was up, so it opens on
    /// the buyer's last hold, not on the hold the configuration opens on.
    init(
        configuration: SeatLayerSeasonConfiguration,
        controller: SeatLayerSeasonController?,
        themeMode: SeatLayerPickerThemeMode,
        again: Bool
    ) {
        let resolved = controller ?? SeatLayerSeasonController()
        self.controller = resolved
        self.configuration = configuration
        chartView = SeatLayerView(
            frame: .zero,
            bridgeProfile: .season(config: themeMode == .auto ? [:] : ["theme": .string(themeMode.rawValue)]),
            session: resolved
        )
        loader = SeatLayerSurfaceLoader(view: chartView, surface: configuration)
        super.init(frame: .zero)
        loader.onPageLost = { [weak self] in
            guard let self else { return }
            resuming = self.controller.hold
            self.controller.dropPage()
        }
        loader.prepareReplacement = { [weak self] in self?.openOnResumedHold() }
        loader.reload = { [weak self] in _ = try? await self?.load() }
        loader.onGiveUp = { [weak self] error in
            self?.resuming = nil
            self?.controller.phase = .failed(error)
        }
        if again {
            resuming = resolved.lastHold
            openOnResumedHold()
        }
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

    public required init?(coder: NSCoder) {
        return nil
    }

    /// Starts the Season page once and awaits its handshake.
    @discardableResult
    public func load() async throws -> ReadyInfo {
        do {
            try configuration.validate()
        } catch let error as SeatLayerError {
            controller.phase = .failed(error)
            throw error
        }
        do {
            return try await loader.load()
        } catch where resuming != nil && !(error is CancellationError) {
            // A hold that is gone is not a Season that did not load: the page
            // opens without it.
            resuming = nil
            openOnResumedHold()
            return try await loader.load()
        }
    }

    /// The buyer's retry after a failure: the steps of a lost page start again.
    public func retry() async throws {
        loader.resetRecovery()
        _ = try await load()
    }

    /// Tears the page down; the controller's commands fail after it.
    public func destroy() async {
        await loader.destroy()
    }

    /// The system ended the page after it was ready.
    func pageLost(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        loader.pageLost(at: now)
    }

    /// The replacement page opens on the buyer's last hold, or on none: the
    /// hold the configuration opens on may be gone.
    private func openOnResumedHold() {
        chartView.setProfileConfig([
            "initialOperationId": resuming.map { .string($0.operationId) } ?? .null,
        ])
    }
}

#if canImport(SwiftUI)
/// SwiftUI host for the Season page alone.
public struct SeatLayerSeasonMap: UIViewRepresentable {
    public typealias UIViewType = SeatLayerSeasonMapView

    private let configuration: SeatLayerSeasonConfiguration
    private let controller: SeatLayerSeasonController
    private let themeMode: SeatLayerPickerThemeMode
    private var again = false

    public init(
        configuration: SeatLayerSeasonConfiguration,
        controller: SeatLayerSeasonController,
        themeMode: SeatLayerPickerThemeMode = .auto
    ) {
        self.configuration = configuration
        self.controller = controller
        self.themeMode = themeMode
    }

    /// A page of the picker's; `again` as on the view.
    init(
        configuration: SeatLayerSeasonConfiguration,
        controller: SeatLayerSeasonController,
        themeMode: SeatLayerPickerThemeMode,
        again: Bool
    ) {
        self.init(configuration: configuration, controller: controller, themeMode: themeMode)
        self.again = again
    }

    public func makeUIView(context: Context) -> SeatLayerSeasonMapView {
        let view = SeatLayerSeasonMapView(
            configuration: configuration,
            controller: controller,
            themeMode: themeMode,
            again: again
        )
        Task { @MainActor in _ = try? await view.load() }
        return view
    }

    public func updateUIView(_ uiView: SeatLayerSeasonMapView, context: Context) {}
}
#endif
#endif
