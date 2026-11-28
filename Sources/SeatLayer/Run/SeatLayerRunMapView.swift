#if canImport(UIKit)
import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

/// UIKit host for the run page.
///
/// The page draws the run: its performances, map, seat card and cart. Place
/// your own bar around it, or use `SeatLayerRunPicker` for the ready one.
@MainActor
public final class SeatLayerRunMapView: UIView {
    public let controller: SeatLayerRunController

    private let configuration: SeatLayerRunConfiguration
    private let chartView: SeatLayerView
    private let loader: SeatLayerSurfaceLoader
    /// The hold the next page opens on, after the system ended the last one.
    private var resuming: SeatLayerRunHandoff?

    /// - Parameter themeMode: The side the page opens on. `.auto` leaves it
    ///   to the page.
    public init(
        configuration: SeatLayerRunConfiguration,
        controller: SeatLayerRunController? = nil,
        themeMode: SeatLayerPickerThemeMode = .auto
    ) {
        let resolved = controller ?? SeatLayerRunController()
        self.controller = resolved
        self.configuration = configuration
        chartView = SeatLayerView(
            frame: .zero,
            bridgeProfile: .group(config: themeMode == .auto ? [:] : ["theme": .string(themeMode.rawValue)]),
            session: resolved
        )
        loader = SeatLayerSurfaceLoader(view: chartView, surface: configuration)
        super.init(frame: .zero)
        resolved.readsHeldOrderOnReady = configuration.initialOperationId != nil
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

    /// Starts the run page once and awaits its handshake.
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
            // A hold that is gone is not a run that did not load: the page
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

    /// The replacement page opens on the buyer's last hold, or on none.
    private func openOnResumedHold() {
        controller.readsHeldOrderOnReady = resuming != nil || configuration.initialOperationId != nil
        chartView.setProfileConfig([
            "initialHoldId": resuming.map { .string($0.holdId) } ?? .null,
            "initialOperationId": resuming.map { .string($0.operationId) } ?? .null,
        ])
    }
}

#if canImport(SwiftUI)
/// SwiftUI host for the run page alone.
public struct SeatLayerRunMap: UIViewRepresentable {
    public typealias UIViewType = SeatLayerRunMapView

    private let configuration: SeatLayerRunConfiguration
    private let controller: SeatLayerRunController
    private let themeMode: SeatLayerPickerThemeMode

    public init(
        configuration: SeatLayerRunConfiguration,
        controller: SeatLayerRunController,
        themeMode: SeatLayerPickerThemeMode = .auto
    ) {
        self.configuration = configuration
        self.controller = controller
        self.themeMode = themeMode
    }

    public func makeUIView(context: Context) -> SeatLayerRunMapView {
        let view = SeatLayerRunMapView(configuration: configuration, controller: controller, themeMode: themeMode)
        Task { @MainActor in _ = try? await view.load() }
        return view
    }

    public func updateUIView(_ uiView: SeatLayerRunMapView, context: Context) {}
}
#endif
#endif
